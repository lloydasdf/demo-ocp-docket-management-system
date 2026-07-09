BEGIN;

-- Add the non-assigned initial docket stage required by the Case Status / Case Stage split.
INSERT INTO public.case_stages (code, display_label, sort_order, is_final_stage, is_milestone, is_active)
VALUES
  ('FOR_RAFFLE', 'For Raffle', 10, false, false, true),
  ('CASE_RAFFLED', 'Case Raffled', 30, false, true, true)
ON CONFLICT (code) DO UPDATE SET
  display_label = EXCLUDED.display_label,
  sort_order = EXCLUDED.sort_order,
  is_final_stage = EXCLUDED.is_final_stage,
  is_milestone = EXCLUDED.is_milestone,
  is_active = true,
  updated_at = now();

WITH stage_color_seed(code, color_name, background_class, text_class, border_class) AS (
  VALUES
    ('FOR_RAFFLE', 'gray', 'bg-gray-50', 'text-gray-800', 'border-gray-200'),
    ('CASE_RAFFLED', 'blue', 'bg-blue-50', 'text-blue-800', 'border-blue-200')
)
INSERT INTO public.case_stage_colors (stage_id, color_name, background_class, text_class, border_class, is_active)
SELECT cs.id, seed.color_name, seed.background_class, seed.text_class, seed.border_class, true
FROM stage_color_seed seed
JOIN public.case_stages cs ON cs.code = seed.code
ON CONFLICT (stage_id) DO UPDATE SET
  color_name = EXCLUDED.color_name,
  background_class = EXCLUDED.background_class,
  text_class = EXCLUDED.text_class,
  border_class = EXCLUDED.border_class,
  is_active = true,
  updated_at = now();

CREATE OR REPLACE FUNCTION public.create_new_docket_entry(p_payload jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_auth_uid uuid := auth.uid(); v_user_id bigint; v_case_id bigint; v_item jsonb; v_sub jsonb; v_contact_id bigint; v_audit_metadata jsonb;
  v_docket_type_id bigint := (p_payload->>'docketTypeId')::bigint; v_docket_year int := (p_payload->>'docketYear')::int; v_date_received date := (p_payload->>'dateReceived')::date; v_initial_status_id bigint := (p_payload->>'initialStatusId')::bigint;
  v_case_classification_id bigint := nullif(p_payload->>'caseClassificationId','')::bigint; v_region_code text := nullif(btrim(p_payload->>'regionCode'), ''); v_month_code text; v_docket_number int; v_display text; v_dt_prefix text;
  v_person_id bigint; v_org_id bigint; v_name text; v_cp_id bigint; v_address_id bigint; v_violation_id bigint; v_received_event_type_id bigint; v_raffled_event_type_id bigint; v_event_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_assignment_event_id bigint; v_assignment_id bigint;
  v_pending_status_id bigint; v_for_raffle_stage_id bigint; v_case_raffled_stage_id bigint; v_initial_stage_id bigint; v_status_date date := COALESCE(v_date_received, CURRENT_DATE);
  v_assigned_prosecutor_id bigint := CASE WHEN COALESCE((p_payload->>'caseAlsoRaffled')::boolean,false) THEN nullif(p_payload->>'assignedProsecutorId','')::bigint ELSE NULL END; v_assignment_date date := v_date_received; v_assignment_remarks text := CASE WHEN p_payload ? 'assignmentRemarks' THEN nullif(btrim(p_payload->>'assignmentRemarks'),'') ELSE 'Assigned during manual docket creation' END;
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

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_order,title,description,status_id,case_status_id,case_stage_id,source,source_table,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_received_event_type_id,v_status_date,1,'Case received',v_case_received_description,v_pending_status_id,v_pending_status_id,v_initial_stage_id,'MANUAL_ENTRY','case_status_history',v_user_id,v_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,NULL,v_pending_status_id,v_user_id,now(),v_status_date,v_case_received_description,v_event_id) RETURNING id INTO v_status_history_id;
  INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (v_case_id,NULL,v_initial_stage_id,v_user_id,now(),v_status_date,v_case_received_description,v_event_id) RETURNING id INTO v_stage_history_id;
  UPDATE public.case_events SET source_id = v_status_history_id WHERE id = v_event_id;
  IF v_assigned_prosecutor_id IS NOT NULL THEN INSERT INTO public.case_assignments(case_id,prosecutor_id,assigned_by_user_id,assigned_at,remarks) VALUES (v_case_id,v_assigned_prosecutor_id,v_user_id,v_assignment_date::timestamp with time zone,v_assignment_remarks) RETURNING id INTO v_assignment_id; INSERT INTO public.case_events(case_id,event_type_id,event_date,event_order,title,description,status_id,case_status_id,case_stage_id,prosecutor_id,source,source_table,source_id,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_raffled_event_type_id,v_status_date,2,'Case raffled',v_assignment_remarks,v_pending_status_id,v_pending_status_id,v_case_raffled_stage_id,v_assigned_prosecutor_id,'MANUAL_ENTRY','case_assignments',v_assignment_id,v_user_id,v_user_id) RETURNING id INTO v_assignment_event_id; UPDATE public.case_assignments SET case_event_id = v_assignment_event_id WHERE id = v_assignment_id; END IF;

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

COMMENT ON FUNCTION public.create_new_docket_entry(p_payload jsonb) IS 'Creates a docket entry and supports multiple places of commission via placesOfCommission[] (legacy placeOfCommission still accepted).';
GRANT EXECUTE ON FUNCTION public.create_new_docket_entry(jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
