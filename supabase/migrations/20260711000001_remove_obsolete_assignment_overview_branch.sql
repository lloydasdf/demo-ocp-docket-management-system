BEGIN;

-- Cleanup after Assignment/Reassignment moved fully into Add Event.
-- Removes the obsolete section = assignment branch while preserving status and overview edit behavior.

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
  v_status_history_id bigint;
  v_from_status_id bigint;
  v_to_status_id bigint;
  v_status_date date;
  v_status_remarks text;
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
  ELSE
    RAISE EXCEPTION 'Editing section % is not implemented yet', v_section;
  END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_new
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'EDIT_CASE_OVERVIEW_' || upper(v_section), 'cases', v_case_id, v_case_id, 'Edited case overview ' || replace(v_section, '_', ' '), jsonb_strip_nulls(jsonb_build_object('reason', v_reason, 'section', v_section, 'case_received_event_sync', v_case_received_sync)), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.edit_case_overview_section(jsonb) TO anon, authenticated, service_role;

COMMIT;
