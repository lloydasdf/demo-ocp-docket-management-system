CREATE OR REPLACE FUNCTION public.create_new_docket_entry(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_user_id bigint;
  v_case_id bigint;
  v_status_event_id bigint;
  v_assignment_event_id bigint;
  v_status_history_id bigint;
  v_assignment_id bigint;
  v_received_event_type_id bigint;
  v_raffled_event_type_id bigint;
  v_assigned_prosecutor_id bigint := nullif(p_payload->>'assignedProsecutorId','')::bigint;
  v_docket_type_id bigint := (p_payload->>'docketTypeId')::bigint;
  v_docket_year int := (p_payload->>'docketYear')::int;
  v_date_received date := (p_payload->>'dateReceived')::date;
  v_initial_status_id bigint := (p_payload->>'initialStatusId')::bigint;
  v_case_classification_id bigint := nullif(p_payload->>'caseClassificationId','')::bigint;
  v_region_code text := nullif(btrim(p_payload->>'regionCode'), '');
  v_month_code text;
  v_docket_number int;
  v_display text;
  v_dt_prefix text;
  v_item jsonb;
  v_person_id bigint;
  v_person_name text;
  v_cp_id bigint;
  v_address_id bigint;
  v_violation_id bigint;
  v_seen_violation_ids bigint[] := '{}';
  v_created_persons int := 0; v_reused_persons int := 0;
  v_created_addresses int := 0; v_reused_addresses int := 0;
  v_created_violations int := 0; v_reused_violations int := 0;
  v_participant_count int := 0; v_violation_count int := 0;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Authenticated Supabase user is required for docket creation';
  END IF;

  SELECT id INTO v_user_id
  FROM public.users
  WHERE auth_user_id = v_auth_uid AND is_active IS TRUE
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authenticated user % is not mapped to an active public.users row', v_auth_uid;
  END IF;

  IF v_docket_type_id IS NULL OR v_docket_year IS NULL OR v_date_received IS NULL OR v_initial_status_id IS NULL THEN
    RAISE EXCEPTION 'Missing required case fields: docketTypeId, docketYear, dateReceived, and initialStatusId are required';
  END IF;
  IF jsonb_array_length(COALESCE(p_payload->'participants','[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'At least one participant is required';
  END IF;
  IF jsonb_array_length(COALESCE(p_payload->'violations','[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'At least one violation is required';
  END IF;

  SELECT prefix INTO v_dt_prefix FROM public.docket_types WHERE id = v_docket_type_id AND is_active IS TRUE;
  IF v_dt_prefix IS NULL THEN RAISE EXCEPTION 'Invalid docket type id %', v_docket_type_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.case_statuses WHERE id = v_initial_status_id) THEN RAISE EXCEPTION 'Invalid initial status id %', v_initial_status_id; END IF;
  IF v_case_classification_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.case_classifications WHERE id = v_case_classification_id) THEN RAISE EXCEPTION 'Invalid case classification id %', v_case_classification_id; END IF;
  IF v_assigned_prosecutor_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = v_assigned_prosecutor_id AND is_active IS TRUE) THEN RAISE EXCEPTION 'Invalid assigned prosecutor id %', v_assigned_prosecutor_id; END IF;

  SELECT id INTO v_received_event_type_id FROM public.case_event_types WHERE is_active IS TRUE AND code = 'CASE_RECEIVED' LIMIT 1;
  IF v_received_event_type_id IS NULL THEN
    RAISE EXCEPTION 'No active CASE_RECEIVED case_event_types row is configured';
  END IF;
  IF v_assigned_prosecutor_id IS NOT NULL THEN
    SELECT id INTO v_raffled_event_type_id FROM public.case_event_types WHERE is_active IS TRUE AND code = 'CASE_RAFFLED' LIMIT 1;
    IF v_raffled_event_type_id IS NULL THEN
      RAISE EXCEPTION 'No active CASE_RAFFLED case_event_types row is configured';
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(v_docket_type_id::int, v_docket_year);
  SELECT COALESCE(MAX(docket_number), 0) + 1 INTO v_docket_number FROM public.cases WHERE docket_type_id = v_docket_type_id AND docket_year = v_docket_year;
  v_month_code := upper(to_char(v_date_received, 'MON'));
  v_display := concat_ws('-', v_region_code, v_dt_prefix, right(v_docket_year::text, 2) || COALESCE(v_month_code, ''), lpad(v_docket_number::text, 6, '0'));

  INSERT INTO public.cases(docket_type_id,docket_year,docket_number,date_received,created_by_user_id,updated_by_user_id,is_archived,region_code,docket_month_code,case_classification_id)
  VALUES (v_docket_type_id,v_docket_year,v_docket_number,v_date_received,v_user_id,v_user_id,false,v_region_code,v_month_code,v_case_classification_id)
  RETURNING id INTO v_case_id;

  INSERT INTO public.case_private_details(case_id,source,remarks,is_summary_procedure,summary_text,current_status_id,current_status_date,current_status_raw,current_status_remarks)
  VALUES (v_case_id,'MANUAL_ENTRY',nullif(btrim(p_payload->>'remarks'),''),COALESCE((p_payload->>'isSummaryProcedure')::boolean,false),nullif(btrim(p_payload->>'summaryText'),''),v_initial_status_id,v_date_received,NULL,NULL);

  INSERT INTO public.docket_number_history(case_id,docket_type_id,docket_year,docket_number,docket_display_number,event_type,changed_by_user_id,changed_at,reason)
  VALUES (v_case_id,v_docket_type_id,v_docket_year,v_docket_number,v_display,'ASSIGNED',v_user_id,now(),'Manual docket creation');

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'participants') LOOP
    IF NULLIF(v_item->>'existingPersonId','') IS NOT NULL AND (v_item ? 'newPerson') AND v_item->'newPerson' <> 'null'::jsonb THEN
      RAISE EXCEPTION 'Participant entry cannot contain both existingPersonId and newPerson';
    END IF;
    IF COALESCE((v_item->>'roleId')::bigint,0) = 0 OR NOT EXISTS (SELECT 1 FROM public.participant_roles WHERE id = (v_item->>'roleId')::bigint) THEN RAISE EXCEPTION 'Invalid participant role'; END IF;
    IF COALESCE((v_item->>'participantOrder')::int,0) = 0 THEN RAISE EXCEPTION 'Participant order is required'; END IF;

    IF NULLIF(v_item->>'existingPersonId','') IS NOT NULL THEN
      SELECT id, full_name INTO v_person_id, v_person_name FROM public.persons WHERE id = (v_item->>'existingPersonId')::bigint;
      IF v_person_id IS NULL THEN RAISE EXCEPTION 'Existing person id % was not found', v_item->>'existingPersonId'; END IF;
      v_reused_persons := v_reused_persons + 1;
    ELSE
      v_person_name := regexp_replace(concat_ws(' ', nullif(btrim(v_item#>>'{newPerson,firstName}'),''), CASE WHEN COALESCE((v_item#>>'{newPerson,noMiddleName}')::boolean,false) THEN 'NMN' ELSE nullif(btrim(v_item#>>'{newPerson,middleName}'),'') END, nullif(btrim(v_item#>>'{newPerson,lastName}'),''), nullif(btrim(v_item#>>'{newPerson,suffix}'),'')), '\s+', ' ', 'g');
      IF v_person_name = '' THEN RAISE EXCEPTION 'New participant full-name preview cannot be empty'; END IF;
      INSERT INTO public.persons(first_name,middle_name,last_name,suffix,full_name,gender,birth_date,notes,person_descriptor)
      VALUES (nullif(btrim(v_item#>>'{newPerson,firstName}'),''), CASE WHEN COALESCE((v_item#>>'{newPerson,noMiddleName}')::boolean,false) THEN 'NMN' ELSE nullif(btrim(v_item#>>'{newPerson,middleName}'),'') END, nullif(btrim(v_item#>>'{newPerson,lastName}'),''), nullif(btrim(v_item#>>'{newPerson,suffix}'),''), v_person_name, nullif(btrim(v_item#>>'{newPerson,gender}'),''), nullif(v_item#>>'{newPerson,birthDate}','')::date, nullif(btrim(v_item#>>'{newPerson,notes}'),''), nullif(btrim(v_item#>>'{newPerson,personDescriptor}'),''))
      RETURNING id INTO v_person_id;
      v_created_persons := v_created_persons + 1;
    END IF;

    INSERT INTO public.case_participants(case_id,person_id,role_id,participant_order,participant_kind,display_name_snapshot)
    VALUES (v_case_id,v_person_id,(v_item->>'roleId')::bigint,(v_item->>'participantOrder')::int,'PERSON',v_person_name) RETURNING id INTO v_cp_id;
    v_participant_count := v_participant_count + 1;

    IF nullif(btrim(v_item->>'remarks'),'') IS NOT NULL OR nullif(btrim(v_item->>'sourceDetail'),'') IS NOT NULL THEN
      INSERT INTO public.case_participant_private_details(case_participant_id,case_id,source,remarks,source_detail)
      VALUES (v_cp_id,v_case_id,'MANUAL_ENTRY',nullif(btrim(v_item->>'remarks'),''),nullif(btrim(v_item->>'sourceDetail'),''));
    END IF;
    IF v_item ? 'attributes' AND v_item->'attributes' <> 'null'::jsonb THEN
      INSERT INTO public.case_participant_attributes(case_participant_id,age_text,age_years,age_basis_date,age_source,gender_text,gender_normalized,is_minor_at_case,is_senior_at_case,is_pwd_at_case,resident_of_gentri_text,is_resident_of_gentri,notes,created_by_user_id,updated_by_user_id)
      VALUES (v_cp_id,nullif(btrim(v_item#>>'{attributes,ageText}'),''),nullif(v_item#>>'{attributes,ageYears}','')::int,v_date_received,'MANUAL_ENTRY',nullif(btrim(v_item#>>'{attributes,genderText}'),''),nullif(btrim(v_item#>>'{attributes,genderNormalized}'),''),nullif(v_item#>>'{attributes,isMinorAtCase}','')::boolean,nullif(v_item#>>'{attributes,isSeniorAtCase}','')::boolean,nullif(v_item#>>'{attributes,isPwdAtCase}','')::boolean,nullif(btrim(v_item#>>'{attributes,residentOfGentriText}'),''),nullif(v_item#>>'{attributes,isResidentOfGentri}','')::boolean,nullif(btrim(v_item#>>'{attributes,notes}'),''),v_user_id,v_user_id);
    END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'addresses','[]'::jsonb)) LOOP
    IF NULLIF(v_item->>'existingAddressId','') IS NOT NULL AND (v_item ? 'newAddress') AND v_item->'newAddress' <> 'null'::jsonb THEN RAISE EXCEPTION 'Address entry cannot contain both existingAddressId and newAddress'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.address_types WHERE id = (v_item->>'addressTypeId')::bigint) THEN RAISE EXCEPTION 'Invalid address type'; END IF;
    IF NULLIF(v_item->>'existingAddressId','') IS NOT NULL THEN
      SELECT id INTO v_address_id FROM public.addresses WHERE id=(v_item->>'existingAddressId')::bigint; IF v_address_id IS NULL THEN RAISE EXCEPTION 'Existing address not found'; END IF; v_reused_addresses := v_reused_addresses + 1;
    ELSE
      INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country) VALUES (nullif(btrim(v_item#>>'{newAddress,line1}'),''),nullif(btrim(v_item#>>'{newAddress,line2}'),''),nullif(btrim(v_item#>>'{newAddress,barangay}'),''),nullif(btrim(v_item#>>'{newAddress,city}'),''),nullif(btrim(v_item#>>'{newAddress,province}'),''),nullif(btrim(v_item#>>'{newAddress,region}'),''),nullif(btrim(v_item#>>'{newAddress,zipCode}'),''),COALESCE(nullif(btrim(v_item#>>'{newAddress,country}'),''),'Philippines')) RETURNING id INTO v_address_id; v_created_addresses := v_created_addresses + 1;
    END IF;
    INSERT INTO public.case_addresses(case_id,address_id,address_type_id,is_primary,remarks) VALUES (v_case_id,v_address_id,(v_item->>'addressTypeId')::bigint,COALESCE((v_item->>'isPrimary')::boolean,false),nullif(btrim(v_item->>'remarks'),''));
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'violations') LOOP
    IF COALESCE(NULLIF(v_item->>'existingViolationId',''), NULLIF(v_item->>'violationId','')) IS NOT NULL AND (v_item ? 'newViolation') AND v_item->'newViolation' <> 'null'::jsonb THEN RAISE EXCEPTION 'Violation entry cannot contain both existingViolationId and newViolation'; END IF;
    IF COALESCE((v_item->>'violationOrder')::int,0) = 0 THEN RAISE EXCEPTION 'Violation order is required'; END IF;
    IF COALESCE(NULLIF(v_item->>'existingViolationId',''), NULLIF(v_item->>'violationId','')) IS NOT NULL THEN
      SELECT id INTO v_violation_id FROM public.violations WHERE id=COALESCE(NULLIF(v_item->>'existingViolationId',''), NULLIF(v_item->>'violationId',''))::bigint; IF v_violation_id IS NULL THEN RAISE EXCEPTION 'Existing violation not found'; END IF; v_reused_violations := v_reused_violations + 1;
    ELSE
      IF nullif(btrim(v_item#>>'{newViolation,title}'),'') IS NULL THEN RAISE EXCEPTION 'New violation title is required'; END IF;
      INSERT INTO public.violations(title,reference_code,short_label,description,law_reference,created_by_user_id,is_active,canonical_title) VALUES (btrim(v_item#>>'{newViolation,title}'),nullif(btrim(v_item#>>'{newViolation,referenceCode}'),''),nullif(btrim(v_item#>>'{newViolation,shortLabel}'),''),nullif(btrim(v_item#>>'{newViolation,description}'),''),nullif(btrim(v_item#>>'{newViolation,lawReference}'),''),v_user_id,true,regexp_replace(lower(btrim(v_item#>>'{newViolation,title}')), '\s+', ' ', 'g')) RETURNING id INTO v_violation_id; v_created_violations := v_created_violations + 1;
    END IF;
    IF v_violation_id = ANY(v_seen_violation_ids) THEN RAISE EXCEPTION 'Duplicate violation id % in payload', v_violation_id; END IF;
    v_seen_violation_ids := array_append(v_seen_violation_ids, v_violation_id);
    INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text) VALUES (v_case_id,v_violation_id,(v_item->>'violationOrder')::int,nullif(btrim(v_item->>'rawViolationText'),''));
    v_violation_count := v_violation_count + 1;
  END LOOP;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_order,title,description,status_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (v_case_id,v_received_event_type_id,v_date_received,1,'Case received','Initial status set during manual docket creation',v_initial_status_id,jsonb_build_object('docketDisplayNumber',v_display),'MANUAL_ENTRY','case_status_history',v_user_id,v_user_id)
  RETURNING id INTO v_status_event_id;

  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
  VALUES (v_case_id,NULL,v_initial_status_id,v_user_id,now(),v_date_received,'Initial status set during manual docket creation',v_status_event_id)
  RETURNING id INTO v_status_history_id;

  UPDATE public.case_events SET source_id = v_status_history_id WHERE id = v_status_event_id;

  IF v_assigned_prosecutor_id IS NOT NULL THEN
    INSERT INTO public.case_assignments(case_id,prosecutor_id,assigned_by_user_id,assigned_at,remarks)
    VALUES (v_case_id,v_assigned_prosecutor_id,v_user_id,now(),'Assigned during manual docket creation')
    RETURNING id INTO v_assignment_id;

    INSERT INTO public.case_events(case_id,event_type_id,event_date,event_order,title,description,prosecutor_id,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
    VALUES (v_case_id,v_raffled_event_type_id,v_date_received,2,'Case raffled','Assigned during manual docket creation',v_assigned_prosecutor_id,jsonb_build_object('docketDisplayNumber',v_display),'MANUAL_ENTRY','case_assignments',v_assignment_id,v_user_id,v_user_id)
    RETURNING id INTO v_assignment_event_id;

    UPDATE public.case_assignments SET case_event_id = v_assignment_event_id WHERE id = v_assignment_id;
  END IF;

  RETURN jsonb_build_object('caseId',v_case_id,'docketTypeId',v_docket_type_id,'docketYear',v_docket_year,'docketNumber',v_docket_number,'docketMonthCode',v_month_code,'docketDisplayNumber',v_display,'createdPersonCount',v_created_persons,'reusedPersonCount',v_reused_persons,'createdAddressCount',v_created_addresses,'reusedAddressCount',v_reused_addresses,'createdViolationCount',v_created_violations,'reusedViolationCount',v_reused_violations,'participantCount',v_participant_count,'violationCount',v_violation_count);
END;
$$;

CREATE OR REPLACE VIEW public.v_case_details_page AS
WITH latest_assignment AS (
  SELECT DISTINCT ON (ca.case_id)
    ca.case_id,
    ca.prosecutor_id,
    ca.staff_id,
    ca.assigned_at,
    ca.id
  FROM public.case_assignments ca
  WHERE ca.unassigned_at IS NULL
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
), violation_summary AS (
  SELECT
    cv.case_id,
    string_agg(
      COALESCE(NULLIF(btrim(cv.raw_violation_text), ''), v.title),
      ', '
      ORDER BY cv.violation_order NULLS LAST, cv.id
    ) AS violations
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  GROUP BY cv.case_id
), case_address_summary AS (
  SELECT
    ca.case_id,
    jsonb_agg(
      jsonb_build_object(
        'id', ca.id,
        'address_id', ca.address_id,
        'address_type_id', ca.address_type_id,
        'address_type_label', at.display_label,
        'is_primary', ca.is_primary,
        'remarks', ca.remarks,
        'addresses', jsonb_build_object(
          'barangay', a.barangay,
          'city', a.city,
          'country', a.country,
          'line1', a.line1,
          'line2', a.line2,
          'province', a.province,
          'region', a.region,
          'zip_code', a.zip_code
        )
      )
      ORDER BY ca.is_primary DESC, ca.id
    ) AS case_addresses
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  GROUP BY ca.case_id
)
SELECT
  c.id,
  c.docket_type_id,
  c.docket_year,
  c.docket_number,
  c.docket_month_code,
  c.date_received,
  c.created_by_user_id,
  c.updated_by_user_id,
  c.is_archived,
  c.created_at,
  c.updated_at,
  c.region_code,
  c.case_classification_id,
  concat_ws(
    '-',
    c.region_code,
    dt.prefix,
    right(c.docket_year::text, 2) || COALESCE(c.docket_month_code, ''),
    lpad(c.docket_number::text, 6, '0')
  ) AS docket_display_number,
  dt.prefix AS docket_type_prefix,
  dt.name AS docket_type_name,
  vs.violations,
  cpd.source,
  cpd.remarks,
  cpd.legacy_source_file,
  cpd.legacy_source_sheet,
  cpd.legacy_row_number,
  cpd.legacy_raw_json,
  cpd.is_summary_procedure,
  cpd.summary_text,
  cpd.current_status_id,
  cpd.current_status_date,
  cpd.current_status_approved_date_raw,
  cpd.current_status_approved_date_raw AS status_approved_date_raw,
  NULL::date AS status_approved_date,
  cpd.current_status_raw,
  cpd.current_status_remarks,
  cs.code AS current_status_code,
  cs.display_label AS current_status_label,
  la.prosecutor_id AS current_prosecutor_id,
  p.short_name AS prosecutor_short_name,
  p.full_name AS prosecutor_full_name,
  la.staff_id AS current_staff_id,
  st.short_name AS staff_short_name,
  st.full_name AS staff_full_name,
  la.assigned_at AS current_assigned_at,
  NULL::text AS case_classification_code,
  NULL::text AS case_classification_name,
  cc.display_label AS case_classification_label,
  cc.description AS case_classification_description,
  NULL::text AS gdrive_folder_id,
  NULL::text AS gdrive_folder_link,
  NULL::text AS gdrive_folder_name,
  NULL::text AS gdrive_folder_status,
  NULL::timestamp with time zone AS gdrive_folder_last_scanned_at,
  NULL::text AS court_codes,
  NULL::text AS criminal_case_numbers,
  NULL::boolean AS court_needs_review,
  COALESCE(cas.case_addresses, '[]'::jsonb) AS case_addresses
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_statuses cs ON cs.id = cpd.current_status_id
LEFT JOIN latest_assignment la ON la.case_id = c.id
LEFT JOIN public.prosecutors p ON p.id = la.prosecutor_id
LEFT JOIN public.staff st ON st.id = la.staff_id
LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
LEFT JOIN violation_summary vs ON vs.case_id = c.id
LEFT JOIN case_address_summary cas ON cas.case_id = c.id
WHERE NOT c.is_archived;

COMMENT ON VIEW public.v_case_details_page IS 'Centralized case details page read model with case-level addresses. Intentionally policy-free for development debugging.';
