ALTER TABLE public.case_assignments
  ADD COLUMN IF NOT EXISTS is_voided boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS voided_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS voided_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS void_reason text;

DROP INDEX IF EXISTS public.one_active_assignment_per_case;
CREATE UNIQUE INDEX IF NOT EXISTS one_active_assignment_per_case
  ON public.case_assignments(case_id)
  WHERE unassigned_at IS NULL AND is_voided IS FALSE;

CREATE OR REPLACE FUNCTION public.edit_case_overview_section(p_payload jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_section text := lower(btrim(p_payload->>'section'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_old jsonb;
  v_new jsonb;
  v_event_type_id bigint;
  v_event_id bigint;
  v_assignment_id bigint;
  v_status_history_id bigint;
  v_old_assignment_id bigint;
  v_old_prosecutor_id bigint;
  v_old_case_event_id bigint;
  v_linked_event_id bigint;
  v_linked_event_void text;
  v_old_prosecutor_name text;
  v_new_prosecutor_name text;
  v_staff_id bigint;
  v_assignment_action text;
  v_from_status_id bigint;
  v_to_status_id bigint;
  v_status_date date;
  v_status_remarks text;
  v_prosecutor_id bigint;
  v_assigned_at timestamptz;
  v_assignment_remarks text;
  v_old_date_received date;
  v_new_date_received date;
  v_case_received_sync text;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_section IS NULL THEN RAISE EXCEPTION 'section is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_old
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  IF v_section = 'docket_info' THEN
    SELECT date_received INTO v_old_date_received FROM public.cases WHERE id = v_case_id;
    UPDATE public.cases SET
      docket_type_id = COALESCE(nullif(p_payload#>>'{data,docketTypeId}','')::bigint, docket_type_id),
      docket_year = COALESCE(nullif(p_payload#>>'{data,docketYear}','')::int, docket_year),
      docket_number = COALESCE(nullif(p_payload#>>'{data,docketNumber}','')::int, docket_number),
      docket_month_code = COALESCE(nullif(btrim(p_payload#>>'{data,docketMonthCode}'),''), docket_month_code),
      date_received = COALESCE(nullif(p_payload#>>'{data,dateReceived}','')::date, date_received),
      updated_by_user_id = v_user_id,
      updated_at = now()
    WHERE id = v_case_id;

    SELECT date_received INTO v_new_date_received FROM public.cases WHERE id = v_case_id;
    IF v_new_date_received IS DISTINCT FROM v_old_date_received THEN
      SELECT id INTO v_event_type_id
      FROM public.case_event_types
      WHERE code = 'CASE_RECEIVED' AND is_active IS TRUE
      LIMIT 1;

      IF v_event_type_id IS NULL THEN
        v_case_received_sync := 'skipped_missing_event_type';
      ELSE
        SELECT id INTO v_event_id
        FROM public.case_events
        WHERE case_id = v_case_id
          AND event_type_id = v_event_type_id
          AND COALESCE(is_voided, false) IS FALSE
        ORDER BY event_date DESC NULLS LAST, id DESC
        LIMIT 1;

        IF v_event_id IS NOT NULL THEN
          UPDATE public.case_events
          SET event_date = v_new_date_received,
              title = COALESCE(NULLIF(title, ''), 'Case received'),
              description = COALESCE(NULLIF(description, ''), 'Case received date updated from overview edit'),
              details_jsonb = COALESCE(details_jsonb, '{}'::jsonb) || jsonb_build_object(
                'action', 'sync_case_received_from_overview',
                'old_date_received', v_old_date_received,
                'new_date_received', v_new_date_received,
                'reason', v_reason
              ),
              updated_by_user_id = v_user_id,
              updated_at = now()
          WHERE id = v_event_id;
          v_case_received_sync := 'updated_existing_event';
        ELSIF v_new_date_received IS NOT NULL THEN
          INSERT INTO public.case_events(case_id,event_type_id,event_date,title,description,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
          VALUES (
            v_case_id,
            v_event_type_id,
            v_new_date_received,
            'Case received',
            'Case received date updated from overview edit',
            jsonb_build_object('action', 'sync_case_received_from_overview', 'old_date_received', v_old_date_received, 'new_date_received', v_new_date_received, 'reason', v_reason),
            'MANUAL_EDIT',
            'cases',
            v_case_id,
            v_user_id,
            v_user_id
          );
          v_case_received_sync := 'created_missing_event';
        ELSE
          v_case_received_sync := 'skipped_null_date_received';
        END IF;
      END IF;
    END IF;
  ELSIF v_section = 'case_details' THEN
    UPDATE public.cases SET
      case_classification_id = nullif(p_payload#>>'{data,caseClassificationId}','')::bigint,
      updated_by_user_id = v_user_id,
      updated_at = now()
    WHERE id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    UPDATE public.case_private_details SET
      is_summary_procedure = COALESCE(nullif(p_payload#>>'{data,isSummaryProcedure}','')::boolean, false),
      summary_text = nullif(btrim(p_payload#>>'{data,summaryText}'),''),
      remarks = nullif(btrim(p_payload#>>'{data,remarks}'),'')
    WHERE case_id = v_case_id;
  ELSIF v_section = 'status' THEN
    v_to_status_id := nullif(p_payload#>>'{data,statusId}','')::bigint;
    v_status_date := COALESCE(nullif(p_payload#>>'{data,statusDate}','')::date, current_date);
    v_status_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_to_status_id IS NULL THEN RAISE EXCEPTION 'statusId is required'; END IF;
    SELECT current_status_id INTO v_from_status_id FROM public.case_private_details WHERE case_id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'STATUS_UPDATED' AND is_active IS TRUE LIMIT 1;
    IF v_event_type_id IS NULL THEN SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'CASE_RECEIVED' LIMIT 1; END IF;
    IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing case event type STATUS_UPDATED or CASE_RECEIVED'; END IF;
    INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks)
    VALUES (v_case_id,v_from_status_id,v_to_status_id,v_user_id,now(),v_status_date,v_status_remarks)
    RETURNING id INTO v_status_history_id;
    INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
    VALUES (
      v_case_id,
      v_event_type_id,
      v_status_date,
      now()::time,
      'Status updated',
      v_status_remarks,
      v_to_status_id,
      jsonb_build_object('from_status_id', v_from_status_id, 'to_status_id', v_to_status_id, 'status_date', v_status_date, 'remarks', v_status_remarks, 'reason', v_reason),
      'MANUAL_EDIT',
      'case_status_history',
      v_status_history_id,
      v_user_id,
      v_user_id
    ) RETURNING id INTO v_event_id;
    UPDATE public.case_status_history SET case_event_id = v_event_id WHERE id = v_status_history_id;
    UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
    UPDATE public.case_private_details SET current_status_id = v_to_status_id, current_status_date = v_status_date, current_status_remarks = v_status_remarks, current_status_approved_date_raw = nullif(btrim(p_payload#>>'{data,statusApprovedDateRaw}'),'') WHERE case_id = v_case_id;
  ELSIF v_section = 'assignment' THEN
    v_prosecutor_id := nullif(p_payload#>>'{data,prosecutorId}','')::bigint;
    v_staff_id := nullif(p_payload#>>'{data,staffId}','')::bigint;
    v_assignment_action := COALESCE(nullif(btrim(p_payload#>>'{data,assignmentMode}'),''), 'reassign');
    v_assigned_at := COALESCE(nullif(p_payload#>>'{data,assignedAt}','')::timestamptz, now());
    v_assignment_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_assignment_action IN ('reassign', 'void_replace') AND v_prosecutor_id IS NULL THEN RAISE EXCEPTION 'prosecutorId is required'; END IF;
    IF v_assignment_action NOT IN ('reassign', 'void_replace') THEN RAISE EXCEPTION 'Unsupported assignment mode %', v_assignment_action; END IF;
    SELECT ca.id, ca.prosecutor_id, ca.case_event_id, COALESCE(p.full_name, p.short_name)
    INTO v_old_assignment_id, v_old_prosecutor_id, v_old_case_event_id, v_old_prosecutor_name
    FROM public.case_assignments ca
    LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
    WHERE ca.case_id = v_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE
    ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
    LIMIT 1;

    IF v_assignment_action IN ('reassign', 'void_replace') THEN
      SELECT COALESCE(p.full_name, p.short_name) INTO v_new_prosecutor_name
      FROM public.prosecutors p
      WHERE p.id = v_prosecutor_id;

      SELECT id INTO v_event_type_id
      FROM public.case_event_types
      WHERE code = 'CASE_RAFFLED'
        AND is_active IS TRUE
      LIMIT 1;

      IF v_event_type_id IS NULL THEN
        SELECT id INTO v_event_type_id
        FROM public.case_event_types
        WHERE code = 'CASE_ASSIGNED'
          AND is_active IS TRUE
        LIMIT 1;
      END IF;

      IF v_event_type_id IS NULL THEN
        RAISE EXCEPTION 'Missing case event type CASE_RAFFLED or CASE_ASSIGNED';
      END IF;
    END IF;

    IF v_assignment_action = 'reassign' THEN
      IF v_old_assignment_id IS NULL THEN
        RAISE EXCEPTION 'No active assignment found for case %', v_case_id;
      END IF;

      UPDATE public.case_assignments
      SET unassigned_at = COALESCE(v_assigned_at, now()),
          remarks = concat_ws(E'\n', remarks, 'Reassigned reason: ' || v_reason)
      WHERE id = v_old_assignment_id;
    ELSE
      IF v_old_assignment_id IS NULL THEN
        RAISE EXCEPTION 'No active assignment found for case %', v_case_id;
      END IF;

      UPDATE public.case_assignments
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = v_user_id,
          void_reason = v_reason,
          remarks = concat_ws(E'\n', remarks, 'Void reason: ' || v_reason)
      WHERE id = v_old_assignment_id;

      v_linked_event_id := v_old_case_event_id;
      IF v_linked_event_id IS NULL THEN
        SELECT id INTO v_linked_event_id
        FROM public.case_events
        WHERE source_table = 'case_assignments'
          AND source_id = v_old_assignment_id
        ORDER BY id DESC
        LIMIT 1;
      END IF;

      IF v_linked_event_id IS NULL THEN
        v_linked_event_void := 'skipped_no_event';
      ELSE
        UPDATE public.case_events
        SET is_voided = true,
            voided_at = now(),
            voided_by_user_id = v_user_id,
            void_reason = 'Assignment voided: ' || v_reason,
            updated_by_user_id = v_user_id,
            updated_at = now()
        WHERE id = v_linked_event_id;
        v_linked_event_void := 'voided';
      END IF;
    END IF;

    INSERT INTO public.case_assignments(case_id,prosecutor_id,staff_id,assigned_by_user_id,assigned_at,remarks)
      VALUES (v_case_id,v_prosecutor_id,v_staff_id,v_user_id,v_assigned_at,v_assignment_remarks) RETURNING id INTO v_assignment_id;
      INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,prosecutor_id,staff_id,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id)
      VALUES (
        v_case_id,
        v_event_type_id,
        v_assigned_at::date,
        v_assigned_at::time,
        CASE WHEN v_assignment_action = 'void_replace' THEN 'Assignment replacement' ELSE 'Case reassigned' END,
        v_assignment_remarks,
        v_prosecutor_id,
        v_staff_id,
        CASE WHEN v_assignment_action = 'void_replace' THEN
          jsonb_build_object('action', 'replacement_after_void', 'voided_assignment_id', v_old_assignment_id, 'voided_event_id', v_linked_event_id, 'previous_prosecutor_name', v_old_prosecutor_name, 'new_prosecutor_name', v_new_prosecutor_name, 'reason', v_reason, 'remarks', v_assignment_remarks)
        ELSE
          jsonb_build_object('action', 'reassign', 'previous_prosecutor_name', v_old_prosecutor_name, 'new_prosecutor_name', v_new_prosecutor_name, 'reason', v_reason, 'remarks', v_assignment_remarks)
        END,
        'MANUAL_EDIT',
        'case_assignments',
        v_assignment_id,
        v_user_id,
        v_user_id
      ) RETURNING id INTO v_event_id;
      UPDATE public.case_assignments SET case_event_id = v_event_id WHERE id = v_assignment_id;
      UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Editing section % is not implemented yet', v_section;
  END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_new
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'EDIT_CASE_OVERVIEW_' || upper(v_section), 'cases', v_case_id, v_case_id, 'Edited case overview ' || replace(v_section, '_', ' '), jsonb_strip_nulls(jsonb_build_object('reason', v_reason, 'section', v_section, 'case_received_event_sync', v_case_received_sync, 'assignment_mode', v_assignment_action, 'linked_event_void', v_linked_event_void)), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.edit_case_overview_section(jsonb) TO anon, authenticated, service_role;


ALTER TABLE public.case_violations
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS delete_reason text;

ALTER TABLE public.case_addresses
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS delete_reason text;

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS delete_reason text;


CREATE OR REPLACE FUNCTION public.manage_case_violations(p_payload jsonb)
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
  v_violation jsonb := coalesce(p_payload->'violation', '{}'::jsonb);
  v_case_violation_id bigint := nullif(v_violation->>'id','')::bigint;
  v_violation_id bigint := nullif(v_violation->>'violationId','')::bigint;
  v_violation_order integer := nullif(v_violation->>'violationOrder','')::integer;
  v_raw_violation_text text := nullif(btrim(v_violation->>'rawViolationText'), '');
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(cv) || jsonb_build_object('violation', to_jsonb(v)) ORDER BY cv.violation_order NULLS LAST, cv.id), '[]'::jsonb)
  INTO v_old
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE cv.case_id = v_case_id;

  IF v_action IN ('add', 'edit') THEN
    IF v_violation_id IS NULL THEN RAISE EXCEPTION 'violationId is required'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.violations WHERE id = v_violation_id) THEN RAISE EXCEPTION 'Violation % not found', v_violation_id; END IF;
    IF v_action = 'add' THEN
      INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text)
      VALUES (v_case_id, v_violation_id, COALESCE(v_violation_order, (SELECT COALESCE(max(cv.violation_order), 0) + 1 FROM public.case_violations cv WHERE cv.case_id = v_case_id)), v_raw_violation_text);
    ELSE
      IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
      IF EXISTS (SELECT 1 FROM public.case_violations WHERE id = v_case_violation_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore violation before editing'; END IF;
      UPDATE public.case_violations
      SET violation_id = v_violation_id,
          violation_order = v_violation_order,
          raw_violation_text = v_raw_violation_text
      WHERE id = v_case_violation_id AND case_id = v_case_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
    END IF;
  ELSIF v_action = 'remove' THEN
    IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_violations
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by_user_id = v_user_id,
        delete_reason = v_reason
    WHERE id = v_case_violation_id AND case_id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
  ELSIF v_action = 'restore' THEN
    IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_violations
    SET is_deleted = false,
        deleted_at = NULL,
        deleted_by_user_id = NULL,
        delete_reason = NULL
    WHERE id = v_case_violation_id AND case_id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported violations action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(cv) || jsonb_build_object('violation', to_jsonb(v)) ORDER BY cv.violation_order NULLS LAST, cv.id), '[]'::jsonb)
  INTO v_new
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE cv.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_VIOLATIONS_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed case violations', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.manage_case_places(p_payload jsonb)
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
  v_place jsonb := coalesce(p_payload->'place', '{}'::jsonb);
  v_case_address_id bigint := nullif(v_place->>'id','')::bigint;
  v_address_id bigint := nullif(v_place->>'addressId','')::bigint;
  v_address_type_id bigint;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(ca) || jsonb_build_object('address', to_jsonb(a), 'address_type', to_jsonb(at)) ORDER BY ca.id), '[]'::jsonb)
  INTO v_old
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  WHERE ca.case_id = v_case_id;

  IF v_action IN ('add', 'edit') THEN
    v_address_type_id := nullif(v_place->>'addressTypeId','')::bigint;
    IF v_address_type_id IS NULL THEN
      SELECT id INTO v_address_type_id
      FROM public.address_types
      WHERE is_active IS TRUE
        AND (
          upper(code) IN ('PLACE_OF_COMMISSION', 'COMMISSION_PLACE', 'POC')
          OR display_label ILIKE '%commission%'
        )
      ORDER BY CASE WHEN upper(code) = 'PLACE_OF_COMMISSION' THEN 0 ELSE 1 END, id
      LIMIT 1;
    END IF;
    IF v_address_type_id IS NULL THEN RAISE EXCEPTION 'Missing address type for Place of Commission'; END IF;
    IF v_action = 'add' THEN
      INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country,latitude,longitude)
      VALUES (nullif(btrim(v_place->>'line1'),''), nullif(btrim(v_place->>'line2'),''), nullif(btrim(v_place->>'barangay'),''), nullif(btrim(v_place->>'city'),''), nullif(btrim(v_place->>'province'),''), nullif(btrim(v_place->>'region'),''), nullif(btrim(v_place->>'zipCode'),''), coalesce(nullif(btrim(v_place->>'country'),''), 'Philippines'), nullif(v_place->>'latitude','')::numeric, nullif(v_place->>'longitude','')::numeric)
      RETURNING id INTO v_address_id;
      INSERT INTO public.case_addresses(case_id,address_id,address_type_id,is_primary,remarks)
      VALUES (v_case_id, v_address_id, v_address_type_id, coalesce(nullif(v_place->>'isPrimary','')::boolean,false), nullif(btrim(v_place->>'remarks'),''))
      RETURNING id INTO v_case_address_id;
    ELSE
      IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
      SELECT address_id INTO v_address_id FROM public.case_addresses WHERE id = v_case_address_id AND case_id = v_case_id;
      IF v_address_id IS NULL THEN RAISE EXCEPTION 'Place % not found', v_case_address_id; END IF;
      IF EXISTS (SELECT 1 FROM public.case_addresses WHERE id = v_case_address_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore place before editing'; END IF;
      UPDATE public.addresses SET line1=nullif(btrim(v_place->>'line1'),''), line2=nullif(btrim(v_place->>'line2'),''), barangay=nullif(btrim(v_place->>'barangay'),''), city=nullif(btrim(v_place->>'city'),''), province=nullif(btrim(v_place->>'province'),''), region=nullif(btrim(v_place->>'region'),''), zip_code=nullif(btrim(v_place->>'zipCode'),''), country=coalesce(nullif(btrim(v_place->>'country'),''), 'Philippines'), latitude=nullif(v_place->>'latitude','')::numeric, longitude=nullif(v_place->>'longitude','')::numeric WHERE id = v_address_id;
      UPDATE public.case_addresses SET address_type_id=v_address_type_id, is_primary=coalesce(nullif(v_place->>'isPrimary','')::boolean,false), remarks=nullif(btrim(v_place->>'remarks'),'') WHERE id = v_case_address_id AND case_id = v_case_id;
    END IF;
    IF coalesce(nullif(v_place->>'isPrimary','')::boolean,false) IS TRUE THEN
      UPDATE public.case_addresses
      SET is_primary = false
      WHERE case_id = v_case_id
        AND id <> v_case_address_id
        AND coalesce(is_deleted, false) IS FALSE;
    END IF;
  ELSIF v_action = 'remove' THEN
    IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_addresses SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason WHERE id = v_case_address_id AND case_id = v_case_id;
  ELSIF v_action = 'restore' THEN
    IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_addresses SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL WHERE id = v_case_address_id AND case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Unsupported places action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(ca) || jsonb_build_object('address', to_jsonb(a), 'address_type', to_jsonb(at)) ORDER BY ca.id), '[]'::jsonb)
  INTO v_new
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  WHERE ca.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_PLACES_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed places of commission', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.manage_case_notes(p_payload jsonb)
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
  v_note jsonb := coalesce(p_payload->'note', '{}'::jsonb);
  v_note_id bigint := nullif(v_note->>'id','')::bigint;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.created_at DESC, n.id DESC), '[]'::jsonb) INTO v_old FROM public.notes n WHERE n.case_id = v_case_id;

  IF v_action = 'add' THEN
    IF nullif(btrim(v_note->>'noteText'),'') IS NULL THEN RAISE EXCEPTION 'noteText is required'; END IF;
    INSERT INTO public.notes(case_id,created_by_user_id,note_text,is_private)
    VALUES (v_case_id, v_user_id, nullif(btrim(v_note->>'noteText'),''), coalesce(nullif(v_note->>'isPrivate','')::boolean,false));
  ELSIF v_action = 'edit' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    IF EXISTS (SELECT 1 FROM public.notes WHERE id = v_note_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore note before editing'; END IF;
    IF nullif(btrim(v_note->>'noteText'),'') IS NULL THEN RAISE EXCEPTION 'noteText is required'; END IF;
    UPDATE public.notes SET note_text = nullif(btrim(v_note->>'noteText'),''), is_private = coalesce(nullif(v_note->>'isPrivate','')::boolean,false), updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSIF v_action = 'remove' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.notes SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason, updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSIF v_action = 'restore' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.notes SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL, updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Unsupported notes action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.created_at DESC, n.id DESC), '[]'::jsonb) INTO v_new FROM public.notes n WHERE n.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_NOTES_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed case notes', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_case_violations(jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.manage_case_places(jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.manage_case_notes(jsonb) TO anon, authenticated, service_role;


-- Keep case overview assignment read model aligned with soft-voided assignments.
CREATE OR REPLACE VIEW public.v_case_details_page AS
 WITH latest_assignment AS (
         SELECT DISTINCT ON (ca.case_id) ca.case_id,
            ca.prosecutor_id,
            ca.staff_id,
            ca.assigned_at,
            ca.id
           FROM public.case_assignments ca
          WHERE ca.unassigned_at IS NULL AND COALESCE(ca.is_voided, false) IS FALSE
          ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
        ), violation_summary AS (
         SELECT cv.case_id,
            string_agg(COALESCE(NULLIF(btrim(cv.raw_violation_text), ''::text), v.title), ', '::text ORDER BY cv.violation_order, cv.id) AS violations
           FROM (public.case_violations cv
             LEFT JOIN public.violations v ON ((v.id = cv.violation_id)))
          WHERE COALESCE(cv.is_deleted, false) IS FALSE
          GROUP BY cv.case_id
        ), note_summary AS (
         SELECT n.case_id,
            jsonb_agg(jsonb_build_object('id', n.id, 'note_text', n.note_text, 'is_private', n.is_private, 'created_by_user_id', n.created_by_user_id, 'created_at', n.created_at, 'updated_at', n.updated_at) ORDER BY n.created_at DESC, n.id DESC) AS notes
           FROM public.notes n
          WHERE COALESCE(n.is_deleted, false) IS FALSE
          GROUP BY n.case_id
        ), case_address_summary AS (
         SELECT ca.case_id,
            jsonb_agg(jsonb_build_object('id', ca.id, 'address_id', ca.address_id, 'address_type_id', ca.address_type_id, 'address_type_label', at.display_label, 'is_primary', ca.is_primary, 'remarks', ca.remarks, 'addresses', jsonb_build_object('barangay', a.barangay, 'city', a.city, 'country', a.country, 'line1', a.line1, 'line2', a.line2, 'province', a.province, 'region', a.region, 'zip_code', a.zip_code)) ORDER BY ca.is_primary DESC, ca.id) AS case_addresses
           FROM ((public.case_addresses ca
             JOIN public.addresses a ON ((a.id = ca.address_id)))
             LEFT JOIN public.address_types at ON ((at.id = ca.address_type_id)))
          WHERE COALESCE(ca.is_deleted, false) IS FALSE
          GROUP BY ca.case_id
        )
 SELECT c.id,
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
    concat_ws('-'::text, c.region_code, dt.prefix, ("right"((c.docket_year)::text, 2) || COALESCE(c.docket_month_code, ''::text)), lpad((c.docket_number)::text, 6, '0'::text)) AS docket_display_number,
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
    COALESCE(cas.case_addresses, '[]'::jsonb) AS case_addresses,
    COALESCE(ns.notes, '[]'::jsonb) AS notes
   FROM ((((((((((public.cases c
     JOIN public.docket_types dt ON ((dt.id = c.docket_type_id)))
     LEFT JOIN public.case_private_details cpd ON ((cpd.case_id = c.id)))
     LEFT JOIN public.case_statuses cs ON ((cs.id = cpd.current_status_id)))
     LEFT JOIN latest_assignment la ON ((la.case_id = c.id)))
     LEFT JOIN public.prosecutors p ON ((p.id = la.prosecutor_id)))
     LEFT JOIN public.staff st ON ((st.id = la.staff_id)))
     LEFT JOIN public.case_classifications cc ON ((cc.id = c.case_classification_id)))
     LEFT JOIN violation_summary vs ON ((vs.case_id = c.id)))
     LEFT JOIN note_summary ns ON ((ns.case_id = c.id)))
     LEFT JOIN case_address_summary cas ON ((cas.case_id = c.id)))
  WHERE (NOT c.is_archived);


-- Keep docket quick details assignment read model aligned with soft-voided assignments.
CREATE OR REPLACE VIEW public.v_docket_quickdetails AS
WITH latest_assignment AS (
  SELECT DISTINCT ON (ca.case_id)
    ca.case_id,
    ca.prosecutor_id,
    ca.assigned_at,
    ca.id
  FROM public.case_assignments ca
  WHERE ca.unassigned_at IS NULL
    AND ca.is_voided IS FALSE
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
)
SELECT
  c.id,
  c.date_received,
  cs.code AS current_status_code,
  cs.display_label AS current_status_label,
  p.full_name AS prosecutor_full_name,
  p.short_name AS prosecutor_short_name
FROM public.cases c
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_statuses cs ON cs.id = cpd.current_status_id
LEFT JOIN latest_assignment la ON la.case_id = c.id
LEFT JOIN public.prosecutors p ON p.id = la.prosecutor_id
WHERE NOT c.is_archived;

COMMENT ON VIEW public.v_docket_quickdetails IS 'Cases page quick details read model for prosecutor, status, and received date. Intentionally policy-free for development debugging.';
