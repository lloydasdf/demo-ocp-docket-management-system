-- Verification for enhanced public.create_new_docket_entry participant/address/assignment behavior.
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
  v_case_classification_id bigint;
  v_prosecutor_id bigint;
  v_existing_person_id bigint;
  v_existing_address_id bigint;
  v_existing_org_id bigint;
  v_no_raffle_result jsonb;
  v_no_raffle_case_id bigint;
  v_result jsonb;
  v_case_id bigint;
  v_received_event_id bigint;
  v_status_history_id bigint;
  v_assignment_id bigint;
  v_raffle_event_id bigint;
  v_before_cases int;
  v_after_cases int;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', v_auth_uid::text, true);

  INSERT INTO public.prosecutors(first_name,last_name,full_name,short_name,is_active)
  VALUES ('Enhanced','Prosecutor','Enhanced Prosecutor','ENH',true)
  RETURNING id INTO v_prosecutor_id;

  INSERT INTO auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  VALUES (v_auth_uid,'authenticated','authenticated','enhanced-' || v_auth_uid || '@example.test',now(),'{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now())
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.users(email,password_hash,is_active,auth_user_id,prosecutor_id)
  VALUES ('enhanced-' || v_auth_uid || '@example.test','test-only',true,v_auth_uid,v_prosecutor_id)
  RETURNING id INTO v_user_id;

  INSERT INTO public.docket_types(name,prefix,sort_order,is_active)
  VALUES ('Enhanced Type ' || v_auth_uid,'ET' || left(replace(v_auth_uid::text,'-',''),4),0,true)
  RETURNING id INTO v_docket_type_id;

  INSERT INTO public.case_statuses(code,display_label,sort_order,is_active)
  VALUES ('ENHANCED_' || left(replace(v_auth_uid::text,'-',''),8),'Enhanced Status',0,true)
  RETURNING id INTO v_status_id;

  INSERT INTO public.case_classifications(display_label,description,is_active)
  VALUES ('Enhanced Classification','Verification classification',true)
  RETURNING id INTO v_case_classification_id;

  INSERT INTO public.participant_roles(code,display_label,is_active)
  VALUES ('ENHANCED_' || right(replace(v_auth_uid::text,'-',''),8),'Enhanced Role',true)
  RETURNING id INTO v_role_id;

  INSERT INTO public.address_types(code,display_label,is_active)
  VALUES ('ENHANCED_' || substring(replace(v_auth_uid::text,'-','') from 9 for 8),'Enhanced Address',true)
  RETURNING id INTO v_address_type_id;

  INSERT INTO public.persons(first_name,middle_name,last_name,full_name,gender)
  VALUES ('Existing','Middle','Person','Existing Middle Person','Female')
  RETURNING id INTO v_existing_person_id;

  INSERT INTO public.person_aliases(person_id,alias_name,alias_type,source,is_active)
  VALUES (v_existing_person_id,'Existing Alias','AKA','MANUAL_ENTRY',false);

  INSERT INTO public.addresses(line1,city,province,country)
  VALUES ('Existing Person Address','General Trias','Cavite','Philippines')
  RETURNING id INTO v_existing_address_id;

  INSERT INTO public.person_addresses(person_id,address_id,address_type_id,is_primary,remarks)
  VALUES (v_existing_person_id,v_existing_address_id,v_address_type_id,true,'pre-existing relation');

  IF NOT EXISTS (
    SELECT 1
    FROM public.v_person_details pd
    CROSS JOIN LATERAL jsonb_array_elements(pd.person_addresses) AS addr
    WHERE pd.id = v_existing_person_id
      AND (addr->>'address_id')::bigint = v_existing_address_id
  ) THEN RAISE EXCEPTION 'v_person_details did not expose address_id for existing person address'; END IF;

  IF has_table_privilege('anon', 'public.v_organization_search', 'SELECT') THEN RAISE EXCEPTION 'anon must not have SELECT on v_organization_search'; END IF;
  IF NOT has_table_privilege('authenticated', 'public.v_organization_search', 'SELECT') THEN RAISE EXCEPTION 'authenticated must have SELECT on v_organization_search'; END IF;

  INSERT INTO public.organizations(organization_name,created_by_user_id,updated_by_user_id)
  VALUES ('Existing Organization',v_user_id,v_user_id)
  RETURNING id INTO v_existing_org_id;

  INSERT INTO public.organization_aliases(organization_id,alias_name,source,is_active)
  VALUES (v_existing_org_id,'Existing Org Alias','MANUAL_ENTRY',false);

  v_result := public.create_new_docket_entry(jsonb_build_object(
    'docketTypeId', v_docket_type_id,
    'docketYear', 2099,
    'dateReceived', '2099-02-20',
    'initialStatusId', v_status_id,
    'caseClassificationId', v_case_classification_id,
    'regionCode', 'TEST',
    'caseAlsoRaffled', true,
    'assignedProsecutorId', v_prosecutor_id,
    'assignmentDate', '2099-02-20',
    'participants', jsonb_build_array(
      jsonb_build_object(
        'roleId', v_role_id,
        'participantOrder', 1,
        'newPerson', jsonb_build_object('firstName','New','middleName','Middle','lastName','Person','noMiddleName',false,'gender','Male'),
        'aliases', jsonb_build_array(jsonb_build_object('aliasName','New Alias','aliasType','AKA')),
        'addresses', jsonb_build_array(jsonb_build_object(
          'addressTypeId', v_address_type_id,
          'isPrimary', true,
          'newAddress', jsonb_build_object('line1','New Person Address','city','General Trias','province','Cavite','country','Philippines')
        )),
        'attributes', jsonb_build_object('ageText','17','ageYears',17,'genderText','Male','genderNormalized','MALE','minorText','YES','isMinorAtCase',true,'seniorText','NO','isSeniorAtCase',false,'pwdText','YES','isPwdAtCase',true,'residentOfGentriText','YES','isResidentOfGentri',true)
      ),
      jsonb_build_object(
        'roleId', v_role_id,
        'participantOrder', 2,
        'existingPersonId', v_existing_person_id,
        'aliases', jsonb_build_array(jsonb_build_object('aliasName','Existing Alias','aliasType','AKA'), jsonb_build_object('aliasName','Only New Alias','aliasType','AKA')),
        'addresses', jsonb_build_array(
          jsonb_build_object('addressTypeId', v_address_type_id, 'existingAddressId', v_existing_address_id, 'isPrimary', true),
          jsonb_build_object('addressTypeId', v_address_type_id, 'existingAddressId', v_existing_address_id, 'isPrimary', true)
        ),
        'attributes', jsonb_build_object('ageText','45','ageYears',45,'genderText','Female','genderNormalized','FEMALE')
      ),
      jsonb_build_object(
        'roleId', v_role_id,
        'participantOrder', 3,
        'newOrganization', jsonb_build_object('organizationName','New Verification Organization','contactPerson','Org Contact','contactNumber','09170000001','email','new-org@example.test','detailsJsonb',jsonb_build_object('permitNumber','PERMIT-NEW','officeHours','8AM-5PM')),
        'aliases', jsonb_build_array(jsonb_build_object('aliasName','New Org Alias'))
      ),
      jsonb_build_object(
        'roleId', v_role_id,
        'participantOrder', 4,
        'existingOrganizationId', v_existing_org_id,
        'aliases', jsonb_build_array(jsonb_build_object('aliasName','Existing Org Alias'), jsonb_build_object('aliasName','Only New Org Alias'))
      )
    ),
    'placeOfCommission', jsonb_build_object(
      'addressTypeId', v_address_type_id,
      'isPrimary', true,
      'newAddress', jsonb_build_object('line1','Place of Commission','city','General Trias','province','Cavite','country','Philippines')
    ),
    'violations', jsonb_build_array(jsonb_build_object(
      'violationOrder', 1,
      'newViolation', jsonb_build_object('title','Enhanced Verification Violation'),
      'rawViolationText', 'Enhanced Verification Violation Raw'
    ))
  ));

  v_case_id := (v_result->>'caseId')::bigint;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id AND case_classification_id = v_case_classification_id) THEN RAISE EXCEPTION 'case classification was not saved'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participants WHERE case_id = v_case_id AND person_id IS NOT NULL AND participant_kind = 'PERSON') THEN RAISE EXCEPTION 'person participant missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participants WHERE case_id = v_case_id AND organization_id = v_existing_org_id AND person_id IS NULL AND participant_kind = 'ORGANIZATION') THEN RAISE EXCEPTION 'existing organization participant missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participants cp JOIN public.organizations o ON o.id = cp.organization_id WHERE cp.case_id = v_case_id AND o.organization_name = 'New Verification Organization' AND cp.participant_kind = 'ORGANIZATION') THEN RAISE EXCEPTION 'new organization participant missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participants cp JOIN public.organizations o ON o.id = cp.organization_id WHERE cp.case_id = v_case_id AND o.organization_name = 'New Verification Organization' AND o.details_jsonb->>'permitNumber' = 'PERMIT-NEW') THEN RAISE EXCEPTION 'new organization details_jsonb missing'; END IF;
  IF (SELECT count(*) FROM public.person_aliases WHERE person_id = v_existing_person_id AND alias_name = 'Existing Alias') <> 1 THEN RAISE EXCEPTION 'existing person alias duplicated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.person_aliases WHERE person_id = v_existing_person_id AND alias_name = 'Existing Alias' AND is_active IS TRUE) THEN RAISE EXCEPTION 'inactive existing person alias was not reactivated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.person_aliases WHERE person_id = v_existing_person_id AND alias_name = 'Only New Alias') THEN RAISE EXCEPTION 'new person alias missing'; END IF;
  IF (SELECT count(*) FROM public.organization_aliases WHERE organization_id = v_existing_org_id AND alias_name = 'Existing Org Alias') <> 1 THEN RAISE EXCEPTION 'existing organization alias duplicated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organization_aliases WHERE organization_id = v_existing_org_id AND alias_name = 'Existing Org Alias' AND is_active IS TRUE) THEN RAISE EXCEPTION 'inactive existing organization alias was not reactivated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.organization_aliases WHERE organization_id = v_existing_org_id AND alias_name = 'Only New Org Alias') THEN RAISE EXCEPTION 'new organization alias missing'; END IF;
  IF (SELECT count(*) FROM public.person_addresses WHERE person_id = v_existing_person_id AND address_id = v_existing_address_id AND address_type_id = v_address_type_id) <> 1 THEN RAISE EXCEPTION 'duplicate person address relation not skipped'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.person_addresses pa JOIN public.case_participants cp ON cp.person_id = pa.person_id WHERE cp.case_id = v_case_id AND cp.participant_order = 1) THEN RAISE EXCEPTION 'new participant address missing'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_addresses WHERE case_id = v_case_id) THEN RAISE EXCEPTION 'place of commission case address missing'; END IF;
  IF (SELECT count(*) FROM public.case_addresses WHERE case_id = v_case_id) <> 1 THEN RAISE EXCEPTION 'participant address was incorrectly saved as case address'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_participant_attributes cpa JOIN public.case_participants cp ON cp.id = cpa.case_participant_id WHERE cp.case_id = v_case_id AND cpa.age_years = 17 AND cpa.is_minor_at_case IS TRUE AND cpa.is_pwd_at_case IS TRUE AND cpa.is_resident_of_gentri IS TRUE) THEN RAISE EXCEPTION 'participant attributes missing'; END IF;

  SELECT ce.id, csh.id INTO v_received_event_id, v_status_history_id
  FROM public.case_events ce
  JOIN public.case_status_history csh ON csh.case_event_id = ce.id
  WHERE ce.case_id = v_case_id AND ce.source_table = 'case_status_history' AND ce.source_id = csh.id;
  IF v_received_event_id IS NULL OR v_status_history_id IS NULL THEN RAISE EXCEPTION 'received event links missing'; END IF;

  SELECT ca.id, ce.id INTO v_assignment_id, v_raffle_event_id
  FROM public.case_assignments ca
  JOIN public.case_events ce ON ce.id = ca.case_event_id AND ce.source_id = ca.id
  WHERE ca.case_id = v_case_id AND ce.source_table = 'case_assignments';
  IF v_assignment_id IS NULL OR v_raffle_event_id IS NULL THEN RAISE EXCEPTION 'raffle event links missing'; END IF;

  v_no_raffle_result := public.create_new_docket_entry(jsonb_build_object(
    'docketTypeId', v_docket_type_id,
    'docketYear', 2099,
    'dateReceived', '2099-03-01',
    'initialStatusId', v_status_id,
    'caseAlsoRaffled', false,
    'participants', jsonb_build_array(jsonb_build_object('roleId', v_role_id, 'participantOrder', 1, 'existingPersonId', v_existing_person_id)),
    'violations', jsonb_build_array(jsonb_build_object('violationOrder', 1, 'newViolation', jsonb_build_object('title','No Raffle Verification Violation')))
  ));
  v_no_raffle_case_id := (v_no_raffle_result->>'caseId')::bigint;
  IF EXISTS (SELECT 1 FROM public.case_assignments WHERE case_id = v_no_raffle_case_id) THEN RAISE EXCEPTION 'case without raffle created assignment'; END IF;

  SELECT count(*) INTO v_before_cases FROM public.cases;
  BEGIN
    PERFORM public.create_new_docket_entry(jsonb_build_object(
      'docketTypeId', v_docket_type_id,
      'docketYear', 2099,
      'dateReceived', '2099-02-20',
      'initialStatusId', v_status_id,
      'caseAlsoRaffled', true,
      'assignedProsecutorId', v_prosecutor_id,
      'assignmentDate', '2099-02-21',
      'participants', jsonb_build_array(jsonb_build_object('roleId', v_role_id, 'participantOrder', 1, 'existingPersonId', v_existing_person_id)),
      'violations', jsonb_build_array(jsonb_build_object('violationOrder', 1, 'newViolation', jsonb_build_object('title','Rollback Verification Violation')))
    ));
    RAISE EXCEPTION 'same-day validation did not reject different assignmentDate';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Same-day raffle assignment date%' THEN RAISE; END IF;
  END;
  SELECT count(*) INTO v_after_cases FROM public.cases;
  IF v_after_cases <> v_before_cases THEN RAISE EXCEPTION 'invalid payload was not rolled back'; END IF;
END $$;

ROLLBACK;
