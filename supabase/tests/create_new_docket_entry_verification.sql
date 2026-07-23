-- Repeatable verification for public.create_new_docket_entry(p_payload jsonb).
-- Run with psql against a disposable/local database. The transaction rolls back all rows.
BEGIN;

DO $$
DECLARE
  v_auth_uid uuid := gen_random_uuid();
  v_user_id bigint;
  v_docket_type_id bigint;
  v_status_id bigint;
  v_role_id bigint;
  v_address_type_id bigint;
  v_received_event_type_id bigint;
  v_raffled_event_type_id bigint;
  v_prosecutor_id bigint;
  v_payload jsonb;
  v_result jsonb;
  v_reused_result jsonb;
  v_case_id bigint;
  v_reused_case_id bigint;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_auth_uid::text, true);

  INSERT INTO public.prosecutors(first_name,last_name,full_name,short_name,is_active)
  VALUES ('Verification','Prosecutor','Verification Prosecutor','VERIF',true)
  RETURNING id INTO v_prosecutor_id;

  INSERT INTO auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  VALUES (v_auth_uid,'authenticated','authenticated','verification-' || v_auth_uid || '@example.test',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now())
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.users(email,password_hash,is_active,auth_user_id,prosecutor_id)
  VALUES ('verification-' || v_auth_uid || '@example.test','test-only',true,v_auth_uid,v_prosecutor_id)
  RETURNING id INTO v_user_id;

  INSERT INTO public.docket_types(name,prefix,sort_order,is_active)
  VALUES ('Verification Type ' || v_auth_uid,'VT' || left(replace(v_auth_uid::text,'-',''),4),0,true)
  RETURNING id INTO v_docket_type_id;

  INSERT INTO public.case_statuses(code,display_label,sort_order,is_active)
  VALUES ('VERIFICATION_' || left(replace(v_auth_uid::text,'-',''),8),'Verification Status',0,true)
  RETURNING id INTO v_status_id;

  INSERT INTO public.participant_roles(code,display_label,is_active)
  VALUES ('VERIFICATION_' || right(replace(v_auth_uid::text,'-',''),8),'Verification Role',true)
  RETURNING id INTO v_role_id;

  INSERT INTO public.address_types(code,display_label,is_active)
  VALUES ('VERIFICATION_' || substring(replace(v_auth_uid::text,'-','') from 9 for 8),'Verification Address',true)
  RETURNING id INTO v_address_type_id;

  SELECT id INTO v_received_event_type_id FROM public.case_event_types WHERE code = 'CASE_RECEIVED' AND is_active IS TRUE LIMIT 1;
  IF v_received_event_type_id IS NULL THEN RAISE EXCEPTION 'Required CASE_RECEIVED event type is missing'; END IF;

  SELECT id INTO v_raffled_event_type_id FROM public.case_event_types WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE LIMIT 1;
  IF v_raffled_event_type_id IS NULL THEN RAISE EXCEPTION 'Required CASE_RAFFLED event type is missing'; END IF;

  v_payload := jsonb_build_object(
    'docketTypeId', v_docket_type_id,
    'docketYear', 2099,
    'dateReceived', '2099-01-15',
    'initialStatusId', v_status_id,
    'regionCode', 'TEST',
    'remarks', 'verification case',
    'isSummaryProcedure', false,
    'caseAlsoRaffled', true,
    'assignedProsecutorId', v_prosecutor_id,
    'participants', jsonb_build_array(jsonb_build_object(
      'roleId', v_role_id,
      'participantOrder', 1,
      'newPerson', jsonb_build_object('firstName','Repeatable','middleName','','lastName','Participant','noMiddleName',false),
      'attributes', jsonb_build_object('ageText','33','ageYears',33,'genderText','Female','genderNormalized','FEMALE')
    )),
    'addresses', jsonb_build_array(jsonb_build_object(
      'addressTypeId', v_address_type_id,
      'isPrimary', true,
      'newAddress', jsonb_build_object('line1','1 Verification St','city','General Trias','province','Cavite','country','Philippines')
    )),
    'violations', jsonb_build_array(jsonb_build_object(
      'violationOrder', 1,
      'newViolation', jsonb_build_object('title','Verification Violation'),
      'rawViolationText', 'Verification Violation Raw'
    ))
  );

  v_result := public.create_new_docket_entry(v_payload);

  v_case_id := (v_result->>'caseId')::bigint;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'cases row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_private_details WHERE case_id = v_case_id AND current_status_id = v_status_id) THEN RAISE EXCEPTION 'case_private_details row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.docket_number_history WHERE case_id = v_case_id AND event_type = 'ASSIGNED') THEN RAISE EXCEPTION 'docket_number_history row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participants WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'case_participants row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participant_attributes cpa JOIN public.case_participants cp ON cp.id = cpa.case_participant_id WHERE cp.case_id = v_case_id) THEN RAISE EXCEPTION 'case_participant_attributes row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_addresses WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'case_addresses row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_violations WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'case_violations row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_events WHERE case_id = v_case_id AND status_id = v_status_id AND event_type_id = v_received_event_type_id AND source_table = 'case_status_history' AND source_id IS NOT NULL AND details_jsonb = '{}'::jsonb) THEN RAISE EXCEPTION 'CASE_RECEIVED case_events row missing or details_jsonb filled'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_status_history WHERE case_id = v_case_id AND case_event_id IS NOT NULL) THEN RAISE EXCEPTION 'linked case_status_history row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_assignments WHERE case_id = v_case_id AND prosecutor_id = v_prosecutor_id AND case_event_id IS NOT NULL) THEN RAISE EXCEPTION 'case_assignments row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_events WHERE case_id = v_case_id AND prosecutor_id = v_prosecutor_id AND event_type_id = v_raffled_event_type_id AND source_table = 'case_assignments' AND source_id IS NOT NULL AND details_jsonb = '{}'::jsonb) THEN RAISE EXCEPTION 'CASE_RAFFLED case_events row missing or details_jsonb filled'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.v_case_details_page WHERE id = v_case_id AND prosecutor_full_name IS NOT NULL AND docket_display_number = v_result->>'docketDisplayNumber' AND jsonb_array_length(case_addresses) = 1) THEN RAISE EXCEPTION 'v_case_details_page did not expose assignment/address/display number'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.docket_number_history WHERE case_id = v_case_id AND docket_display_number = v_result->>'docketDisplayNumber') THEN RAISE EXCEPTION 'docket display number mismatch in history'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.v_case_participants_detail WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'v_case_participants_detail row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.v_case_timeline WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'v_case_timeline row missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.v_case_assignment_detail WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'v_case_assignment_detail row missing'; END IF;
  IF (v_result->>'createdViolationCount')::int <> 1 OR (v_result->>'reusedViolationCount')::int <> 0 THEN RAISE EXCEPTION 'new violation counts are incorrect'; END IF;

  v_reused_result := public.create_new_docket_entry(
    jsonb_set(v_payload, '{violations,0,newViolation,title}', to_jsonb('  verification   violation  '::text))
  );
  v_reused_case_id := (v_reused_result->>'caseId')::bigint;

  IF (v_reused_result->>'createdViolationCount')::int <> 0 OR (v_reused_result->>'reusedViolationCount')::int <> 1 THEN RAISE EXCEPTION 'matching violation was not reused'; END IF;
  IF (SELECT violation_id FROM public.case_violations WHERE case_id = v_case_id) <> (SELECT violation_id FROM public.case_violations WHERE case_id = v_reused_case_id) THEN RAISE EXCEPTION 'matching violation did not use the existing catalog row'; END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.audit_logs
    WHERE actor_user_id = v_user_id
      AND action = 'CREATE_DOCKET'
      AND entity_name = 'cases'
      AND entity_id = v_case_id
      AND case_id = v_case_id
      AND summary = 'user[' || v_user_id::text || '] created the new docket ' || (v_result->>'docketDisplayNumber')
      AND metadata->'payload' ? 'participants'
      AND metadata#>>'{inserted,cases,id}' = v_case_id::text
      AND metadata#>'{inserted,cases,columns}' ? 'docket_number'
      AND metadata#>'{inserted,case_participants,columns}' ? 'display_name_snapshot'
  ) THEN RAISE EXCEPTION 'CREATE_DOCKET audit log row missing or incomplete'; END IF;
END $$;

ROLLBACK;
