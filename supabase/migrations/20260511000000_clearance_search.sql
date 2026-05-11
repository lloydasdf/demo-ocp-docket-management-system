-- Live clearance search backed by PostgreSQL fuzzy matching.
-- Run this in Supabase before using the Clearance Search page.

create extension if not exists pg_trgm;
create extension if not exists fuzzystrmatch;

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
  full_name text,
  aliases text[],
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
    select nullif(trim(p_query), '') as q,
           least(greatest(coalesce(p_limit, 50), 1), 100) as safe_limit,
           case when p_search_type in ('name', 'alias', 'all') then p_search_type else 'all' end as search_type
  ), candidate_aliases as (
    select
      pa.person_id,
      array_agg(pa.alias_name order by pa.alias_name) filter (where pa.is_active) as aliases,
      max(similarity(pa.alias_name, normalized.q)) filter (where pa.is_active) as alias_similarity,
      (array_agg(pa.alias_name order by similarity(pa.alias_name, normalized.q) desc) filter (where pa.is_active))[1] as best_alias
    from public.person_aliases pa
    cross join normalized
    group by pa.person_id
  ), scored as (
    select
      p.id as person_id,
      cp.case_id,
      concat_ws('-', dt.prefix, c.docket_year::text, lpad(c.docket_number::text, 4, '0')) as docket_number,
      concat_ws('-', dt.prefix, c.docket_year::text, lpad(c.docket_number::text, 4, '0')) as case_number,
      p.full_name,
      coalesce(ca.aliases, array[]::text[]) as aliases,
      coalesce(cs.display_label, cs.code, 'Pending') as status,
      coalesce(csh.changed_at, c.updated_at, c.created_at) as last_updated,
      greatest(
        case when normalized.search_type in ('name', 'all') then similarity(p.full_name, normalized.q) else 0 end,
        case when normalized.search_type in ('alias', 'all') then coalesce(ca.alias_similarity, 0) else 0 end,
        case when normalized.search_type in ('name', 'all') and dmetaphone(p.full_name) = dmetaphone(normalized.q) then 0.86 else 0 end,
        case when normalized.search_type in ('alias', 'all') and ca.best_alias is not null and dmetaphone(ca.best_alias) = dmetaphone(normalized.q) then 0.82 else 0 end
      ) as raw_score,
      case
        when normalized.search_type in ('name', 'all') and lower(p.full_name) = lower(normalized.q) then 'exact'
        when normalized.search_type in ('alias', 'all') and ca.best_alias is not null and lower(ca.best_alias) = lower(normalized.q) then 'alias'
        when normalized.search_type in ('alias', 'all') and coalesce(ca.alias_similarity, 0) >= similarity(p.full_name, normalized.q) then 'alias'
        when normalized.search_type in ('name', 'all') and dmetaphone(p.full_name) = dmetaphone(normalized.q) then 'phonetic'
        else 'fuzzy'
      end as match_type,
      case
        when normalized.search_type in ('alias', 'all') and ca.best_alias is not null and coalesce(ca.alias_similarity, 0) >= similarity(p.full_name, normalized.q)
          then 'Alias match: ' || ca.best_alias
        when normalized.search_type in ('name', 'all') and dmetaphone(p.full_name) = dmetaphone(normalized.q)
          then 'Phonetic match: ' || p.full_name
        else 'Name match: ' || p.full_name
      end as match_details,
      coalesce(pr.display_label, pr.code, 'Participant') as role_label,
      normalized.safe_limit,
      normalized.q
    from normalized
    join public.persons p on normalized.q is not null and p.is_active
    join public.case_participants cp on cp.person_id = p.id
    join public.cases c on c.id = cp.case_id and not c.is_archived
    join public.docket_types dt on dt.id = c.docket_type_id
    left join public.participant_roles pr on pr.id = cp.role_id
    left join candidate_aliases ca on ca.person_id = p.id
    left join lateral (
      select h.to_status_id, h.changed_at
      from public.case_status_history h
      where h.case_id = c.id
      order by h.changed_at desc
      limit 1
    ) csh on true
    left join public.case_statuses cs on cs.id = csh.to_status_id
  )
  select
    person_id,
    case_id,
    docket_number,
    case_number,
    full_name,
    aliases,
    status,
    last_updated,
    least(100, greatest(0, round(raw_score * 100)::integer)) as confidence_score,
    match_details,
    match_type,
    role_label
  from scored
  where q is not null
    and (
      raw_score >= 0.25
      or full_name % q
      or exists (select 1 from unnest(aliases) as alias_name(alias_value) where alias_value % q)
    )
  order by raw_score desc, last_updated desc
  limit (select safe_limit from normalized);
$$;

create index if not exists idx_persons_full_name_trgm
  on public.persons using gin (full_name gin_trgm_ops);

create index if not exists idx_person_aliases_alias_name_trgm
  on public.person_aliases using gin (alias_name gin_trgm_ops);
