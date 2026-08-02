CREATE OR REPLACE FUNCTION public.add_case_participant(p_payload jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case_id bigint := nullif(p_payload->>'caseId', '')::bigint;
  v_user_id bigint := nullif(p_payload->>'userId', '')::bigint;
  v_item jsonb := coalesce(p_payload->'participant', '{}'::jsonb);
  v_kind text := upper(coalesce(nullif(btrim(v_item->>'participantKind'), ''), 'PERSON'));
  v_role_id bigint := nullif(v_item->>'roleId', '')::bigint;
  v_person_id bigint;
  v_organization_id bigint;
  v_case_participant_id bigint;
  v_contact_id bigint;
  v_name text;
  v_order integer;
  v_relationship jsonb;
BEGIN
  IF v_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Valid caseId is required'; END IF;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'userId is required'; END IF;
  IF v_kind NOT IN ('PERSON', 'ORGANIZATION') THEN RAISE EXCEPTION 'participantKind must be PERSON or ORGANIZATION'; END IF;
  IF v_role_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.participant_roles WHERE id = v_role_id AND coalesce(is_active, true)) THEN RAISE EXCEPTION 'Valid active roleId is required'; END IF;

  IF v_kind = 'ORGANIZATION' THEN
    v_name := nullif(btrim(v_item->>'organizationName'), '');
    IF v_name IS NULL THEN RAISE EXCEPTION 'Organization name is required'; END IF;
    INSERT INTO public.organizations(organization_name, contact_person, contact_number, email, details_jsonb, created_by_user_id, updated_by_user_id)
    VALUES (v_name, nullif(btrim(v_item->>'contactPerson'), ''), nullif(btrim(v_item->>'contactNumber'), ''), nullif(btrim(v_item->>'email'), ''), '{}'::jsonb, v_user_id, v_user_id)
    RETURNING id INTO v_organization_id;
  ELSE
    v_name := regexp_replace(concat_ws(' ', nullif(btrim(v_item->>'firstName'), ''), CASE WHEN coalesce((v_item->>'noMiddleName')::boolean, false) THEN 'NMN' ELSE nullif(btrim(v_item->>'middleName'), '') END, nullif(btrim(v_item->>'lastName'), ''), nullif(btrim(v_item->>'suffix'), '')), '\s+', ' ', 'g');
    IF nullif(v_name, '') IS NULL THEN RAISE EXCEPTION 'Participant name is required'; END IF;
    INSERT INTO public.persons(first_name, middle_name, last_name, suffix, full_name, gender, birth_date, age, notes, person_descriptor)
    VALUES (nullif(btrim(v_item->>'firstName'), ''), CASE WHEN coalesce((v_item->>'noMiddleName')::boolean, false) THEN 'NMN' ELSE nullif(btrim(v_item->>'middleName'), '') END, nullif(btrim(v_item->>'lastName'), ''), nullif(btrim(v_item->>'suffix'), ''), v_name, nullif(btrim(v_item->>'gender'), ''), nullif(v_item->>'birthDate', '')::date, nullif(btrim(v_item->>'age'), ''), nullif(btrim(v_item->>'notes'), ''), nullif(btrim(v_item->>'personDescriptor'), ''))
    RETURNING id INTO v_person_id;
  END IF;

  SELECT coalesce(max(participant_order), 0) + 1 INTO v_order FROM public.case_participants WHERE case_id = v_case_id;
  INSERT INTO public.case_participants(case_id, person_id, organization_id, role_id, participant_order, participant_kind, display_name_snapshot)
  VALUES (v_case_id, v_person_id, v_organization_id, v_role_id, v_order, v_kind, v_name) RETURNING id INTO v_case_participant_id;

  INSERT INTO public.case_participant_private_details(case_participant_id, case_id, source, remarks, source_detail)
  VALUES (v_case_participant_id, v_case_id, 'MANUAL_ENTRY', nullif(btrim(v_item->>'remarks'), ''), nullif(btrim(v_item->>'sourceDetail'), ''));

  IF nullif(btrim(v_item->>'contactNumber'), '') IS NOT NULL THEN
    INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary)
    VALUES ('PHONE', btrim(v_item->>'contactNumber'), 'Primary phone', true) RETURNING id INTO v_contact_id;
    INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_case_participant_id, v_contact_id);
  END IF;
  IF nullif(btrim(v_item->>'email'), '') IS NOT NULL THEN
    INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary)
    VALUES ('EMAIL', btrim(v_item->>'email'), 'Primary email', false) RETURNING id INTO v_contact_id;
    INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_case_participant_id, v_contact_id);
  END IF;

  IF v_kind = 'PERSON' THEN
    INSERT INTO public.case_participant_attributes(case_participant_id, age_text, age_years, gender_text, gender_normalized, is_minor_at_case, is_senior_at_case, is_pwd_at_case, notes, created_by_user_id, updated_by_user_id)
    VALUES (v_case_participant_id, nullif(btrim(v_item->>'age'), ''), CASE WHEN v_item->>'age' ~ '^\d+$' THEN (v_item->>'age')::int END, nullif(btrim(v_item->>'gender'), ''), nullif(upper(btrim(v_item->>'gender')), ''), coalesce((v_item->>'isMinorAtCase')::boolean, false), coalesce((v_item->>'isSeniorAtCase')::boolean, false), coalesce((v_item->>'isPwdAtCase')::boolean, false), nullif(btrim(v_item->>'attributeNotes'), ''), v_user_id, v_user_id);
    PERFORM public.upsert_clearance_possible_tokens_for_person(v_person_id);
    PERFORM public.upsert_clearance_phonetic_tokens_for_person(v_person_id);
  ELSE
    PERFORM public.upsert_clearance_possible_tokens_for_organization(v_organization_id);
    PERFORM public.upsert_clearance_phonetic_tokens_for_organization(v_organization_id);
  END IF;

  -- Optional relationships are accepted for API callers even though the modal does not require them.
  FOR v_relationship IN SELECT * FROM jsonb_array_elements(coalesce(v_item->'relationships', '[]'::jsonb)) LOOP
    INSERT INTO public.case_participant_relationships(case_id, from_case_participant_id, to_case_participant_id, relationship_type, notes, created_by_user_id)
    VALUES (v_case_id, v_case_participant_id, (v_relationship->>'toCaseParticipantId')::bigint, nullif(upper(btrim(v_relationship->>'relationshipType')), ''), nullif(btrim(v_relationship->>'remarks'), ''), v_user_id);
  END LOOP;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, new_data)
  SELECT v_user_id, 'ADD_CASE_PARTICIPANT', 'case_participants', v_case_participant_id, v_case_id, 'Added case participant', jsonb_build_object('participantKind', v_kind, 'roleId', v_role_id), to_jsonb(detail)
  FROM public.v_case_participants_detail detail WHERE detail.id = v_case_participant_id;
  RETURN v_case_participant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_case_participant(jsonb) TO anon, authenticated, service_role;
