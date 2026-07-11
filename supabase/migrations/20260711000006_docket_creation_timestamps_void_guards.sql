BEGIN;

-- Preserve docket creation event times and enforce non-void/supersession rules server-side.
CREATE OR REPLACE FUNCTION public.create_new_docket_entry(p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_auth_uid uuid := auth.uid(); v_user_id bigint; v_case_id bigint; v_item jsonb; v_sub jsonb; v_contact_id bigint; v_audit_metadata jsonb;
  v_docket_type_id bigint := (p_payload->>'docketTypeId')::bigint; v_docket_year int := (p_payload->>'docketYear')::int; v_date_received date := (p_payload->>'dateReceived')::date; v_time_received time without time zone := COALESCE(nullif(p_payload->>'timeReceived','')::time, CURRENT_TIME(0)); v_initial_status_id bigint := (p_payload->>'initialStatusId')::bigint;
  v_case_classification_id bigint := nullif(p_payload->>'caseClassificationId','')::bigint; v_region_code text := nullif(btrim(p_payload->>'regionCode'), ''); v_month_code text; v_docket_number int; v_display text; v_dt_prefix text;
  v_person_id bigint; v_org_id bigint; v_name text; v_cp_id bigint; v_address_id bigint; v_violation_id bigint; v_received_event_type_id bigint; v_raffled_event_type_id bigint; v_event_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_assignment_event_id bigint; v_assignment_id bigint;
  v_pending_status_id bigint; v_for_raffle_stage_id bigint; v_case_raffled_stage_id bigint; v_initial_stage_id bigint; v_status_date date := COALESCE(v_date_received, CURRENT_DATE);
  v_assigned_prosecutor_id bigint := CASE WHEN COALESCE((p_payload->>'caseAlsoRaffled')::boolean,false) THEN nullif(p_payload->>'assignedProsecutorId','')::bigint ELSE NULL END; v_assignment_date date := COALESCE(nullif(p_payload->>'assignmentDate','')::date, v_date_received); v_assignment_time time without time zone := COALESCE(nullif(p_payload->>'assignmentTime','')::time, v_time_received); v_assignment_remarks text := CASE WHEN p_payload ? 'assignmentRemarks' THEN nullif(btrim(p_payload->>'assignmentRemarks'),'') ELSE 'Assigned during manual docket creation' END;
  v_case_note_text text := nullif(btrim(p_payload->>'notes'),'');
  v_case_received_description text := COALESCE(nullif(btrim(p_payload->>'caseReceivedDescription'),''), 'Case received on ' || to_char(v_date_received, 'FMMM/FMDD/YYYY'));
  v_seen_violation_ids bigint[] := '{}'; v_created_persons int := 0; v_reused_persons int := 0; v_created_addresses int := 0; v_reused_addresses int := 0; v_created_violations int := 0; v_reused_violations int := 0; v_participant_count int := 0; v_violation_count int := 0;
BEGIN
  IF v_auth_uid IS NULL THEN RAISE EXCEPTION 'Authenticated Supabase user is required for docket creation'; END IF;
  SELECT id INTO v_user_id FROM public.users WHERE auth_user_id = v_auth_uid AND is_active IS TRUE LIMIT 1;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authenticated user % is not mapped to an active public.users row', v_auth_uid; END IF;
  IF v_docket_type_id IS NULL OR v_docket_year IS NULL OR v_date_received IS NULL THEN RAISE EXCEPTION 'Missing required case fields'; END IF;
  IF jsonb_array_length(COALESCE(p_payload->'participants','[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'At least one participant is required'; END IF;
  IF jsonb_array_length(COALESCE(p_payload->'violations','[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'At least one violation is required'; END IF;
  SELECT prefix INTO v_dt_prefix FROM public.docket_types WHERE id = v_docket_type_id AND is_active IS TRUE; IF v_dt_prefix IS NULL THEN RAISE EXCEPTION 'Invalid docket type id'; END IF;
  IF v_initial_status_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.case_statuses WHERE id = v_initial_status_id) THEN RAISE EXCEPTION 'Invalid initial status id'; END IF;
  IF v_case_classification_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.case_classifications WHERE id = v_case_classification_id) THEN RAISE EXCEPTION 'Invalid case classification id %', v_case_classification_id; END IF;
  IF COALESCE((p_payload->>'caseAlsoRaffled')::boolean,false) AND v_assigned_prosecutor_id IS NULL THEN RAISE EXCEPTION 'assignedProsecutorId is required when caseAlsoRaffled is true'; END IF;
  IF v_assigned_prosecutor_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = v_assigned_prosecutor_id AND is_active IS TRUE) THEN RAISE EXCEPTION 'Invalid assigned prosecutor id %', v_assigned_prosecutor_id; END IF;
  SELECT id INTO v_received_event_type_id FROM public.case_event_types WHERE is_active IS TRUE AND code = 'CASE_RECEIVED' LIMIT 1; IF v_received_event_type_id IS NULL THEN RAISE EXCEPTION 'No active CASE_RECEIVED case event type'; END IF;
  IF v_assigned_prosecutor_id IS NOT NULL THEN SELECT id INTO v_raffled_event_type_id FROM public.case_event_types WHERE is_active IS TRUE AND code = 'CASE_RAFFLED' LIMIT 1; IF v_raffled_event_type_id IS NULL THEN RAISE EXCEPTION 'No active CASE_RAFFLED case event type'; END IF; END IF;
  SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1; IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'No active PENDING case status'; END IF;
  SELECT id INTO v_for_raffle_stage_id FROM public.case_stages WHERE code = 'FOR_RAFFLE' AND is_active IS TRUE LIMIT 1; IF v_for_raffle_stage_id IS NULL THEN RAISE EXCEPTION 'No active FOR_RAFFLE case stage'; END IF;
  SELECT id INTO v_case_raffled_stage_id FROM public.case_stages WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE LIMIT 1; IF v_case_raffled_stage_id IS NULL THEN RAISE EXCEPTION 'No active CASE_RAFFLED case stage'; END IF;
  v_initial_stage_id := CASE WHEN v_assigned_prosecutor_id IS NOT NULL THEN v_case_raffled_stage_id ELSE v_for_raffle_stage_id END;

  PERFORM pg_advisory_xact_lock(v_docket_type_id::int, v_docket_year);
  SELECT COALESCE(MAX(docket_number),0)+1 INTO v_docket_number FROM public.cases WHERE docket_type_id = v_docket_type_id AND docket_year = v_docket_year;
  v_month_code := upper(COALESCE(nullif(btrim(p_payload->>'docketMonthCode'),''), chr(64 + extract(month from v_date_received)::int))); IF v_month_code !~ '^[A-L]$' THEN RAISE EXCEPTION 'Invalid docket month code %', v_month_code; END IF; v_display := concat_ws('-', v_region_code, v_dt_prefix, right(v_docket_year::text,2)||v_month_code, lpad(v_docket_number::text,6,'0'));
  INSERT INTO public.cases(docket_type_id,docket_year,docket_number,date_received,created_by_user_id,updated_by_user_id,is_archived,region_code,docket_month_code,case_classification_id) VALUES (v_docket_type_id,v_docket_year,v_docket_number,v_date_received,v_user_id,v_user_id,false,v_region_code,v_month_code,v_case_classification_id) RETURNING id INTO v_case_id;
  INSERT INTO public.case_private_details(case_id,source,remarks,is_summary_procedure,summary_text,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date) VALUES (v_case_id,'MANUAL_ENTRY',nullif(btrim(p_payload->>'remarks'),''),COALESCE((p_payload->>'isSummaryProcedure')::boolean,false),nullif(btrim(p_payload->>'summaryText'),''),v_pending_status_id,v_status_date,v_pending_status_id,v_status_date,v_initial_stage_id,v_status_date);
  INSERT INTO public.docket_number_history(case_id,docket_type_id,docket_year,docket_number,docket_display_number,event_type,changed_by_user_id,changed_at,reason) VALUES (v_case_id,v_docket_type_id,v_docket_year,v_docket_number,v_display,'ASSIGNED',v_user_id,now(),'Manual docket creation');
  IF v_case_note_text IS NOT NULL THEN INSERT INTO public.notes(case_id,created_by_user_id,note_text,is_private) VALUES (v_case_id,v_user_id,v_case_note_text,false); END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'participants') LOOP
    IF (nullif(v_item->>'existingPersonId','') IS NOT NULL OR v_item ? 'newPerson') AND (nullif(v_item->>'existingOrganizationId','') IS NOT NULL OR v_item ? 'newOrganization') THEN RAISE EXCEPTION 'Participant cannot contain both person and organization identity'; END IF;
    IF NOT (nullif(v_item->>'existingPersonId','') IS NOT NULL OR v_item ? 'newPerson' OR nullif(v_item->>'existingOrganizationId','') IS NOT NULL OR v_item ? 'newOrganization') THEN RAISE EXCEPTION 'Participant must contain exactly one person or organization identity'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.participant_roles WHERE id = (v_item->>'roleId')::bigint) THEN RAISE EXCEPTION 'Invalid participant role'; END IF;
    v_person_id := NULL; v_org_id := NULL;
    IF nullif(v_item->>'existingOrganizationId','') IS NOT NULL OR v_item ? 'newOrganization' THEN
      IF nullif(v_item->>'existingOrganizationId','') IS NOT NULL THEN SELECT id, organization_name INTO v_org_id, v_name FROM public.organizations WHERE id=(v_item->>'existingOrganizationId')::bigint; IF v_org_id IS NULL THEN RAISE EXCEPTION 'Existing organization not found'; END IF;
      ELSE v_name := nullif(btrim(v_item#>>'{newOrganization,organizationName}'),''); IF v_name IS NULL THEN RAISE EXCEPTION 'Organization name is required'; END IF; INSERT INTO public.organizations(organization_name,contact_person,contact_number,email,details_jsonb,created_by_user_id,updated_by_user_id) VALUES (v_name,nullif(btrim(v_item#>>'{newOrganization,contactPerson}'),''),nullif(btrim(v_item#>>'{newOrganization,contactNumber}'),''),nullif(btrim(v_item#>>'{newOrganization,email}'),''),COALESCE(NULLIF(v_item#>'{newOrganization,detailsJsonb}', 'null'::jsonb), '{}'::jsonb),v_user_id,v_user_id) RETURNING id INTO v_org_id; END IF;
      FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'aliases','[]'::jsonb)) LOOP IF nullif(btrim(v_sub->>'aliasName'),'') IS NOT NULL THEN UPDATE public.organization_aliases oa SET is_active = TRUE, updated_at = now() WHERE oa.organization_id = v_org_id AND lower(btrim(oa.alias_name)) = lower(btrim(v_sub->>'aliasName')) AND oa.is_active IS FALSE; INSERT INTO public.organization_aliases(organization_id,alias_name,source) SELECT v_org_id,btrim(v_sub->>'aliasName'),'MANUAL_ENTRY' WHERE NOT EXISTS (SELECT 1 FROM public.organization_aliases oa WHERE oa.organization_id = v_org_id AND lower(btrim(oa.alias_name)) = lower(btrim(v_sub->>'aliasName'))); END IF; END LOOP;
      PERFORM public.upsert_clearance_possible_tokens_for_organization(v_org_id); PERFORM public.upsert_clearance_phonetic_tokens_for_organization(v_org_id);
    ELSE
      IF nullif(v_item->>'existingPersonId','') IS NOT NULL THEN SELECT id, full_name INTO v_person_id, v_name FROM public.persons WHERE id=(v_item->>'existingPersonId')::bigint; IF v_person_id IS NULL THEN RAISE EXCEPTION 'Existing person not found'; END IF; v_reused_persons := v_reused_persons+1;
      ELSE v_name := regexp_replace(concat_ws(' ', nullif(btrim(v_item#>>'{newPerson,firstName}'),''), CASE WHEN COALESCE((v_item#>>'{newPerson,noMiddleName}')::boolean,false) THEN 'NMN' ELSE nullif(btrim(v_item#>>'{newPerson,middleName}'),'') END, nullif(btrim(v_item#>>'{newPerson,lastName}'),''), nullif(btrim(v_item#>>'{newPerson,suffix}'),'')), '\s+', ' ', 'g'); IF v_name = '' THEN RAISE EXCEPTION 'New participant full-name preview cannot be empty'; END IF; INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor) VALUES (nullif(btrim(v_item#>>'{newPerson,firstName}'),''),CASE WHEN COALESCE((v_item#>>'{newPerson,noMiddleName}')::boolean,false) THEN 'NMN' ELSE nullif(btrim(v_item#>>'{newPerson,middleName}'),'') END,nullif(btrim(v_item#>>'{newPerson,lastName}'),''),nullif(btrim(v_item#>>'{newPerson,suffix}'),''),v_name,nullif(btrim(v_item#>>'{newPerson,gender}'),''),nullif(v_item#>>'{newPerson,birthDate}','')::date,nullif(btrim(v_item#>>'{newPerson,notes}'),''),nullif(btrim(v_item#>>'{newPerson,personDescriptor}'),'')) RETURNING id INTO v_person_id; v_created_persons := v_created_persons+1; END IF;
      FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'aliases','[]'::jsonb)) LOOP IF nullif(btrim(v_sub->>'aliasName'),'') IS NOT NULL THEN UPDATE public.person_aliases pa SET is_active = TRUE, updated_at = now() WHERE pa.person_id = v_person_id AND lower(btrim(pa.alias_name)) = lower(btrim(v_sub->>'aliasName')) AND pa.is_active IS FALSE; INSERT INTO public.person_aliases(person_id,alias_name,alias_type,source) SELECT v_person_id,btrim(v_sub->>'aliasName'),'AKA','MANUAL_ENTRY' WHERE NOT EXISTS (SELECT 1 FROM public.person_aliases pa WHERE pa.person_id = v_person_id AND lower(btrim(pa.alias_name)) = lower(btrim(v_sub->>'aliasName'))); END IF; END LOOP;
      PERFORM public.upsert_clearance_possible_tokens_for_person(v_person_id); PERFORM public.upsert_clearance_phonetic_tokens_for_person(v_person_id);
    END IF;
    FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'addresses','[]'::jsonb)) LOOP
      IF nullif(v_sub->>'existingAddressId','') IS NOT NULL THEN SELECT id INTO v_address_id FROM public.addresses WHERE id=(v_sub->>'existingAddressId')::bigint; IF v_address_id IS NULL THEN RAISE EXCEPTION 'Existing address not found'; END IF; v_reused_addresses:=v_reused_addresses+1; ELSE INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_sub#>>'{newAddress,line1}'),''),nullif(btrim(v_sub#>>'{newAddress,line2}'),''),nullif(btrim(v_sub#>>'{newAddress,barangay}'),''),nullif(btrim(v_sub#>>'{newAddress,city}'),''),nullif(btrim(v_sub#>>'{newAddress,province}'),''),nullif(btrim(v_sub#>>'{newAddress,region}'),''),nullif(btrim(v_sub#>>'{newAddress,zipCode}'),''),COALESCE(nullif(btrim(v_sub#>>'{newAddress,country}'),''),'Philippines')) RETURNING id INTO v_address_id; v_created_addresses:=v_created_addresses+1; END IF;
      IF v_org_id IS NOT NULL THEN INSERT INTO public.organization_addresses(organization_id,address_id,address_type_id,is_primary,remarks) VALUES (v_org_id,v_address_id,(v_sub->>'addressTypeId')::bigint,COALESCE((v_sub->>'isPrimary')::boolean,false),nullif(btrim(v_sub->>'remarks'),'')) ON CONFLICT (organization_id,address_id,address_type_id) DO UPDATE SET is_primary = EXCLUDED.is_primary, remarks = COALESCE(EXCLUDED.remarks, public.organization_addresses.remarks);
      ELSE INSERT INTO public.person_addresses(person_id,address_id,address_type_id,is_primary,remarks) VALUES (v_person_id,v_address_id,(v_sub->>'addressTypeId')::bigint,COALESCE((v_sub->>'isPrimary')::boolean,false),nullif(btrim(v_sub->>'remarks'),'')) ON CONFLICT (person_id,address_id,address_type_id) DO UPDATE SET is_primary = EXCLUDED.is_primary, remarks = COALESCE(EXCLUDED.remarks, public.person_addresses.remarks); END IF;
    END LOOP;
    INSERT INTO public.case_participants(case_id,person_id,organization_id,role_id,participant_order,participant_kind,display_name_snapshot) VALUES (v_case_id,v_person_id,v_org_id,(v_item->>'roleId')::bigint,COALESCE((v_item->>'participantOrder')::int,v_participant_count+1),CASE WHEN v_org_id IS NULL THEN 'PERSON' ELSE 'ORGANIZATION' END,v_name) RETURNING id INTO v_cp_id; v_participant_count:=v_participant_count+1;
    FOR v_sub IN SELECT * FROM jsonb_array_elements(COALESCE(v_item->'contactInformations','[]'::jsonb)) LOOP
      IF nullif(btrim(v_sub->>'contactValue'),'') IS NOT NULL THEN
        INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary, remarks)
        VALUES (COALESCE(nullif(upper(btrim(v_sub->>'contactType')),''),'PHONE'), btrim(v_sub->>'contactValue'), nullif(btrim(v_sub->>'label'),''), COALESCE((v_sub->>'isPrimary')::boolean,false), nullif(btrim(v_sub->>'remarks'),''))
        RETURNING id INTO v_contact_id;
        INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_cp_id, v_contact_id);
      END IF;
    END LOOP;
    IF nullif(btrim(v_item->>'contactNumber'),'') IS NOT NULL THEN INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary) VALUES ('PHONE', btrim(v_item->>'contactNumber'), 'Primary phone', true) RETURNING id INTO v_contact_id; INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_cp_id, v_contact_id); END IF;
    IF nullif(btrim(v_item->>'email'),'') IS NOT NULL THEN INSERT INTO public.contact_informations(contact_type, contact_value, label, is_primary) VALUES ('EMAIL', btrim(v_item->>'email'), 'Primary email', false) RETURNING id INTO v_contact_id; INSERT INTO public.participant_contact_informations(case_participant_id, contact_information_id) VALUES (v_cp_id, v_contact_id); END IF;
    IF nullif(btrim(v_item->>'remarks'),'') IS NOT NULL OR nullif(btrim(v_item->>'sourceDetail'),'') IS NOT NULL THEN INSERT INTO public.case_participant_private_details(case_participant_id,case_id,source,remarks,source_detail) VALUES (v_cp_id,v_case_id,'MANUAL_ENTRY',nullif(btrim(v_item->>'remarks'),''),nullif(btrim(v_item->>'sourceDetail'),'')); END IF;
    IF v_person_id IS NOT NULL AND v_item ? 'attributes' AND v_item->'attributes' <> 'null'::jsonb THEN INSERT INTO public.case_participant_attributes(case_participant_id,age_text,age_years,age_basis_date,age_source,gender_text,gender_normalized,minor_text,is_minor_at_case,senior_text,is_senior_at_case,pwd_text,is_pwd_at_case,notes,created_by_user_id,updated_by_user_id) VALUES (v_cp_id,nullif(btrim(v_item#>>'{attributes,ageText}'),''),nullif(v_item#>>'{attributes,ageYears}','')::int,v_date_received,'MANUAL_ENTRY',nullif(btrim(v_item#>>'{attributes,genderText}'),''),nullif(btrim(v_item#>>'{attributes,genderNormalized}'),''),nullif(btrim(v_item#>>'{attributes,minorText}'),''),nullif(v_item#>>'{attributes,isMinorAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,seniorText}'),''),nullif(v_item#>>'{attributes,isSeniorAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,pwdText}'),''),nullif(v_item#>>'{attributes,isPwdAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,notes}'),''),v_user_id,v_user_id); END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(CASE WHEN p_payload ? 'placesOfCommission' AND jsonb_typeof(p_payload->'placesOfCommission') = 'array' THEN p_payload->'placesOfCommission' WHEN p_payload ? 'placeOfCommission' AND p_payload->'placeOfCommission' <> 'null'::jsonb THEN jsonb_build_array(p_payload->'placeOfCommission') ELSE COALESCE(p_payload->'addresses','[]'::jsonb) END) LOOP
    IF nullif(v_item->>'existingAddressId','') IS NOT NULL THEN SELECT id INTO v_address_id FROM public.addresses WHERE id=(v_item->>'existingAddressId')::bigint; v_reused_addresses:=v_reused_addresses+1; ELSE INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_item#>>'{newAddress,line1}'),''),nullif(btrim(v_item#>>'{newAddress,line2}'),''),nullif(btrim(v_item#>>'{newAddress,barangay}'),''),nullif(btrim(v_item#>>'{newAddress,city}'),''),nullif(btrim(v_item#>>'{newAddress,province}'),''),nullif(btrim(v_item#>>'{newAddress,region}'),''),nullif(btrim(v_item#>>'{newAddress,zipCode}'),''),COALESCE(nullif(btrim(v_item#>>'{newAddress,country}'),''),'Philippines')) RETURNING id INTO v_address_id; v_created_addresses:=v_created_addresses+1; END IF;
    INSERT INTO public.case_addresses(case_id,address_id,address_type_id,is_primary,remarks) VALUES (v_case_id,v_address_id,(v_item->>'addressTypeId')::bigint,COALESCE((v_item->>'isPrimary')::boolean,true),nullif(btrim(v_item->>'remarks'),''));
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'violations') LOOP
    v_violation_id := COALESCE(NULLIF(v_item->>'existingViolationId',''), NULLIF(v_item->>'violationId',''))::bigint;
    IF v_violation_id IS NULL THEN INSERT INTO public.violations(title,reference_code,short_label,description,law_reference,created_by_user_id,is_active,canonical_title) VALUES (btrim(v_item#>>'{newViolation,title}'),nullif(btrim(v_item#>>'{newViolation,referenceCode}'),''),nullif(btrim(v_item#>>'{newViolation,shortLabel}'),''),nullif(btrim(v_item#>>'{newViolation,description}'),''),nullif(btrim(v_item#>>'{newViolation,lawReference}'),''),v_user_id,true,regexp_replace(lower(btrim(v_item#>>'{newViolation,title}')), '\s+', ' ', 'g')) RETURNING id INTO v_violation_id; v_created_violations:=v_created_violations+1; ELSE v_reused_violations:=v_reused_violations+1; END IF;
    IF v_violation_id = ANY(v_seen_violation_ids) THEN RAISE EXCEPTION 'Duplicate violation id % in payload', v_violation_id; END IF; v_seen_violation_ids:=array_append(v_seen_violation_ids,v_violation_id);
    INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text) VALUES (v_case_id,v_violation_id,COALESCE((v_item->>'violationOrder')::int,v_violation_count+1),nullif(btrim(v_item->>'rawViolationText'),'')); v_violation_count:=v_violation_count+1;
  END LOOP;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,event_order,title,description,status_id,case_status_id,case_stage_id,source,source_table,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_received_event_type_id,v_status_date,v_time_received,1,'Case received',v_case_received_description,v_pending_status_id,v_pending_status_id,v_initial_stage_id,'MANUAL_ENTRY','case_status_history',v_user_id,v_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,NULL,v_pending_status_id,v_user_id,now(),v_status_date,v_case_received_description,v_event_id) RETURNING id INTO v_status_history_id;
  INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (v_case_id,NULL,v_initial_stage_id,v_user_id,now(),v_status_date,v_case_received_description,v_event_id) RETURNING id INTO v_stage_history_id;
  UPDATE public.case_events SET source_id = v_status_history_id WHERE id = v_event_id;
  IF v_assigned_prosecutor_id IS NOT NULL THEN INSERT INTO public.case_assignments(case_id,prosecutor_id,assigned_by_user_id,assigned_at,remarks) VALUES (v_case_id,v_assigned_prosecutor_id,v_user_id,(v_assignment_date + v_assignment_time) AT TIME ZONE 'Asia/Manila',v_assignment_remarks) RETURNING id INTO v_assignment_id; INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,event_order,title,description,status_id,case_status_id,case_stage_id,prosecutor_id,source,source_table,source_id,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_raffled_event_type_id,v_assignment_date,v_assignment_time,2,'Case raffled',v_assignment_remarks,v_pending_status_id,v_pending_status_id,v_case_raffled_stage_id,v_assigned_prosecutor_id,'MANUAL_ENTRY','case_assignments',v_assignment_id,v_user_id,v_user_id) RETURNING id INTO v_assignment_event_id; UPDATE public.case_assignments SET case_event_id = v_assignment_event_id WHERE id = v_assignment_id; END IF;

  v_audit_metadata := jsonb_build_object(
    'payload', p_payload,
    'case_status_stage_split', jsonb_build_object(
      'current_case_status_id', v_pending_status_id,
      'current_case_stage_id', v_initial_stage_id,
      'case_received_event_id', v_event_id,
      'case_received_event_case_status_id', v_pending_status_id,
      'case_received_event_case_stage_id', v_initial_stage_id,
      'assignment_event_id', v_assignment_event_id,
      'assignment_event_case_status_id', CASE WHEN v_assignment_event_id IS NULL THEN NULL ELSE v_pending_status_id END,
      'assignment_event_case_stage_id', CASE WHEN v_assignment_event_id IS NULL THEN NULL ELSE v_case_raffled_stage_id END,
      'case_stage_history_id', v_stage_history_id
    ),
    'inserted', jsonb_build_object(
      'cases', jsonb_build_object('id', v_case_id, 'columns', jsonb_build_array('docket_type_id','docket_year','docket_number','date_received','created_by_user_id','updated_by_user_id','is_archived','region_code','docket_month_code','case_classification_id')),
      'case_private_details', jsonb_build_object('columns', jsonb_build_array('case_id','source','remarks','is_summary_procedure','summary_text','current_status_id','current_status_date','current_case_status_id','current_case_status_date','current_case_stage_id','current_case_stage_date')),
      'notes', CASE WHEN v_case_note_text IS NULL THEN NULL ELSE jsonb_build_object('columns', jsonb_build_array('case_id','created_by_user_id','note_text','is_private')) END,
      'docket_number_history', jsonb_build_object('columns', jsonb_build_array('case_id','docket_type_id','docket_year','docket_number','docket_display_number','event_type','changed_by_user_id','changed_at','reason')),
      'case_participants', jsonb_build_object('count', v_participant_count, 'columns', jsonb_build_array('case_id','person_id','organization_id','role_id','participant_order','participant_kind','display_name_snapshot')),
      'case_addresses', jsonb_build_object('columns', jsonb_build_array('case_id','address_id','address_type_id','is_primary','remarks')),
      'case_violations', jsonb_build_object('count', v_violation_count, 'columns', jsonb_build_array('case_id','violation_id','violation_order','raw_violation_text')),
      'case_events', jsonb_build_object('columns', jsonb_build_array('case_id','event_type_id','event_date','event_order','title','description','status_id','case_status_id','case_stage_id','prosecutor_id','source','source_table','source_id','created_by_user_id','updated_by_user_id')),
      'case_status_history', jsonb_build_object('id', v_status_history_id, 'columns', jsonb_build_array('case_id','from_status_id','to_status_id','changed_by_user_id','changed_at','status_date','remarks','case_event_id')),
      'case_stage_history', jsonb_build_object('id', v_stage_history_id, 'columns', jsonb_build_array('case_id','from_stage_id','to_stage_id','changed_by_user_id','changed_at','stage_date','remarks','case_event_id')),
      'case_assignments', CASE WHEN v_assignment_id IS NULL THEN NULL ELSE jsonb_build_object('id', v_assignment_id, 'columns', jsonb_build_array('case_id','prosecutor_id','assigned_by_user_id','assigned_at','remarks','case_event_id')) END,
      'persons', jsonb_build_object('createdCount', v_created_persons, 'reusedCount', v_reused_persons),
      'addresses', jsonb_build_object('createdCount', v_created_addresses, 'reusedCount', v_reused_addresses),
      'violations', jsonb_build_object('createdCount', v_created_violations, 'reusedCount', v_reused_violations),
      'contact_informations', jsonb_build_object('columns', jsonb_build_array('contact_type','contact_value','label','is_primary','remarks')),
      'participant_contact_informations', jsonb_build_object('columns', jsonb_build_array('case_participant_id','contact_information_id'))
    )
  );

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, new_data)
  VALUES (v_user_id, 'CREATE_DOCKET', 'cases', v_case_id, v_case_id, 'user[' || v_user_id::text || '] created the new docket ' || v_display, v_audit_metadata, v_audit_metadata);

  RETURN jsonb_build_object('caseId',v_case_id,'docketTypeId',v_docket_type_id,'docketYear',v_docket_year,'docketNumber',v_docket_number,'docketMonthCode',v_month_code,'docketDisplayNumber',v_display,'createdPersonCount',v_created_persons,'reusedPersonCount',v_reused_persons,'createdAddressCount',v_created_addresses,'reusedAddressCount',v_reused_addresses,'createdViolationCount',v_created_violations,'reusedViolationCount',v_reused_violations,'participantCount',v_participant_count,'violationCount',v_violation_count);
END;
$_$;


--
-- Name: FUNCTION create_new_docket_entry(p_payload jsonb); Type: COMMENT; Schema: public; Owner: -
--


CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
  v_motion_id bigint; v_motion_old jsonb; v_motion_new jsonb;
  v_petition_id bigint; v_petition_old jsonb; v_petition_new jsonb;
  v_manual_update_id bigint; v_manual_update_old jsonb; v_manual_update_new jsonb;
  v_motion_resolution_id bigint; v_motion_resolution_old jsonb; v_motion_resolution_new jsonb; v_motion_approval_count integer;
  v_motion_decision_approval_id bigint; v_motion_decision_approval_old jsonb; v_motion_decision_approval_new jsonb;
  v_previous_assignment_id bigint; v_previous_assignment_old jsonb; v_previous_assignment_new jsonb; v_latest_assignment_id bigint;
  v_status_code text; v_status_label text; v_status_id bigint; v_prev_status_id bigint; v_status_history_id bigint; v_old_details jsonb; v_new_details jsonb;
BEGIN
  IF nullif(trim(p_void_reason), '') IS NULL THEN RAISE EXCEPTION 'Void reason is required'; END IF;
  SELECT to_jsonb(ce), ce.case_id, cet.code, ce.source_table, ce.source_id INTO v_old, v_case_id, v_event_type_code, v_source_table, v_source_id
  FROM public.case_events ce LEFT JOIN public.case_event_types cet ON cet.id = ce.event_type_id WHERE ce.id = p_case_event_id AND ce.is_voided = false;
  IF v_old IS NULL THEN RAISE EXCEPTION 'Active case event % not found', p_case_event_id; END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolution_approvals' OR v_event_type_code = 'CASE_DECISION_APPROVED' THEN
    SELECT a.id INTO v_approval_id FROM public.case_resolution_approvals a WHERE a.id = v_source_id OR a.case_event_id = p_case_event_id LIMIT 1;
    IF v_approval_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_court_filings cf JOIN public.case_resolution_approval_actions aa ON aa.id = cf.case_resolution_approval_action_id WHERE aa.approval_id = v_approval_id AND cf.is_voided = false) THEN
      RAISE EXCEPTION 'This approval has a court filing. Void the court filing first.';
    END IF;
  END IF;
  IF lower(coalesce(v_source_table,'')) = 'case_resolutions' OR v_event_type_code = 'CASE_RESOLVED' THEN
    SELECT cr.id INTO v_resolution_id FROM public.case_resolutions cr WHERE cr.id = v_source_id OR cr.case_event_id = p_case_event_id LIMIT 1;
    IF v_resolution_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_court_filings cf JOIN public.case_resolution_approval_actions aa ON aa.id = cf.case_resolution_approval_action_id JOIN public.case_resolution_approvals a ON a.id = aa.approval_id WHERE a.case_resolution_id = v_resolution_id AND cf.is_voided = false) THEN
      RAISE EXCEPTION 'This resolution has a court filing. Void the court filing first.';
    END IF;
  END IF;
  IF v_event_type_code = 'CASE_RECEIVED' THEN
    RAISE EXCEPTION 'Case Received events cannot be voided.';
  END IF;
  IF v_event_type_code = 'CASE_RAFFLED' THEN
    SELECT ca.id INTO v_assignment_id
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;
    SELECT ca.id INTO v_latest_assignment_id
    FROM public.case_assignments ca
    WHERE ca.case_id = v_case_id AND ca.is_voided IS FALSE
    ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
    LIMIT 1;
    IF v_assignment_id IS NULL OR v_latest_assignment_id IS DISTINCT FROM v_assignment_id THEN
      RAISE EXCEPTION 'This assignment has already been superseded by a later assignment. Void the latest assignment first.';
    END IF;
  END IF;

  SELECT current_status_id, to_jsonb(cpd) INTO v_prev_status_id, v_old_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
  UPDATE public.case_events SET is_voided = true, void_reason = p_void_reason, voided_at = now(), voided_by_user_id = p_voided_by_user_id, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new FROM public.case_events ce WHERE ce.id = p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata) VALUES (p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id, 'Voided case timeline activity', jsonb_build_object('reason', p_void_reason));

  IF v_event_type_code = 'CUSTOM_EVENT' THEN
    IF lower(coalesce(v_old#>>'{details_jsonb,updates_case_status}', 'false')) = 'true' THEN
      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      SELECT to_jsonb(cpd) INTO v_new_details
      FROM public.case_private_details cpd
      WHERE cpd.case_id = v_case_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_events',
        p_case_event_id,
        'VOID_CUSTOM_EVENT_STATUS_STAGE_RECOMPUTED',
        v_old_details,
        v_new_details,
        v_case_id,
        'Custom Event voided; case status and case stage recomputed from active workflow records.',
        jsonb_build_object(
          'case_event_id',p_case_event_id,
          'reason',p_void_reason,
          'updates_case_status',true,
          'previous_case_status_id',COALESCE(v_old_details->>'current_case_status_id', v_old_details->>'current_status_id'),
          'previous_case_status_label',(SELECT display_label FROM public.case_statuses WHERE id = NULLIF(COALESCE(v_old_details->>'current_case_status_id', v_old_details->>'current_status_id'), '')::bigint),
          'previous_case_stage_id',v_old_details->>'current_case_stage_id',
          'previous_case_stage_label',(SELECT display_label FROM public.case_stages WHERE id = NULLIF(v_old_details->>'current_case_stage_id', '')::bigint),
          'recomputed_case_status_id',COALESCE(v_new_details->>'current_case_status_id', v_new_details->>'current_status_id'),
          'recomputed_case_status_label',(SELECT display_label FROM public.case_statuses WHERE id = NULLIF(COALESCE(v_new_details->>'current_case_status_id', v_new_details->>'current_status_id'), '')::bigint),
          'recomputed_case_stage_id',v_new_details->>'current_case_stage_id',
          'recomputed_case_stage_label',(SELECT display_label FROM public.case_stages WHERE id = NULLIF(v_new_details->>'current_case_stage_id', '')::bigint)
        )
      );
    END IF;
    RETURN;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_petitions_for_review' OR v_event_type_code = 'PETITION_FOR_REVIEW' THEN
    SELECT p.id, to_jsonb(p) INTO v_petition_id, v_petition_old
    FROM public.case_petitions_for_review p
    WHERE p.id = v_source_id OR p.case_event_id = p_case_event_id
    ORDER BY CASE WHEN p.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;
    IF v_petition_id IS NOT NULL THEN
      UPDATE public.case_petitions_for_review
      SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now()
      WHERE id = v_petition_id;
      SELECT to_jsonb(p) INTO v_petition_new FROM public.case_petitions_for_review p WHERE p.id = v_petition_id;
      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_petitions_for_review',v_petition_id,'VOID_PETITION_FOR_REVIEW_FROM_EVENT',v_petition_old,v_petition_new,v_case_id,'Petition for Review voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_manual_status_updates' OR v_event_type_code = 'CASE_STATUS_UPDATED' THEN
    SELECT msu.id, to_jsonb(msu) INTO v_manual_update_id, v_manual_update_old
    FROM public.case_manual_status_updates msu
    WHERE msu.id = v_source_id OR msu.case_event_id = p_case_event_id
    ORDER BY CASE WHEN msu.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;
    IF v_manual_update_id IS NOT NULL THEN
      UPDATE public.case_manual_status_updates
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          updated_at = now()
      WHERE id = v_manual_update_id;
      SELECT to_jsonb(msu) INTO v_manual_update_new FROM public.case_manual_status_updates msu WHERE msu.id = v_manual_update_id;
      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_manual_status_updates',v_manual_update_id,'VOID_CASE_STATUS_UPDATED_FROM_EVENT',v_manual_update_old,v_manual_update_new,v_case_id,'Manual Case Status Updated event voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_motions' OR v_event_type_code = 'MOTION_RECEIVED' THEN
    SELECT cm.id, to_jsonb(cm) INTO v_motion_id, v_motion_old FROM public.case_motions cm WHERE cm.id = v_source_id OR cm.case_event_id = p_case_event_id ORDER BY CASE WHEN cm.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_motion_id IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM public.case_motion_resolutions cmr WHERE cmr.case_motion_id = v_motion_id AND cmr.is_voided = false) THEN
        RAISE EXCEPTION 'This motion already has a resolution. Void the motion resolution first.';
      END IF;
      UPDATE public.case_motions SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_motion_id;
      SELECT to_jsonb(cm) INTO v_motion_new FROM public.case_motions cm WHERE cm.id = v_motion_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motions',v_motion_id,'VOID_MOTION_RECEIVED_FROM_EVENT',v_motion_old,v_motion_new,v_case_id,'Motion Received voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_motion_resolution_approvals' OR v_event_type_code = 'MOTION_DECISION_APPROVED' THEN
    SELECT cmra.id, to_jsonb(cmra) INTO v_motion_decision_approval_id, v_motion_decision_approval_old
    FROM public.case_motion_resolution_approvals cmra
    WHERE cmra.id = v_source_id OR cmra.case_event_id = p_case_event_id
    ORDER BY CASE WHEN cmra.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_motion_decision_approval_id IS NOT NULL THEN
      UPDATE public.case_motion_resolution_approvals
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          updated_by_user_id = p_voided_by_user_id,
          updated_at = now()
      WHERE id = v_motion_decision_approval_id;

      SELECT to_jsonb(cmra) INTO v_motion_decision_approval_new
      FROM public.case_motion_resolution_approvals cmra
      WHERE cmra.id = v_motion_decision_approval_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motion_resolution_approvals',v_motion_decision_approval_id,'VOID_MOTION_DECISION_APPROVED_FROM_EVENT',v_motion_decision_approval_old,v_motion_decision_approval_new,v_case_id,'Motion Decision Approved voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_motion_resolutions' OR v_event_type_code = 'MOTION_RESOLVED' THEN
    SELECT cmr.id, to_jsonb(cmr) INTO v_motion_resolution_id, v_motion_resolution_old
    FROM public.case_motion_resolutions cmr
    WHERE cmr.id = v_source_id OR cmr.case_event_id = p_case_event_id
    ORDER BY CASE WHEN cmr.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_motion_resolution_id IS NOT NULL THEN
      SELECT count(*) INTO v_motion_approval_count
      FROM public.case_motion_resolution_approvals cmra
      WHERE cmra.case_motion_resolution_id = v_motion_resolution_id
        AND cmra.is_voided = false;
      IF COALESCE(v_motion_approval_count, 0) > 0 THEN
        RAISE EXCEPTION 'This motion resolution already has an approved decision. Void the approval event first.';
      END IF;

      UPDATE public.case_motion_resolutions
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          updated_by_user_id = p_voided_by_user_id,
          updated_at = now()
      WHERE id = v_motion_resolution_id;

      SELECT to_jsonb(cmr) INTO v_motion_resolution_new
      FROM public.case_motion_resolutions cmr
      WHERE cmr.id = v_motion_resolution_id;

      UPDATE public.case_motions cm
      SET motion_status = 'PENDING',
          updated_by_user_id = p_voided_by_user_id,
          updated_at = now()
      FROM public.case_motion_resolutions cmr
      WHERE cm.id = cmr.case_motion_id
        AND cmr.id = v_motion_resolution_id
        AND cm.is_voided = false;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motion_resolutions',v_motion_resolution_id,'VOID_MOTION_RESOLVED_FROM_EVENT',v_motion_resolution_old,v_motion_resolution_new,v_case_id,'Motion Resolved voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_court_filings' OR v_event_type_code = 'COURT_FILING' THEN
    SELECT cf.id, to_jsonb(cf) INTO v_filing_id, v_filing_old FROM public.case_court_filings cf WHERE cf.id = v_source_id OR cf.case_event_id = p_case_event_id ORDER BY CASE WHEN cf.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_filing_id IS NOT NULL THEN
      UPDATE public.case_court_filings SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_filing_id;
      SELECT to_jsonb(cf) INTO v_filing_new FROM public.case_court_filings cf WHERE cf.id = v_filing_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      SELECT to_jsonb(cpd) INTO v_new_details
      FROM public.case_private_details cpd
      WHERE cpd.case_id = v_case_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_court_filings',v_filing_id,'VOID_COURT_FILING_FROM_EVENT',v_filing_old,jsonb_build_object('court_filing',v_filing_new,'case_private_details',v_new_details),v_case_id,'Court filing voided and case status recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF v_event_type_code = 'CASE_RECEIVED' THEN
    RAISE EXCEPTION 'Case Received events cannot be voided.';
  END IF;

  IF v_event_type_code IN ('CASE_RAFFLED','CASE_ASSIGNMENT') THEN
    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_assignment_id IS NOT NULL THEN
      SELECT ca.id INTO v_latest_assignment_id
      FROM public.case_assignments ca
      WHERE ca.case_id = v_case_id AND ca.is_voided IS FALSE
      ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
      LIMIT 1;

      IF v_latest_assignment_id IS DISTINCT FROM v_assignment_id THEN
        RAISE EXCEPTION 'This assignment has already been superseded by a later assignment. Void the latest assignment first.';
      END IF;

      UPDATE public.case_assignments
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          unassigned_at = COALESCE(unassigned_at, now())
      WHERE id = v_assignment_id;

      SELECT to_jsonb(ca) INTO v_assignment_new
      FROM public.case_assignments ca
      WHERE ca.id = v_assignment_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_assignments',
        v_assignment_id,
        'VOID_CASE_ASSIGNMENT_FROM_EVENT',
        v_assignment_old,
        v_assignment_new,
        v_case_id,
        'Assignment row voided because the Case Assignment event was voided.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason)
      );
    END IF;
  ELSIF v_event_type_code = 'CASE_REASSIGNMENT' THEN
    v_previous_assignment_id := NULLIF(v_old#>>'{details_jsonb,previous_assignment_id}', '')::bigint;

    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    SELECT ca.id INTO v_latest_assignment_id
    FROM public.case_assignments ca
    WHERE ca.case_id = v_case_id
      AND ca.is_voided IS FALSE
    ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
    LIMIT 1;

    IF v_assignment_id IS NULL OR v_latest_assignment_id IS DISTINCT FROM v_assignment_id THEN
      RAISE EXCEPTION 'This reassignment has already been superseded by a later assignment. Void the latest reassignment first.';
    END IF;

    UPDATE public.case_assignments
    SET is_voided = true,
        voided_at = now(),
        voided_by_user_id = p_voided_by_user_id,
        void_reason = p_void_reason,
        unassigned_at = COALESCE(unassigned_at, now())
    WHERE id = v_assignment_id;

    SELECT to_jsonb(ca) INTO v_assignment_new
    FROM public.case_assignments ca
    WHERE ca.id = v_assignment_id;

    IF v_previous_assignment_id IS NOT NULL THEN
      SELECT to_jsonb(ca) INTO v_previous_assignment_old
      FROM public.case_assignments ca
      WHERE ca.id = v_previous_assignment_id
        AND ca.case_id = v_case_id
      FOR UPDATE;

      IF v_previous_assignment_old IS NOT NULL THEN
        UPDATE public.case_assignments
        SET unassigned_at = NULL,
            unassigned_by_user_id = NULL,
            unassignment_reason = NULL
        WHERE id = v_previous_assignment_id
          AND case_id = v_case_id
          AND is_voided IS FALSE;

        SELECT to_jsonb(ca) INTO v_previous_assignment_new
        FROM public.case_assignments ca
        WHERE ca.id = v_previous_assignment_id;
      END IF;
    END IF;

    INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
    VALUES (
      p_voided_by_user_id,
      'case_assignments',
      v_assignment_id,
      'VOID_CASE_REASSIGNMENT_NEW_ASSIGNMENT',
      v_assignment_old,
      v_assignment_new,
      v_case_id,
      'Reassignment-created assignment row voided because the Case Reassignment event was voided.',
      jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'previous_assignment_id',v_previous_assignment_id)
    );

    IF v_previous_assignment_old IS NOT NULL THEN
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_assignments',
        v_previous_assignment_id,
        'RESTORE_PREVIOUS_ASSIGNMENT_FROM_REASSIGNMENT_VOID',
        v_previous_assignment_old,
        v_previous_assignment_new,
        v_case_id,
        'Previous assignment restored because the Case Reassignment event was voided.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'voided_assignment_id',v_assignment_id)
      );
    END IF;
  ELSIF lower(coalesce(v_source_table,'')) = 'case_assignments' THEN
    UPDATE public.case_assignments
    SET is_voided = true,
        voided_at = now(),
        voided_by_user_id = p_voided_by_user_id,
        void_reason = p_void_reason,
        unassigned_at = COALESCE(unassigned_at, now())
    WHERE id = v_source_id OR case_event_id = p_case_event_id;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolutions' OR v_event_type_code = 'CASE_RESOLVED' THEN
    SELECT cr.id INTO v_resolution_id FROM public.case_resolutions cr WHERE cr.id = v_source_id OR cr.case_event_id = p_case_event_id LIMIT 1;
    IF v_resolution_id IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id = v_resolution_id AND a.is_voided = false) THEN
        RAISE EXCEPTION 'This resolution already has approved decisions. Void the approval events first.';
      END IF;
      UPDATE public.case_resolutions SET is_voided=true, voided_at=now(), voided_by_user_id=p_voided_by_user_id, void_reason=p_void_reason, updated_by_user_id=p_voided_by_user_id, updated_at=now() WHERE id=v_resolution_id;
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolution_approvals' OR v_event_type_code = 'CASE_DECISION_APPROVED' THEN
    SELECT a.id INTO v_approval_id FROM public.case_resolution_approvals a WHERE a.id = v_source_id OR a.case_event_id = p_case_event_id LIMIT 1;
    IF v_approval_id IS NOT NULL THEN
      UPDATE public.case_resolution_approvals SET is_voided=true, voided_at=now(), voided_by_user_id=p_voided_by_user_id, void_reason=p_void_reason, updated_by_user_id=p_voided_by_user_id, updated_at=now() WHERE id=v_approval_id;
    END IF;
  END IF;

  IF v_event_type_code IN ('CASE_RESOLVED','CASE_DECISION_APPROVED','CASE_RAFFLED','CASE_ASSIGNMENT','CASE_REASSIGNMENT')
     OR lower(coalesce(v_source_table,'')) IN ('case_resolutions','case_resolution_approvals','case_assignments') THEN
    PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

    IF v_event_type_code = 'CASE_REASSIGNMENT' THEN
      SELECT to_jsonb(cpd) INTO v_new_details
      FROM public.case_private_details cpd
      WHERE cpd.case_id = v_case_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_private_details',
        v_case_id,
        'CASE_REASSIGNMENT_VOID_STATUS_STAGE_RECOMPUTED',
        v_old_details,
        v_new_details,
        v_case_id,
        'Case Reassignment voided; case status and case stage recomputed from active workflow records.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'restored_assignment_id',v_previous_assignment_id,'voided_assignment_id',v_assignment_id)
      );
    END IF;
  END IF;

END;
$$;




GRANT EXECUTE ON FUNCTION public.void_case_event(bigint, text, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
