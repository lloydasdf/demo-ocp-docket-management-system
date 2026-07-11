BEGIN;

CREATE OR REPLACE FUNCTION public.edit_case_event_specific(
  p_case_event_id bigint,
  p_expected_event_type_code text,
  p_values jsonb DEFAULT '{}'::jsonb,
  p_edit_reason text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event public.case_events%ROWTYPE;
  v_code text;
  v_old_event jsonb;
  v_new_event jsonb;
  v_old_source jsonb;
  v_new_source jsonb;
  v_source_table text;
  v_source_id bigint;
  v_date date;
  v_time time without time zone;
  v_remarks text;
  v_details jsonb;
  v_title text;
  v_prosecutor bigint;
  v_staff bigint;
  v_latest_assignment_id bigint;
  v_assigned_name text;
  v_recompute boolean := false;
BEGIN
  IF nullif(btrim(coalesce(p_edit_reason,'')), '') IS NULL THEN
    RAISE EXCEPTION 'Reason for Edit is required';
  END IF;

  SELECT ce.* INTO v_event
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id AND ce.is_voided = false
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active timeline event % not found', p_case_event_id; END IF;

  SELECT cet.code INTO v_code
  FROM public.case_event_types cet
  WHERE cet.id = v_event.event_type_id;
  IF v_code IS DISTINCT FROM p_expected_event_type_code THEN RAISE EXCEPTION 'This activity is %, not %', v_code, p_expected_event_type_code; END IF;

  v_source_table := v_event.source_table;
  v_source_id := v_event.source_id;
  v_date := coalesce(nullif(p_values->>'event_date','')::date, v_event.event_date);
  v_time := nullif(p_values->>'event_time','')::time;
  v_remarks := nullif(btrim(coalesce(p_values->>'remarks', p_values->>'description', '')), '');
  v_details := coalesce(v_event.details_jsonb, '{}'::jsonb);
  v_old_event := to_jsonb(v_event);

  IF v_code IN ('COURT_STATUS_UPDATE','PETITION_FOR_REVIEW_UPDATE') THEN
    RAISE EXCEPTION '% is updated through its own update-history workflow and cannot be edited from the timeline', v_code;
  END IF;

  IF v_code IN ('CASE_ASSIGNMENT','CASE_REASSIGNMENT') THEN
    IF v_source_table IS DISTINCT FROM 'case_assignments' OR v_source_id IS NULL THEN RAISE EXCEPTION 'Assignment source record cannot be resolved'; END IF;
    SELECT to_jsonb(ca) INTO v_old_source FROM public.case_assignments ca WHERE ca.id=v_source_id AND ca.case_event_id=p_case_event_id AND ca.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active assignment source record cannot be resolved'; END IF;
    SELECT id INTO v_latest_assignment_id FROM public.case_assignments WHERE case_id=v_event.case_id AND is_voided=false AND unassigned_at IS NULL ORDER BY assigned_at DESC NULLS LAST, id DESC LIMIT 1;
    UPDATE public.case_assignments SET assigned_at=(v_date + coalesce(v_time, assigned_at::time, '00:00'::time)) AT TIME ZONE 'Asia/Manila', remarks=v_remarks WHERE id=v_source_id;
    SELECT to_jsonb(ca) INTO v_new_source FROM public.case_assignments ca WHERE ca.id=v_source_id;
    v_details := v_details || jsonb_build_object('remarks',v_remarks);
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details,updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;


  ELSIF v_code = 'CASE_RECEIVED' THEN
    IF v_source_table IS DISTINCT FROM 'case_status_history' OR v_source_id IS NULL THEN RAISE EXCEPTION 'Case Received source record cannot be resolved'; END IF;
    SELECT to_jsonb(csh) INTO v_old_source FROM public.case_status_history csh WHERE csh.id=v_source_id AND csh.case_event_id=p_case_event_id FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active Case Received status history source record cannot be resolved'; END IF;
    UPDATE public.case_status_history SET status_date=v_date, remarks=v_remarks WHERE id=v_source_id;
    UPDATE public.cases SET date_received=v_date, updated_by_user_id=p_user_id, updated_at=now() WHERE id=v_event.case_id;
    SELECT to_jsonb(csh) INTO v_new_source FROM public.case_status_history csh WHERE csh.id=v_source_id;
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details || jsonb_build_object('date_received',v_date,'time_received',v_time,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'MOTION_RECEIVED' THEN
    IF v_source_table IS DISTINCT FROM 'case_motions' OR v_source_id IS NULL THEN RAISE EXCEPTION 'Motion source record cannot be resolved'; END IF;
    SELECT to_jsonb(cm) INTO v_old_source FROM public.case_motions cm WHERE cm.id=v_source_id AND cm.case_event_id=p_case_event_id AND cm.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active motion source record cannot be resolved'; END IF;
    IF upper(coalesce(p_values->>'filed_by_code','')) NOT IN ('COMPLAINANT','RESPONDENT') THEN RAISE EXCEPTION 'Filed By must be COMPLAINANT or RESPONDENT'; END IF;
    v_title := nullif(btrim(coalesce(p_values->>'motion_title','')), ''); IF v_title IS NULL THEN RAISE EXCEPTION 'Motion Title is required'; END IF;
    v_prosecutor := nullif(p_values->>'assigned_prosecutor_id','')::bigint;
    IF v_prosecutor IS NOT NULL THEN
      SELECT coalesce(short_name, full_name) INTO v_assigned_name FROM public.prosecutors WHERE id=v_prosecutor AND coalesce(is_active,true) IS TRUE;
      IF v_assigned_name IS NULL THEN RAISE EXCEPTION 'Assigned Prosecutor must be active'; END IF;
    END IF;
    UPDATE public.case_motions SET motion_name=v_title,motion_title=v_title,filed_by=CASE upper(p_values->>'filed_by_code') WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,filed_by_code=upper(p_values->>'filed_by_code'),assigned_prosecutor_id=v_prosecutor,date_received=v_date,date_filed=v_date,time_filed=v_time,details_jsonb=coalesce(p_values->'details','[]'::jsonb),remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(cm) INTO v_new_source FROM public.case_motions cm WHERE cm.id=v_source_id;
    v_details := v_details || jsonb_build_object('motion_title',v_title,'filed_by_code',upper(p_values->>'filed_by_code'),'filed_by_label',CASE upper(p_values->>'filed_by_code') WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,'assigned_prosecutor_id',v_prosecutor,'assigned_prosecutor_name',v_assigned_name,'date_filed',v_date,'time_filed',v_time,'details',coalesce(p_values->'details','[]'::jsonb),'remarks',v_remarks);
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,title='Motion Received',description=v_remarks,prosecutor_id=v_prosecutor,details_jsonb=v_details,updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'COURT_FILING' THEN
    SELECT to_jsonb(cf) INTO v_old_source FROM public.case_court_filings cf WHERE cf.id=v_source_id AND cf.case_event_id=p_case_event_id AND cf.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active court filing source record cannot be resolved'; END IF;
    UPDATE public.case_court_filings SET court_name=coalesce(nullif(p_values->>'court_name',''),court_name), court_branch=nullif(p_values->>'court_branch',''), date_filed=v_date, time_filed=v_time, information_count=nullif(p_values->>'information_count','')::integer, remarks=v_remarks, updated_by_user_id=p_user_id, updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(cf) INTO v_new_source FROM public.case_court_filings cf WHERE cf.id=v_source_id;
    v_details := v_details || jsonb_build_object('court_name',p_values->>'court_name','court_branch',p_values->>'court_branch','date_filed',v_date,'time_filed',v_time,'information_count',nullif(p_values->>'information_count','')::integer,'remarks',v_remarks);
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details,updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'PETITION_FOR_REVIEW' THEN
    SELECT to_jsonb(p) INTO v_old_source FROM public.case_petitions_for_review p WHERE p.id=v_source_id AND p.case_event_id=p_case_event_id FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active petition source record cannot be resolved'; END IF;
    IF upper(coalesce(p_values->>'filed_by_code','')) NOT IN ('COMPLAINANT','RESPONDENT') THEN RAISE EXCEPTION 'Filed By must be COMPLAINANT or RESPONDENT'; END IF;
    v_prosecutor := nullif(p_values->>'assigned_prosecutor_id','')::bigint;
    IF v_prosecutor IS NOT NULL THEN
      SELECT coalesce(short_name, full_name) INTO v_assigned_name FROM public.prosecutors WHERE id=v_prosecutor AND coalesce(is_active,true) IS TRUE;
      IF v_assigned_name IS NULL THEN RAISE EXCEPTION 'Assigned Prosecutor must be active'; END IF;
    END IF;
    UPDATE public.case_petitions_for_review SET filed_by=CASE upper(p_values->>'filed_by_code') WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,filed_by_code=upper(p_values->>'filed_by_code'),date_received=v_date,date_filed=v_date,time_filed=v_time,petition_status=nullif(p_values->>'petition_status',''),status_date=v_date,additional_details_jsonb=coalesce(p_values->'details','[]'::jsonb),assigned_prosecutor_id=v_prosecutor,handling_prosecutor_text=v_assigned_name,remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(p) INTO v_new_source FROM public.case_petitions_for_review p WHERE p.id=v_source_id;
    v_details := v_details || jsonb_build_object('filed_by_code',upper(p_values->>'filed_by_code'),'filed_by_label',CASE upper(p_values->>'filed_by_code') WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,'date_filed',v_date,'time_filed',v_time,'petition_status',p_values->>'petition_status','status_date',v_date,'additional_details',coalesce(p_values->'details','[]'::jsonb),'assigned_prosecutor_id',v_prosecutor,'assigned_prosecutor_name',v_assigned_name,'remarks',v_remarks);
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,prosecutor_id=v_prosecutor,details_jsonb=v_details,updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'CASE_RESOLVED' THEN
    SELECT to_jsonb(cr) INTO v_old_source FROM public.case_resolutions cr WHERE cr.id=v_source_id AND cr.case_event_id=p_case_event_id AND cr.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active case resolution source record cannot be resolved'; END IF;
    IF EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id=v_source_id AND a.is_voided=false) AND v_date IS DISTINCT FROM (v_old_source->>'date_resolved')::date THEN
      RAISE EXCEPTION 'This resolution has an active approval dependency; void dependent approval before changing resolution-defining dates';
    END IF;
    UPDATE public.case_resolutions SET date_resolved=v_date,time_resolved=v_time,remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(cr) INTO v_new_source FROM public.case_resolutions cr WHERE cr.id=v_source_id;
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details || jsonb_build_object('date_resolved',v_date,'time_resolved',v_time,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'CASE_DECISION_APPROVED' THEN
    SELECT to_jsonb(a) INTO v_old_source FROM public.case_resolution_approvals a WHERE a.id=v_source_id AND a.case_event_id=p_case_event_id AND a.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active case decision approval source record cannot be resolved'; END IF;
    UPDATE public.case_resolution_approvals SET approved_by_prosecutor_id=coalesce(nullif(p_values->>'approved_by_prosecutor_id','')::bigint,approved_by_prosecutor_id),date_approved=v_date,time_approved=v_time,remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(a) INTO v_new_source FROM public.case_resolution_approvals a WHERE a.id=v_source_id;
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details || jsonb_build_object('approved_by_prosecutor_id',nullif(p_values->>'approved_by_prosecutor_id','')::bigint,'date_approved',v_date,'time_approved',v_time,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'MOTION_RESOLVED' THEN
    SELECT to_jsonb(cmr) INTO v_old_source FROM public.case_motion_resolutions cmr WHERE cmr.id=v_source_id AND cmr.case_event_id=p_case_event_id AND cmr.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active motion resolution source record cannot be resolved'; END IF;
    IF EXISTS (SELECT 1 FROM public.case_motion_resolution_approvals a WHERE a.case_motion_resolution_id=v_source_id AND a.is_voided=false)
       AND (v_date IS DISTINCT FROM (v_old_source->>'date_resolved')::date OR v_time IS DISTINCT FROM nullif(v_old_source->>'time_resolved','')::time) THEN
      RAISE EXCEPTION 'This Motion Resolution has an active Motion Decision Approval. Only remarks can be corrected until the approval is voided.';
    END IF;
    UPDATE public.case_motion_resolutions SET date_resolved=v_date,time_resolved=v_time,remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(cmr) INTO v_new_source FROM public.case_motion_resolutions cmr WHERE cmr.id=v_source_id;
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details || jsonb_build_object('date_resolved',v_date,'time_resolved',v_time,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'MOTION_DECISION_APPROVED' THEN
    SELECT to_jsonb(a) INTO v_old_source FROM public.case_motion_resolution_approvals a WHERE a.id=v_source_id AND a.case_event_id=p_case_event_id AND a.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active motion approval source record cannot be resolved'; END IF;
    v_recompute := coalesce((v_old_source->>'updates_case_status')::boolean,false) AND (v_date IS DISTINCT FROM (v_old_source->>'date_approved')::date OR v_time IS DISTINCT FROM nullif(v_old_source->>'time_approved','')::time);
    UPDATE public.case_motion_resolution_approvals SET approved_by_prosecutor_id=coalesce(nullif(p_values->>'approved_by_prosecutor_id','')::bigint,approved_by_prosecutor_id),date_approved=v_date,time_approved=v_time,remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=v_source_id;
    SELECT to_jsonb(a) INTO v_new_source FROM public.case_motion_resolution_approvals a WHERE a.id=v_source_id;
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details || jsonb_build_object('approved_by_prosecutor_id',nullif(p_values->>'approved_by_prosecutor_id','')::bigint,'date_approved',v_date,'time_approved',v_time,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'CASE_STATUS_UPDATED' THEN
    IF v_source_table IS DISTINCT FROM 'case_manual_status_updates' OR v_source_id IS NULL THEN RAISE EXCEPTION 'Manual status update source record cannot be resolved'; END IF;
    SELECT to_jsonb(msu) INTO v_old_source FROM public.case_manual_status_updates msu WHERE msu.id=v_source_id AND msu.case_event_id=p_case_event_id AND msu.is_voided=false FOR UPDATE;
    IF v_old_source IS NULL THEN RAISE EXCEPTION 'Active manual status update source record cannot be resolved'; END IF;
    v_recompute := v_date IS DISTINCT FROM (v_old_source->>'status_date')::date OR v_time IS DISTINCT FROM v_event.event_time;
    UPDATE public.case_manual_status_updates SET status_date=v_date, remarks=v_remarks, updated_at=now() WHERE id=v_source_id;
    UPDATE public.case_status_history SET status_date=v_date, remarks=v_remarks WHERE case_event_id=p_case_event_id;
    UPDATE public.case_stage_history SET stage_date=v_date, remarks=v_remarks WHERE case_event_id=p_case_event_id;
    SELECT to_jsonb(msu) INTO v_new_source FROM public.case_manual_status_updates msu WHERE msu.id=v_source_id;
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,details_jsonb=v_details || jsonb_build_object('status_date',v_date,'event_time',v_time,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;

  ELSIF v_code = 'CUSTOM_EVENT' THEN
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,title=coalesce(nullif(p_values->>'title',''),title),description=v_remarks,details_jsonb=v_details || jsonb_build_object('custom_details',coalesce(p_values->'details','[]'::jsonb),'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;
    v_old_source := NULL; v_new_source := NULL;
  ELSE
    UPDATE public.case_events SET event_date=v_date,event_time=v_time,description=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;
  END IF;

  IF v_recompute THEN
    PERFORM public.apply_case_state_recompute(v_event.case_id, v_date, v_remarks, p_case_event_id, p_user_id);
  END IF;

  SELECT to_jsonb(ce) INTO v_new_event FROM public.case_events ce WHERE ce.id=p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
  VALUES (p_user_id,'case_events',p_case_event_id,'EDIT_CASE_EVENT_SPECIFIC',jsonb_build_object('event',v_old_event,'source',v_old_source),jsonb_build_object('event',v_new_event,'source',v_new_source),v_event.case_id,'Edited timeline activity with event-specific validation.',jsonb_build_object('reason',p_edit_reason,'event_type_code',v_code,'source_table',v_source_table,'source_id',v_source_id,'status_stage_recomputed',v_recompute));
  RETURN p_case_event_id;
END;
$$;


GRANT EXECUTE ON FUNCTION public.edit_case_event_specific(bigint,text,jsonb,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.edit_case_event_specific(bigint,text,jsonb,text,bigint) TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
