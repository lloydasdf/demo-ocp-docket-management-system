INSERT INTO public.case_stages (code, display_label, sort_order, is_final_stage, is_milestone, is_active)
VALUES ('CASE_RAFFLED', 'Case Raffled', 30, false, true, true)
ON CONFLICT (code) DO UPDATE SET
  display_label = EXCLUDED.display_label,
  sort_order = EXCLUDED.sort_order,
  is_final_stage = EXCLUDED.is_final_stage,
  is_milestone = EXCLUDED.is_milestone,
  is_active = true,
  updated_at = now();

INSERT INTO public.case_stage_colors (stage_id, color_name, background_class, text_class, border_class, is_active)
SELECT cs.id, 'blue', 'bg-blue-50', 'text-blue-800', 'border-blue-200', true
FROM public.case_stages cs
WHERE cs.code = 'CASE_RAFFLED'
ON CONFLICT (stage_id) DO UPDATE SET
  color_name = EXCLUDED.color_name,
  background_class = EXCLUDED.background_class,
  text_class = EXCLUDED.text_class,
  border_class = EXCLUDED.border_class,
  is_active = true;

CREATE OR REPLACE FUNCTION public.record_case_assignment_event(
  p_case_id bigint,
  p_prosecutor_id bigint,
  p_assignment_date date,
  p_assignment_time time without time zone DEFAULT NULL,
  p_staff_id bigint DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_event_type_id bigint;
  v_pending_status_id bigint;
  v_case_raffled_stage_id bigint;
  v_event_id bigint;
  v_assignment_id bigint;
  v_status_history_id bigint;
  v_stage_history_id bigint;
  v_previous_status_id bigint;
  v_previous_case_status_id bigint;
  v_previous_stage_id bigint;
  v_assigned_at timestamptz;
  v_prosecutor_name text;
  v_staff_name text;
  v_old_details jsonb;
  v_new_details jsonb;
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Assigned prosecutor is required'; END IF;
  IF p_assignment_date IS NULL THEN RAISE EXCEPTION 'Assignment date is required'; END IF;

  SELECT id INTO v_event_type_id
  FROM public.case_event_types
  WHERE code = 'CASE_ASSIGNMENT' AND is_active IS TRUE
  LIMIT 1;

  IF v_event_type_id IS NULL THEN
    RAISE EXCEPTION 'Missing active case event type CASE_ASSIGNMENT';
  END IF;

  SELECT id INTO v_pending_status_id
  FROM public.case_statuses
  WHERE code = 'PENDING' AND is_active IS TRUE
  LIMIT 1;

  IF v_pending_status_id IS NULL THEN
    INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
    VALUES ('PENDING', 'Pending', 20, false, false, true)
    ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final = false, is_milestone = false, is_active = true
    RETURNING id INTO v_pending_status_id;
  END IF;

  SELECT id INTO v_case_raffled_stage_id
  FROM public.case_stages
  WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE
  LIMIT 1;

  IF v_case_raffled_stage_id IS NULL THEN
    RAISE EXCEPTION 'Missing active case stage CASE_RAFFLED';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = p_prosecutor_id) THEN
    RAISE EXCEPTION 'Unknown prosecutor id %', p_prosecutor_id;
  END IF;

  IF p_staff_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.staff WHERE id = p_staff_id) THEN
    RAISE EXCEPTION 'Unknown staff id %', p_staff_id;
  END IF;

  SELECT cpd.current_status_id, cpd.current_case_status_id, cpd.current_case_stage_id, to_jsonb(cpd)
  INTO v_previous_status_id, v_previous_case_status_id, v_previous_stage_id, v_old_details
  FROM public.case_private_details cpd
  WHERE cpd.case_id = p_case_id;

  v_assigned_at := (p_assignment_date::timestamp + COALESCE(p_assignment_time, '00:00'::time))::timestamptz;

  SELECT COALESCE(short_name, full_name) INTO v_prosecutor_name
  FROM public.prosecutors
  WHERE id = p_prosecutor_id;

  SELECT COALESCE(short_name, full_name) INTO v_staff_name
  FROM public.staff
  WHERE id = p_staff_id;

  IF EXISTS (
    SELECT 1
    FROM public.case_assignments ca
    WHERE ca.case_id = p_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE
  ) THEN
    RAISE EXCEPTION 'This case already has an active assignment. Void or reassign the current assignment first.';
  END IF;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description,
    status_id, case_status_id, case_stage_id,
    prosecutor_id, staff_id, details_jsonb, source, created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id,
    v_event_type_id,
    p_assignment_date,
    p_assignment_time,
    'Case Assignment',
    'Assigned to Prosec ' || COALESCE(v_prosecutor_name, p_prosecutor_id::text) || ' on ' || to_char(p_assignment_date, 'Mon DD, YYYY'),
    v_pending_status_id,
    v_pending_status_id,
    v_case_raffled_stage_id,
    p_prosecutor_id,
    p_staff_id,
    jsonb_build_object(
      'action', 'case_assignment',
      'new_prosecutor_id', p_prosecutor_id,
      'new_prosecutor_name', v_prosecutor_name,
      'staff_id', p_staff_id,
      'staff_name', v_staff_name,
      'remarks', NULLIF(btrim(COALESCE(p_remarks, '')), ''),
      'automatic_status', 'Pending',
      'automatic_case_status', 'Pending',
      'automatic_case_stage', 'Case Raffled'
    ),
    'MANUAL_ENTRY', p_user_id, p_user_id
  ) RETURNING id INTO v_event_id;

  INSERT INTO public.case_assignments (case_id, prosecutor_id, staff_id, assigned_by_user_id, assigned_at, remarks, case_event_id)
  VALUES (p_case_id, p_prosecutor_id, p_staff_id, p_user_id, v_assigned_at, NULLIF(btrim(COALESCE(p_remarks, '')), ''), v_event_id)
  RETURNING id INTO v_assignment_id;

  UPDATE public.case_events
  SET source_table = 'case_assignments', source_id = v_assignment_id, updated_by_user_id = p_user_id
  WHERE id = v_event_id;

  INSERT INTO public.case_status_history (
    case_id, from_status_id, to_status_id, changed_by_user_id, changed_at, status_date, remarks, case_event_id
  ) VALUES (
    p_case_id,
    COALESCE(v_previous_case_status_id, v_previous_status_id),
    v_pending_status_id,
    p_user_id,
    now(),
    p_assignment_date,
    'Case Assignment recorded. Broad case status set to Pending.',
    v_event_id
  ) RETURNING id INTO v_status_history_id;

  INSERT INTO public.case_stage_history (
    case_id, from_stage_id, to_stage_id, changed_by_user_id, changed_at, stage_date, remarks, case_event_id
  ) VALUES (
    p_case_id,
    v_previous_stage_id,
    v_case_raffled_stage_id,
    p_user_id,
    now(),
    p_assignment_date,
    'Case Assignment recorded. Workflow stage set to Case Raffled.',
    v_event_id
  ) RETURNING id INTO v_stage_history_id;

  INSERT INTO public.case_private_details (
    case_id,
    current_status_id,
    current_status_date,
    current_case_status_id,
    current_case_status_date,
    current_case_stage_id,
    current_case_stage_date,
    updated_at
  )
  VALUES (
    p_case_id,
    v_pending_status_id,
    p_assignment_date,
    v_pending_status_id,
    p_assignment_date,
    v_case_raffled_stage_id,
    p_assignment_date,
    now()
  )
  ON CONFLICT (case_id) DO UPDATE SET
    current_status_id = EXCLUDED.current_status_id,
    current_status_date = EXCLUDED.current_status_date,
    current_case_status_id = EXCLUDED.current_case_status_id,
    current_case_status_date = EXCLUDED.current_case_status_date,
    current_case_stage_id = EXCLUDED.current_case_stage_id,
    current_case_stage_date = EXCLUDED.current_case_stage_date,
    updated_at = now();

  SELECT to_jsonb(cpd) INTO v_new_details
  FROM public.case_private_details cpd
  WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (
    p_user_id,
    'case_assignments',
    v_assignment_id,
    'CASE_ASSIGNED_CASE_RAFFLED_STAGE',
    v_old_details,
    v_new_details,
    p_case_id,
    'Case assigned to ' || COALESCE(v_prosecutor_name, 'selected prosecutor') || '; case status set to Pending and case stage set to Case Raffled.',
    jsonb_build_object(
      'case_event_id', v_event_id,
      'assignment_id', v_assignment_id,
      'status_id', v_pending_status_id,
      'case_status_id', v_pending_status_id,
      'case_stage_id', v_case_raffled_stage_id,
      'status_history_id', v_status_history_id,
      'case_stage_history_id', v_stage_history_id
    )
  );

  RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_status_code text; v_status_label text; v_status_id bigint; v_prev_status_id bigint; v_status_history_id bigint; v_old_details jsonb; v_new_details jsonb;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb; v_prev_case_status_id bigint; v_prev_stage_id bigint; v_pending_status_id bigint; v_for_raffle_stage_id bigint; v_case_raffled_stage_id bigint; v_target_stage_id bigint; v_active_assignment_count integer; v_stage_history_id bigint;
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

  SELECT current_status_id, current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_case_status_id, v_prev_stage_id, v_old_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
  UPDATE public.case_events SET is_voided = true, void_reason = p_void_reason, voided_at = now(), voided_by_user_id = p_voided_by_user_id, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new FROM public.case_events ce WHERE ce.id = p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata) VALUES (p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id, 'Voided case timeline activity', jsonb_build_object('reason', p_void_reason));

  IF lower(coalesce(v_source_table,'')) = 'case_court_filings' OR v_event_type_code = 'COURT_FILING' THEN
    SELECT cf.id, to_jsonb(cf) INTO v_filing_id, v_filing_old FROM public.case_court_filings cf WHERE cf.id = v_source_id OR cf.case_event_id = p_case_event_id ORDER BY CASE WHEN cf.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_filing_id IS NOT NULL THEN
      UPDATE public.case_court_filings SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_filing_id;
      SELECT to_jsonb(cf) INTO v_filing_new FROM public.case_court_filings cf WHERE cf.id = v_filing_id;
      SELECT status_code, status_label INTO v_status_code, v_status_label FROM public.recompute_case_status_after_court_filing(v_case_id) LIMIT 1;
      IF v_status_code IS NOT NULL THEN
        INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active) VALUES (v_status_code, v_status_label, CASE v_status_code WHEN 'PENDING' THEN 20 WHEN 'RESO_FOR_APPROVAL' THEN 80 WHEN 'FOR_FILING' THEN 90 WHEN 'FILED_OTHER_RESO_FOR_APPROVAL' THEN 92 WHEN 'FILED_OTHER_INFO_FOR_FILING' THEN 94 WHEN 'FILED' THEN 96 WHEN 'DISMISSED' THEN 100 ELSE 110 END, v_status_code IN ('FILED','DISMISSED','MIXED_RESULT'), v_status_code <> 'PENDING', true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,sort_order=EXCLUDED.sort_order,is_final=EXCLUDED.is_final,is_milestone=EXCLUDED.is_milestone,is_active=true RETURNING id INTO v_status_id;
        INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,updated_at) VALUES (v_case_id,v_status_id,CURRENT_DATE,'Court filing voided. Status recomputed.',v_status_id,CURRENT_DATE,'Court filing voided. Status recomputed.',now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,updated_at=now();
        IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Court filing voided. Status recomputed.',p_case_event_id) RETURNING id INTO v_status_history_id; END IF;
        SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
      END IF;
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_voided_by_user_id,'case_court_filings',v_filing_id,'VOID_COURT_FILING_FROM_EVENT',v_filing_old,jsonb_build_object('court_filing',v_filing_new,'case_private_details',v_new_details),v_case_id,'Court filing voided and case status recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'status_history_id',v_status_history_id,'reason',p_void_reason,'recomputed_status_code',v_status_code));
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
      SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, unassigned_at = COALESCE(unassigned_at, now())
      WHERE id = v_assignment_id;

      SELECT to_jsonb(ca) INTO v_assignment_new
      FROM public.case_assignments ca
      WHERE ca.id = v_assignment_id;
    END IF;

    SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1;
    SELECT id INTO v_for_raffle_stage_id FROM public.case_stages WHERE code = 'FOR_RAFFLE' AND is_active IS TRUE LIMIT 1;
    SELECT id INTO v_case_raffled_stage_id FROM public.case_stages WHERE code = 'CASE_RAFFLED' AND is_active IS TRUE LIMIT 1;
    IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status PENDING'; END IF;
    IF v_for_raffle_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage FOR_RAFFLE'; END IF;
    IF v_case_raffled_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage CASE_RAFFLED'; END IF;

    SELECT count(*) INTO v_active_assignment_count
    FROM public.case_assignments ca
    WHERE ca.case_id = v_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE;

    v_target_stage_id := CASE WHEN COALESCE(v_active_assignment_count, 0) > 0 THEN v_case_raffled_stage_id ELSE v_for_raffle_stage_id END;

    INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at)
    VALUES (v_case_id,v_pending_status_id,CURRENT_DATE,'Case Assignment voided. Broad case status remains Pending.',v_pending_status_id,CURRENT_DATE,'Case Assignment voided. Broad case status remains Pending.',v_target_stage_id,CURRENT_DATE,'Case Assignment voided. Workflow stage recomputed.',now())
    ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();

    IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_pending_status_id THEN
      INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
      VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_pending_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Case Assignment voided. Broad case status remains Pending.',p_case_event_id)
      RETURNING id INTO v_status_history_id;
    END IF;

    IF v_prev_stage_id IS DISTINCT FROM v_target_stage_id THEN
      INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
      VALUES (v_case_id,v_prev_stage_id,v_target_stage_id,p_voided_by_user_id,now(),CURRENT_DATE,'Case Assignment voided. Workflow stage recomputed.',p_case_event_id)
      RETURNING id INTO v_stage_history_id;
    END IF;

    SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;

    INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
    VALUES (
      p_voided_by_user_id,
      'case_assignments',
      v_assignment_id,
      'VOID_CASE_ASSIGNMENT_STAGE_RECOMPUTED',
      v_assignment_old,
      jsonb_build_object('assignment', v_assignment_new, 'case_private_details', v_new_details),
      v_case_id,
      'Assignment row voided; case status kept Pending and case stage recomputed.',
      jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'case_status_id',v_pending_status_id,'case_stage_id',v_target_stage_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id,'active_assignment_count',v_active_assignment_count)
    );
  ELSIF lower(coalesce(v_source_table,'')) = 'case_assignments' OR v_event_type_code = 'CASE_REASSIGNMENT' THEN
    UPDATE public.case_assignments
    SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, unassigned_at = COALESCE(unassigned_at, now())
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

  IF v_event_type_code IN ('CASE_RESOLVED','CASE_DECISION_APPROVED','CASE_REASSIGNMENT') OR lower(coalesce(v_source_table,'')) IN ('case_resolutions','case_resolution_approvals') THEN
    SELECT status_code, status_label INTO v_status_code, v_status_label FROM public.recompute_case_status_after_court_filing(v_case_id) LIMIT 1;
    IF v_status_code IS NOT NULL THEN
      INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active) VALUES (v_status_code, v_status_label, CASE v_status_code WHEN 'PENDING' THEN 20 WHEN 'RESO_FOR_APPROVAL' THEN 80 WHEN 'FOR_FILING' THEN 90 WHEN 'FILED_OTHER_RESO_FOR_APPROVAL' THEN 92 WHEN 'FILED_OTHER_INFO_FOR_FILING' THEN 94 WHEN 'FILED' THEN 96 WHEN 'DISMISSED' THEN 100 ELSE 110 END, v_status_code IN ('FILED','DISMISSED','MIXED_RESULT'), v_status_code <> 'PENDING', true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,sort_order=EXCLUDED.sort_order,is_final=EXCLUDED.is_final,is_milestone=EXCLUDED.is_milestone,is_active=true RETURNING id INTO v_status_id;
      INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,updated_at) VALUES (v_case_id,v_status_id,CURRENT_DATE,'Timeline event voided. Status recomputed.',v_status_id,CURRENT_DATE,'Timeline event voided. Status recomputed.',now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,updated_at=now();
      IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (v_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_status_id,p_voided_by_user_id,now(),CURRENT_DATE,'Timeline event voided. Status recomputed.',p_case_event_id); END IF;
    END IF;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_case_assignment_event(bigint, bigint, date, time without time zone, bigint, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.void_case_event(bigint, text, bigint) TO authenticated;
