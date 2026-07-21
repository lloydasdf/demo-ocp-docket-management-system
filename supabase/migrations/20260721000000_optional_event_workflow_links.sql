-- Allow timeline events to be recorded before their optional workflow records exist.
-- Linked calls continue to use the previous implementation unchanged.

ALTER FUNCTION public.record_case_decision_approved_event(bigint,bigint,bigint,date,time without time zone,jsonb,text,bigint) RENAME TO record_case_decision_approved_event_linked;
ALTER FUNCTION public.record_court_filing_event(bigint,bigint,bigint,text,text,text,date,time without time zone,integer,text,text,bigint) RENAME TO record_court_filing_event_linked;
ALTER FUNCTION public.record_motion_resolved_event(bigint,bigint,bigint,date,time without time zone,text,bigint) RENAME TO record_motion_resolved_event_linked;
ALTER FUNCTION public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint) RENAME TO record_motion_decision_approved_event_linked;
ALTER FUNCTION public.update_court_filing_status_details(bigint,bigint,jsonb,jsonb,integer,jsonb,text,bigint) RENAME TO update_court_filing_status_details_linked;
ALTER FUNCTION public.record_petition_for_review_update(bigint,bigint,text,date,text,jsonb,boolean,bigint,bigint,bigint) RENAME TO record_petition_for_review_update_linked;

CREATE OR REPLACE FUNCTION public.record_optional_workflow_event(
  p_case_id bigint, p_event_type_code text, p_title text, p_event_date date,
  p_event_time time without time zone, p_remarks text, p_details jsonb, p_user_id bigint
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_event_type_id bigint; v_event_id bigint;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF p_event_date IS NULL THEN RAISE EXCEPTION 'Event date is required'; END IF;
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = p_event_type_code AND is_active = true;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing active event type %', p_event_type_code; END IF;
  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,details_jsonb,source,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_event_date,coalesce(p_event_time,(now() AT TIME ZONE 'Asia/Manila')::time(0)),p_title,nullif(btrim(coalesce(p_remarks,'')),''),coalesce(p_details,'{}'::jsonb),'MANUAL_ENTRY',p_user_id,p_user_id)
  RETURNING id INTO v_event_id;
  RETURN v_event_id;
END; $$;

CREATE OR REPLACE FUNCTION public.record_case_decision_approved_event(p_case_id bigint,p_case_resolution_id bigint DEFAULT NULL,p_approved_by_prosecutor_id bigint DEFAULT NULL,p_date_approved date DEFAULT NULL,p_time_approved time without time zone DEFAULT NULL,p_approval_actions jsonb DEFAULT '[]'::jsonb,p_remarks text DEFAULT NULL,p_user_id bigint DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF p_case_resolution_id IS NOT NULL THEN RETURN public.record_case_decision_approved_event_linked(p_case_id,p_case_resolution_id,p_approved_by_prosecutor_id,p_date_approved,p_time_approved,p_approval_actions,p_remarks,p_user_id); END IF;
  IF p_approved_by_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Approved by prosecutor is required'; END IF;
  RETURN public.record_optional_workflow_event(p_case_id,'CASE_DECISION_APPROVED','Case Decision Approved',p_date_approved,p_time_approved,p_remarks,jsonb_build_object('case_resolution_id',NULL,'approved_by_prosecutor_id',p_approved_by_prosecutor_id,'approval_actions',coalesce(p_approval_actions,'[]'::jsonb)),p_user_id);
END; $$;

CREATE OR REPLACE FUNCTION public.record_court_filing_event(p_case_id bigint,p_case_resolution_approval_action_id bigint,p_court_id bigint DEFAULT NULL,p_court_name text DEFAULT NULL,p_court_branch text DEFAULT NULL,p_charge_filed text DEFAULT NULL,p_date_filed date DEFAULT NULL,p_time_filed time without time zone DEFAULT NULL,p_information_count integer DEFAULT NULL,p_criminal_case_no text DEFAULT NULL,p_remarks text DEFAULT NULL,p_user_id bigint DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF p_case_resolution_approval_action_id IS NOT NULL THEN RETURN public.record_court_filing_event_linked(p_case_id,p_case_resolution_approval_action_id,p_court_id,p_court_name,p_court_branch,p_charge_filed,p_date_filed,p_time_filed,p_information_count,p_criminal_case_no,p_remarks,p_user_id); END IF;
  IF nullif(btrim(coalesce(p_court_name,'')),'') IS NULL OR nullif(btrim(coalesce(p_charge_filed,'')),'') IS NULL THEN RAISE EXCEPTION 'Court and charge filed are required'; END IF;
  RETURN public.record_optional_workflow_event(p_case_id,'COURT_FILING','Court Filing',p_date_filed,p_time_filed,p_remarks,jsonb_build_object('case_resolution_approval_action_id',NULL,'court_id',p_court_id,'court',btrim(p_court_name),'court_branch',nullif(btrim(coalesce(p_court_branch,'')),''),'charge_filed',btrim(p_charge_filed),'information_count',p_information_count,'criminal_case_no',nullif(btrim(coalesce(p_criminal_case_no,'')),'')),p_user_id);
END; $$;
CREATE OR REPLACE FUNCTION public.record_motion_resolved_event(p_case_id bigint,p_case_motion_id bigint,p_recommendation_id bigint,p_date_resolved date,p_time_resolved time without time zone DEFAULT NULL,p_remarks text DEFAULT NULL,p_user_id bigint DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_recommendation_label text;
BEGIN
  IF p_case_motion_id IS NOT NULL THEN RETURN public.record_motion_resolved_event_linked(p_case_id,p_case_motion_id,p_recommendation_id,p_date_resolved,p_time_resolved,p_remarks,p_user_id); END IF;
  SELECT display_label INTO v_recommendation_label FROM public.motion_resolution_recommendations WHERE id=p_recommendation_id AND is_active=true;
  IF v_recommendation_label IS NULL THEN RAISE EXCEPTION 'Recommendation must be active'; END IF;
  RETURN public.record_optional_workflow_event(p_case_id,'MOTION_RESOLVED','Motion Resolved',p_date_resolved,p_time_resolved,p_remarks,jsonb_build_object('motion_id',NULL,'recommendation_id',p_recommendation_id,'recommendation_label',v_recommendation_label),p_user_id);
END; $$;

CREATE OR REPLACE FUNCTION public.record_motion_decision_approved_event(p_case_id bigint,p_case_motion_resolution_id bigint,p_approved_decision_recommendation_id bigint,p_approved_by_prosecutor_id bigint,p_date_approved date,p_time_approved time without time zone DEFAULT NULL,p_update_case_status boolean DEFAULT false,p_selected_case_status_id bigint DEFAULT NULL,p_selected_case_stage_id bigint DEFAULT NULL,p_remarks text DEFAULT NULL,p_user_id bigint DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_decision_label text;
BEGIN
  IF p_case_motion_resolution_id IS NOT NULL THEN RETURN public.record_motion_decision_approved_event_linked(p_case_id,p_case_motion_resolution_id,p_approved_decision_recommendation_id,p_approved_by_prosecutor_id,p_date_approved,p_time_approved,p_update_case_status,p_selected_case_status_id,p_selected_case_stage_id,p_remarks,p_user_id); END IF;
  SELECT display_label INTO v_decision_label FROM public.motion_resolution_recommendations WHERE id=p_approved_decision_recommendation_id AND is_active=true;
  IF v_decision_label IS NULL THEN RAISE EXCEPTION 'Approved decision recommendation must be active'; END IF;
  IF p_approved_by_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Approved by prosecutor is required'; END IF;
  RETURN public.record_optional_workflow_event(p_case_id,'MOTION_DECISION_APPROVED','Motion Decision Approved',p_date_approved,p_time_approved,p_remarks,jsonb_build_object('motion_resolution_id',NULL,'approved_decision_recommendation_id',p_approved_decision_recommendation_id,'approved_decision_label',v_decision_label,'approved_by_prosecutor_id',p_approved_by_prosecutor_id,'updates_case_status',coalesce(p_update_case_status,false),'selected_case_status_id',CASE WHEN coalesce(p_update_case_status,false) THEN p_selected_case_status_id ELSE NULL END,'selected_case_stage_id',CASE WHEN coalesce(p_update_case_status,false) THEN p_selected_case_stage_id ELSE NULL END),p_user_id);
END; $$;

CREATE OR REPLACE FUNCTION public.update_court_filing_status_details(p_case_id bigint,p_court_filing_id bigint DEFAULT NULL,p_criminal_case_numbers jsonb DEFAULT '[]'::jsonb,p_court_statuses jsonb DEFAULT '[]'::jsonb,p_information_count integer DEFAULT NULL,p_additional_details_jsonb jsonb DEFAULT '[]'::jsonb,p_remarks text DEFAULT NULL,p_user_id bigint DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF p_court_filing_id IS NOT NULL THEN RETURN public.update_court_filing_status_details_linked(p_case_id,p_court_filing_id,p_criminal_case_numbers,p_court_statuses,p_information_count,p_additional_details_jsonb,p_remarks,p_user_id); END IF;
  RETURN public.record_optional_workflow_event(p_case_id,'COURT_STATUS_UPDATE','Court Status Update',CURRENT_DATE,NULL,p_remarks,jsonb_build_object('court_filing_id',NULL,'criminal_case_numbers',coalesce(p_criminal_case_numbers,'[]'::jsonb),'court_statuses',coalesce(p_court_statuses,'[]'::jsonb),'information_count',p_information_count,'additional_details',coalesce(p_additional_details_jsonb,'[]'::jsonb)),p_user_id);
END; $$;

CREATE OR REPLACE FUNCTION public.record_petition_for_review_update(p_case_id bigint,p_petition_for_review_id bigint,p_petition_status text,p_status_date date,p_remarks text DEFAULT NULL,p_additional_details_jsonb jsonb DEFAULT '[]'::jsonb,p_updates_case_status boolean DEFAULT false,p_selected_case_status_id bigint DEFAULT NULL,p_selected_case_stage_id bigint DEFAULT NULL,p_user_id bigint DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF p_petition_for_review_id IS NOT NULL THEN RETURN public.record_petition_for_review_update_linked(p_case_id,p_petition_for_review_id,p_petition_status,p_status_date,p_remarks,p_additional_details_jsonb,p_updates_case_status,p_selected_case_status_id,p_selected_case_stage_id,p_user_id); END IF;
  IF nullif(btrim(coalesce(p_petition_status,'')),'') IS NULL THEN RAISE EXCEPTION 'Petition Status is required'; END IF;
  RETURN public.record_optional_workflow_event(p_case_id,'PETITION_FOR_REVIEW_UPDATE','Petition for Review Update',p_status_date,NULL,p_remarks,jsonb_build_object('petition_for_review_id',NULL,'petition_status',btrim(p_petition_status),'additional_details',coalesce(p_additional_details_jsonb,'[]'::jsonb),'updates_case_status',coalesce(p_updates_case_status,false),'selected_case_status_id',CASE WHEN coalesce(p_updates_case_status,false) THEN p_selected_case_status_id ELSE NULL END,'selected_case_stage_id',CASE WHEN coalesce(p_updates_case_status,false) THEN p_selected_case_stage_id ELSE NULL END),p_user_id);
END; $$;

GRANT EXECUTE ON FUNCTION public.record_optional_workflow_event(bigint,text,text,date,time without time zone,text,jsonb,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_case_decision_approved_event(bigint,bigint,bigint,date,time without time zone,jsonb,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_court_filing_event(bigint,bigint,bigint,text,text,text,date,time without time zone,integer,text,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_motion_resolved_event(bigint,bigint,bigint,date,time without time zone,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_motion_decision_approved_event(bigint,bigint,bigint,bigint,date,time without time zone,boolean,bigint,bigint,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_court_filing_status_details(bigint,bigint,jsonb,jsonb,integer,jsonb,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_petition_for_review_update(bigint,bigint,text,date,text,jsonb,boolean,bigint,bigint,bigint) TO authenticated;
