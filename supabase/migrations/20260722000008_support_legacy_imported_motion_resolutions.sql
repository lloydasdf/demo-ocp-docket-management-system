-- Support resolving legacy-imported motions whose normalized title is empty.
-- Consolidate the linked workflow back into the public RPC.

-- The workflow may temporarily record more than one active resolution for a motion.
DROP INDEX IF EXISTS public.case_motion_resolutions_one_active_per_motion_uidx;

-- Standalone Motion Resolved events have no selected motion.
ALTER TABLE public.case_motion_resolutions
  ALTER COLUMN case_motion_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.record_motion_resolved_event(
  p_case_id bigint,
  p_case_motion_id bigint,
  p_recommendation_id bigint,
  p_date_resolved date,
  p_time_resolved time without time zone DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_type_id bigint;
  v_event_id bigint;
  v_resolution_id bigint;
  v_status_id bigint;
  v_stage_id bigint;
  v_prev_status_id bigint;
  v_prev_case_status_id bigint;
  v_prev_stage_id bigint;
  v_status_history_id bigint;
  v_stage_history_id bigint;
  v_old_details jsonb;
  v_new_details jsonb;
  v_effective_time time without time zone;
  v_remarks text := NULLIF(btrim(coalesce(p_remarks, '')), '');
  v_motion_title text;
  v_filed_by_code text;
  v_filed_by_label text;
  v_assigned_prosecutor_id bigint;
  v_assigned_prosecutor_name text;
  v_recommendation_code text;
  v_recommendation_label text;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  IF p_date_resolved IS NULL THEN
    RAISE EXCEPTION 'Date Resolved is required';
  END IF;

  -- Temporarily allow inactive recommendations during workflow simplification.
  SELECT code, display_label
  INTO v_recommendation_code, v_recommendation_label
  FROM public.motion_resolution_recommendations
  WHERE id = p_recommendation_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown recommendation id %', p_recommendation_id;
  END IF;

  IF p_case_motion_id IS NOT NULL THEN
    SELECT
      COALESCE(
        NULLIF(btrim(cm.motion_title), ''),
        NULLIF(btrim(ce.details_jsonb->>'motion_title'), ''),
        NULLIF(btrim(ce.title), ''),
        'Motion'
      ),
      cm.filed_by_code,
      cm.filed_by,
      cm.assigned_prosecutor_id,
      coalesce(p.short_name, p.full_name)
    INTO
      v_motion_title,
      v_filed_by_code,
      v_filed_by_label,
      v_assigned_prosecutor_id,
      v_assigned_prosecutor_name
    FROM public.case_motions cm
    LEFT JOIN public.prosecutors p ON p.id = cm.assigned_prosecutor_id
    JOIN public.case_events ce ON ce.id = cm.case_event_id AND ce.is_voided = false
    WHERE cm.id = p_case_motion_id
      AND cm.case_id = p_case_id
      AND cm.is_voided = false;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Selected motion is not active for this case';
    END IF;
  END IF;

  v_effective_time := coalesce(p_time_resolved, (now() AT TIME ZONE 'Asia/Manila')::time(0));

  SELECT id INTO v_event_type_id
  FROM public.case_event_types
  WHERE code = 'MOTION_RESOLVED' AND is_active IS TRUE
  LIMIT 1;

  SELECT id INTO v_status_id
  FROM public.case_statuses
  WHERE code = 'PENDING' AND is_active IS TRUE
  LIMIT 1;

  SELECT id INTO v_stage_id
  FROM public.case_stages
  WHERE code = 'MOTION_RESO_FOR_APPROVAL' AND is_active IS TRUE
  LIMIT 1;

  IF v_event_type_id IS NULL OR v_status_id IS NULL OR v_stage_id IS NULL THEN
    RAISE EXCEPTION 'Missing Motion Resolved seed data';
  END IF;

  SELECT current_status_id, current_case_status_id, current_case_stage_id, to_jsonb(cpd)
  INTO v_prev_status_id, v_prev_case_status_id, v_prev_stage_id, v_old_details
  FROM public.case_private_details cpd
  WHERE case_id = p_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_resolved,v_effective_time,'Motion Resolved',v_remarks,v_status_id,v_status_id,v_stage_id,jsonb_build_object('motion_id',p_case_motion_id,'motion_title',v_motion_title,'filed_by_code',v_filed_by_code,'filed_by_label',v_filed_by_label,'assigned_prosecutor_id',v_assigned_prosecutor_id,'assigned_prosecutor_name',v_assigned_prosecutor_name,'recommendation_id',p_recommendation_id,'recommendation_code',v_recommendation_code,'recommendation_label',v_recommendation_label,'date_resolved',p_date_resolved,'time_resolved',v_effective_time,'remarks',v_remarks),'MANUAL_ENTRY','case_motion_resolutions',p_user_id,p_user_id)
  RETURNING id INTO v_event_id;

  INSERT INTO public.case_motion_resolutions(case_id,case_motion_id,case_event_id,recommendation_id,date_resolved,time_resolved,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,p_case_motion_id,v_event_id,p_recommendation_id,p_date_resolved,v_effective_time,v_remarks,p_user_id,p_user_id)
  RETURNING id INTO v_resolution_id;

  UPDATE public.case_events
  SET source_id = v_resolution_id, updated_at = now(), updated_by_user_id = p_user_id
  WHERE id = v_event_id;

  IF p_case_motion_id IS NOT NULL THEN
    UPDATE public.case_motions
    SET motion_status = 'RESO_FOR_APPROVAL', updated_by_user_id = p_user_id, updated_at = now()
    WHERE id = p_case_motion_id;
  END IF;

  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at)
  VALUES (p_case_id,v_status_id,p_date_resolved,v_remarks,v_status_id,p_date_resolved,v_remarks,v_stage_id,p_date_resolved,v_remarks,now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();

  IF coalesce(v_prev_case_status_id,v_prev_status_id) IS DISTINCT FROM v_status_id THEN
    INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
    VALUES (p_case_id,coalesce(v_prev_case_status_id,v_prev_status_id),v_status_id,p_user_id,now(),p_date_resolved,v_remarks,v_event_id)
    RETURNING id INTO v_status_history_id;
  END IF;

  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN
    INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
    VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_resolved,v_remarks,v_event_id)
    RETURNING id INTO v_stage_history_id;
  END IF;

  SELECT to_jsonb(cpd) INTO v_new_details
  FROM public.case_private_details cpd
  WHERE case_id = p_case_id;

  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
  VALUES (p_user_id,'case_motion_resolutions',v_resolution_id,'MOTION_RESOLVED',v_old_details,v_new_details,p_case_id,'Motion resolved recorded.',jsonb_build_object('case_event_id',v_event_id,'motion_id',p_case_motion_id,'motion_resolution_id',v_resolution_id,'recommendation_id',p_recommendation_id,'recommendation_code',v_recommendation_code,'recommendation_label',v_recommendation_label,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));

  RETURN v_event_id;
END;
$$;

-- The public RPC above now contains the linked implementation, so remove the old alias.
DROP FUNCTION public.record_motion_resolved_event_linked(
  bigint,
  bigint,
  bigint,
  date,
  time without time zone,
  text,
  bigint
);
