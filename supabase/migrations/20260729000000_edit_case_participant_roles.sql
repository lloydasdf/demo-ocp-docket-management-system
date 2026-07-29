-- Extend the participant-management RPC directly so identity details and the
-- participant's case role are corrected and audited in one operation. Keeping a
-- single RPC implementation avoids a fragile renamed-function wrapper.
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
  v_role_id bigint := nullif(v_participant->>'roleId','')::bigint;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_case_participant_id IS NULL THEN RAISE EXCEPTION 'participant.id is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL AND v_action <> 'edit_main_details' THEN RAISE EXCEPTION 'reason is required'; END IF;

  SELECT cp.person_id, cp.organization_id, COALESCE(cp.participant_kind, CASE WHEN cp.organization_id IS NULL THEN 'PERSON' ELSE 'ORGANIZATION' END)
  INTO v_person_id, v_organization_id, v_kind
  FROM public.case_participants cp
  WHERE cp.id = v_case_participant_id AND cp.case_id = v_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Participant % not found for case %', v_case_participant_id, v_case_id; END IF;

  SELECT to_jsonb(vcp) INTO v_old FROM public.v_case_participants_detail vcp WHERE vcp.id = v_case_participant_id;

  IF v_action = 'edit_main_details' THEN
    v_reason := coalesce(v_reason, 'Identity details updated');
    IF v_role_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.participant_roles
      WHERE id = v_role_id AND is_active = true
    ) THEN
      RAISE EXCEPTION 'A valid participant role is required';
    END IF;

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

    UPDATE public.case_participants SET display_name_snapshot = v_display, role_id = v_role_id WHERE id = v_case_participant_id;
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
