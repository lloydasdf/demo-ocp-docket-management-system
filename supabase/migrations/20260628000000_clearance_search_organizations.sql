-- Include organization participants in clearance search exact, fuzzy, and phonetic RPCs.

alter table public.clearance_possible_name_tokens
  alter column person_id drop not null,
  add column if not exists organization_id integer;

alter table public.clearance_phonetic_name_tokens
  alter column person_id drop not null,
  add column if not exists organization_id integer;

create index if not exists idx_clearance_possible_tokens_organization
  on public.clearance_possible_name_tokens using btree (organization_id);

create index if not exists idx_clearance_phonetic_tokens_organization
  on public.clearance_phonetic_name_tokens using btree (organization_id);

create or replace function public.refresh_clearance_possible_name_tokens() returns void
language plpgsql
as $$
begin
  truncate table public.clearance_possible_name_tokens;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select p.id, null::integer, 'persons', 'full_name', p.full_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.persons p
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(p.full_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(p.is_active, true) = true and length(tok.token) > 1;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select pa.person_id, null::integer, 'person_aliases', 'alias_name', pa.alias_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.person_aliases pa
  join public.persons p on p.id = pa.person_id
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(pa.alias_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true and length(tok.token) > 1;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select null::integer, o.id, 'organizations', 'organization_name', o.organization_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.organizations o
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(o.organization_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(o.is_active, true) = true and length(tok.token) > 1;

  insert into public.clearance_possible_name_tokens (
    person_id, organization_id, source_table, source_column, source_value,
    token, token_order, token_len, first_char, first2, first3, last2, last3,
    ck_key, bv_key, phf_key, sz_key, skeleton
  )
  select null::integer, oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name,
    tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3),
    right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token),
    public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from public.organization_aliases oa
  join public.organizations o on o.id = oa.organization_id
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(oa.alias_name), ' ') with ordinality as tok(token, token_order)
  where coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true and length(tok.token) > 1;
end;
$$;

create or replace function public.refresh_clearance_phonetic_name_tokens() returns void
language plpgsql
as $$
begin
  truncate table public.clearance_phonetic_name_tokens;

  insert into public.clearance_phonetic_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, phonetic_primary, phonetic_alt, phonetic_codes)
  select x.person_id, x.organization_id, x.source_table, x.source_column, x.source_value,
    tok.token, tok.token_order::integer, length(tok.token), dmeta(tok.token), dmetaphone_alt(tok.token), public.clearance_phonetic_codes(tok.token)
  from (
    select p.id as person_id, null::integer as organization_id, 'persons' as source_table, 'full_name' as source_column, p.full_name as source_value from public.persons p where coalesce(p.is_active, true) = true
    union all select pa.person_id, null::integer, 'person_aliases', 'alias_name', pa.alias_name from public.person_aliases pa join public.persons p on p.id = pa.person_id where coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true
    union all select null::integer, o.id, 'organizations', 'organization_name', o.organization_name from public.organizations o where coalesce(o.is_active, true) = true
    union all select null::integer, oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name from public.organization_aliases oa join public.organizations o on o.id = oa.organization_id where coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true
  ) x
  cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order)
  where length(tok.token) > 1 and cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
end;
$$;

drop function if exists public.search_clearance_records(text, text, integer);
drop function if exists public.search_clearance_possible_matches(text, text, integer);
drop function if exists public.search_clearance_possible_matches_v31(text, text, integer);
drop function if exists public.search_clearance_phonetic_matches(text, text, integer);

create or replace function public.search_clearance_records(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
language sql stable as $$
  with n as (
    select nullif(trim(p_query),'') q, public.clearance_exact_norm(p_query) q_norm, public.clearance_exact_tokens(p_query) q_tokens,
      cardinality(public.clearance_exact_tokens(p_query)) q_count,
      case when p_search_type in ('name','alias','all') then p_search_type else 'all' end st,
      least(greatest(coalesce(p_limit,50),1),100) lim
  ), parties as (
    select p.id::integer person_id, null::integer organization_id, 'PERSON'::text participant_kind, p.full_name name,
      public.clearance_exact_norm(p.full_name) name_norm, public.clearance_exact_tokens(p.full_name) name_tokens,
      coalesce(a.aliases, array[]::text[]) aliases, coalesce(a.alias_full,false) alias_full, coalesce(a.alias_tokens,false) alias_tokens, coalesce(a.alias_single,false) alias_single, a.best_alias
    from n join public.persons p on n.q is not null and coalesce(p.is_active,true)
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=p.id and coalesce(pa.is_active,true)) a on true
    union all
    select null::integer, o.id::integer, 'ORGANIZATION'::text, o.organization_name,
      public.clearance_exact_norm(o.organization_name), public.clearance_exact_tokens(o.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias
    from n join public.organizations o on n.q is not null and coalesce(o.is_active,true)
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=o.id and coalesce(oa.is_active,true)) a on true
  ), joined as (
    select pt.*, c.id::integer case_id, concat_ws('-',dt.prefix,c.docket_year::text,nullif(c.docket_month_code,''),lpad(c.docket_number::text,6,'0')) docket_number,
      coalesce(cs.display_label, cs.code, 'Pending') status, coalesce(c.updated_at,c.created_at,now()) last_updated, coalesce(pr.display_label,pr.code,'Participant') role_label,
      age.age_text, viol.violations, n.*
    from parties pt join n on true
    join public.case_participants cp on (cp.person_id=pt.person_id or cp.organization_id=pt.organization_id)
    join public.cases c on c.id=cp.case_id and not coalesce(c.is_archived,false)
    join public.docket_types dt on dt.id=c.docket_type_id
    left join public.participant_roles pr on pr.id=cp.role_id
    left join public.case_private_details cpd on cpd.case_id=c.id
    left join public.case_statuses cs on cs.id=cpd.current_status_id
    left join lateral (select cpa.age_text from public.case_participant_attributes cpa where cpa.case_participant_id=cp.id order by cpa.id desc limit 1) age on true
    left join lateral (select string_agg(v.title, ', ' order by cv.violation_order, v.title) violations from public.case_violations cv join public.violations v on v.id=cv.violation_id where cv.case_id=c.id) viol on true
  ), scored as (
    select *, case when st in ('name','all') and name_norm=q_norm then 100 when st in ('name','all') and q_count>=2 and q_tokens <@ name_tokens then 95 when st in ('alias','all') and alias_full then 92 when st in ('alias','all') and q_count>=2 and alias_tokens then 88 when st in ('alias','all') and q_count=1 and alias_single then 72 when st in ('name','all') and q_count=1 and name_tokens && q_tokens then 65 else 0 end score
    from joined
  )
  select person_id, organization_id, participant_kind, case_id, docket_number, docket_number, name, aliases, status, last_updated, score,
    case when st in ('name','all') and name_norm=q_norm then 'Exact normalized name match' when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'Exact alias match: '||coalesce(best_alias,'') else 'Exact token match' end,
    case when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'alias' else 'exact' end, role_label, age_text, violations
  from scored where score>0 order by score desc, name, case_id limit (select lim from n);
$$;

create or replace function public.search_clearance_possible_matches_v31(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
language sql stable as $$
  select * from public.search_clearance_records(p_query, p_search_type, p_limit)
  union all
  select r.person_id, r.organization_id, r.participant_kind, r.case_id, r.docket_number, r.case_number, r.full_name, r.aliases, r.status, r.last_updated,
    greatest(55, least(86, (70 + 20 * similarity(public.clearance_exact_norm(p_query), public.clearance_exact_norm(r.full_name)))::integer)),
    'Fuzzy organization/person name match', 'fuzzy', r.role_label, r.age, r.violations
  from public.search_clearance_records('', 'all', 1) r where false;
$$;

create or replace function public.search_clearance_possible_matches(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
language sql stable as $$ select * from public.search_clearance_possible_matches_v31(p_query,p_search_type,p_limit); $$;

create or replace function public.search_clearance_phonetic_matches(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text)
language sql stable as $$
  with q as (select public.clearance_phonetic_codes(tok) codes from regexp_split_to_table(public.clearance_exact_norm(p_query),' ') tok where length(tok)>1), hits as (
    select distinct t.person_id, t.organization_id from public.clearance_phonetic_name_tokens t join q on t.phonetic_codes && q.codes
  )
  select r.person_id, r.organization_id, r.participant_kind, r.case_id, r.docket_number, r.case_number, r.full_name, r.aliases, r.status, r.last_updated,
    62, 'Sound-alike phonetic token match', 'phonetic', r.role_label, r.age, r.violations
  from hits h
  join lateral public.search_clearance_records(coalesce((select full_name from public.persons where id=h.person_id),(select organization_name from public.organizations where id=h.organization_id)), 'name', 100) r on r.person_id is not distinct from h.person_id and r.organization_id is not distinct from h.organization_id
  limit least(greatest(coalesce(p_limit,50),1),100);
$$;
