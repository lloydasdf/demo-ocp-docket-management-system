BEGIN;

-- Keep the timeline, history, audit, permission, and RLS behavior of the
-- manual status update workflow unchanged while allowing an omitted reason.
CREATE OR REPLACE FUNCTION public.record_case_status_updated_event(p_case_id bigint,p_case_status_id bigint,p_case_stage_id bigint,p_status_date date,p_remarks text DEFAULT NULL,p_reason text DEFAULT NULL,p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_update_id bigint; v_status_code text; v_status_label text; v_stage_code text; v_stage_label text; v_prev_status_id bigint; v_prev_stage_id bigint; v_prev_status_label text; v_prev_stage_label text; v_status_history_id bigint; v_stage_history_id bigint; v_old jsonb; v_new jsonb; v_remarks text:=nullif(btrim(coalesce(p_remarks,'')), ''); v_reason text:=nullif(btrim(coalesce(p_reason,'')), ''); v_time time;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id=p_case_id) THEN RAISE EXCEPTION 'Case % not found', p_case_id; END IF;
  IF p_status_date IS NULL THEN RAISE EXCEPTION 'Status Date is required'; END IF;
  SELECT code, display_label INTO v_status_code, v_status_label FROM public.case_statuses WHERE id=p_case_status_id AND is_active IS TRUE;
  IF v_status_code IS NULL THEN RAISE EXCEPTION 'Selected Case Status must be active'; END IF;
  IF v_status_code NOT IN ('PENDING','FILED','DISMISSED','MIXED_RESULT') THEN RAISE EXCEPTION 'Selected Case Status must be PENDING, FILED, DISMISSED, or MIXED_RESULT'; END IF;
  SELECT code, display_label INTO v_stage_code, v_stage_label FROM public.case_stages WHERE id=p_case_stage_id AND is_active IS TRUE;
  IF v_stage_code IS NULL THEN RAISE EXCEPTION 'Selected Case Stage must be active'; END IF;
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code='CASE_STATUS_UPDATED' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing CASE_STATUS_UPDATED event type'; END IF;
  INSERT INTO public.case_private_details(case_id, source) VALUES (p_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
  SELECT current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_stage_id, v_old FROM public.case_private_details cpd WHERE cpd.case_id=p_case_id;
  v_prev_status_id := COALESCE(v_prev_status_id, (SELECT current_status_id FROM public.case_private_details WHERE case_id=p_case_id));
  SELECT display_label INTO v_prev_status_label FROM public.case_statuses WHERE id=v_prev_status_id;
  SELECT display_label INTO v_prev_stage_label FROM public.case_stages WHERE id=v_prev_stage_id;
  v_time := (now() AT TIME ZONE 'Asia/Manila')::time(0);
  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_status_date,v_time,'Case Status Updated',COALESCE(v_remarks,v_reason),p_case_status_id,p_case_status_id,p_case_stage_id,jsonb_build_object('selected_case_status_id',p_case_status_id,'selected_case_status_code',v_status_code,'selected_case_status_label',v_status_label,'selected_case_stage_id',p_case_stage_id,'selected_case_stage_code',v_stage_code,'selected_case_stage_label',v_stage_label,'status_date',p_status_date,'remarks',v_remarks,'reason',v_reason,'previous_case_status_id',v_prev_status_id,'previous_case_status_label',v_prev_status_label,'previous_case_stage_id',v_prev_stage_id,'previous_case_stage_label',v_prev_stage_label),'MANUAL_ENTRY','case_manual_status_updates',p_user_id,p_user_id)
  RETURNING id INTO v_event_id;
  INSERT INTO public.case_manual_status_updates(case_id,case_event_id,selected_case_status_id,selected_case_stage_id,status_date,remarks,reason,created_by_user_id)
  VALUES (p_case_id,v_event_id,p_case_status_id,p_case_stage_id,p_status_date,v_remarks,v_reason,p_user_id)
  RETURNING id INTO v_update_id;
  UPDATE public.case_events SET source_id=v_update_id WHERE id=v_event_id;
  UPDATE public.case_private_details SET current_status_id=p_case_status_id,current_status_date=p_status_date,current_status_remarks=COALESCE(v_remarks,v_reason),current_case_status_id=p_case_status_id,current_case_status_date=p_status_date,current_case_status_remarks=COALESCE(v_remarks,v_reason),current_case_stage_id=p_case_stage_id,current_case_stage_date=p_status_date,current_case_stage_remarks=COALESCE(v_remarks,v_reason),updated_at=now() WHERE case_id=p_case_id;
  UPDATE public.cases SET updated_by_user_id=p_user_id, updated_at=now() WHERE id=p_case_id;
  IF v_prev_status_id IS DISTINCT FROM p_case_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES(p_case_id,v_prev_status_id,p_case_status_id,p_user_id,now(),p_status_date,COALESCE(v_remarks,v_reason),v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM p_case_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES(p_case_id,v_prev_stage_id,p_case_stage_id,p_user_id,now(),p_status_date,COALESCE(v_remarks,v_reason),v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new FROM public.case_private_details cpd WHERE cpd.case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES(p_user_id,'case_manual_status_updates',v_update_id,'CASE_STATUS_UPDATED',v_old,v_new,p_case_id,'Case Status Updated recorded.',jsonb_build_object('case_event_id',v_event_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id,'selected_case_status_code',v_status_code,'selected_case_stage_code',v_stage_code));
  RETURN v_event_id;
END; $$;

GRANT EXECUTE ON FUNCTION public.record_case_status_updated_event(bigint,bigint,bigint,date,text,text,bigint) TO authenticated;

COMMIT;
