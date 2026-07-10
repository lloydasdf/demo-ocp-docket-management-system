BEGIN;

INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
VALUES ('MOTION_RESOLVED', 'Motion Resolved', 'MOTION', 'Manual timeline event for resolving a motion.', 155, true, true)
ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label, category=EXCLUDED.category, description=EXCLUDED.description, sort_order=EXCLUDED.sort_order, is_active=true, updated_at=now();

INSERT INTO public.case_stages (code, display_label, sort_order, is_final_stage, is_milestone, is_active)
VALUES ('MOTION_RESO_FOR_APPROVAL', 'Motion Reso for Approval', 75, false, true, true)
ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label, sort_order=EXCLUDED.sort_order, is_final_stage=EXCLUDED.is_final_stage, is_milestone=EXCLUDED.is_milestone, is_active=true, updated_at=now();

ALTER TABLE public.case_motions
  ADD COLUMN IF NOT EXISTS assigned_prosecutor_id bigint REFERENCES public.prosecutors(id);

CREATE TABLE IF NOT EXISTS public.motion_resolution_recommendations (
  id bigserial PRIMARY KEY,
  code text NOT NULL,
  display_label text NOT NULL,
  sort_order integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT motion_resolution_recommendations_code_nonempty CHECK (btrim(code) <> ''),
  CONSTRAINT motion_resolution_recommendations_label_nonempty CHECK (btrim(display_label) <> '')
);
CREATE UNIQUE INDEX IF NOT EXISTS motion_resolution_recommendations_code_ci_uidx ON public.motion_resolution_recommendations (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS motion_resolution_recommendations_active_label_ci_uidx ON public.motion_resolution_recommendations (lower(display_label)) WHERE is_active;

INSERT INTO public.motion_resolution_recommendations(code, display_label, sort_order, is_active)
VALUES ('GRANTED','Granted',10,true), ('DENIED','Denied',20,true)
ON CONFLICT DO NOTHING;
UPDATE public.motion_resolution_recommendations SET display_label='Granted', sort_order=10, is_active=true, updated_at=now() WHERE lower(code)=lower('GRANTED');
UPDATE public.motion_resolution_recommendations SET display_label='Denied', sort_order=20, is_active=true, updated_at=now() WHERE lower(code)=lower('DENIED');

CREATE TABLE IF NOT EXISTS public.case_motion_resolutions (
  id bigserial PRIMARY KEY,
  case_id bigint NOT NULL REFERENCES public.cases(id),
  case_motion_id bigint NOT NULL REFERENCES public.case_motions(id),
  case_event_id bigint UNIQUE REFERENCES public.case_events(id),
  recommendation_id bigint NOT NULL REFERENCES public.motion_resolution_recommendations(id),
  date_resolved date NOT NULL,
  time_resolved time without time zone,
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
CREATE UNIQUE INDEX IF NOT EXISTS case_motion_resolutions_one_active_per_motion_uidx ON public.case_motion_resolutions(case_motion_id) WHERE is_voided = false;
CREATE INDEX IF NOT EXISTS idx_case_motion_resolutions_case_active ON public.case_motion_resolutions(case_id, is_voided, date_resolved DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_case_motion_resolutions_motion ON public.case_motion_resolutions(case_motion_id);
CREATE INDEX IF NOT EXISTS idx_case_motion_resolutions_event ON public.case_motion_resolutions(case_event_id);

GRANT SELECT ON public.motion_resolution_recommendations TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.case_motion_resolutions TO authenticated, service_role;

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
  WHERE cmr.case_id = p_case_id AND cmr.is_voided = false;

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

DROP FUNCTION IF EXISTS public.record_motion_received_event(bigint,text,text,date,time without time zone,jsonb,text,bigint);

CREATE OR REPLACE FUNCTION public.record_motion_received_event(p_case_id bigint, p_motion_title text, p_filed_by_code text, p_date_filed date, p_time_filed time without time zone DEFAULT NULL, p_details_jsonb jsonb DEFAULT '[]'::jsonb, p_remarks text DEFAULT NULL, p_assigned_prosecutor_id bigint DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_motion_id bigint; v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_old_details jsonb; v_new_details jsonb; v_details jsonb := '[]'::jsonb; v_item jsonb; v_detail text; v_value text; v_title text := NULLIF(btrim(coalesce(p_motion_title,'')), ''); v_filed_by_code text := upper(btrim(coalesce(p_filed_by_code,''))); v_remarks text := NULLIF(btrim(coalesce(p_remarks,'')), ''); v_effective_time time without time zone; v_assigned_prosecutor_name text;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id=p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'Motion Title is required'; END IF;
  IF v_filed_by_code NOT IN ('COMPLAINANT','RESPONDENT') THEN RAISE EXCEPTION 'Filed By must be COMPLAINANT or RESPONDENT'; END IF;
  IF p_date_filed IS NULL THEN RAISE EXCEPTION 'Date Filed is required'; END IF;
  IF p_assigned_prosecutor_id IS NOT NULL THEN
    SELECT coalesce(p.short_name, p.full_name) INTO v_assigned_prosecutor_name FROM public.prosecutors p WHERE p.id = p_assigned_prosecutor_id AND p.is_active IS TRUE LIMIT 1;
    IF v_assigned_prosecutor_name IS NULL THEN RAISE EXCEPTION 'Assigned Prosecutor must be an active prosecutor'; END IF;
  END IF;
  IF p_details_jsonb IS NOT NULL AND jsonb_typeof(p_details_jsonb) <> 'array' THEN RAISE EXCEPTION 'Additional Details must be a JSON array'; END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(p_details_jsonb, '[]'::jsonb)) LOOP
    v_detail := btrim(coalesce(v_item->>'detail', '')); v_value := btrim(coalesce(v_item->>'value', ''));
    IF v_detail <> '' OR v_value <> '' THEN v_details := v_details || jsonb_build_array(jsonb_build_object('detail', v_detail, 'value', v_value)); END IF;
  END LOOP;
  v_effective_time := coalesce(p_time_filed, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code='MOTION_RECEIVED' AND is_active IS TRUE LIMIT 1;
  SELECT id INTO v_status_id FROM public.case_statuses WHERE code='PENDING' AND is_active IS TRUE LIMIT 1;
  SELECT id INTO v_stage_id FROM public.case_stages WHERE code='MOTION_PENDING' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL OR v_status_id IS NULL OR v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing Motion Received seed data'; END IF;
  SELECT current_status_id,current_case_status_id,current_case_stage_id,to_jsonb(cpd) INTO v_prev_status_id,v_prev_case_status_id,v_prev_stage_id,v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_filed,v_effective_time,'Motion Received',v_remarks,v_status_id,v_status_id,v_stage_id,jsonb_build_object('motion_title',v_title,'filed_by_code',v_filed_by_code,'filed_by_label',CASE v_filed_by_code WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,'assigned_prosecutor_id',p_assigned_prosecutor_id,'assigned_prosecutor_name',v_assigned_prosecutor_name,'date_filed',p_date_filed,'time_filed',v_effective_time,'details',v_details,'remarks',v_remarks),'MANUAL_ENTRY','case_motions',p_user_id,p_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_motions(case_id,case_event_id,motion_name,motion_title,filed_by,filed_by_code,assigned_prosecutor_id,date_received,date_filed,time_filed,details_jsonb,motion_status,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_id,v_title,v_title,CASE v_filed_by_code WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,v_filed_by_code,p_assigned_prosecutor_id,p_date_filed,p_date_filed,v_effective_time,v_details,'PENDING',v_remarks,p_user_id,p_user_id) RETURNING id INTO v_motion_id;
  UPDATE public.case_events SET source_id=v_motion_id, updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;
  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at) VALUES (p_case_id,v_status_id,p_date_filed,v_remarks,v_status_id,p_date_filed,v_remarks,v_stage_id,p_date_filed,v_remarks,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();
  IF coalesce(v_prev_case_status_id,v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,coalesce(v_prev_case_status_id,v_prev_status_id),v_status_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_motions',v_motion_id,'MOTION_RECEIVED',v_old_details,v_new_details,p_case_id,'Motion received recorded.',jsonb_build_object('case_event_id',v_event_id,'motion_id',v_motion_id,'filed_by_code',v_filed_by_code,'assigned_prosecutor_id',p_assigned_prosecutor_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));
  RETURN v_event_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_motion_received_event(bigint,text,text,date,time without time zone,jsonb,text,bigint,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.add_motion_resolution_recommendation(p_display_label text, p_code text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_label text := NULLIF(btrim(coalesce(p_display_label,'')), ''); v_code text; v_id bigint; v_old jsonb; v_new jsonb;
BEGIN
  IF v_label IS NULL THEN RAISE EXCEPTION 'Recommendation Label is required'; END IF;
  v_code := upper(regexp_replace(coalesce(NULLIF(btrim(p_code), ''), v_label), '[^a-zA-Z0-9]+', '_', 'g'));
  v_code := trim(both '_' FROM coalesce(nullif(v_code,''), 'RECOMMENDATION'));
  IF EXISTS (SELECT 1 FROM public.motion_resolution_recommendations WHERE is_active AND (lower(code)=lower(v_code) OR lower(display_label)=lower(v_label))) THEN
    RAISE EXCEPTION 'An active recommendation with this code or label already exists.';
  END IF;
  INSERT INTO public.motion_resolution_recommendations(code, display_label, sort_order, is_active)
  VALUES (v_code, v_label, 100, true) RETURNING id INTO v_id;
  SELECT to_jsonb(r) INTO v_new FROM public.motion_resolution_recommendations r WHERE r.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,summary,metadata)
  VALUES (p_user_id,'motion_resolution_recommendations',v_id,'CREATE_MOTION_RESOLUTION_RECOMMENDATION',v_old,v_new,'Motion resolution recommendation added.',jsonb_build_object('code',v_code,'display_label',v_label));
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.add_motion_resolution_recommendation(text,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_motion_resolved_event(p_case_id bigint, p_case_motion_id bigint, p_recommendation_id bigint, p_date_resolved date, p_time_resolved time without time zone DEFAULT NULL, p_remarks text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_resolution_id bigint; v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_old_details jsonb; v_new_details jsonb; v_effective_time time without time zone; v_remarks text := NULLIF(btrim(coalesce(p_remarks,'')), ''); v_motion_title text; v_filed_by_code text; v_filed_by_label text; v_assigned_prosecutor_id bigint; v_assigned_prosecutor_name text; v_recommendation_code text; v_recommendation_label text;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id=p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF p_date_resolved IS NULL THEN RAISE EXCEPTION 'Date Resolved is required'; END IF;
  SELECT cm.motion_title, cm.filed_by_code, cm.filed_by, cm.assigned_prosecutor_id, coalesce(p.short_name,p.full_name)
  INTO v_motion_title, v_filed_by_code, v_filed_by_label, v_assigned_prosecutor_id, v_assigned_prosecutor_name
  FROM public.case_motions cm
  LEFT JOIN public.prosecutors p ON p.id = cm.assigned_prosecutor_id
  JOIN public.case_events ce ON ce.id = cm.case_event_id AND ce.is_voided = false
  WHERE cm.id = p_case_motion_id AND cm.case_id = p_case_id AND cm.is_voided = false;
  IF v_motion_title IS NULL THEN RAISE EXCEPTION 'Selected motion is not active for this case'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_motion_resolutions cmr WHERE cmr.case_motion_id = p_case_motion_id AND cmr.is_voided = false) THEN RAISE EXCEPTION 'This motion already has an active resolution.'; END IF;
  SELECT code, display_label INTO v_recommendation_code, v_recommendation_label FROM public.motion_resolution_recommendations WHERE id=p_recommendation_id AND is_active IS TRUE LIMIT 1;
  IF v_recommendation_code IS NULL THEN RAISE EXCEPTION 'Recommendation must be active'; END IF;
  v_effective_time := coalesce(p_time_resolved, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code='MOTION_RESOLVED' AND is_active IS TRUE LIMIT 1;
  SELECT id INTO v_status_id FROM public.case_statuses WHERE code='PENDING' AND is_active IS TRUE LIMIT 1;
  SELECT id INTO v_stage_id FROM public.case_stages WHERE code='MOTION_RESO_FOR_APPROVAL' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL OR v_status_id IS NULL OR v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing Motion Resolved seed data'; END IF;
  SELECT current_status_id,current_case_status_id,current_case_stage_id,to_jsonb(cpd) INTO v_prev_status_id,v_prev_case_status_id,v_prev_stage_id,v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_resolved,v_effective_time,'Motion Resolved',v_remarks,v_status_id,v_status_id,v_stage_id,jsonb_build_object('motion_id',p_case_motion_id,'motion_title',v_motion_title,'filed_by_code',v_filed_by_code,'filed_by_label',v_filed_by_label,'assigned_prosecutor_id',v_assigned_prosecutor_id,'assigned_prosecutor_name',v_assigned_prosecutor_name,'recommendation_id',p_recommendation_id,'recommendation_code',v_recommendation_code,'recommendation_label',v_recommendation_label,'date_resolved',p_date_resolved,'time_resolved',v_effective_time,'remarks',v_remarks),'MANUAL_ENTRY','case_motion_resolutions',p_user_id,p_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_motion_resolutions(case_id,case_motion_id,case_event_id,recommendation_id,date_resolved,time_resolved,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,p_case_motion_id,v_event_id,p_recommendation_id,p_date_resolved,v_effective_time,v_remarks,p_user_id,p_user_id) RETURNING id INTO v_resolution_id;
  UPDATE public.case_events SET source_id=v_resolution_id, updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;
  UPDATE public.case_motions SET motion_status='RESO_FOR_APPROVAL', updated_by_user_id=p_user_id, updated_at=now() WHERE id=p_case_motion_id;
  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at) VALUES (p_case_id,v_status_id,p_date_resolved,v_remarks,v_status_id,p_date_resolved,v_remarks,v_stage_id,p_date_resolved,v_remarks,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();
  IF coalesce(v_prev_case_status_id,v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,coalesce(v_prev_case_status_id,v_prev_status_id),v_status_id,p_user_id,now(),p_date_resolved,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_resolved,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_motion_resolutions',v_resolution_id,'MOTION_RESOLVED',v_old_details,v_new_details,p_case_id,'Motion resolved recorded.',jsonb_build_object('case_event_id',v_event_id,'motion_id',p_case_motion_id,'motion_resolution_id',v_resolution_id,'recommendation_id',p_recommendation_id,'recommendation_code',v_recommendation_code,'recommendation_label',v_recommendation_label,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));
  RETURN v_event_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_motion_resolved_event(bigint,bigint,bigint,date,time without time zone,text,bigint) TO authenticated;

CREATE OR REPLACE VIEW public.v_case_motions_detail AS
SELECT
  cm.id, cm.case_id, cm.motion_order, cm.motion_name, cm.filed_by, cm.filed_by_raw, cm.date_received, cm.date_received_raw, cm.date_resolved, cm.date_resolved_raw, cm.date_approved, cm.date_approved_raw, cm.motion_status, cm.motion_status_raw, cm.remarks, cm.remarks_raw, cm.created_at, cm.updated_at, cm.case_event_id, cm.motion_title, cm.filed_by_code, cm.date_filed, cm.time_filed, cm.details_jsonb, cm.is_voided, cm.voided_at, cm.voided_by_user_id, cm.void_reason, cm.assigned_prosecutor_id, coalesce(p.short_name,p.full_name) AS assigned_prosecutor_name,
  cmr.id AS active_motion_resolution_id, cmr.recommendation_id AS active_motion_resolution_recommendation_id, mrr.code AS active_motion_resolution_recommendation_code, mrr.display_label AS active_motion_resolution_recommendation_label
FROM public.case_motions cm
LEFT JOIN public.prosecutors p ON p.id = cm.assigned_prosecutor_id
LEFT JOIN public.case_motion_resolutions cmr ON cmr.case_motion_id = cm.id AND cmr.is_voided = false
LEFT JOIN public.motion_resolution_recommendations mrr ON mrr.id = cmr.recommendation_id;
GRANT SELECT ON public.v_case_motions_detail TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
  v_motion_id bigint; v_motion_old jsonb; v_motion_new jsonb;
  v_motion_resolution_id bigint; v_motion_resolution_old jsonb; v_motion_resolution_new jsonb; v_motion_approval_count integer;
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

  IF lower(coalesce(v_source_table,'')) = 'case_motion_resolutions' OR v_event_type_code = 'MOTION_RESOLVED' THEN
    SELECT cmr.id, to_jsonb(cmr) INTO v_motion_resolution_id, v_motion_resolution_old
    FROM public.case_motion_resolutions cmr
    WHERE cmr.id = v_source_id OR cmr.case_event_id = p_case_event_id
    ORDER BY CASE WHEN cmr.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_motion_resolution_id IS NOT NULL THEN
      IF to_regclass('public.case_motion_resolution_approvals') IS NOT NULL THEN
        EXECUTE 'SELECT count(*) FROM public.case_motion_resolution_approvals WHERE case_motion_resolution_id = $1 AND is_voided = false'
        INTO v_motion_approval_count
        USING v_motion_resolution_id;
        IF COALESCE(v_motion_approval_count, 0) > 0 THEN
          RAISE EXCEPTION 'This motion resolution already has an approved decision. Void the approval event first.';
        END IF;
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

COMMENT ON FUNCTION public.record_motion_resolved_event(bigint,bigint,bigint,date,time without time zone,text,bigint) IS 'Records MOTION_RESOLVED as PENDING/MOTION_RESO_FOR_APPROVAL, linked to one active motion and an active recommendation; verification covers Granted/Denied/custom recommendations, duplicate active resolution blocking, history-on-change, and Asia/Manila time default.';
COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Motion-aware exact-record priority: active case_motion_resolutions awaiting approval -> PENDING/MOTION_RESO_FOR_APPROVAL; active unresolved case_motions -> PENDING/MOTION_PENDING; otherwise existing non-motion workflow fallback.';
COMMENT ON FUNCTION public.void_case_event(bigint,text,bigint) IS 'Changed for MOTION_RESOLVED and Motion Received dependency guard while preserving unrelated event branches; verification covers dependency blocking and recompute after void.';

-- Verification SQL/comments:
-- 1. record_motion_received_event with p_assigned_prosecutor_id omitted by UI defaults to latest active assignment; manually passed prosecutor_id is stored on case_motions.assigned_prosecutor_id.
-- 2. record_motion_resolved_event(... recommendation GRANTED ...) -> case_private_details PENDING / MOTION_RESO_FOR_APPROVAL.
-- 3. record_motion_resolved_event(... recommendation DENIED ...) -> case_private_details PENDING / MOTION_RESO_FOR_APPROVAL.
-- 4. add_motion_resolution_recommendation('Custom Label', NULL, user_id) returns a selectable active lookup row and rejects duplicate active code/label.
-- 5. A second active record_motion_resolved_event for the same case_motion_id raises via unique index / validation.
-- 6. public.void_case_event(motion_resolved_event_id, ...) voids case_motion_resolutions, leaves case_motions active, and recomputes to MOTION_PENDING unless another active motion resolution remains.
-- 7. public.void_case_event(motion_received_event_id, ...) raises while an active case_motion_resolutions row exists for that motion.
-- 8. If public.case_motion_resolution_approvals exists with active rows, voiding MOTION_RESOLVED raises: This motion resolution already has an approved decision. Void the approval event first.
-- 9. Compare case_status_history/case_stage_history counts around record/void to verify rows are inserted only when ids change.
-- 10. Omitted p_time_resolved uses (now() AT TIME ZONE 'Asia/Manila')::time(0); explicit historical p_time_resolved is preserved.
-- 11. Existing CASE_ASSIGNMENT, CASE_REASSIGNMENT, CASE_RESOLVED, CASE_DECISION_APPROVED, and COURT_FILING branches remain in public.void_case_event.

COMMIT;
