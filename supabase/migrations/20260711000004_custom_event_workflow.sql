CREATE OR REPLACE FUNCTION public.compute_current_case_state(p_case_id bigint)
RETURNS TABLE(case_status_code text, case_stage_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_active_petition_count integer; v_petition_status_code text; v_petition_stage_code text;
  v_motion_resolution_for_approval_count integer; v_pending_motion_count integer; v_unapproved_resolution_count integer; v_unfiled_for_filing_count integer; v_filed_for_filing_count integer; v_dismissal_count integer; v_active_assignment_count integer; v_explicit_status_code text; v_explicit_stage_code text;
BEGIN
  SELECT count(*) INTO v_active_petition_count
  FROM public.case_petitions_for_review p
  JOIN public.case_events ce ON ce.id=p.case_event_id AND ce.is_voided=false
  WHERE p.case_id=p_case_id AND p.is_voided=false;

  SELECT cs.code, cst.code INTO v_petition_status_code, v_petition_stage_code
  FROM public.case_petition_for_review_updates u
  JOIN public.case_petitions_for_review p ON p.id=u.petition_for_review_id AND p.is_voided=false
  JOIN public.case_events pe ON pe.id=p.case_event_id AND pe.is_voided=false
  JOIN public.case_statuses cs ON cs.id=u.selected_case_status_id AND cs.is_active IS TRUE
  JOIN public.case_stages cst ON cst.id=u.selected_case_stage_id AND cst.is_active IS TRUE
  WHERE u.case_id=p_case_id AND u.is_voided=false AND u.updates_case_status=true
  ORDER BY u.status_date DESC, NULL::time without time zone DESC NULLS LAST, pe.id DESC, u.id DESC
  LIMIT 1;

  SELECT count(*) INTO v_motion_resolution_for_approval_count FROM public.case_motion_resolutions cmr JOIN public.case_motions cm ON cm.id=cmr.case_motion_id AND cm.is_voided=false JOIN public.case_events re ON re.id=cmr.case_event_id AND re.is_voided=false JOIN public.case_events me ON me.id=cm.case_event_id AND me.is_voided=false WHERE cmr.case_id=p_case_id AND cmr.is_voided=false AND NOT EXISTS (SELECT 1 FROM public.case_motion_resolution_approvals a JOIN public.case_events ae ON ae.id=a.case_event_id AND ae.is_voided=false WHERE a.case_motion_resolution_id=cmr.id AND a.is_voided=false);
  SELECT count(*) INTO v_pending_motion_count FROM public.case_motions cm JOIN public.case_events ce ON ce.id=cm.case_event_id AND ce.is_voided=false WHERE cm.case_id=p_case_id AND cm.is_voided=false AND cm.case_event_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.case_motion_resolutions cmr WHERE cmr.case_motion_id=cm.id AND cmr.is_voided=false);
  IF COALESCE(v_motion_resolution_for_approval_count,0)>0 THEN RETURN QUERY SELECT 'PENDING'::text,'MOTION_RESO_FOR_APPROVAL'::text; RETURN; ELSIF COALESCE(v_pending_motion_count,0)>0 THEN RETURN QUERY SELECT 'PENDING'::text,'MOTION_PENDING'::text; RETURN; END IF;

  SELECT count(*) INTO v_unapproved_resolution_count FROM public.case_resolutions cr WHERE cr.case_id=p_case_id AND cr.is_voided=false AND NOT EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id=cr.id AND a.is_voided=false);
  SELECT count(*) FILTER (WHERE aa.decision_code='FOR_FILING' AND EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id=aa.id AND cf.is_voided=false)), count(*) FILTER (WHERE aa.decision_code='FOR_FILING' AND NOT EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id=aa.id AND cf.is_voided=false)), count(*) FILTER (WHERE aa.decision_code='DISMISSAL') INTO v_filed_for_filing_count, v_unfiled_for_filing_count, v_dismissal_count FROM public.case_resolution_approval_actions aa JOIN public.case_resolution_approvals a ON a.id=aa.approval_id AND a.is_voided=false JOIN public.case_resolutions cr ON cr.id=a.case_resolution_id AND cr.is_voided=false WHERE aa.case_id=p_case_id;
  IF COALESCE(v_unapproved_resolution_count,0)>0 THEN IF COALESCE(v_filed_for_filing_count,0)>0 THEN RETURN QUERY SELECT 'PENDING'::text,'FILED_OTHER_RESO_FOR_APPROVAL'::text; ELSE RETURN QUERY SELECT 'PENDING'::text,'RESO_FOR_APPROVAL'::text; END IF; RETURN; ELSIF COALESCE(v_unfiled_for_filing_count,0)>0 THEN IF COALESCE(v_filed_for_filing_count,0)>0 THEN RETURN QUERY SELECT 'PENDING'::text,'FILED_OTHER_INFO_FOR_FILING'::text; ELSE RETURN QUERY SELECT 'PENDING'::text,'FOR_FILING'::text; END IF; RETURN; END IF;

  IF COALESCE(v_active_petition_count,0) > 0 AND v_petition_status_code IS NULL THEN RETURN QUERY SELECT 'PENDING'::text, 'PENDING_PETREV'::text; RETURN; END IF;

  SELECT explicit_state.status_code, explicit_state.stage_code INTO v_explicit_status_code, v_explicit_stage_code
  FROM (
    SELECT cs.code AS status_code, cst.code AS stage_code, ce.event_date, ce.event_time, ce.id AS case_event_id, msu.id AS source_id
    FROM public.case_manual_status_updates msu
    JOIN public.case_events ce ON ce.id=msu.case_event_id AND ce.is_voided=false
    JOIN public.case_event_types cet ON cet.id=ce.event_type_id AND cet.code='CASE_STATUS_UPDATED'
    JOIN public.case_statuses cs ON cs.id=msu.selected_case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id=msu.selected_case_stage_id AND cst.is_active IS TRUE
    WHERE msu.case_id=p_case_id AND msu.is_voided=false AND (COALESCE(v_active_petition_count,0)=0 OR v_petition_status_code IS NOT NULL)
    UNION ALL
    SELECT cs.code, cst.code, ce.event_date, ce.event_time, ce.id, a.id
    FROM public.case_motion_resolution_approvals a
    JOIN public.case_events ce ON ce.id=a.case_event_id AND ce.is_voided=false
    JOIN public.case_statuses cs ON cs.id=a.selected_case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id=a.selected_case_stage_id AND cst.is_active IS TRUE
    JOIN public.case_motion_resolutions r ON r.id=a.case_motion_resolution_id AND r.is_voided=false
    JOIN public.case_motions m ON m.id=a.case_motion_id AND m.is_voided=false
    WHERE a.case_id=p_case_id AND a.is_voided=false AND a.updates_case_status=true
    UNION ALL
    SELECT cs.code, cst.code, u.status_date, NULL::time without time zone, pe.id, u.id
    FROM public.case_petition_for_review_updates u
    JOIN public.case_petitions_for_review p ON p.id=u.petition_for_review_id AND p.is_voided=false
    JOIN public.case_events pe ON pe.id=p.case_event_id AND pe.is_voided=false
    JOIN public.case_statuses cs ON cs.id=u.selected_case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id=u.selected_case_stage_id AND cst.is_active IS TRUE
    WHERE u.case_id=p_case_id AND u.is_voided=false AND u.updates_case_status=true
    UNION ALL
    SELECT cs.code, cst.code, ce.event_date, ce.event_time, ce.id, ce.id
    FROM public.case_events ce
    JOIN public.case_event_types cet ON cet.id=ce.event_type_id AND cet.code='CUSTOM_EVENT'
    JOIN public.case_statuses cs ON cs.id=ce.case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id=ce.case_stage_id AND cst.is_active IS TRUE
    WHERE ce.case_id=p_case_id AND ce.is_voided=false AND COALESCE((ce.details_jsonb->>'updates_case_status')::boolean,false)=true
  ) explicit_state
  ORDER BY explicit_state.event_date DESC, explicit_state.event_time DESC NULLS LAST, explicit_state.case_event_id DESC, explicit_state.source_id DESC
  LIMIT 1;
  IF v_explicit_status_code IS NOT NULL THEN RETURN QUERY SELECT v_explicit_status_code, v_explicit_stage_code; RETURN; END IF;

  SELECT count(*) INTO v_active_assignment_count FROM public.case_assignments ca WHERE ca.case_id=p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE;
  IF COALESCE(v_filed_for_filing_count,0)>0 AND COALESCE(v_dismissal_count,0)>0 THEN RETURN QUERY SELECT 'MIXED_RESULT'::text,'MIXED_RESULT'::text; ELSIF COALESCE(v_filed_for_filing_count,0)>0 THEN RETURN QUERY SELECT 'FILED'::text,'FILED'::text; ELSIF COALESCE(v_dismissal_count,0)>0 THEN RETURN QUERY SELECT 'DISMISSED'::text,'DISMISSED'::text; ELSIF COALESCE(v_active_assignment_count,0)>0 THEN RETURN QUERY SELECT 'PENDING'::text,'CASE_RAFFLED'::text; ELSE RETURN QUERY SELECT 'PENDING'::text,'FOR_RAFFLE'::text; END IF;
END;
$$;



CREATE OR REPLACE FUNCTION public.record_custom_case_event(
  p_case_id bigint,
  p_title text,
  p_event_date date,
  p_event_time time without time zone,
  p_remarks text DEFAULT NULL,
  p_additional_details jsonb DEFAULT '[]'::jsonb,
  p_update_case_status boolean DEFAULT false,
  p_selected_case_status_id bigint DEFAULT NULL,
  p_selected_case_stage_id bigint DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_title text:=nullif(btrim(coalesce(p_title,'')), ''); v_remarks text:=nullif(btrim(coalesce(p_remarks,'')), '');
  v_details jsonb:='[]'::jsonb; v_row jsonb; v_status_code text; v_status_label text; v_stage_code text; v_stage_label text; v_prev_status_id bigint; v_prev_stage_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_old jsonb; v_new jsonb;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id=p_case_id) THEN RAISE EXCEPTION 'Case % not found', p_case_id; END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'Event Title is required'; END IF;
  IF p_event_date IS NULL THEN RAISE EXCEPTION 'Event Date is required'; END IF;
  IF p_event_time IS NULL THEN RAISE EXCEPTION 'Event Time is required'; END IF;
  IF jsonb_typeof(COALESCE(p_additional_details,'[]'::jsonb)) <> 'array' THEN RAISE EXCEPTION 'Additional Details input must be an array'; END IF;
  FOR v_row IN SELECT value FROM jsonb_array_elements(COALESCE(p_additional_details,'[]'::jsonb)) LOOP
    IF nullif(btrim(coalesce(v_row->>'detail','')), '') IS NOT NULL OR nullif(btrim(coalesce(v_row->>'value','')), '') IS NOT NULL THEN
      v_details := v_details || jsonb_build_array(jsonb_build_object('detail', btrim(coalesce(v_row->>'detail','')), 'value', btrim(coalesce(v_row->>'value',''))));
    END IF;
  END LOOP;
  IF p_update_case_status THEN
    SELECT code, display_label INTO v_status_code, v_status_label FROM public.case_statuses WHERE id=p_selected_case_status_id AND is_active IS TRUE;
    IF v_status_code IS NULL THEN RAISE EXCEPTION 'Selected Case Status must be active'; END IF;
    IF v_status_code NOT IN ('PENDING','FILED','DISMISSED','MIXED_RESULT') THEN RAISE EXCEPTION 'Selected Case Status must be PENDING, FILED, DISMISSED, or MIXED_RESULT'; END IF;
    SELECT code, display_label INTO v_stage_code, v_stage_label FROM public.case_stages WHERE id=p_selected_case_stage_id AND is_active IS TRUE;
    IF v_stage_code IS NULL THEN RAISE EXCEPTION 'Selected Case Stage must be active'; END IF;
  END IF;
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code='CUSTOM_EVENT' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing CUSTOM_EVENT event type'; END IF;
  INSERT INTO public.case_private_details(case_id, source) VALUES (p_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
  SELECT current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_stage_id, v_old FROM public.case_private_details cpd WHERE cpd.case_id=p_case_id;
  v_prev_status_id := COALESCE(v_prev_status_id, (SELECT current_status_id FROM public.case_private_details WHERE case_id=p_case_id));
  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_event_date,p_event_time,v_title,v_remarks,CASE WHEN p_update_case_status THEN p_selected_case_status_id ELSE NULL END,CASE WHEN p_update_case_status THEN p_selected_case_status_id ELSE NULL END,CASE WHEN p_update_case_status THEN p_selected_case_stage_id ELSE NULL END,jsonb_build_object('title',v_title,'event_date',p_event_date,'event_time',p_event_time,'remarks',v_remarks,'additional_details',v_details,'updates_case_status',p_update_case_status,'selected_case_status_id',CASE WHEN p_update_case_status THEN p_selected_case_status_id ELSE NULL END,'selected_case_status_code',v_status_code,'selected_case_status_label',v_status_label,'selected_case_stage_id',CASE WHEN p_update_case_status THEN p_selected_case_stage_id ELSE NULL END,'selected_case_stage_code',v_stage_code,'selected_case_stage_label',v_stage_label),'MANUAL_ENTRY','case_events',p_user_id,p_user_id)
  RETURNING id INTO v_event_id;
  UPDATE public.case_events SET source_id=v_event_id WHERE id=v_event_id;
  IF p_update_case_status THEN
    UPDATE public.case_private_details SET current_status_id=p_selected_case_status_id,current_status_date=p_event_date,current_status_remarks=COALESCE(v_remarks,v_title),current_case_status_id=p_selected_case_status_id,current_case_status_date=p_event_date,current_case_status_remarks=COALESCE(v_remarks,v_title),current_case_stage_id=p_selected_case_stage_id,current_case_stage_date=p_event_date,current_case_stage_remarks=COALESCE(v_remarks,v_title),updated_at=now() WHERE case_id=p_case_id;
    IF v_prev_status_id IS DISTINCT FROM p_selected_case_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES(p_case_id,v_prev_status_id,p_selected_case_status_id,p_user_id,now(),p_event_date,COALESCE(v_remarks,v_title),v_event_id) RETURNING id INTO v_status_history_id; END IF;
    IF v_prev_stage_id IS DISTINCT FROM p_selected_case_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES(p_case_id,v_prev_stage_id,p_selected_case_stage_id,p_user_id,now(),p_event_date,COALESCE(v_remarks,v_title),v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  END IF;
  UPDATE public.cases SET updated_by_user_id=p_user_id, updated_at=now() WHERE id=p_case_id;
  SELECT jsonb_build_object('case_event', to_jsonb(ce), 'case_private_details', to_jsonb(cpd)) INTO v_new FROM public.case_events ce LEFT JOIN public.case_private_details cpd ON cpd.case_id=ce.case_id WHERE ce.id=v_event_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES(p_user_id,'case_events',v_event_id,'RECORD_CUSTOM_CASE_EVENT',v_old,v_new,p_case_id,'Custom Event recorded.',jsonb_build_object('updates_case_status',p_update_case_status,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));
  RETURN v_event_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.record_custom_case_event(bigint,text,date,time without time zone,text,jsonb,boolean,bigint,bigint,bigint) TO authenticated;
COMMENT ON FUNCTION public.record_custom_case_event(bigint,text,date,time without time zone,text,jsonb,boolean,bigint,bigint,bigint) IS 'Records a Custom Event in case_events only, optionally applying selected active broad Case Status and Case Stage.';
GRANT EXECUTE ON FUNCTION public.compute_current_case_state(bigint) TO authenticated;
COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Manual Case Status Updated, Motion Decision Approved, Petition Update, and Custom Event explicit statuses share deterministic explicit-state recompute; active Custom Events with updates_case_status=true participate in void recomputation.';
