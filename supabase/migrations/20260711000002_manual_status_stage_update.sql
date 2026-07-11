BEGIN;

CREATE OR REPLACE FUNCTION public.add_case_stage(p_display_label text, p_code text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_label text := nullif(btrim(p_display_label), '');
  v_code text := nullif(upper(regexp_replace(btrim(coalesce(p_code, p_display_label)), '[^A-Za-z0-9]+', '_', 'g')), '');
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_label IS NULL THEN RAISE EXCEPTION 'Display Label is required'; END IF;
  v_code := regexp_replace(v_code, '^_+|_+$', '', 'g');
  IF v_code IS NULL OR v_code = '' THEN RAISE EXCEPTION 'Case Stage code is required'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_stages WHERE upper(code) = v_code) THEN RAISE EXCEPTION 'Case Stage code already exists'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_stages WHERE is_active IS TRUE AND lower(regexp_replace(btrim(display_label::text), '\s+', ' ', 'g')) = lower(regexp_replace(v_label, '\s+', ' ', 'g'))) THEN RAISE EXCEPTION 'An active Case Stage with this label already exists'; END IF;

  INSERT INTO public.case_stages(code, display_label, sort_order, is_final_stage, is_milestone, is_active)
  VALUES (v_code, v_label, COALESCE((SELECT max(sort_order) + 10 FROM public.case_stages), 10), false, false, true)
  RETURNING id INTO v_id;

  SELECT to_jsonb(cs) INTO v_new FROM public.case_stages cs WHERE cs.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,new_data,summary,metadata)
  VALUES (p_user_id,'case_stages',v_id,'ADD_CASE_STAGE',v_new,'Added Case Stage ' || v_label || '.',jsonb_build_object('code',v_code));
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_case_stage(text,text,bigint) TO authenticated;

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
  v_stage_history_id bigint;
  v_from_status_id bigint;
  v_to_status_id bigint;
  v_from_stage_id bigint;
  v_to_stage_id bigint;
  v_status_code text;
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
      SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'CASE_RECEIVED' AND is_active IS TRUE LIMIT 1;
      IF v_event_type_id IS NULL THEN
        v_case_received_sync := 'skipped_missing_event_type';
      ELSE
        SELECT id INTO v_event_id FROM public.case_events WHERE case_id = v_case_id AND event_type_id = v_event_type_id AND COALESCE(is_voided, false) IS FALSE ORDER BY event_date DESC NULLS LAST, id DESC LIMIT 1;
        IF v_event_id IS NOT NULL THEN
          UPDATE public.case_events SET event_date = v_new_date_received, title = COALESCE(NULLIF(title, ''), 'Case received'), description = COALESCE(NULLIF(description, ''), 'Case received date updated from overview edit'), details_jsonb = COALESCE(details_jsonb, '{}'::jsonb) || jsonb_build_object('action', 'sync_case_received_from_overview', 'old_date_received', v_old_date_received, 'new_date_received', v_new_date_received, 'reason', v_reason), updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_event_id;
          v_case_received_sync := 'updated_existing_event';
        ELSIF v_new_date_received IS NOT NULL THEN
          INSERT INTO public.case_events(case_id,event_type_id,event_date,title,description,details_jsonb,source,source_table,source_id,created_by_user_id,updated_by_user_id) VALUES (v_case_id,v_event_type_id,v_new_date_received,'Case received','Case received date updated from overview edit',jsonb_build_object('action', 'sync_case_received_from_overview', 'old_date_received', v_old_date_received, 'new_date_received', v_new_date_received, 'reason', v_reason),'MANUAL_EDIT','cases',v_case_id,v_user_id,v_user_id);
          v_case_received_sync := 'created_missing_event';
        ELSE
          v_case_received_sync := 'skipped_null_date_received';
        END IF;
      END IF;
    END IF;
  ELSIF v_section = 'case_details' THEN
    UPDATE public.cases SET case_classification_id = nullif(p_payload#>>'{data,caseClassificationId}','')::bigint, updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    UPDATE public.case_private_details SET is_summary_procedure = COALESCE(nullif(p_payload#>>'{data,isSummaryProcedure}','')::boolean, false), summary_text = nullif(btrim(p_payload#>>'{data,summaryText}'),''), remarks = nullif(btrim(p_payload#>>'{data,remarks}'),'') WHERE case_id = v_case_id;
  ELSIF v_section = 'status' THEN
    v_to_status_id := nullif(p_payload#>>'{data,statusId}','')::bigint;
    v_to_stage_id := nullif(p_payload#>>'{data,stageId}','')::bigint;
    v_status_date := nullif(p_payload#>>'{data,statusDate}','')::date;
    v_status_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_to_status_id IS NULL THEN RAISE EXCEPTION 'Case Status is required'; END IF;
    IF v_to_stage_id IS NULL THEN RAISE EXCEPTION 'Case Stage is required'; END IF;
    IF v_status_date IS NULL THEN RAISE EXCEPTION 'Status Date is required'; END IF;
    SELECT code INTO v_status_code FROM public.case_statuses WHERE id = v_to_status_id AND is_active IS TRUE;
    IF v_status_code IS NULL THEN RAISE EXCEPTION 'Selected Case Status must be active'; END IF;
    IF v_status_code NOT IN ('PENDING','FILED','DISMISSED','MIXED_RESULT') THEN RAISE EXCEPTION 'Selected Case Status must be PENDING, FILED, DISMISSED, or MIXED_RESULT'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.case_stages WHERE id = v_to_stage_id AND is_active IS TRUE) THEN RAISE EXCEPTION 'Selected Case Stage must be active'; END IF;

    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    SELECT current_case_status_id, current_case_stage_id INTO v_from_status_id, v_from_stage_id FROM public.case_private_details WHERE case_id = v_case_id;
    v_from_status_id := COALESCE(v_from_status_id, (SELECT current_status_id FROM public.case_private_details WHERE case_id = v_case_id));

    IF v_from_status_id IS DISTINCT FROM v_to_status_id THEN
      INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks)
      VALUES (v_case_id,v_from_status_id,v_to_status_id,v_user_id,now(),v_status_date,v_status_remarks) RETURNING id INTO v_status_history_id;
    END IF;
    IF v_from_stage_id IS DISTINCT FROM v_to_stage_id THEN
      INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks)
      VALUES (v_case_id,v_from_stage_id,v_to_stage_id,v_user_id,now(),v_status_date,v_status_remarks) RETURNING id INTO v_stage_history_id;
    END IF;

    UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
    UPDATE public.case_private_details SET
      current_status_id = v_to_status_id,
      current_status_date = v_status_date,
      current_status_remarks = v_status_remarks,
      current_case_status_id = v_to_status_id,
      current_case_status_date = v_status_date,
      current_case_status_remarks = v_status_remarks,
      current_case_stage_id = v_to_stage_id,
      current_case_stage_date = v_status_date,
      current_case_stage_remarks = v_status_remarks
    WHERE case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Editing section % is not implemented yet', v_section;
  END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_new
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'EDIT_CASE_OVERVIEW_' || upper(v_section), 'cases', v_case_id, v_case_id, 'Edited case overview ' || replace(v_section, '_', ' '), jsonb_strip_nulls(jsonb_build_object('reason', v_reason, 'section', v_section, 'case_received_event_sync', v_case_received_sync, 'status_history_id', v_status_history_id, 'case_stage_history_id', v_stage_history_id, 'case_events_created_for_status_update', false)), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.edit_case_overview_section(jsonb) TO anon, authenticated, service_role;

-- Verification notes:
-- 1. Update Status UI filters Case Status options to PENDING, FILED, DISMISSED, and MIXED_RESULT only.
-- 2. Update Status UI loads all active Case Stage rows from v_ref_case_stages.
-- 3. public.add_case_stage creates an active case_stages seed row and writes an audit log.
-- 4. The frontend refreshes stages and selects the newly returned stage id after add_case_stage succeeds.
-- 5. public.add_case_stage rejects duplicate codes case-insensitively.
-- 6. public.add_case_stage rejects equivalent active display labels after trim/space normalization.
-- 7. The status branch updates both current_case_status_* and current_case_stage_* fields.
-- 8. Legacy current_status_id/current_status_date/current_status_remarks stay synchronized to Case Status.
-- 9. case_status_history receives a row only when Case Status changes.
-- 10. case_stage_history receives a row only when Case Stage changes.
-- 11. The status branch does not insert into case_events, so no timeline activity is created.
-- 12. statusApprovedDateRaw is not read from the RPC payload and is absent from the Update Status UI.
-- 13. Event recording, void, Motion, Petition, Court, Assignment, and Reassignment RPCs are not changed here.

COMMIT;
