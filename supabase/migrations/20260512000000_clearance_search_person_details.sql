-- Include person age and case violations in clearance search results.

drop function if exists public.search_clearance_records(text, text, integer);

create or replace function public.search_clearance_records(
  p_query text,
  p_search_type text default 'all',
  p_limit integer default 50
)
returns table (
  person_id integer,
  case_id integer,
  docket_number text,
  case_number text,
  violations text,
  full_name text,
  aliases text[],
  age text,
  status text,
  last_updated timestamptz,
  confidence_score integer,
  match_details text,
  match_type text,
  role_label text
)
language sql
stable
as $$
  with normalized as (
    select
      q,
      least(greatest(coalesce(p_limit, 50), 1), 100) as safe_limit,
      case when p_search_type in ('name', 'alias', 'all') then p_search_type else 'all' end as search_type,
      q_norm,
      coalesce(q_tokens, array[]::text[]) as q_tokens,
      cardinality(coalesce(q_tokens, array[]::text[])) as q_token_count
    from (
      select
        nullif(trim(p_query), '') as q,
        nullif(trim(regexp_replace(lower(trim(p_query)), '[^a-z0-9]+', ' ', 'g')), '') as q_norm
    ) input
    left join lateral (
      select array_agg(token order by token) as q_tokens
      from regexp_split_to_table(coalesce(input.q_norm, ''), ' ') as token
      where length(token) > 1
    ) query_tokens on true
  ), alias_rows as (
    select
      pa.person_id,
      pa.alias_name,
      greatest(
        case when nullif(trim(regexp_replace(lower(coalesce(pa.alias_name, '')), '[^a-z0-9]+', ' ', 'g')), '') = normalized.q_norm then 0.98 else 0 end,
        case when alias_metrics.all_query_tokens_exact and normalized.q_token_count >= 2 then 0.92 else 0 end,
        case when alias_metrics.all_query_tokens_exact and normalized.q_token_count = 1 then 0.74 else 0 end,
        case when alias_metrics.all_query_tokens_prefix and normalized.q_token_count >= 2 then 0.84 else 0 end,
        case when alias_metrics.all_query_tokens_prefix and normalized.q_token_count = 1 then 0.80 else 0 end,
        case when alias_metrics.phonetic_token_matches = normalized.q_token_count and normalized.q_token_count >= 2 then 0.70 else 0 end,
        case when alias_metrics.phonetic_token_matches > 0 then 0.56 else 0 end,
        least(similarity(coalesce(pa.alias_name, ''), normalized.q), 0.86),
        least(alias_metrics.best_token_similarity * 0.95, 0.72)
      ) as alias_score,
      case
        when nullif(trim(regexp_replace(lower(coalesce(pa.alias_name, '')), '[^a-z0-9]+', ' ', 'g')), '') = normalized.q_norm then 'Exact alias match: ' || pa.alias_name
        when alias_metrics.all_query_tokens_exact then 'Exact alias token match: ' || pa.alias_name
        when alias_metrics.all_query_tokens_prefix then 'Alias prefix match: ' || pa.alias_name
        when alias_metrics.phonetic_token_matches > 0 then 'Phonetic alias token match: ' || pa.alias_name
        else 'Alias fuzzy match: ' || pa.alias_name
      end as alias_details
    from public.person_aliases pa
    cross join normalized
    left join lateral (
      select
        coalesce(alias_tokens.tokens, array[]::text[]) as tokens,
        normalized.q_token_count > 0
          and normalized.q_tokens <@ coalesce(alias_tokens.tokens, array[]::text[]) as all_query_tokens_exact,
        normalized.q_token_count > 0
          and not exists (
            select 1
            from unnest(normalized.q_tokens) as query_token(value)
            where length(query_token.value) < 3
              or not exists (
                select 1
                from unnest(coalesce(alias_tokens.tokens, array[]::text[])) as alias_token(value)
                where alias_token.value like query_token.value || '%'
                  or replace(alias_token.value, 'v', 'b') like replace(query_token.value, 'v', 'b') || '%'
              )
          ) as all_query_tokens_prefix,
        coalesce((
          select count(*)::integer
          from unnest(normalized.q_tokens) as query_token(value)
          where length(query_token.value) >= 4
            and exists (
              select 1
              from unnest(coalesce(alias_tokens.tokens, array[]::text[])) as alias_token(value)
              where length(alias_token.value) >= 4
                and (
                  dmetaphone(alias_token.value) = dmetaphone(query_token.value)
                  or dmetaphone(replace(alias_token.value, 'v', 'b')) = dmetaphone(replace(query_token.value, 'v', 'b'))
                )
            )
        ), 0) as phonetic_token_matches,
        coalesce((
          select max(greatest(
            similarity(alias_token.value, query_token.value),
            similarity(replace(alias_token.value, 'v', 'b'), replace(query_token.value, 'v', 'b'))
          ))
          from unnest(normalized.q_tokens) as query_token(value)
          cross join unnest(coalesce(alias_tokens.tokens, array[]::text[])) as alias_token(value)
        ), 0) as best_token_similarity
      from (
        select array_agg(token order by token) as tokens
        from regexp_split_to_table(
          coalesce(nullif(trim(regexp_replace(lower(coalesce(pa.alias_name, '')), '[^a-z0-9]+', ' ', 'g')), ''), ''),
          ' '
        ) as token
        where length(token) > 1
      ) alias_tokens
    ) alias_metrics on true
    where pa.is_active
      and normalized.q is not null
      and normalized.search_type in ('alias', 'all')
  ), candidate_aliases as (
    select
      person_id,
      array_agg(alias_name order by alias_name) as aliases,
      max(alias_score) as alias_score,
      (array_agg(alias_name order by alias_score desc, alias_name))[1] as best_alias,
      (array_agg(alias_details order by alias_score desc, alias_name))[1] as alias_details
    from alias_rows
    group by person_id
  ), base as (
    select
      p.id as person_id,
      cp.case_id,
      concat_ws('-', dt.prefix, c.docket_year::text, lpad(c.docket_number::text, 4, '0')) as docket_number,
      concat_ws('-', dt.prefix, c.docket_year::text, lpad(c.docket_number::text, 4, '0')) as case_number,
      p.full_name,
      coalesce(ca.aliases, array[]::text[]) as aliases,
      p.age,
      coalesce(cv.violations, c.summary_text, '—') as violations,
      coalesce(ca.alias_score, 0) as alias_score,
      ca.alias_details,
      coalesce(cs.display_label, cs.code, 'Pending') as status,
      coalesce(csh.changed_at, c.updated_at, c.created_at) as last_updated,
      coalesce(pr.display_label, pr.code, 'Participant') as role_label,
      normalized.safe_limit,
      normalized.search_type,
      normalized.q,
      normalized.q_norm,
      normalized.q_tokens,
      normalized.q_token_count
    from normalized
    join public.persons p on normalized.q is not null and p.is_active
    join public.case_participants cp on cp.person_id = p.id
    join public.cases c on c.id = cp.case_id and not c.is_archived
    join public.docket_types dt on dt.id = c.docket_type_id
    left join public.participant_roles pr on pr.id = cp.role_id
    left join candidate_aliases ca on ca.person_id = p.id
    left join lateral (
      select string_agg(coalesce(v.short_label, v.title, cv.raw_violation_text), ', ' order by cv.violation_order nulls last, cv.id) as violations
      from public.case_violations cv
      left join public.violations v on v.id = cv.violation_id
      where cv.case_id = c.id
    ) cv on true
    left join lateral (
      select h.to_status_id, h.changed_at
      from public.case_status_history h
      where h.case_id = c.id
      order by h.changed_at desc
      limit 1
    ) csh on true
    left join public.case_statuses cs on cs.id = csh.to_status_id
  ), scored as (
    select
      base.*,
      name_metrics.exact_name_match,
      name_metrics.exact_unordered_name_match,
      name_metrics.all_query_tokens_exact,
      name_metrics.all_query_tokens_prefix,
      name_metrics.phonetic_token_matches,
      name_metrics.best_prefix_token,
      greatest(
        case when base.search_type in ('name', 'all') and name_metrics.exact_name_match then 1.00 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.exact_unordered_name_match then 1.00 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_exact and base.q_token_count >= 2 then 0.94 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_exact and base.q_token_count = 1 then 0.76 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_prefix and base.q_token_count >= 2 then 0.86 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.all_query_tokens_prefix and base.q_token_count = 1 then 0.82 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.phonetic_token_matches = base.q_token_count and base.q_token_count >= 2 then 0.72 else 0 end,
        case when base.search_type in ('name', 'all') and name_metrics.phonetic_token_matches > 0 then 0.58 else 0 end,
        case when base.search_type in ('name', 'all') then least(similarity(coalesce(base.full_name, ''), base.q), 0.89) else 0 end,
        case when base.search_type in ('name', 'all') then least(name_metrics.best_token_similarity * 0.95, 0.74) else 0 end
      ) as name_score
    from base
    left join lateral (
      select
        nullif(trim(regexp_replace(lower(coalesce(base.full_name, '')), '[^a-z0-9]+', ' ', 'g')), '') = base.q_norm as exact_name_match,
        base.q_token_count > 0
          and base.q_token_count = cardinality(coalesce(name_tokens.tokens, array[]::text[]))
          and base.q_tokens = coalesce(name_tokens.tokens, array[]::text[]) as exact_unordered_name_match,
        base.q_token_count > 0
          and base.q_tokens <@ coalesce(name_tokens.tokens, array[]::text[]) as all_query_tokens_exact,
        base.q_token_count > 0
          and not exists (
            select 1
            from unnest(base.q_tokens) as query_token(value)
            where length(query_token.value) < 3
              or not exists (
                select 1
                from unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
                where name_token.value like query_token.value || '%'
                  or replace(name_token.value, 'v', 'b') like replace(query_token.value, 'v', 'b') || '%'
              )
          ) as all_query_tokens_prefix,
        coalesce((
          select count(*)::integer
          from unnest(base.q_tokens) as query_token(value)
          where length(query_token.value) >= 4
            and exists (
              select 1
              from unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
              where length(name_token.value) >= 4
                and (
                  dmetaphone(name_token.value) = dmetaphone(query_token.value)
                  or dmetaphone(replace(name_token.value, 'v', 'b')) = dmetaphone(replace(query_token.value, 'v', 'b'))
                )
            )
        ), 0) as phonetic_token_matches,
        (
          select name_token.value
          from unnest(base.q_tokens) as query_token(value)
          join unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
            on name_token.value like query_token.value || '%'
              or replace(name_token.value, 'v', 'b') like replace(query_token.value, 'v', 'b') || '%'
          order by length(name_token.value), name_token.value
          limit 1
        ) as best_prefix_token,
        coalesce((
          select max(greatest(
            similarity(name_token.value, query_token.value),
            similarity(replace(name_token.value, 'v', 'b'), replace(query_token.value, 'v', 'b'))
          ))
          from unnest(base.q_tokens) as query_token(value)
          cross join unnest(coalesce(name_tokens.tokens, array[]::text[])) as name_token(value)
        ), 0) as best_token_similarity
      from (
        select array_agg(token order by token) as tokens
        from regexp_split_to_table(
          coalesce(nullif(trim(regexp_replace(lower(coalesce(base.full_name, '')), '[^a-z0-9]+', ' ', 'g')), ''), ''),
          ' '
        ) as token
        where length(token) > 1
      ) name_tokens
    ) name_metrics on true
  ), ranked as (
    select
      *,
      greatest(name_score, alias_score) as raw_score
    from scored
  )
  select
    person_id,
    case_id,
    docket_number,
    case_number,
    violations,
    full_name,
    aliases,
    age,
    status,
    last_updated,
    least(100, greatest(0, round(raw_score * 100)::integer)) as confidence_score,
    case
      when alias_score > name_score and alias_score >= 0.45 then alias_details
      when exact_name_match or exact_unordered_name_match then 'Exact name match: ' || full_name
      when all_query_tokens_exact then 'Exact name token match: ' || full_name
      when all_query_tokens_prefix then 'Name prefix match: ' || coalesce(best_prefix_token, full_name)
      when phonetic_token_matches > 0 then 'Phonetic token match: ' || full_name
      else 'Name fuzzy match: ' || full_name
    end as match_details,
    case
      when alias_score > name_score and alias_score >= 0.45 then 'alias'
      when exact_name_match or exact_unordered_name_match or (all_query_tokens_exact and q_token_count >= 2) then 'exact'
      when phonetic_token_matches > 0 and name_score <= 0.72 then 'phonetic'
      else 'fuzzy'
    end as match_type,
    role_label
  from ranked
  where q is not null
    and raw_score >= 0.45
  order by raw_score desc, last_updated desc, full_name
  limit (select safe_limit from normalized);
$$;
