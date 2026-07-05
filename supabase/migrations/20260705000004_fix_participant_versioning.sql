ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS is_voided boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS voided_at timestamptz,
  ADD COLUMN IF NOT EXISTS voided_by_user_id bigint,
  ADD COLUMN IF NOT EXISTS void_reason text,
  ADD COLUMN IF NOT EXISTS replaced_by_organization_id bigint;

ALTER TABLE public.case_participant_corrections
  ALTER COLUMN old_person_id DROP NOT NULL,
  ALTER COLUMN new_person_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS old_organization_id bigint REFERENCES public.organizations(id),
  ADD COLUMN IF NOT EXISTS new_organization_id bigint REFERENCES public.organizations(id);

ALTER TABLE public.person_addresses
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS deactivated_at timestamptz,
  ADD COLUMN IF NOT EXISTS deactivated_by_user_id bigint,
  ADD COLUMN IF NOT EXISTS deactivation_reason text;

ALTER TABLE public.organization_addresses
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS deactivated_at timestamptz,
  ADD COLUMN IF NOT EXISTS deactivated_by_user_id bigint,
  ADD COLUMN IF NOT EXISTS deactivation_reason text;

ALTER TABLE public.participant_contact_informations
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS deactivated_at timestamptz,
  ADD COLUMN IF NOT EXISTS deactivated_by_user_id bigint,
  ADD COLUMN IF NOT EXISTS deactivation_reason text;

DROP VIEW IF EXISTS public.v_case_participant_corrections;

CREATE VIEW public.v_case_participant_corrections AS
SELECT c.id,
       c.case_id,
       c.case_participant_id,
       c.old_person_id,
       c.new_person_id,
       c.old_organization_id,
       c.new_organization_id,
       c.old_snapshot_json,
       c.new_snapshot_json,
       c.reason,
       c.corrected_by_user_id,
       COALESCE(s.full_name, p.full_name, u.email, ('User #' || c.corrected_by_user_id::text)) AS corrected_by_display,
       c.corrected_at
FROM public.case_participant_corrections c
LEFT JOIN public.users u ON u.id = c.corrected_by_user_id
LEFT JOIN public.staff s ON s.id = u.staff_id
LEFT JOIN public.prosecutors p ON p.id = u.prosecutor_id;

GRANT SELECT ON public.v_case_participant_corrections TO anon, authenticated, service_role;

CREATE OR REPLACE VIEW public.v_case_participants_detail AS
 SELECT cp.id,
    cp.case_id,
    cp.person_id,
    cp.role_id,
    cp.created_at,
    cp.participant_order,
    cp.organization_id,
    cp.participant_kind,
    cp.display_name_snapshot,
    cppd.remarks,
    cppd.source,
    cppd.source_detail,
    cppd.legacy_source_file,
    cppd.legacy_source_sheet,
    cppd.legacy_row_number,
    cppd.legacy_raw_text,
    jsonb_build_object('code', pr.code, 'display_label', pr.display_label) AS participant_roles,
    COALESCE(pci.contact_informations, '[]'::jsonb) AS contact_informations,
        CASE
            WHEN (cpa.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('age_text', cpa.age_text, 'age_years', cpa.age_years, 'gender_text', cpa.gender_text, 'gender_normalized', cpa.gender_normalized, 'is_minor_at_case', cpa.is_minor_at_case, 'is_senior_at_case', cpa.is_senior_at_case, 'is_pwd_at_case', cpa.is_pwd_at_case)
        END AS case_participant_attributes,
        CASE
            WHEN (p.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('age', p.age, 'birth_date', p.birth_date, 'first_name', p.first_name, 'full_name', p.full_name, 'gender', p.gender, 'id', p.id, 'is_minor', p.is_minor, 'is_pwd', p.is_pwd, 'is_senior', p.is_senior, 'last_name', p.last_name, 'middle_name', p.middle_name, 'notes', p.notes, 'person_descriptor', p.person_descriptor, 'suffix', p.suffix, 'is_voided', COALESCE(p.is_voided, false), 'replaced_by_person_id', p.replaced_by_person_id, 'person_aliases', COALESCE(pal.person_aliases, '[]'::jsonb), 'person_addresses', COALESCE(pa.person_addresses, '[]'::jsonb))
        END AS persons,
        CASE
            WHEN (o.id IS NULL) THEN NULL::jsonb
            ELSE jsonb_build_object('id', o.id, 'organization_name', o.organization_name, 'contact_person', o.contact_person, 'contact_number', o.contact_number, 'email', o.email, 'details_jsonb', o.details_jsonb, 'is_voided', COALESCE(o.is_voided, false), 'replaced_by_organization_id', o.replaced_by_organization_id, 'organization_aliases', COALESCE(oa.organization_aliases, '[]'::jsonb), 'organization_addresses', COALESCE(org_addr.organization_addresses, '[]'::jsonb))
        END AS organizations
   FROM ((((((((((public.case_participants cp
     LEFT JOIN public.case_participant_private_details cppd ON ((cppd.case_participant_id = cp.id)))
     LEFT JOIN public.case_participant_attributes cpa ON ((cpa.case_participant_id = cp.id)))
     LEFT JOIN public.participant_roles pr ON ((pr.id = cp.role_id)))
     LEFT JOIN public.persons p ON ((p.id = cp.person_id)))
     LEFT JOIN public.organizations o ON ((o.id = cp.organization_id)))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', ci.id, 'participant_contact_information_id', pci_1.id, 'contact_type', ci.contact_type, 'contact_value', ci.contact_value, 'label', ci.label, 'is_primary', ci.is_primary, 'remarks', ci.remarks) ORDER BY ci.is_primary DESC NULLS LAST, ci.contact_type, ci.id) AS contact_informations
           FROM (public.participant_contact_informations pci_1
             JOIN public.contact_informations ci ON ((ci.id = pci_1.contact_information_id)))
          WHERE ((pci_1.case_participant_id = cp.id) AND (COALESCE(pci_1.is_active, true) IS TRUE))) pci ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', a.id, 'alias_name', a.alias_name, 'is_active', a.is_active) ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS person_aliases
           FROM public.person_aliases a
          WHERE ((a.person_id = p.id) AND (a.is_active IS TRUE))) pal ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', paddr.id, 'address_id', paddr.address_id, 'address_type_id', paddr.address_type_id, 'is_primary', paddr.is_primary, 'remarks', paddr.remarks, 'addresses',
                CASE
                    WHEN (a.id IS NULL) THEN NULL::jsonb
                    ELSE jsonb_build_object('id', a.id, 'barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)
                END) ORDER BY paddr.is_primary DESC NULLS LAST, paddr.id) AS person_addresses
           FROM (public.person_addresses paddr
             LEFT JOIN public.addresses a ON ((a.id = paddr.address_id)))
          WHERE ((paddr.person_id = p.id) AND (COALESCE(paddr.is_active, true) IS TRUE) AND (paddr.end_date IS NULL OR paddr.end_date > CURRENT_DATE))) pa ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', a.id, 'alias_name', a.alias_name, 'is_active', a.is_active) ORDER BY a.is_active DESC NULLS LAST, a.alias_name) AS organization_aliases
           FROM public.organization_aliases a
          WHERE ((a.organization_id = o.id) AND (a.is_active IS TRUE))) oa ON (true))
     LEFT JOIN LATERAL ( SELECT jsonb_agg(jsonb_build_object('id', oaddr.id, 'address_id', oaddr.address_id, 'address_type_id', oaddr.address_type_id, 'is_primary', oaddr.is_primary, 'remarks', oaddr.remarks, 'addresses',
                CASE
                    WHEN (a.id IS NULL) THEN NULL::jsonb
                    ELSE jsonb_build_object('id', a.id, 'barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)
                END) ORDER BY oaddr.is_primary DESC NULLS LAST, oaddr.id) AS organization_addresses
           FROM (public.organization_addresses oaddr
             LEFT JOIN public.addresses a ON ((a.id = oaddr.address_id)))
          WHERE ((oaddr.organization_id = o.id) AND (COALESCE(oaddr.is_active, true) IS TRUE) AND (oaddr.end_date IS NULL OR oaddr.end_date > CURRENT_DATE))) org_addr ON (true));;

CREATE OR REPLACE FUNCTION public.upsert_clearance_possible_tokens_for_person(p_person_id bigint) RETURNS void
LANGUAGE plpgsql AS $$
begin
  delete from public.clearance_possible_name_tokens where person_id = p_person_id;
  insert into public.clearance_possible_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, first_char, first2, first3, last2, last3, ck_key, bv_key, phf_key, sz_key, skeleton)
  select x.person_id, null::integer, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3), right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token), public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from (
    select p.id as person_id, 'persons' as source_table, 'full_name' as source_column, p.full_name as source_value from public.persons p where p.id = p_person_id and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
    union all
    select pa.person_id, 'person_aliases', 'alias_name', pa.alias_name from public.person_aliases pa join public.persons p on p.id = pa.person_id where pa.person_id = p_person_id and coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1;
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_clearance_phonetic_tokens_for_person(p_person_id bigint) RETURNS void
LANGUAGE plpgsql AS $$
begin
  delete from public.clearance_phonetic_name_tokens where person_id = p_person_id;
  insert into public.clearance_phonetic_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, phonetic_primary, phonetic_alt, phonetic_codes)
  select x.person_id, null::integer, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), dmetaphone(tok.token), dmetaphone_alt(tok.token), public.clearance_phonetic_codes(tok.token)
  from (
    select p.id as person_id, 'persons' as source_table, 'full_name' as source_column, p.full_name as source_value from public.persons p where p.id = p_person_id and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
    union all
    select pa.person_id, 'person_aliases', 'alias_name', pa.alias_name from public.person_aliases pa join public.persons p on p.id = pa.person_id where pa.person_id = p_person_id and coalesce(pa.is_active, true) = true and coalesce(p.is_active, true) = true and not coalesce(p.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1 and cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_clearance_possible_tokens_for_organization(p_organization_id bigint) RETURNS void
LANGUAGE plpgsql AS $$
begin
  delete from public.clearance_possible_name_tokens where organization_id = p_organization_id;
  insert into public.clearance_possible_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, first_char, first2, first3, last2, last3, ck_key, bv_key, phf_key, sz_key, skeleton)
  select null::integer, x.organization_id, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), left(tok.token,1), left(tok.token,2), left(tok.token,3), right(tok.token,2), right(tok.token,3), public.clearance_ck_key(tok.token), public.clearance_bv_key(tok.token), public.clearance_phf_key(tok.token), public.clearance_sz_key(tok.token), public.clearance_token_skeleton(tok.token)
  from (
    select o.id as organization_id, 'organizations' as source_table, 'organization_name' as source_column, o.organization_name as source_value from public.organizations o where o.id = p_organization_id and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
    union all
    select oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name from public.organization_aliases oa join public.organizations o on o.id = oa.organization_id where oa.organization_id = p_organization_id and coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1;
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_clearance_phonetic_tokens_for_organization(p_organization_id bigint) RETURNS void
LANGUAGE plpgsql AS $$
begin
  delete from public.clearance_phonetic_name_tokens where organization_id = p_organization_id;
  insert into public.clearance_phonetic_name_tokens (person_id, organization_id, source_table, source_column, source_value, token, token_order, token_len, phonetic_primary, phonetic_alt, phonetic_codes)
  select null::integer, x.organization_id, x.source_table, x.source_column, x.source_value, tok.token, tok.token_order::integer, length(tok.token), dmetaphone(tok.token), dmetaphone_alt(tok.token), public.clearance_phonetic_codes(tok.token)
  from (
    select o.id as organization_id, 'organizations' as source_table, 'organization_name' as source_column, o.organization_name as source_value from public.organizations o where o.id = p_organization_id and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
    union all
    select oa.organization_id, 'organization_aliases', 'alias_name', oa.alias_name from public.organization_aliases oa join public.organizations o on o.id = oa.organization_id where oa.organization_id = p_organization_id and coalesce(oa.is_active, true) = true and coalesce(o.is_active, true) = true and not coalesce(o.is_voided, false)
  ) x cross join lateral regexp_split_to_table(public.clearance_exact_norm(x.source_value), ' ') with ordinality as tok(token, token_order) where length(tok.token) > 1 and cardinality(public.clearance_phonetic_codes(tok.token)) > 0;
end;
$$;
CREATE OR REPLACE FUNCTION public.manage_case_participants(p_payload jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_action text := lower(btrim(p_payload->>'action'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_participant jsonb := coalesce(p_payload->'participant', '{}'::jsonb);
  v_case_participant_id bigint := nullif(v_participant->>'id','')::bigint;
  v_person_id bigint;
  v_new_person_id bigint;
  v_new_organization_id bigint;
  v_organization_id bigint;
  v_kind text;
  v_display text;
  v_old jsonb;
  v_new jsonb;
  v_old_snapshot jsonb;
  v_new_snapshot jsonb;
  v_alias_id bigint := nullif(v_participant->>'aliasId','')::bigint;
  v_address_relation_id bigint := nullif(v_participant->>'addressRelationId','')::bigint;
  v_address_id bigint := nullif(v_participant->>'addressId','')::bigint;
  v_contact_relation_id bigint := nullif(v_participant->>'participantContactInformationId','')::bigint;
  v_contact_id bigint := nullif(v_participant->>'contactInformationId','')::bigint;
  v_address_type_id bigint := nullif(v_participant->>'addressTypeId','')::bigint;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_case_participant_id IS NULL THEN RAISE EXCEPTION 'participant.id is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;

  SELECT cp.person_id, cp.organization_id, COALESCE(cp.participant_kind, CASE WHEN cp.organization_id IS NULL THEN 'PERSON' ELSE 'ORGANIZATION' END)
  INTO v_person_id, v_organization_id, v_kind
  FROM public.case_participants cp
  WHERE cp.id = v_case_participant_id AND cp.case_id = v_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Participant % not found for case %', v_case_participant_id, v_case_id; END IF;

  SELECT to_jsonb(vcp) INTO v_old FROM public.v_case_participants_detail vcp WHERE vcp.id = v_case_participant_id;

  IF v_action = 'edit_main_details' THEN
    IF v_kind = 'ORGANIZATION' THEN
      IF v_organization_id IS NULL THEN RAISE EXCEPTION 'Participant has no organization identity to correct'; END IF;
      v_display := nullif(btrim(v_participant->>'organizationName'), '');
      IF v_display IS NULL THEN RAISE EXCEPTION 'organizationName is required'; END IF;
      SELECT jsonb_build_object('organization', to_jsonb(o), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_old_snapshot
      FROM public.case_participants cp
      JOIN public.organizations o ON o.id = cp.organization_id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;
      INSERT INTO public.organizations(organization_name, contact_person, contact_number, email, notes, is_active, source, source_detail, legacy_source_file, legacy_source_sheet, legacy_row_number, legacy_raw_text, created_by_user_id, updated_by_user_id, details_jsonb)
      SELECT v_display, nullif(btrim(v_participant->>'contactPerson'), ''), nullif(btrim(v_participant->>'contactNumber'), ''), nullif(btrim(v_participant->>'email'), ''), o.notes, o.is_active, o.source, o.source_detail, o.legacy_source_file, o.legacy_source_sheet, o.legacy_row_number, o.legacy_raw_text, o.created_by_user_id, v_user_id, o.details_jsonb
      FROM public.organizations o WHERE o.id = v_organization_id RETURNING id INTO v_new_organization_id;
      UPDATE public.organizations SET is_voided = true, voided_at = now(), voided_by_user_id = v_user_id, void_reason = v_reason, replaced_by_organization_id = v_new_organization_id, is_active = false, updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_organization_id;
      UPDATE public.case_participants SET organization_id = v_new_organization_id, display_name_snapshot = v_display WHERE id = v_case_participant_id;
      v_organization_id := v_new_organization_id;
    ELSE
      IF v_person_id IS NULL THEN RAISE EXCEPTION 'Participant has no person identity to correct'; END IF;
      SELECT jsonb_build_object('person', to_jsonb(p), 'attributes', to_jsonb(cpa), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_old_snapshot
      FROM public.case_participants cp
      JOIN public.persons p ON p.id = cp.person_id
      LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;

      IF COALESCE((v_participant->>'useStructuredName')::boolean, false) IS TRUE THEN
        v_display := concat_ws(' ', nullif(btrim(v_participant->>'firstName'), ''), nullif(btrim(v_participant->>'middleName'), ''), nullif(btrim(v_participant->>'lastName'), ''), nullif(btrim(v_participant->>'suffix'), ''));
        IF nullif(btrim(v_display), '') IS NULL THEN RAISE EXCEPTION 'Structured name fields are required'; END IF;
        INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor,age,is_minor,is_senior,is_pwd,is_active)
        SELECT nullif(btrim(v_participant->>'firstName'), ''), nullif(btrim(v_participant->>'middleName'), ''), nullif(btrim(v_participant->>'lastName'), ''), nullif(btrim(v_participant->>'suffix'), ''), btrim(v_display), nullif(btrim(v_participant->>'gender'), ''), nullif(v_participant->>'birthDate','')::date, nullif(btrim(v_participant->>'notes'), ''), nullif(btrim(v_participant->>'personDescriptor'), ''), nullif(btrim(v_participant->>'age'), ''), p.is_minor, p.is_senior, p.is_pwd, p.is_active FROM public.persons p WHERE p.id = v_person_id RETURNING id INTO v_new_person_id;
      ELSE
        v_display := nullif(btrim(v_participant->>'fullName'), '');
        IF v_display IS NULL THEN RAISE EXCEPTION 'fullName is required'; END IF;
        INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor,age,is_minor,is_senior,is_pwd,is_active)
        SELECT p.first_name, p.middle_name, p.last_name, p.suffix, v_display, nullif(btrim(v_participant->>'gender'), ''), nullif(v_participant->>'birthDate','')::date, nullif(btrim(v_participant->>'notes'), ''), nullif(btrim(v_participant->>'personDescriptor'), ''), nullif(btrim(v_participant->>'age'), ''), p.is_minor, p.is_senior, p.is_pwd, p.is_active FROM public.persons p WHERE p.id = v_person_id RETURNING id INTO v_new_person_id;
      END IF;

      UPDATE public.persons SET is_voided = true, voided_at = now(), voided_by_user_id = v_user_id, void_reason = v_reason, replaced_by_person_id = v_new_person_id, updated_at = now() WHERE id = v_person_id;
      UPDATE public.case_participants SET person_id = v_new_person_id, display_name_snapshot = v_display WHERE id = v_case_participant_id;
      v_person_id := v_new_person_id;
    END IF;

    UPDATE public.case_participants SET display_name_snapshot = v_display WHERE id = v_case_participant_id;
    INSERT INTO public.case_participant_private_details(case_participant_id, case_id, remarks, source, source_detail)
    VALUES (v_case_participant_id, v_case_id, nullif(btrim(v_participant->>'remarks'), ''), 'MANUAL_ENTRY', nullif(btrim(v_participant->>'sourceDetail'), ''))
    ON CONFLICT (case_participant_id) DO UPDATE SET remarks = EXCLUDED.remarks, source_detail = EXCLUDED.source_detail, updated_at = now();
    INSERT INTO public.case_participant_attributes(case_participant_id, age_text, age_years, gender_text, gender_normalized, is_minor_at_case, is_senior_at_case, is_pwd_at_case, notes, updated_by_user_id)
    VALUES (v_case_participant_id, coalesce(nullif(btrim(v_participant->>'ageText'), ''), nullif(btrim(v_participant->>'age'), '')), nullif(v_participant->>'ageYears','')::int, coalesce(nullif(btrim(v_participant->>'genderText'), ''), nullif(btrim(v_participant->>'gender'), '')), nullif(btrim(v_participant->>'genderNormalized'), ''), nullif(v_participant->>'isMinorAtCase','')::boolean, nullif(v_participant->>'isSeniorAtCase','')::boolean, nullif(v_participant->>'isPwdAtCase','')::boolean, nullif(btrim(v_participant->>'attributeNotes'), ''), v_user_id)
    ON CONFLICT (case_participant_id) DO UPDATE SET age_text = EXCLUDED.age_text, age_years = EXCLUDED.age_years, gender_text = EXCLUDED.gender_text, gender_normalized = EXCLUDED.gender_normalized, is_minor_at_case = EXCLUDED.is_minor_at_case, is_senior_at_case = EXCLUDED.is_senior_at_case, is_pwd_at_case = EXCLUDED.is_pwd_at_case, notes = EXCLUDED.notes, updated_by_user_id = EXCLUDED.updated_by_user_id, updated_at = now();

    IF v_kind = 'ORGANIZATION' THEN
      SELECT jsonb_build_object('organization', to_jsonb(o), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_new_snapshot
      FROM public.case_participants cp
      JOIN public.organizations o ON o.id = cp.organization_id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;
      INSERT INTO public.case_participant_corrections(case_id, case_participant_id, old_person_id, new_person_id, old_organization_id, new_organization_id, old_snapshot_json, new_snapshot_json, reason, corrected_by_user_id)
      VALUES (v_case_id, v_case_participant_id, NULL, NULL, (v_old_snapshot#>>'{organization,id}')::bigint, v_new_organization_id, v_old_snapshot, v_new_snapshot, v_reason, v_user_id);
    ELSE
      SELECT jsonb_build_object('person', to_jsonb(p), 'attributes', to_jsonb(cpa), 'participant', to_jsonb(cp), 'private_details', to_jsonb(cppd))
      INTO v_new_snapshot
      FROM public.case_participants cp
      JOIN public.persons p ON p.id = cp.person_id
      LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
      LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
      WHERE cp.id = v_case_participant_id;
      INSERT INTO public.case_participant_corrections(case_id, case_participant_id, old_person_id, new_person_id, old_snapshot_json, new_snapshot_json, reason, corrected_by_user_id)
      VALUES (v_case_id, v_case_participant_id, (v_old_snapshot#>>'{person,id}')::bigint, v_new_person_id, v_old_snapshot, v_new_snapshot, v_reason, v_user_id);
    END IF;
  ELSIF v_action IN ('add_alias','edit_alias','remove_alias') THEN
    IF v_kind = 'ORGANIZATION' THEN
      IF v_action = 'add_alias' THEN INSERT INTO public.organization_aliases(organization_id, alias_name, source) VALUES (v_organization_id, nullif(btrim(v_participant->>'aliasName'), ''), 'MANUAL_ENTRY'); ELSIF v_action = 'edit_alias' THEN UPDATE public.organization_aliases SET alias_name = nullif(btrim(v_participant->>'aliasName'), ''), updated_at = now() WHERE id = v_alias_id AND organization_id = v_organization_id; ELSE UPDATE public.organization_aliases SET is_active = false, updated_at = now() WHERE id = v_alias_id AND organization_id = v_organization_id; END IF;
    ELSE
      IF v_action = 'add_alias' THEN INSERT INTO public.person_aliases(person_id, alias_name, alias_type, source) VALUES (v_person_id, nullif(btrim(v_participant->>'aliasName'), ''), 'AKA', 'MANUAL_ENTRY'); ELSIF v_action = 'edit_alias' THEN UPDATE public.person_aliases SET alias_name = nullif(btrim(v_participant->>'aliasName'), ''), updated_at = now() WHERE id = v_alias_id AND person_id = v_person_id; ELSE UPDATE public.person_aliases SET is_active = false, updated_at = now() WHERE id = v_alias_id AND person_id = v_person_id; END IF;
    END IF;
  ELSIF v_action IN ('add_address','edit_address','remove_address') THEN
    IF v_action = 'remove_address' THEN
      IF v_kind = 'ORGANIZATION' THEN UPDATE public.organization_addresses SET is_active = false, end_date = coalesce(end_date, current_date), deactivated_at = now(), deactivated_by_user_id = v_user_id, deactivation_reason = v_reason WHERE id = v_address_relation_id AND organization_id = v_organization_id; ELSE UPDATE public.person_addresses SET is_active = false, end_date = coalesce(end_date, current_date), deactivated_at = now(), deactivated_by_user_id = v_user_id, deactivation_reason = v_reason WHERE id = v_address_relation_id AND person_id = v_person_id; END IF;
    ELSE
      IF v_address_type_id IS NULL THEN RAISE EXCEPTION 'addressTypeId is required'; END IF;
      IF v_action = 'add_address' THEN
        INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_participant->>'line1'),''), nullif(btrim(v_participant->>'line2'),''), nullif(btrim(v_participant->>'barangay'),''), nullif(btrim(v_participant->>'city'),''), nullif(btrim(v_participant->>'province'),''), nullif(btrim(v_participant->>'region'),''), nullif(btrim(v_participant->>'zipCode'),''), coalesce(nullif(btrim(v_participant->>'country'),''), 'Philippines')) RETURNING id INTO v_address_id;
        IF v_kind = 'ORGANIZATION' THEN INSERT INTO public.organization_addresses(organization_id,address_id,address_type_id,is_primary,remarks) VALUES (v_organization_id,v_address_id,v_address_type_id,coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),nullif(btrim(v_participant->>'remarks'),'')); ELSE INSERT INTO public.person_addresses(person_id,address_id,address_type_id,is_primary,remarks) VALUES (v_person_id,v_address_id,v_address_type_id,coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),nullif(btrim(v_participant->>'remarks'),'')); END IF;
      ELSE
        IF v_kind = 'ORGANIZATION' THEN SELECT address_id INTO v_address_id FROM public.organization_addresses WHERE id = v_address_relation_id AND organization_id = v_organization_id; ELSE SELECT address_id INTO v_address_id FROM public.person_addresses WHERE id = v_address_relation_id AND person_id = v_person_id; END IF;
        UPDATE public.addresses SET line1=nullif(btrim(v_participant->>'line1'),''), line2=nullif(btrim(v_participant->>'line2'),''), barangay=nullif(btrim(v_participant->>'barangay'),''), city=nullif(btrim(v_participant->>'city'),''), province=nullif(btrim(v_participant->>'province'),''), region=nullif(btrim(v_participant->>'region'),''), zip_code=nullif(btrim(v_participant->>'zipCode'),''), country=coalesce(nullif(btrim(v_participant->>'country'),''),'Philippines') WHERE id = v_address_id;
        IF v_kind = 'ORGANIZATION' THEN UPDATE public.organization_addresses SET address_type_id=v_address_type_id,is_primary=coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),remarks=nullif(btrim(v_participant->>'remarks'),'') WHERE id=v_address_relation_id AND organization_id=v_organization_id; ELSE UPDATE public.person_addresses SET address_type_id=v_address_type_id,is_primary=coalesce(nullif(v_participant->>'isPrimary','')::boolean,false),remarks=nullif(btrim(v_participant->>'remarks'),'') WHERE id=v_address_relation_id AND person_id=v_person_id; END IF;
      END IF;
    END IF;
  ELSIF v_action IN ('add_contact','edit_contact','remove_contact') THEN
    IF v_action = 'remove_contact' THEN UPDATE public.participant_contact_informations SET is_active = false, deactivated_at = now(), deactivated_by_user_id = v_user_id, deactivation_reason = v_reason WHERE id = v_contact_relation_id AND case_participant_id = v_case_participant_id;
    ELSIF v_action = 'add_contact' THEN INSERT INTO public.contact_informations(contact_type,contact_value,label,is_primary,remarks) VALUES (coalesce(nullif(btrim(v_participant->>'contactType'),''),'OTHER'), nullif(btrim(v_participant->>'contactValue'),''), nullif(btrim(v_participant->>'label'),''), coalesce(nullif(v_participant->>'isPrimary','')::boolean,false), nullif(btrim(v_participant->>'remarks'),'')) RETURNING id INTO v_contact_id; INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_case_participant_id, v_contact_id);
    ELSE SELECT contact_information_id INTO v_contact_id FROM public.participant_contact_informations WHERE id = v_contact_relation_id AND case_participant_id = v_case_participant_id; UPDATE public.contact_informations SET contact_type=coalesce(nullif(btrim(v_participant->>'contactType'),''),'OTHER'), contact_value=nullif(btrim(v_participant->>'contactValue'),''), label=nullif(btrim(v_participant->>'label'),''), is_primary=coalesce(nullif(v_participant->>'isPrimary','')::boolean,false), remarks=nullif(btrim(v_participant->>'remarks'),''), updated_at=now() WHERE id = v_contact_id; END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported participants action %', v_action;
  END IF;

  IF v_action = 'edit_main_details' THEN
    IF v_kind = 'ORGANIZATION' THEN
      PERFORM public.upsert_clearance_possible_tokens_for_organization((v_old_snapshot#>>'{organization,id}')::bigint);
      PERFORM public.upsert_clearance_phonetic_tokens_for_organization((v_old_snapshot#>>'{organization,id}')::bigint);
      PERFORM public.upsert_clearance_possible_tokens_for_organization(v_organization_id);
      PERFORM public.upsert_clearance_phonetic_tokens_for_organization(v_organization_id);
    ELSE
      PERFORM public.upsert_clearance_possible_tokens_for_person((v_old_snapshot#>>'{person,id}')::bigint);
      PERFORM public.upsert_clearance_phonetic_tokens_for_person((v_old_snapshot#>>'{person,id}')::bigint);
      PERFORM public.upsert_clearance_possible_tokens_for_person(v_person_id);
      PERFORM public.upsert_clearance_phonetic_tokens_for_person(v_person_id);
    END IF;
  END IF;

  SELECT to_jsonb(vcp) INTO v_new FROM public.v_case_participants_detail vcp WHERE vcp.id = v_case_participant_id;
  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_PARTICIPANTS_' || upper(v_action), 'case_participants', v_case_participant_id, v_case_id, CASE WHEN v_action = 'edit_main_details' AND v_kind <> 'ORGANIZATION' THEN 'Corrected case participant identity' ELSE 'Managed case participant' END, jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_case_participants(jsonb) TO anon, authenticated, service_role;

-- Rebuild clearance search RPCs after adding organization void/version columns.
drop function if exists public.search_clearance_phonetic_matches(text, text, integer);
drop function if exists public.search_clearance_possible_matches(text, text, integer);
drop function if exists public.search_clearance_possible_matches_v31(text, text, integer);
drop function if exists public.search_clearance_records(text, text, integer);

create or replace function public.search_clearance_records(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer,
  organization_id integer,
  participant_kind text,
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
  role_label text,
  age text,
  violations text,
  is_voided boolean,
  is_corrected boolean,
  replaced_by_person_id integer,
  active_person_id integer,
  correction_reason text,
  corrected_at timestamptz,
  corrected_by text,
  old_snapshot_json jsonb,
  new_snapshot_json jsonb,
  result_group text,
  match_source text
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
  ), joined as (
    select pt.*, c.id::integer case_id, concat_ws('-',dt.prefix,c.docket_year::text,nullif(c.docket_month_code,''),lpad(c.docket_number::text,6,'0')) docket_number,
      coalesce(cs.display_label, cs.code, 'Pending') status, coalesce(c.updated_at,c.created_at,now()) last_updated, coalesce(pr.display_label,pr.code,'Participant') role_label,
      age.age_text, viol.violations, n.*
    from parties pt join n on true
    join public.case_participants cp on (
      (pt.correction_id is not null and cp.id = (select cpc.case_participant_id from public.case_participant_corrections cpc where cpc.id = pt.correction_id))
      or (pt.correction_id is null and (cp.person_id=pt.person_id or cp.organization_id=pt.organization_id))
    )
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
  ), deduped as (
    select distinct on (result_group, person_id, organization_id, case_id, match_source)
      person_id, organization_id, participant_kind, case_id, docket_number, docket_number::text case_number, official_name full_name, aliases, status, last_updated, score confidence_score,
      case when match_source = 'voided_previous_name' and result_group = 'active' then 'Matched previous corrected name: ' || search_name when match_source = 'voided_previous_name' then 'Matched voided/corrected previous name' when st in ('name','all') and name_norm=q_norm then 'Exact normalized name match' when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'Exact alias match: '||coalesce(best_alias,'') else 'Exact token match' end match_details,
      case when st in ('alias','all') and (alias_full or alias_tokens or alias_single) then 'alias' else 'exact' end match_type, role_label, age_text, violations,
      is_voided, is_corrected, replaced_by_person_id, active_person_id, correction_reason, corrected_at, corrected_by, old_snapshot_json, new_snapshot_json, result_group, match_source
    from scored where score>0
    order by result_group, person_id nulls last, organization_id nulls last, case_id, match_source, score desc
  )
  select * from deduped order by case when result_group='active' then 0 else 1 end, confidence_score desc, full_name, case_id limit (select lim from n);
$$;

create or replace function public.search_clearance_possible_matches_v31(p_query text, p_search_type text default 'all', p_limit integer default 50)
returns table(
  person_id integer, organization_id integer, participant_kind text, case_id integer, docket_number text, case_number text, full_name text, aliases text[], status text, last_updated timestamptz, confidence_score integer, match_details text, match_type text, role_label text, age text, violations text,
  is_voided boolean, is_corrected boolean, replaced_by_person_id integer, active_person_id integer, correction_reason text, corrected_at timestamptz, corrected_by text, old_snapshot_json jsonb, new_snapshot_json jsonb, result_group text, match_source text
)
language sql stable as $$
  with normalized as (
    select nullif(trim(p_query), '') as q, public.clearance_exact_tokens(p_query) as q_tokens, cardinality(public.clearance_exact_tokens(p_query)) as q_token_count, case when p_search_type in ('name', 'alias', 'all') then p_search_type else 'all' end as search_type, least(greatest(coalesce(p_limit, 50), 1), 100) as safe_limit
  ), query_tokens as (
    select u.token, length(u.token) as token_len, left(u.token, 1) as first_char, left(u.token, 2) as first2, right(u.token, 2) as last2, public.clearance_ck_key(u.token) as ck_key, public.clearance_bv_key(u.token) as bv_key, public.clearance_phf_key(u.token) as phf_key, public.clearance_sz_key(u.token) as sz_key, public.clearance_token_skeleton(u.token) as skeleton
    from normalized n cross join lateral unnest(n.q_tokens) as u(token)
  ), raw_token_candidates as materialized (
    select t.person_id, t.organization_id, t.source_value, t.source_table, q.token as query_token, t.token as matched_token,
      case when t.token = q.token then 'exact' when t.ck_key = q.ck_key then 'c/k variant' when t.bv_key = q.bv_key then 'b/v variant' when t.phf_key = q.phf_key then 'ph/f variant' when t.sz_key = q.sz_key then 's/z variant' when t.skeleton = q.skeleton then 'skeleton variant' else 'fuzzy' end as raw_reason,
      case when t.token = q.token then 1 when t.ck_key = q.ck_key or t.bv_key = q.bv_key or t.phf_key = q.phf_key or t.sz_key = q.sz_key then 2 when t.skeleton = q.skeleton then 3 else 4 end as raw_priority
    from query_tokens q join public.clearance_possible_name_tokens t on (t.token = q.token or t.ck_key = q.ck_key or t.bv_key = q.bv_key or t.phf_key = q.phf_key or t.sz_key = q.sz_key or (q.token_len >= 4 and t.token_len >= 4 and t.skeleton = q.skeleton) or (q.token_len >= 4 and t.token_len >= 4 and t.first2 = q.first2 and t.last2 = q.last2) or (q.token_len >= 5 and t.token_len >= 5 and t.first_char = q.first_char and levenshtein_less_equal(t.token, q.token, 2) <= 2)) join normalized n on true
    where n.q is not null and (n.search_type = 'all' or (n.search_type = 'name' and t.source_table in ('persons', 'organizations')) or (n.search_type = 'alias' and t.source_table in ('person_aliases', 'organization_aliases')))
  ), entity_candidates as (
    select person_id, organization_id, min(raw_priority) as best_priority, count(distinct query_token) as matched_query_tokens, (array_agg(source_value order by raw_priority, source_value))[1] as best_source_value, string_agg(distinct raw_reason, ', ' order by raw_reason) as reasons
    from raw_token_candidates group by person_id, organization_id
  ), fuzzy_rows as (
    select r.person_id, r.organization_id, r.participant_kind, r.case_id, r.docket_number, r.case_number, r.full_name, r.aliases, r.status, r.last_updated,
      greatest(55, least(89, 58 + case when ec.matched_query_tokens >= (select q_token_count from normalized) and (select q_token_count from normalized) >= 2 then 18 else 0 end + case ec.best_priority when 1 then 10 when 2 then 8 when 3 then 6 else 3 end + least(8, ec.matched_query_tokens * 2)))::integer as confidence_score,
      'Possible fuzzy token match (' || ec.reasons || '): ' || coalesce(ec.best_source_value, r.full_name) as match_details,
      case when ec.best_priority <= 2 then 'variant' else 'fuzzy' end as match_type,
      r.role_label, r.age, r.violations, r.is_voided, r.is_corrected, r.replaced_by_person_id, r.active_person_id, r.correction_reason, r.corrected_at, r.corrected_by, r.old_snapshot_json, r.new_snapshot_json, r.result_group, r.match_source
    from entity_candidates ec
    join lateral public.search_clearance_records(coalesce((select p.full_name from public.persons p where p.id = ec.person_id), (select o.organization_name from public.organizations o where o.id = ec.organization_id), ec.best_source_value), 'name', 100) r on r.person_id is not distinct from ec.person_id and r.organization_id is not distinct from ec.organization_id
    where ec.matched_query_tokens > 0
  ), combined as (
    select *, 1 as result_priority from public.search_clearance_records(p_query, p_search_type, p_limit)
    union all
    select *, 2 as result_priority from fuzzy_rows
  ), deduped as (
    select distinct on (result_group, person_id, organization_id, case_id, match_source)
      person_id, organization_id, participant_kind, case_id, docket_number, case_number, full_name, aliases, status, last_updated, confidence_score, match_details, match_type, role_label, age, violations,
      is_voided, is_corrected, replaced_by_person_id, active_person_id, correction_reason, corrected_at, corrected_by, old_snapshot_json, new_snapshot_json, result_group, match_source
    from combined order by result_group, person_id nulls last, organization_id nulls last, case_id, match_source, result_priority, confidence_score desc
  ) select * from deduped order by case when result_group='active' then 0 else 1 end, confidence_score desc, full_name, case_id limit (select safe_limit from normalized);
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
  with q as (select public.clearance_phonetic_codes(tok) codes from regexp_split_to_table(public.clearance_exact_norm(p_query),' ') tok where length(tok)>1), hits as (
    select distinct t.person_id, t.organization_id from public.clearance_phonetic_name_tokens t join q on t.phonetic_codes && q.codes
  )
  select r.person_id, r.organization_id, r.participant_kind, r.case_id, r.docket_number, r.case_number, r.full_name, r.aliases, r.status, r.last_updated,
    62, 'Sound-alike phonetic token match', 'phonetic', r.role_label, r.age, r.violations,
    r.is_voided, r.is_corrected, r.replaced_by_person_id, r.active_person_id, r.correction_reason, r.corrected_at, r.corrected_by, r.old_snapshot_json, r.new_snapshot_json, r.result_group, r.match_source
  from hits h
  join lateral public.search_clearance_records(coalesce((select full_name from public.persons where id=h.person_id),(select organization_name from public.organizations where id=h.organization_id)), 'name', 100) r on r.person_id is not distinct from h.person_id and r.organization_id is not distinct from h.organization_id
  limit least(greatest(coalesce(p_limit,50),1),100);
$$;

grant execute on function public.search_clearance_records(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_possible_matches(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_possible_matches_v31(text, text, integer) to anon, authenticated, service_role;
grant execute on function public.search_clearance_phonetic_matches(text, text, integer) to anon, authenticated, service_role;
