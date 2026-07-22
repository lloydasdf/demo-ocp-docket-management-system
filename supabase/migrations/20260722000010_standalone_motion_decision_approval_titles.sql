-- Require a user-entered title for standalone Motion Decision Approved events.
BEGIN;

ALTER TABLE public.case_motion_resolution_approvals
  ADD COLUMN IF NOT EXISTS motion_title text;

DROP FUNCTION IF EXISTS public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint);

CREATE OR REPLACE FUNCTION public.record_motion_decision_approved_event(
  p_case_id bigint, p_case_motion_resolution_id bigint DEFAULT NULL,
  p_approved_decision_recommendation_id bigint DEFAULT NULL,
  p_approved_by_prosecutor_id bigint DEFAULT NULL, p_date_approved date DEFAULT NULL,
  p_time_approved time without time zone DEFAULT NULL, p_update_case_status boolean DEFAULT false,
  p_selected_case_status_id bigint DEFAULT NULL, p_selected_case_stage_id bigint DEFAULT NULL,
  p_remarks text DEFAULT NULL, p_user_id bigint DEFAULT NULL,
  p_motion_title text DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_approval_id bigint; v_case_motion_id bigint;
  v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint;
  v_status_history_id bigint; v_stage_history_id bigint; v_old_details jsonb; v_new_details jsonb;
  v_effective_time time without time zone; v_remarks text := NULLIF(btrim(coalesce(p_remarks,'')), ''); v_entered_motion_title text := NULLIF(btrim(coalesce(p_motion_title,'')), '');
  v_motion_title text; v_filed_by_code text; v_filed_by_label text; v_assigned_prosecutor_id bigint; v_assigned_prosecutor_name text;
  v_original_recommendation_id bigint; v_original_recommendation_code text; v_original_recommendation_label text;
  v_approved_decision_code text; v_approved_decision_label text; v_approved_by_name text;
  v_approver_position_code text; v_approver_position_group_type text; v_status_code text; v_stage_code text; v_status_label text; v_stage_label text;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF p_date_approved IS NULL THEN RAISE EXCEPTION 'Date Approved is required'; END IF;
  IF p_approved_decision_recommendation_id IS NULL THEN RAISE EXCEPTION 'Approved decision recommendation is required'; END IF;
  IF p_approved_by_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Approved By prosecutor is required'; END IF;
  IF v_entered_motion_title IS NULL THEN RAISE EXCEPTION 'Motion Title is required'; END IF;

  IF p_case_motion_resolution_id IS NOT NULL THEN
    SELECT cmr.case_motion_id, cm.motion_title, cm.filed_by_code, cm.filed_by, cm.assigned_prosecutor_id, coalesce(ap.short_name, ap.full_name), cmr.recommendation_id, rr.code, rr.display_label
    INTO v_case_motion_id, v_motion_title, v_filed_by_code, v_filed_by_label, v_assigned_prosecutor_id, v_assigned_prosecutor_name, v_original_recommendation_id, v_original_recommendation_code, v_original_recommendation_label
    FROM public.case_motion_resolutions cmr
    JOIN public.case_motions cm ON cm.id = cmr.case_motion_id AND cm.is_voided = false
    JOIN public.case_events me ON me.id = cm.case_event_id AND me.is_voided = false
    JOIN public.case_events re ON re.id = cmr.case_event_id AND re.is_voided = false
    JOIN public.motion_resolution_recommendations rr ON rr.id = cmr.recommendation_id
    LEFT JOIN public.prosecutors ap ON ap.id = cm.assigned_prosecutor_id
    WHERE cmr.id = p_case_motion_resolution_id AND cmr.case_id = p_case_id AND cmr.is_voided = false;
    IF v_case_motion_id IS NULL THEN RAISE EXCEPTION 'Selected motion resolution is not active for this case'; END IF;
  END IF;

  v_motion_title := v_entered_motion_title;

  SELECT code, display_label INTO v_approved_decision_code, v_approved_decision_label FROM public.motion_resolution_recommendations WHERE id = p_approved_decision_recommendation_id AND is_active IS TRUE LIMIT 1;
  IF v_approved_decision_code IS NULL THEN RAISE EXCEPTION 'Approved decision recommendation must be active'; END IF;
  SELECT pr.full_name, p.code, p.group_type INTO v_approved_by_name, v_approver_position_code, v_approver_position_group_type FROM public.prosecutors pr LEFT JOIN public.positions p ON p.id = pr.position_id WHERE pr.id = p_approved_by_prosecutor_id AND pr.is_active IS TRUE LIMIT 1;
  IF v_approved_by_name IS NULL THEN RAISE EXCEPTION 'Approved By prosecutor must be active'; END IF;
  IF coalesce(v_approver_position_group_type, '') <> 'PROSECUTOR' OR coalesce(v_approver_position_code, '') NOT IN ('CHIEF_PROSECUTOR', 'DEPUTY_PROSECUTOR') THEN RAISE EXCEPTION 'Approved By must be an active Chief Prosecutor or Deputy Prosecutor'; END IF;

  IF coalesce(p_update_case_status, false) THEN
    IF p_selected_case_status_id IS NULL OR p_selected_case_stage_id IS NULL THEN RAISE EXCEPTION 'Case Status and Case Stage are required when updating case status'; END IF;
    SELECT code, display_label INTO v_status_code, v_status_label FROM public.case_statuses WHERE id = p_selected_case_status_id AND is_active IS TRUE LIMIT 1;
    SELECT code, display_label INTO v_stage_code, v_stage_label FROM public.case_stages WHERE id = p_selected_case_stage_id AND is_active IS TRUE LIMIT 1;
    IF v_status_code IS NULL THEN RAISE EXCEPTION 'Selected Case Status must be active'; END IF;
    IF v_stage_code IS NULL THEN RAISE EXCEPTION 'Selected Case Stage must be active'; END IF;
    v_status_id := p_selected_case_status_id; v_stage_id := p_selected_case_stage_id;
  END IF;

  v_effective_time := coalesce(p_time_approved, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'MOTION_DECISION_APPROVED' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing Motion Decision Approved event type'; END IF;
  SELECT current_status_id, current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_case_status_id, v_prev_stage_id, v_old_details FROM public.case_private_details cpd WHERE case_id = p_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_approved,v_effective_time,v_motion_title,v_remarks,jsonb_build_object('motion_id',v_case_motion_id,'motion_resolution_id',p_case_motion_resolution_id,'motion_title',v_motion_title,'filed_by_code',v_filed_by_code,'filed_by_label',v_filed_by_label,'assigned_prosecutor_id',v_assigned_prosecutor_id,'assigned_prosecutor_name',v_assigned_prosecutor_name,'original_recommendation_id',v_original_recommendation_id,'original_recommendation_code',v_original_recommendation_code,'original_recommendation_label',v_original_recommendation_label,'approved_decision_recommendation_id',p_approved_decision_recommendation_id,'approved_decision_code',v_approved_decision_code,'approved_decision_label',v_approved_decision_label,'approved_by_prosecutor_id',p_approved_by_prosecutor_id,'approved_by_name',v_approved_by_name,'date_approved',p_date_approved,'time_approved',v_effective_time,'updates_case_status',coalesce(p_update_case_status,false),'selected_case_status_id',CASE WHEN coalesce(p_update_case_status,false) THEN p_selected_case_status_id ELSE NULL END,'selected_case_status_label',CASE WHEN coalesce(p_update_case_status,false) THEN v_status_label ELSE NULL END,'selected_case_stage_id',CASE WHEN coalesce(p_update_case_status,false) THEN p_selected_case_stage_id ELSE NULL END,'selected_case_stage_label',CASE WHEN coalesce(p_update_case_status,false) THEN v_stage_label ELSE NULL END,'remarks',v_remarks),'MANUAL_ENTRY','case_motion_resolution_approvals',p_user_id,p_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_motion_resolution_approvals(case_id,case_motion_id,case_motion_resolution_id,case_event_id,motion_title,approved_decision_recommendation_id,approved_by_prosecutor_id,date_approved,time_approved,updates_case_status,selected_case_status_id,selected_case_stage_id,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_case_motion_id,p_case_motion_resolution_id,v_event_id,v_motion_title,p_approved_decision_recommendation_id,p_approved_by_prosecutor_id,p_date_approved,v_effective_time,coalesce(p_update_case_status,false),CASE WHEN coalesce(p_update_case_status,false) THEN p_selected_case_status_id ELSE NULL END,CASE WHEN coalesce(p_update_case_status,false) THEN p_selected_case_stage_id ELSE NULL END,v_remarks,p_user_id,p_user_id) RETURNING id INTO v_approval_id;

  IF NOT coalesce(p_update_case_status, false) THEN
    SELECT case_status_code, case_stage_code INTO v_status_code, v_stage_code FROM public.compute_current_case_state(p_case_id) LIMIT 1;
    SELECT id, display_label INTO v_status_id, v_status_label FROM public.case_statuses WHERE code = v_status_code AND is_active IS TRUE LIMIT 1;
    SELECT id, display_label INTO v_stage_id, v_stage_label FROM public.case_stages WHERE code = v_stage_code AND is_active IS TRUE LIMIT 1;
  END IF;
  IF v_status_id IS NULL OR v_stage_id IS NULL THEN RAISE EXCEPTION 'Unable to determine case status/stage'; END IF;
  UPDATE public.case_events SET source_id=v_approval_id,status_id=v_status_id,case_status_id=v_status_id,case_stage_id=v_stage_id,details_jsonb=details_jsonb || jsonb_build_object('case_status_id',v_status_id,'case_status_code',v_status_code,'case_status_label',v_status_label,'case_stage_id',v_stage_id,'case_stage_code',v_stage_code,'case_stage_label',v_stage_label),updated_at=now(),updated_by_user_id=p_user_id WHERE id=v_event_id;
  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at) VALUES (p_case_id,v_status_id,p_date_approved,v_remarks,v_status_id,p_date_approved,v_remarks,v_stage_id,p_date_approved,v_remarks,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();
  IF coalesce(v_prev_case_status_id,v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,coalesce(v_prev_case_status_id,v_prev_status_id),v_status_id,p_user_id,now(),p_date_approved,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_approved,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_motion_resolution_approvals',v_approval_id,'MOTION_DECISION_APPROVED',v_old_details,v_new_details,p_case_id,'Motion decision approved.',jsonb_build_object('case_event_id',v_event_id,'motion_id',v_case_motion_id,'motion_resolution_id',p_case_motion_resolution_id,'motion_resolution_approval_id',v_approval_id,'approved_decision_recommendation_id',p_approved_decision_recommendation_id,'approved_by_prosecutor_id',p_approved_by_prosecutor_id,'updates_case_status',coalesce(p_update_case_status,false),'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));
  RETURN v_event_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint,text) TO authenticated;
COMMENT ON FUNCTION public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint,text) IS 'Records a standalone Motion Decision Approved event with a required motion title, approval record, optional status update, timeline, history, audit, and void support.';

COMMIT;
