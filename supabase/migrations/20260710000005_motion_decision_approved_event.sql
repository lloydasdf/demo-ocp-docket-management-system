BEGIN;

INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
VALUES ('MOTION_DECISION_APPROVED', 'Motion Decision Approved', 'MOTION', 'Manual timeline event for approving a motion resolution decision.', 160, true, true)
ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label, category=EXCLUDED.category, description=EXCLUDED.description, sort_order=EXCLUDED.sort_order, is_active=true, updated_at=now();

CREATE TABLE IF NOT EXISTS public.case_motion_resolution_approvals (
  id bigserial PRIMARY KEY,
  case_id bigint NOT NULL REFERENCES public.cases(id),
  case_motion_id bigint NOT NULL REFERENCES public.case_motions(id),
  case_motion_resolution_id bigint NOT NULL REFERENCES public.case_motion_resolutions(id),
  case_event_id bigint UNIQUE REFERENCES public.case_events(id),
  approved_decision_recommendation_id bigint NOT NULL REFERENCES public.motion_resolution_recommendations(id),
  approved_by_prosecutor_id bigint NOT NULL REFERENCES public.prosecutors(id),
  date_approved date NOT NULL,
  time_approved time without time zone,
  updates_case_status boolean NOT NULL DEFAULT false,
  selected_case_status_id bigint REFERENCES public.case_statuses(id),
  selected_case_stage_id bigint REFERENCES public.case_stages(id),
  remarks text,
  created_by_user_id bigint REFERENCES public.users(id),
  updated_by_user_id bigint REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  is_voided boolean NOT NULL DEFAULT false,
  voided_at timestamptz,
  voided_by_user_id bigint REFERENCES public.users(id),
  void_reason text
);
CREATE UNIQUE INDEX IF NOT EXISTS case_motion_resolution_approvals_one_active_uidx ON public.case_motion_resolution_approvals(case_motion_resolution_id) WHERE is_voided = false;
CREATE INDEX IF NOT EXISTS idx_case_motion_resolution_approvals_case_active ON public.case_motion_resolution_approvals(case_id, is_voided, date_approved DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_case_motion_resolution_approvals_motion ON public.case_motion_resolution_approvals(case_motion_id);
CREATE INDEX IF NOT EXISTS idx_case_motion_resolution_approvals_event ON public.case_motion_resolution_approvals(case_event_id);
GRANT SELECT, INSERT, UPDATE ON public.case_motion_resolution_approvals TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.compute_current_case_state(p_case_id bigint)
RETURNS TABLE(case_status_code text, case_stage_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_motion_resolution_for_approval_count integer;
  v_pending_motion_count integer;
  v_unapproved_resolution_count integer;
  v_unfiled_for_filing_count integer;
  v_filed_for_filing_count integer;
  v_dismissal_count integer;
  v_active_assignment_count integer;
BEGIN
  SELECT count(*) INTO v_motion_resolution_for_approval_count
  FROM public.case_motion_resolutions cmr
  JOIN public.case_motions cm ON cm.id = cmr.case_motion_id AND cm.is_voided = false
  JOIN public.case_events ce ON ce.id = cmr.case_event_id AND ce.is_voided = false
  WHERE cmr.case_id = p_case_id
    AND cmr.is_voided = false
    AND NOT EXISTS (SELECT 1 FROM public.case_motion_resolution_approvals cmra WHERE cmra.case_motion_resolution_id = cmr.id AND cmra.is_voided = false);

  SELECT count(*) INTO v_pending_motion_count
  FROM public.case_motions cm
  JOIN public.case_events ce ON ce.id = cm.case_event_id AND ce.is_voided = false
  WHERE cm.case_id = p_case_id
    AND cm.is_voided = false
    AND cm.case_event_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.case_motion_resolutions cmr WHERE cmr.case_motion_id = cm.id AND cmr.is_voided = false);

  IF COALESCE(v_motion_resolution_for_approval_count, 0) > 0 THEN
    RETURN QUERY SELECT 'PENDING'::text, 'MOTION_RESO_FOR_APPROVAL'::text;
    RETURN;
  ELSIF COALESCE(v_pending_motion_count, 0) > 0 THEN
    RETURN QUERY SELECT 'PENDING'::text, 'MOTION_PENDING'::text;
    RETURN;
  END IF;

  SELECT count(*) INTO v_unapproved_resolution_count FROM public.case_resolutions cr WHERE cr.case_id = p_case_id AND cr.is_voided = false AND NOT EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id = cr.id AND a.is_voided = false);
  SELECT count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false)), count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND NOT EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false)), count(*) FILTER (WHERE aa.decision_code = 'DISMISSAL') INTO v_filed_for_filing_count, v_unfiled_for_filing_count, v_dismissal_count FROM public.case_resolution_approval_actions aa JOIN public.case_resolution_approvals a ON a.id = aa.approval_id AND a.is_voided = false JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id AND cr.is_voided = false WHERE aa.case_id = p_case_id;
  SELECT count(*) INTO v_active_assignment_count FROM public.case_assignments ca WHERE ca.case_id = p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE;

  IF COALESCE(v_unapproved_resolution_count, 0) > 0 THEN
    IF COALESCE(v_filed_for_filing_count, 0) > 0 THEN RETURN QUERY SELECT 'PENDING'::text, 'FILED_OTHER_RESO_FOR_APPROVAL'::text; ELSE RETURN QUERY SELECT 'PENDING'::text, 'RESO_FOR_APPROVAL'::text; END IF;
  ELSIF COALESCE(v_unfiled_for_filing_count, 0) > 0 THEN
    IF COALESCE(v_filed_for_filing_count, 0) > 0 THEN RETURN QUERY SELECT 'PENDING'::text, 'FILED_OTHER_INFO_FOR_FILING'::text; ELSE RETURN QUERY SELECT 'PENDING'::text, 'FOR_FILING'::text; END IF;
  ELSIF COALESCE(v_filed_for_filing_count, 0) > 0 AND COALESCE(v_dismissal_count, 0) > 0 THEN RETURN QUERY SELECT 'MIXED_RESULT'::text, 'MIXED_RESULT'::text;
  ELSIF COALESCE(v_filed_for_filing_count, 0) > 0 THEN RETURN QUERY SELECT 'FILED'::text, 'FILED'::text;
  ELSIF COALESCE(v_dismissal_count, 0) > 0 THEN RETURN QUERY SELECT 'DISMISSED'::text, 'DISMISSED'::text;
  ELSIF COALESCE(v_active_assignment_count, 0) > 0 THEN RETURN QUERY SELECT 'PENDING'::text, 'CASE_RAFFLED'::text;
  ELSE RETURN QUERY SELECT 'PENDING'::text, 'FOR_RAFFLE'::text;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_motion_decision_approved_event(
  p_case_id bigint,
  p_case_motion_resolution_id bigint,
  p_approved_decision_recommendation_id bigint,
  p_approved_by_prosecutor_id bigint,
  p_date_approved date,
  p_time_approved time without time zone DEFAULT NULL,
  p_update_case_status boolean DEFAULT false,
  p_selected_case_status_id bigint DEFAULT NULL,
  p_selected_case_stage_id bigint DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_approval_id bigint; v_case_motion_id bigint; v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_old_details jsonb; v_new_details jsonb; v_effective_time time without time zone; v_remarks text := NULLIF(btrim(coalesce(p_remarks,'')), '');
  v_motion_title text; v_filed_by_code text; v_filed_by_label text; v_assigned_prosecutor_id bigint; v_assigned_prosecutor_name text; v_original_recommendation_id bigint; v_original_recommendation_code text; v_original_recommendation_label text; v_approved_decision_code text; v_approved_decision_label text; v_approved_by_name text; v_approver_position_code text; v_approver_position_group_type text; v_status_code text; v_stage_code text; v_status_label text; v_stage_label text;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id=p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF p_date_approved IS NULL THEN RAISE EXCEPTION 'Date Approved is required'; END IF;

  SELECT cmr.case_motion_id, cm.motion_title, cm.filed_by_code, cm.filed_by, cm.assigned_prosecutor_id, coalesce(ap.short_name,ap.full_name), cmr.recommendation_id, rr.code, rr.display_label
  INTO v_case_motion_id, v_motion_title, v_filed_by_code, v_filed_by_label, v_assigned_prosecutor_id, v_assigned_prosecutor_name, v_original_recommendation_id, v_original_recommendation_code, v_original_recommendation_label
  FROM public.case_motion_resolutions cmr
  JOIN public.case_motions cm ON cm.id = cmr.case_motion_id AND cm.is_voided = false
  JOIN public.case_events me ON me.id = cm.case_event_id AND me.is_voided = false
  JOIN public.case_events re ON re.id = cmr.case_event_id AND re.is_voided = false
  JOIN public.motion_resolution_recommendations rr ON rr.id = cmr.recommendation_id
  LEFT JOIN public.prosecutors ap ON ap.id = cm.assigned_prosecutor_id
  WHERE cmr.id = p_case_motion_resolution_id AND cmr.case_id = p_case_id AND cmr.is_voided = false;
  IF v_case_motion_id IS NULL THEN RAISE EXCEPTION 'Selected motion resolution is not active for this case'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_motion_resolution_approvals a WHERE a.case_motion_resolution_id = p_case_motion_resolution_id AND a.is_voided = false) THEN RAISE EXCEPTION 'This motion resolution already has an active approval.'; END IF;

  SELECT code, display_label INTO v_approved_decision_code, v_approved_decision_label FROM public.motion_resolution_recommendations WHERE id=p_approved_decision_recommendation_id AND is_active IS TRUE LIMIT 1;
  IF v_approved_decision_code IS NULL THEN RAISE EXCEPTION 'Approved decision recommendation must be active'; END IF;

  SELECT pr.full_name, p.code, p.group_type INTO v_approved_by_name, v_approver_position_code, v_approver_position_group_type
  FROM public.prosecutors pr LEFT JOIN public.positions p ON p.id = pr.position_id
  WHERE pr.id = p_approved_by_prosecutor_id AND pr.is_active IS TRUE LIMIT 1;
  IF v_approved_by_name IS NULL THEN RAISE EXCEPTION 'Approved By prosecutor must be active'; END IF;
  IF COALESCE(v_approver_position_group_type, '') <> 'PROSECUTOR' OR COALESCE(v_approver_position_code, '') NOT IN ('CHIEF_PROSECUTOR','DEPUTY_PROSECUTOR') THEN
    RAISE EXCEPTION 'Approved By must be an active Chief Prosecutor or Deputy Prosecutor';
  END IF;

  IF COALESCE(p_update_case_status, false) THEN
    IF p_selected_case_status_id IS NULL OR p_selected_case_stage_id IS NULL THEN RAISE EXCEPTION 'Case Status and Case Stage are required when updating case status'; END IF;
    SELECT code, display_label INTO v_status_code, v_status_label FROM public.case_statuses WHERE id=p_selected_case_status_id AND is_active IS TRUE LIMIT 1;
    SELECT code, display_label INTO v_stage_code, v_stage_label FROM public.case_stages WHERE id=p_selected_case_stage_id AND is_active IS TRUE LIMIT 1;
    IF v_status_code IS NULL OR v_status_code NOT IN ('PENDING','FILED','DISMISSED','MIXED_RESULT') THEN RAISE EXCEPTION 'Selected Case Status is not allowed'; END IF;
    IF v_stage_code IS NULL THEN RAISE EXCEPTION 'Selected Case Stage must be active'; END IF;
    v_status_id := p_selected_case_status_id; v_stage_id := p_selected_case_stage_id;
  END IF;

  v_effective_time := coalesce(p_time_approved, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code='MOTION_DECISION_APPROVED' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing Motion Decision Approved event type'; END IF;
  SELECT current_status_id,current_case_status_id,current_case_stage_id,to_jsonb(cpd) INTO v_prev_status_id,v_prev_case_status_id,v_prev_stage_id,v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_approved,v_effective_time,'Motion Decision Approved',v_remarks,jsonb_build_object('motion_id',v_case_motion_id,'motion_resolution_id',p_case_motion_resolution_id,'motion_title',v_motion_title,'filed_by_code',v_filed_by_code,'filed_by_label',v_filed_by_label,'assigned_prosecutor_id',v_assigned_prosecutor_id,'assigned_prosecutor_name',v_assigned_prosecutor_name,'original_recommendation_id',v_original_recommendation_id,'original_recommendation_code',v_original_recommendation_code,'original_recommendation_label',v_original_recommendation_label,'approved_decision_recommendation_id',p_approved_decision_recommendation_id,'approved_decision_code',v_approved_decision_code,'approved_decision_label',v_approved_decision_label,'approved_by_prosecutor_id',p_approved_by_prosecutor_id,'approved_by_name',v_approved_by_name,'date_approved',p_date_approved,'time_approved',v_effective_time,'updates_case_status',COALESCE(p_update_case_status,false),'selected_case_status_id',CASE WHEN COALESCE(p_update_case_status,false) THEN p_selected_case_status_id ELSE NULL END,'selected_case_status_label',CASE WHEN COALESCE(p_update_case_status,false) THEN v_status_label ELSE NULL END,'selected_case_stage_id',CASE WHEN COALESCE(p_update_case_status,false) THEN p_selected_case_stage_id ELSE NULL END,'selected_case_stage_label',CASE WHEN COALESCE(p_update_case_status,false) THEN v_stage_label ELSE NULL END,'remarks',v_remarks),'MANUAL_ENTRY','case_motion_resolution_approvals',p_user_id,p_user_id) RETURNING id INTO v_event_id;

  INSERT INTO public.case_motion_resolution_approvals(case_id,case_motion_id,case_motion_resolution_id,case_event_id,approved_decision_recommendation_id,approved_by_prosecutor_id,date_approved,time_approved,updates_case_status,selected_case_status_id,selected_case_stage_id,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_case_motion_id,p_case_motion_resolution_id,v_event_id,p_approved_decision_recommendation_id,p_approved_by_prosecutor_id,p_date_approved,v_effective_time,COALESCE(p_update_case_status,false),CASE WHEN COALESCE(p_update_case_status,false) THEN p_selected_case_status_id ELSE NULL END,CASE WHEN COALESCE(p_update_case_status,false) THEN p_selected_case_stage_id ELSE NULL END,v_remarks,p_user_id,p_user_id) RETURNING id INTO v_approval_id;

  IF NOT COALESCE(p_update_case_status, false) THEN
    SELECT case_status_code, case_stage_code INTO v_status_code, v_stage_code FROM public.compute_current_case_state(p_case_id) LIMIT 1;
    SELECT id, display_label INTO v_status_id, v_status_label FROM public.case_statuses WHERE code=v_status_code AND is_active IS TRUE LIMIT 1;
    SELECT id, display_label INTO v_stage_id, v_stage_label FROM public.case_stages WHERE code=v_stage_code AND is_active IS TRUE LIMIT 1;
  END IF;
  IF v_status_id IS NULL OR v_stage_id IS NULL THEN RAISE EXCEPTION 'Unable to determine case status/stage'; END IF;

  UPDATE public.case_events SET source_id=v_approval_id,status_id=v_status_id,case_status_id=v_status_id,case_stage_id=v_stage_id,details_jsonb=details_jsonb || jsonb_build_object('case_status_id',v_status_id,'case_status_code',v_status_code,'case_status_label',v_status_label,'case_stage_id',v_stage_id,'case_stage_code',v_stage_code,'case_stage_label',v_stage_label),updated_at=now(),updated_by_user_id=p_user_id WHERE id=v_event_id;
  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at) VALUES (p_case_id,v_status_id,p_date_approved,v_remarks,v_status_id,p_date_approved,v_remarks,v_stage_id,p_date_approved,v_remarks,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();
  IF coalesce(v_prev_case_status_id,v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,coalesce(v_prev_case_status_id,v_prev_status_id),v_status_id,p_user_id,now(),p_date_approved,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_approved,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_motion_resolution_approvals',v_approval_id,'MOTION_DECISION_APPROVED',v_old_details,v_new_details,p_case_id,'Motion decision approved.',jsonb_build_object('case_event_id',v_event_id,'motion_id',v_case_motion_id,'motion_resolution_id',p_case_motion_resolution_id,'motion_resolution_approval_id',v_approval_id,'original_recommendation_id',v_original_recommendation_id,'approved_decision_recommendation_id',p_approved_decision_recommendation_id,'approved_by_prosecutor_id',p_approved_by_prosecutor_id,'updates_case_status',COALESCE(p_update_case_status,false),'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));
  RETURN v_event_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint) TO authenticated;

CREATE OR REPLACE VIEW public.v_case_motion_resolutions_detail AS
SELECT cmr.id, cmr.case_id, cmr.case_motion_id, cmr.case_event_id, cmr.recommendation_id, rr.code AS recommendation_code, rr.display_label AS recommendation_label, cmr.date_resolved, cmr.time_resolved, cmr.remarks, cmr.is_voided, cm.motion_title, cm.filed_by, cm.filed_by_code, cm.date_filed, cm.assigned_prosecutor_id, coalesce(ap.short_name,ap.full_name) AS assigned_prosecutor_name, cmra.id AS active_motion_decision_approval_id
FROM public.case_motion_resolutions cmr
JOIN public.case_motions cm ON cm.id = cmr.case_motion_id
LEFT JOIN public.prosecutors ap ON ap.id = cm.assigned_prosecutor_id
LEFT JOIN public.motion_resolution_recommendations rr ON rr.id = cmr.recommendation_id
LEFT JOIN public.case_motion_resolution_approvals cmra ON cmra.case_motion_resolution_id = cmr.id AND cmra.is_voided = false;
GRANT SELECT ON public.v_case_motion_resolutions_detail TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
  v_motion_id bigint; v_motion_old jsonb; v_motion_new jsonb;
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

  SELECT current_status_id, to_jsonb(cpd) INTO v_prev_status_id, v_old_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
  UPDATE public.case_events SET is_voided = true, void_reason = p_void_reason, voided_at = now(), voided_by_user_id = p_voided_by_user_id, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new FROM public.case_events ce WHERE ce.id = p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata) VALUES (p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id, 'Voided case timeline activity', jsonb_build_object('reason', p_void_reason));

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

COMMENT ON FUNCTION public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint) IS 'Records MOTION_DECISION_APPROVED, storing original and approved recommendations, optional manual status/stage impact, audit metadata, and Asia/Manila default time.';
COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Motion-aware exact-record priority: active case_motion_resolutions without active case_motion_resolution_approvals -> PENDING/MOTION_RESO_FOR_APPROVAL; active unresolved case_motions -> PENDING/MOTION_PENDING; otherwise existing non-motion fallback.';
COMMENT ON FUNCTION public.void_case_event(bigint,text,bigint) IS 'Changed for MOTION_DECISION_APPROVED and exact Motion Resolved dependency guard while preserving unrelated event branches.';

-- Verification SQL/comments:
-- 1. record_motion_decision_approved_event rejects approvers outside CHIEF_PROSECUTOR or DEPUTY_PROSECUTOR.
-- 2. case_motion_resolution_approvals_one_active_uidx prevents more than one active approval per Motion Resolution.
-- 3. Approved decision recommendation may differ from case_motion_resolutions.recommendation_id; both values are stored in event details and audit metadata.
-- 4. add_motion_resolution_recommendation remains reused by the UI; refreshed options can be auto-selected before final save.
-- 5. Update Case Status = false inserts no status-update event and recomputes from remaining active workflows.
-- 6. Update Case Status = true applies selected broad status/stage and records conditional history rows.
-- 7. public.void_case_event(motion_decision_approved_event_id, ...) recomputes to PENDING / MOTION_RESO_FOR_APPROVAL for the unapproved Motion Resolution.
-- 8. public.void_case_event(motion_resolved_event_id, ...) raises while an active case_motion_resolution_approvals row exists.
-- 9. Status/stage histories are inserted only when ids change.
-- 10. Omitted p_time_approved uses (now() AT TIME ZONE 'Asia/Manila')::time(0); explicit historical time is preserved.
-- 11. Existing non-motion public.void_case_event branches remain present in the function body.
-- 12. UI progressive form prevents advancing until required fields are complete and calls the RPC only from the final review Save.

COMMIT;
