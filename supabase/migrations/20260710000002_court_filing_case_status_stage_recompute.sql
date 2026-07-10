BEGIN;

CREATE OR REPLACE FUNCTION public.record_court_filing_event(
  p_case_id bigint,
  p_case_resolution_approval_action_id bigint,
  p_court_id bigint DEFAULT NULL,
  p_court_name text DEFAULT NULL,
  p_court_branch text DEFAULT NULL,
  p_charge_filed text DEFAULT NULL,
  p_date_filed date DEFAULT NULL,
  p_time_filed time without time zone DEFAULT NULL,
  p_information_count integer DEFAULT NULL,
  p_criminal_case_no text DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_filing_id bigint; v_approval_id bigint; v_resolution_id bigint;
  v_case_status_code text; v_case_stage_code text; v_case_status_label text; v_case_stage_label text;
  v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint;
  v_status_history_id bigint; v_stage_history_id bigint;
  v_effective_time time without time zone;
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
  v_old_details jsonb; v_new_details jsonb; v_court_id bigint; v_court_name text; v_court_code text; v_court_code_candidate text; v_code_suffix integer := 0; v_charge text := NULLIF(btrim(COALESCE(p_charge_filed, '')), '');
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_case_resolution_approval_action_id IS NULL THEN RAISE EXCEPTION 'Approved filing decision is required'; END IF;
  IF p_court_id IS NULL AND NULLIF(btrim(COALESCE(p_court_name, '')), '') IS NULL THEN RAISE EXCEPTION 'Court is required'; END IF;
  IF v_charge IS NULL THEN RAISE EXCEPTION 'Charge filed is required'; END IF;
  IF p_date_filed IS NULL THEN RAISE EXCEPTION 'Date filed is required'; END IF;
  v_effective_time := COALESCE(p_time_filed, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;

  SELECT aa.approval_id, a.case_resolution_id INTO v_approval_id, v_resolution_id
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id = aa.approval_id
  JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id
  WHERE aa.id = p_case_resolution_approval_action_id AND aa.case_id = p_case_id
    AND aa.decision_code = 'FOR_FILING' AND a.is_voided = false AND cr.is_voided = false;
  IF v_approval_id IS NULL THEN RAISE EXCEPTION 'No active approved FOR_FILING decision was found for this case.'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_court_filings WHERE case_resolution_approval_action_id = p_case_resolution_approval_action_id AND is_voided = false) THEN
    RAISE EXCEPTION 'This approved filing decision already has a court filing.';
  END IF;

  IF p_court_id IS NOT NULL THEN
    SELECT c.id, c.name INTO v_court_id, v_court_name FROM public.courts c WHERE c.id = p_court_id;
    IF v_court_id IS NULL THEN RAISE EXCEPTION 'Unknown court id %', p_court_id; END IF;
  ELSE
    SELECT c.id, c.name INTO v_court_id, v_court_name FROM public.courts c WHERE lower(btrim(c.name)) = lower(btrim(p_court_name)) ORDER BY c.id LIMIT 1;
    IF v_court_id IS NULL THEN
      v_court_name := NULLIF(btrim(p_court_name), '');
      v_court_code_candidate := upper(regexp_replace(v_court_name, '[^a-zA-Z0-9]+', '_', 'g'));
      v_court_code_candidate := trim(both '_' FROM COALESCE(NULLIF(v_court_code_candidate, ''), 'COURT'));
      v_court_code := left(v_court_code_candidate, 64);
      WHILE EXISTS (SELECT 1 FROM public.courts WHERE code = v_court_code) LOOP
        v_code_suffix := v_code_suffix + 1;
        v_court_code := left(v_court_code_candidate, greatest(1, 63 - length(v_code_suffix::text))) || '_' || v_code_suffix::text;
      END LOOP;
      INSERT INTO public.courts(code, name, court_type, is_active) VALUES (v_court_code, v_court_name, NULL, true) RETURNING id, name INTO v_court_id, v_court_name;
    END IF;
  END IF;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active) VALUES ('COURT_FILING','Court Filing','COURT','Manual timeline event for recording filing in court.',140,true,true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,is_active=true,updated_at=now() RETURNING id INTO v_event_type_id;

  SELECT current_status_id, current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_case_status_id, v_prev_stage_id, v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_filed,v_effective_time,'Court Filing','Filed in ' || v_court_name || ' on ' || to_char(p_date_filed, 'Mon FMDD, YYYY'),NULL,NULL,NULL,
    jsonb_build_object('court',v_court_name,'court_id',v_court_id,'court_branch',NULLIF(btrim(COALESCE(p_court_branch,'')),''),'charge_filed',v_charge,'date_filed',p_date_filed,'time_filed',v_effective_time,'information_count',p_information_count,'criminal_case_no',NULLIF(btrim(COALESCE(p_criminal_case_no,'')),''),'remarks',v_remarks,'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id),
    'MANUAL_ENTRY',p_user_id,p_user_id) RETURNING id INTO v_event_id;

  INSERT INTO public.case_court_filings(case_id,case_event_id,case_resolution_approval_id,case_resolution_approval_action_id,court_id,court_name,court_branch,charge_filed,date_filed,time_filed,information_count,criminal_case_no,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_id,v_approval_id,p_case_resolution_approval_action_id,v_court_id,v_court_name,NULLIF(btrim(COALESCE(p_court_branch,'')),''),v_charge,p_date_filed,v_effective_time,p_information_count,NULLIF(btrim(COALESCE(p_criminal_case_no,'')),''),v_remarks,p_user_id,p_user_id) RETURNING id INTO v_filing_id;

  SELECT case_status_code, case_stage_code INTO v_case_status_code, v_case_stage_code FROM public.compute_current_case_state(p_case_id) LIMIT 1;
  SELECT id, display_label INTO v_status_id, v_case_status_label FROM public.case_statuses WHERE code = v_case_status_code AND is_active IS TRUE LIMIT 1;
  SELECT id, display_label INTO v_stage_id, v_case_stage_label FROM public.case_stages WHERE code = v_case_stage_code AND is_active IS TRUE LIMIT 1;
  IF v_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status %', v_case_status_code; END IF;
  IF v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage %', v_case_stage_code; END IF;

  UPDATE public.case_events SET source_table='case_court_filings', source_id=v_filing_id, status_id=v_status_id, case_status_id=v_status_id, case_stage_id=v_stage_id, details_jsonb=details_jsonb || jsonb_build_object('case_status_code',v_case_status_code,'case_status_label',v_case_status_label,'case_stage_code',v_case_stage_code,'case_stage_label',v_case_stage_label), updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;

  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at)
  VALUES (p_case_id,v_status_id,p_date_filed,v_remarks,v_status_id,p_date_filed,v_remarks,v_stage_id,p_date_filed,v_remarks,now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();

  IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_status_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_court_filings',v_filing_id,'COURT_FILING',v_old_details,v_new_details,p_case_id,'Court filing recorded.',jsonb_build_object('case_event_id',v_event_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id,'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id,'case_status_code',v_case_status_code,'case_stage_code',v_case_stage_code));
  RETURN v_event_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_court_filing_event(bigint,bigint,bigint,text,text,text,date,time without time zone,integer,text,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
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

  SELECT current_status_id, to_jsonb(cpd) INTO v_prev_status_id, v_old_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
  UPDATE public.case_events SET is_voided = true, void_reason = p_void_reason, voided_at = now(), voided_by_user_id = p_voided_by_user_id, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new FROM public.case_events ce WHERE ce.id = p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata) VALUES (p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id, 'Voided case timeline activity', jsonb_build_object('reason', p_void_reason));

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

  IF v_event_type_code = 'CASE_ASSIGNMENT' THEN
    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_assignment_id IS NOT NULL THEN
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

  IF v_event_type_code IN ('CASE_RESOLVED','CASE_DECISION_APPROVED','CASE_ASSIGNMENT','CASE_REASSIGNMENT')
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

COMMENT ON FUNCTION public.record_court_filing_event(bigint, bigint, bigint, text, text, text, date, time without time zone, integer, text, text, bigint) IS 'Records COURT_FILING using split Case Status / Case Stage from public.compute_current_case_state().';

-- Verification SQL/comments (run in a seeded transaction and roll back):
-- 1. Court Filing with no other pending work: SELECT status.code, stage.code after public.record_court_filing_event(...) -> FILED / FILED.
-- 2. Court Filing while another approved filing action remains unfiled -> PENDING / FILED_OTHER_INFO_FOR_FILING.
-- 3. Court Filing while another resolution awaits approval -> PENDING / FILED_OTHER_RESO_FOR_APPROVAL.
-- 4. Court Filing with completed dismissal outcome -> MIXED_RESULT / MIXED_RESULT.
-- 5. Voiding the only Court Filing through public.void_case_event(court_filing_event_id, ...) -> PENDING / FOR_FILING.
-- 6. Voiding one of multiple Court Filings where another filed action remains -> PENDING / FILED_OTHER_INFO_FOR_FILING.
-- 7. public.void_case_event(approval_event_id, ...) and public.void_case_event(resolution_event_id, ...) still raise while an active linked Court Filing exists.
-- 8. Compare case_status_history and case_stage_history counts before/after COURT_FILING record/void: each table receives a row only when its respective recomputed id changes.

COMMIT;
