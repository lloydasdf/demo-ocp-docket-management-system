-- Refactor clearance search RPCs into two-stage candidate search + shared formatter.

drop function if exists public.search_clearance_phonetic_matches(text, text, integer);
drop function if exists public.search_clearance_possible_matches(text, text, integer);
drop function if exists public.search_clearance_possible_matches_v31(text, text, integer);
drop function if exists public.search_clearance_records(text, text, integer);
drop function if exists public.format_clearance_search_results(jsonb, integer);
drop function if exists public.search_clearance_exact_candidates(text, text, integer);

create index if not exists idx_case_participants_person_id_case_id on public.case_participants(person_id, case_id) where person_id is not null;
create index if not exists idx_case_participants_organization_id_case_id on public.case_participants(organization_id, case_id) where organization_id is not null;
create index if not exists idx_case_participant_corrections_case_participant_id on public.case_participant_corrections(case_participant_id);

create or replace function public.format_clearance_search_results(p_candidates jsonb, p_limit integer default 50)
returns table(
  person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text,
  is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text
)
language sql stable as $$
  with input_candidates as materialized (
    select *
    from jsonb_to_recordset(coalesce(p_candidates, '[]'::jsonb)) as c(
      person_id integer, organization_id integer, participant_kind text, confidence_score integer, match_details text, match_type text, match_source text, result_group text, correction_id bigint,
      full_name text, aliases text[], is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb
    )
  ), limited_candidates as materialized (
    select distinct on (result_group, person_id, organization_id, match_source, correction_id)
      *
    from input_candidates
    where person_id is not null or organization_id is not null or correction_id is not null
    order by result_group, person_id nulls last, organization_id nulls last, match_source, correction_id nulls last, confidence_score desc
    limit least(greatest(coalesce(p_limit, 50), 1), 100) * 4
  ), joined as (
    select lc.person_id, lc.organization_id, coalesce(lc.participant_kind, case when lc.organization_id is not null then 'ORGANIZATION' else 'PERSON' end) participant_kind,
      c.id::integer case_id,
      concat_ws('-', dt.prefix, c.docket_year::text, nullif(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0')) docket_number,
      coalesce(lc.full_name, p.full_name, o.organization_name) full_name,
      coalesce(lc.aliases, pa.aliases, oa.aliases, array[]::text[]) aliases,
      coalesce(cs.display_label, cs.code, 'Pending') status,
      coalesce(c.updated_at, c.created_at, now()) last_updated,
      lc.confidence_score, lc.match_details, lc.match_type,
      coalesce(pr.display_label, pr.code, 'Participant') role_label,
      age.age_text, viol.violations,
      coalesce(lc.is_voided, false) is_voided, coalesce(lc.is_corrected, false) is_corrected, lc.replaced_by_person_id, lc.active_person_id, lc.correction_reason, lc.corrected_at, lc.corrected_by, lc.old_snapshot_json, lc.new_snapshot_json,
      coalesce(lc.result_group, 'active') result_group, coalesce(lc.match_source, lc.match_type) match_source
    from limited_candidates lc
    join public.case_participants cp on (
      (lc.correction_id is not null and cp.id = (select cpc.case_participant_id from public.case_participant_corrections cpc where cpc.id = lc.correction_id))
      or (lc.correction_id is null and ((lc.person_id is not null and cp.person_id = lc.person_id) or (lc.organization_id is not null and cp.organization_id = lc.organization_id)))
    )
    join public.cases c on c.id = cp.case_id and not coalesce(c.is_archived, false)
    join public.docket_types dt on dt.id = c.docket_type_id
    left join public.persons p on p.id = lc.person_id
    left join public.organizations o on o.id = lc.organization_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases from public.person_aliases pa where pa.person_id = lc.person_id and coalesce(pa.is_active, true)) pa on true
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases from public.organization_aliases oa where oa.organization_id = lc.organization_id and coalesce(oa.is_active, true)) oa on true
    left join public.participant_roles pr on pr.id = cp.role_id
    left join public.case_private_details cpd on cpd.case_id = c.id
    left join public.case_statuses cs on cs.id = cpd.current_status_id
    left join lateral (select cpa.age_text from public.case_participant_attributes cpa where cpa.case_participant_id = cp.id order by cpa.id desc limit 1) age on true
    left join lateral (select string_agg(v.title, ', ' order by cv.violation_order, v.title) violations from public.case_violations cv join public.violations v on v.id = cv.violation_id where cv.case_id = c.id) viol on true
  ), deduped as (
    select distinct on (result_group, person_id, organization_id, case_id, match_source)
      person_id, organization_id, participant_kind, case_id, docket_number, docket_number::text case_number, full_name, aliases, status, last_updated, confidence_score, match_details, match_type, role_label, age_text age, violations,
      is_voided, is_corrected, replaced_by_person_id, active_person_id, correction_reason, corrected_at, corrected_by, old_snapshot_json, new_snapshot_json, result_group, match_source
    from joined
    order by result_group, person_id nulls last, organization_id nulls last, case_id, match_source, confidence_score desc
  )
  select * from deduped
  order by case when result_group = 'active' then 0 else 1 end, confidence_score desc, full_name, case_id
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;
create or replace function public.search_clearance_exact_candidates(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer,
  organization_id integer,
  participant_kind text,
  confidence_score integer,
  match_details text,
  match_type text,
  match_source text,
  result_group text,
  correction_id bigint,
  full_name text,
  aliases text[],
  is_voided boolean,
  is_corrected boolean,
  replaced_by_person_id integer,
  active_person_id integer,
  correction_reason text,
  corrected_at timestamptz,
  corrected_by text,
  old_snapshot_json jsonb,
  new_snapshot_json jsonb
)
language sql stable as $$
  with n as (
    select nullif(trim(p_query),'') q, public.clearance_exact_norm(p_query) q_norm, public.clearance_exact_tokens(p_query) q_tokens,
      cardinality(public.clearance_exact_tokens(p_query)) q_count,
      case when p_search_type in ('name','alias','all') then p_search_type else 'all' end st,
      least(greatest(coalesce(p_limit,50),1),100) lim
  ), parties as (
    select p.id::integer person_id, null::integer organization_id, 'PERSON'::text participant_kind,
      p.full_name official_name, p.full_name search_name,
      public.clearance_exact_norm(p.full_name) name_norm, public.clearance_exact_tokens(p.full_name) name_tokens,
      coalesce(a.aliases, array[]::text[]) aliases, coalesce(a.alias_full,false) alias_full, coalesce(a.alias_tokens,false) alias_tokens, coalesce(a.alias_single,false) alias_single, a.best_alias,
      false is_voided, false is_corrected, null::integer replaced_by_person_id, p.id::integer active_person_id,
      null::bigint correction_id, null::text correction_reason, null::timestamptz corrected_at, null::text corrected_by,
      null::jsonb old_snapshot_json, null::jsonb new_snapshot_json, 'active'::text result_group, 'active_name'::text match_source
    from n join public.persons p on n.q is not null and coalesce(p.is_active,true) and not coalesce(p.is_voided,false)
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=p.id and coalesce(pa.is_active,true)) a on true

    union all
    select oldp.id::integer, null::integer, 'PERSON'::text,
      oldp.full_name, oldp.full_name,
      public.clearance_exact_norm(oldp.full_name), public.clearance_exact_tokens(oldp.full_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      coalesce(oldp.is_voided,false), cpc.id is not null, oldp.replaced_by_person_id::integer, coalesce(oldp.replaced_by_person_id, cpc.new_person_id, oldp.id)::integer,
      cpc.id, coalesce(cpc.reason, oldp.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'inactive'::text, 'voided_previous_name'::text
    from n join public.persons oldp on n.q is not null and (coalesce(oldp.is_voided,false) or not coalesce(oldp.is_active,true))
    left join public.case_participant_corrections cpc on cpc.old_person_id = oldp.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=oldp.id and coalesce(pa.is_active,true)) a on true

    union all
    select newp.id::integer, null::integer, 'PERSON'::text,
      newp.full_name, oldp.full_name,
      public.clearance_exact_norm(oldp.full_name), public.clearance_exact_tokens(oldp.full_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      false, true, oldp.replaced_by_person_id::integer, newp.id::integer,
      cpc.id, coalesce(cpc.reason, oldp.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'active'::text, 'voided_previous_name'::text
    from n
    join public.persons oldp on n.q is not null and coalesce(oldp.is_voided,false) and oldp.replaced_by_person_id is not null
    join public.persons newp on newp.id = oldp.replaced_by_person_id and coalesce(newp.is_active,true) and not coalesce(newp.is_voided,false)
    left join public.case_participant_corrections cpc on cpc.old_person_id = oldp.id and cpc.new_person_id = newp.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases, bool_or(public.clearance_exact_norm(pa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(pa.alias_name) && n.q_tokens) alias_single, (array_agg(pa.alias_name order by case when public.clearance_exact_norm(pa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(pa.alias_name) then 2 else 3 end, pa.alias_name))[1] best_alias from public.person_aliases pa where pa.person_id=newp.id and coalesce(pa.is_active,true)) a on true

    union all
    select null::integer, o.id::integer, 'ORGANIZATION'::text, o.organization_name, o.organization_name,
      public.clearance_exact_norm(o.organization_name), public.clearance_exact_tokens(o.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      false, false, null::integer, null::integer, null::bigint, null::text, null::timestamptz, null::text, null::jsonb, null::jsonb, 'active'::text, 'active_name'::text
    from n join public.organizations o on n.q is not null and coalesce(o.is_active,true) and not coalesce(o.is_voided,false)
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=o.id and coalesce(oa.is_active,true)) a on true

    union all
    select null::integer, oldo.id::integer, 'ORGANIZATION'::text, oldo.organization_name, oldo.organization_name,
      public.clearance_exact_norm(oldo.organization_name), public.clearance_exact_tokens(oldo.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      coalesce(oldo.is_voided,false), cpc.id is not null, null::integer, null::integer,
      cpc.id, coalesce(cpc.reason, oldo.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'inactive'::text, 'voided_previous_name'::text
    from n join public.organizations oldo on n.q is not null and (coalesce(oldo.is_voided,false) or not coalesce(oldo.is_active,true))
    left join public.case_participant_corrections cpc on cpc.old_organization_id = oldo.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=oldo.id and coalesce(oa.is_active,true)) a on true

    union all
    select null::integer, newo.id::integer, 'ORGANIZATION'::text, newo.organization_name, oldo.organization_name,
      public.clearance_exact_norm(oldo.organization_name), public.clearance_exact_tokens(oldo.organization_name),
      coalesce(a.aliases, array[]::text[]), coalesce(a.alias_full,false), coalesce(a.alias_tokens,false), coalesce(a.alias_single,false), a.best_alias,
      false, true, null::integer, null::integer,
      cpc.id, coalesce(cpc.reason, oldo.void_reason), cpc.corrected_at, coalesce(s.full_name, prc.full_name, u.email, case when cpc.corrected_by_user_id is not null then 'User #' || cpc.corrected_by_user_id::text end),
      cpc.old_snapshot_json, cpc.new_snapshot_json, 'active'::text, 'voided_previous_name'::text
    from n
    join public.organizations oldo on n.q is not null and coalesce(oldo.is_voided,false) and oldo.replaced_by_organization_id is not null
    join public.organizations newo on newo.id = oldo.replaced_by_organization_id and coalesce(newo.is_active,true) and not coalesce(newo.is_voided,false)
    left join public.case_participant_corrections cpc on cpc.old_organization_id = oldo.id and cpc.new_organization_id = newo.id
    left join public.users u on u.id = cpc.corrected_by_user_id
    left join public.staff s on s.id = u.staff_id
    left join public.prosecutors prc on prc.id = u.prosecutor_id
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases, bool_or(public.clearance_exact_norm(oa.alias_name)=n.q_norm) alias_full, bool_or(n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name)) alias_tokens, bool_or(n.q_count=1 and public.clearance_exact_tokens(oa.alias_name) && n.q_tokens) alias_single, (array_agg(oa.alias_name order by case when public.clearance_exact_norm(oa.alias_name)=n.q_norm then 1 when n.q_count>0 and n.q_tokens <@ public.clearance_exact_tokens(oa.alias_name) then 2 else 3 end, oa.alias_name))[1] best_alias from public.organization_aliases oa where oa.organization_id=newo.id and coalesce(oa.is_active,true)) a on true
  ), scored as (
    select *, case when st in ('name','all') and name_norm=q_norm then 100 when st in ('name','all') and q_count>=2 and q_tokens <@ name_tokens then 95 when st in ('alias','all') and alias_full then 92 when st in ('alias','all') and q_count>=2 and alias_tokens then 88 when st in ('alias','all') and q_count=1 and alias_single then 72 when st in ('name','all') and q_count=1 and name_tokens && q_tokens then 65 else 0 end score
    from parties join n on true
  ), deduped as (
    select distinct on (result_group, person_id, organization_id, match_source, correction_id)
      person_id, organization_id, participant_kind, score confidence_score,
      case when match_source = 'voided_previous_name' and result_group = 'active' then 'Matched previous corrected name: ' || search_name when match_source = 'voided_previous_name' then 'Matched voided/corrected previous name' when st in ('name','all') and name_norm=q_norm then 'Exact normalized name match' when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'Exact alias match: '||coalesce(best_alias,'') else 'Exact token match' end match_details,
      case when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'alias' else 'exact' end match_type,
      match_source, result_group, correction_id, official_name full_name, aliases, is_voided, is_corrected, replaced_by_person_id, active_person_id, correction_reason, corrected_at, corrected_by, old_snapshot_json, new_snapshot_json
    from scored where score>0
    order by result_group, person_id nulls last, organization_id nulls last, match_source, correction_id nulls last, score desc
  )
  select * from deduped order by case when result_group='active' then 0 else 1 end, confidence_score desc, full_name limit least(greatest(coalesce(p_limit,50),1),100);
$$;

create or replace function public.search_clearance_records(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text,
  is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text
)
language sql stable as $$
  select * from public.format_clearance_search_results(
    (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from public.search_clearance_exact_candidates(p_query, p_search_type, least(greatest(coalesce(p_limit, 50), 1), 100)) c),
    p_limit
  );
$$;

create or replace function public.search_clearance_possible_matches_v31(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text,
  is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text
)
language sql stable as $$
  with normalized as (
    select nullif(trim(p_query), '') q, public.clearance_exact_tokens(p_query) q_tokens, cardinality(public.clearance_exact_tokens(p_query)) q_token_count, case when p_search_type in ('name', 'alias', 'all') then p_search_type else 'all' end search_type, least(greatest(coalesce(p_limit, 50), 1), 100) safe_limit
  ), query_tokens as (
    select u.token, length(u.token) token_len, left(u.token, 1) first_char, left(u.token, 2) first2, right(u.token, 2) last2, public.clearance_ck_key(u.token) ck_key, public.clearance_bv_key(u.token) bv_key, public.clearance_phf_key(u.token) phf_key, public.clearance_sz_key(u.token) sz_key, public.clearance_token_skeleton(u.token) skeleton
    from normalized n cross join lateral unnest(n.q_tokens) u(token)
  ), raw_token_candidates as materialized (
    select t.person_id, t.organization_id, t.source_value, t.source_table, q.token query_token,
      case when t.token = q.token then 'exact' when t.ck_key = q.ck_key then 'c/k variant' when t.bv_key = q.bv_key then 'b/v variant' when t.phf_key = q.phf_key then 'ph/f variant' when t.sz_key = q.sz_key then 's/z variant' when t.skeleton = q.skeleton then 'skeleton variant' else 'fuzzy' end raw_reason,
      case when t.token = q.token then 1 when t.ck_key = q.ck_key or t.bv_key = q.bv_key or t.phf_key = q.phf_key or t.sz_key = q.sz_key then 2 when t.skeleton = q.skeleton then 3 else 4 end raw_priority
    from query_tokens q
    join public.clearance_possible_name_tokens t on (t.token = q.token or t.ck_key = q.ck_key or t.bv_key = q.bv_key or t.phf_key = q.phf_key or t.sz_key = q.sz_key or (q.token_len >= 4 and t.token_len >= 4 and t.skeleton = q.skeleton) or (q.token_len >= 4 and t.token_len >= 4 and t.first2 = q.first2 and t.last2 = q.last2) or (q.token_len >= 5 and t.token_len >= 5 and t.first_char = q.first_char and levenshtein_less_equal(t.token, q.token, 2) <= 2))
    join normalized n on true
    where n.q is not null and (n.search_type = 'all' or (n.search_type = 'name' and t.source_table in ('persons', 'organizations')) or (n.search_type = 'alias' and t.source_table in ('person_aliases', 'organization_aliases')))
  ), entity_candidates as materialized (
    select person_id, organization_id, min(raw_priority) best_priority, count(distinct query_token) matched_query_tokens, (array_agg(source_value order by raw_priority, source_value))[1] best_source_value, string_agg(distinct raw_reason, ', ' order by raw_reason) reasons
    from raw_token_candidates group by person_id, organization_id
    order by min(raw_priority), count(distinct query_token) desc
    limit (select safe_limit * 3 from normalized)
  ), fuzzy_candidates as (
    select ec.person_id, ec.organization_id, case when ec.organization_id is not null then 'ORGANIZATION' else 'PERSON' end participant_kind,
      greatest(55, least(89, 58 + case when ec.matched_query_tokens >= (select q_token_count from normalized) and (select q_token_count from normalized) >= 2 then 18 else 0 end + case ec.best_priority when 1 then 10 when 2 then 8 when 3 then 6 else 3 end + least(8, ec.matched_query_tokens * 2)))::integer confidence_score,
      'Possible fuzzy token match (' || ec.reasons || '): ' || coalesce(ec.best_source_value, p.full_name, o.organization_name) match_details,
      case when ec.best_priority <= 2 then 'variant' else 'fuzzy' end match_type,
      case when ec.best_priority <= 2 then 'possible_variant' else 'possible_fuzzy' end match_source,
      case when coalesce(p.is_voided, o.is_voided, false) or not coalesce(p.is_active, o.is_active, true) then 'inactive' else 'active' end result_group,
      null::bigint correction_id, coalesce(p.full_name, o.organization_name, ec.best_source_value) full_name,
      coalesce(pa.aliases, oa.aliases, array[]::text[]) aliases, coalesce(p.is_voided, o.is_voided, false) is_voided, false is_corrected, p.replaced_by_person_id::integer, coalesce(p.replaced_by_person_id, p.id)::integer active_person_id,
      coalesce(p.void_reason, o.void_reason) correction_reason, null::timestamptz corrected_at, null::text corrected_by, null::jsonb old_snapshot_json, null::jsonb new_snapshot_json
    from entity_candidates ec
    left join public.persons p on p.id = ec.person_id
    left join public.organizations o on o.id = ec.organization_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases from public.person_aliases pa where pa.person_id = ec.person_id and coalesce(pa.is_active, true)) pa on true
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases from public.organization_aliases oa where oa.organization_id = ec.organization_id and coalesce(oa.is_active, true)) oa on true
    where ec.matched_query_tokens > 0
  ), combined as (
    select * from public.search_clearance_exact_candidates(p_query, p_search_type, (select safe_limit from normalized))
    union all select * from fuzzy_candidates
  )
  select * from public.format_clearance_search_results((select coalesce(jsonb_agg(to_jsonb(c) order by confidence_score desc), '[]'::jsonb) from combined c), (select safe_limit from normalized));
$$;

create or replace function public.search_clearance_possible_matches(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text,
  is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text
)
language sql stable as $$ select * from public.search_clearance_possible_matches_v31(p_query,p_search_type,p_limit); $$;

create or replace function public.search_clearance_phonetic_matches(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text,
  is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text
)
language sql stable as $$
  with q as (
    select public.clearance_phonetic_codes(tok) codes from regexp_split_to_table(public.clearance_exact_norm(p_query), ' ') tok where length(tok) > 1
  ), hits as materialized (
    select distinct t.person_id, t.organization_id
    from public.clearance_phonetic_name_tokens t join q on t.phonetic_codes && q.codes
    limit least(greatest(coalesce(p_limit, 50), 1), 100) * 3
  ), candidates as (
    select h.person_id, h.organization_id, case when h.organization_id is not null then 'ORGANIZATION' else 'PERSON' end participant_kind,
      62::integer confidence_score, 'Sound-alike phonetic token match'::text match_details, 'phonetic'::text match_type, 'phonetic'::text match_source,
      case when coalesce(p.is_voided, o.is_voided, false) or not coalesce(p.is_active, o.is_active, true) then 'inactive' else 'active' end result_group,
      null::bigint correction_id, coalesce(p.full_name, o.organization_name) full_name, coalesce(pa.aliases, oa.aliases, array[]::text[]) aliases,
      coalesce(p.is_voided, o.is_voided, false) is_voided, false is_corrected, p.replaced_by_person_id::integer, coalesce(p.replaced_by_person_id, p.id)::integer active_person_id,
      coalesce(p.void_reason, o.void_reason) correction_reason, null::timestamptz corrected_at, null::text corrected_by, null::jsonb old_snapshot_json, null::jsonb new_snapshot_json
    from hits h
    left join public.persons p on p.id = h.person_id
    left join public.organizations o on o.id = h.organization_id
    left join lateral (select array_agg(pa.alias_name order by pa.alias_name) aliases from public.person_aliases pa where pa.person_id = h.person_id and coalesce(pa.is_active, true)) pa on true
    left join lateral (select array_agg(oa.alias_name order by oa.alias_name) aliases from public.organization_aliases oa where oa.organization_id = h.organization_id and coalesce(oa.is_active, true)) oa on true
  )
  select * from public.format_clearance_search_results((select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from candidates c), p_limit);
$$;

grant execute on function public.format_clearance_search_results(jsonb, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_exact_candidates(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_records(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_possible_matches(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_possible_matches_v31(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_phonetic_matches(text, text, integer) to anon, authenticated, service_role;
