BEGIN;

INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
VALUES ('MOTION_RECEIVED', 'Motion Received', 'MOTION', 'Manual timeline event for receiving a motion.', 150, true, true)
ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label, category=EXCLUDED.category, description=EXCLUDED.description, sort_order=EXCLUDED.sort_order, is_active=true, updated_at=now();

INSERT INTO public.case_stages (code, display_label, sort_order, is_final_stage, is_milestone, is_active)
VALUES
  ('MOTION_PENDING', 'Motion Pending', 70, false, true, true),
  ('MOTION_RESO_FOR_APPROVAL', 'Motion Reso for Approval', 75, false, true, true)
ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label, sort_order=EXCLUDED.sort_order, is_final_stage=EXCLUDED.is_final_stage, is_milestone=EXCLUDED.is_milestone, is_active=true, updated_at=now();

ALTER TABLE public.case_motions
  ADD COLUMN IF NOT EXISTS case_event_id bigint UNIQUE REFERENCES public.case_events(id),
  ADD COLUMN IF NOT EXISTS motion_title text,
  ADD COLUMN IF NOT EXISTS filed_by_code text,
  ADD COLUMN IF NOT EXISTS date_filed date,
  ADD COLUMN IF NOT EXISTS time_filed time without time zone,
  ADD COLUMN IF NOT EXISTS details_jsonb jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_voided boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS voided_at timestamptz,
  ADD COLUMN IF NOT EXISTS voided_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS void_reason text;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'case_motions_filed_by_code_check' AND conrelid = 'public.case_motions'::regclass) THEN
    ALTER TABLE public.case_motions ADD CONSTRAINT case_motions_filed_by_code_check CHECK (filed_by_code IS NULL OR filed_by_code IN ('COMPLAINANT','RESPONDENT'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_case_motions_case_event_id ON public.case_motions(case_event_id);
CREATE INDEX IF NOT EXISTS idx_case_motions_active_received ON public.case_motions(case_id, is_voided, date_filed DESC, id DESC) WHERE case_event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.compute_current_case_state(p_case_id bigint)
RETURNS TABLE(case_status_code text, case_stage_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_motion_pending_count integer;
  v_motion_resolution_for_approval_count integer;
  v_unapproved_resolution_count integer;
  v_unfiled_for_filing_count integer;
  v_filed_for_filing_count integer;
  v_dismissal_count integer;
  v_active_assignment_count integer;
BEGIN
  SELECT count(*) INTO v_motion_resolution_for_approval_count
  FROM public.case_motions cm
  WHERE cm.case_id = p_case_id AND cm.is_voided = false
    AND upper(coalesce(cm.motion_status, '')) IN ('MOTION_RESO_FOR_APPROVAL','RESO_FOR_APPROVAL','FOR_APPROVAL','PENDING_APPROVAL');

  SELECT count(*) INTO v_motion_pending_count
  FROM public.case_motions cm
  WHERE cm.case_id = p_case_id AND cm.is_voided = false
    AND (cm.case_event_id IS NOT NULL OR cm.date_filed IS NOT NULL OR cm.filed_by_code IS NOT NULL)
    AND upper(coalesce(cm.motion_status, 'PENDING')) NOT IN ('RESOLVED','APPROVED','DENIED','GRANTED','DISMISSED','VOIDED')
    AND upper(coalesce(cm.motion_status, '')) NOT IN ('MOTION_RESO_FOR_APPROVAL','RESO_FOR_APPROVAL','FOR_APPROVAL','PENDING_APPROVAL');

  IF COALESCE(v_motion_resolution_for_approval_count, 0) > 0 THEN
    RETURN QUERY SELECT 'PENDING'::text, 'MOTION_RESO_FOR_APPROVAL'::text;
    RETURN;
  ELSIF COALESCE(v_motion_pending_count, 0) > 0 THEN
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

CREATE OR REPLACE FUNCTION public.record_motion_received_event(p_case_id bigint, p_motion_title text, p_filed_by_code text, p_date_filed date, p_time_filed time without time zone DEFAULT NULL, p_details_jsonb jsonb DEFAULT '[]'::jsonb, p_remarks text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_motion_id bigint; v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint; v_status_history_id bigint; v_stage_history_id bigint; v_old_details jsonb; v_new_details jsonb; v_details jsonb := '[]'::jsonb; v_item jsonb; v_detail text; v_value text; v_title text := NULLIF(btrim(coalesce(p_motion_title,'')), ''); v_filed_by_code text := upper(btrim(coalesce(p_filed_by_code,''))); v_remarks text := NULLIF(btrim(coalesce(p_remarks,'')), ''); v_effective_time time without time zone;
BEGIN
  IF p_case_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.cases WHERE id=p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF v_title IS NULL THEN RAISE EXCEPTION 'Motion Title is required'; END IF;
  IF v_filed_by_code NOT IN ('COMPLAINANT','RESPONDENT') THEN RAISE EXCEPTION 'Filed By must be COMPLAINANT or RESPONDENT'; END IF;
  IF p_date_filed IS NULL THEN RAISE EXCEPTION 'Date Filed is required'; END IF;
  IF p_details_jsonb IS NOT NULL AND jsonb_typeof(p_details_jsonb) <> 'array' THEN RAISE EXCEPTION 'Additional Details must be a JSON array'; END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(coalesce(p_details_jsonb, '[]'::jsonb)) LOOP
    v_detail := btrim(coalesce(v_item->>'detail', ''));
    v_value := btrim(coalesce(v_item->>'value', ''));
    IF v_detail <> '' OR v_value <> '' THEN v_details := v_details || jsonb_build_array(jsonb_build_object('detail', v_detail, 'value', v_value)); END IF;
  END LOOP;
  v_effective_time := coalesce(p_time_filed, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code='MOTION_RECEIVED' AND is_active IS TRUE LIMIT 1;
  SELECT id INTO v_status_id FROM public.case_statuses WHERE code='PENDING' AND is_active IS TRUE LIMIT 1;
  SELECT id INTO v_stage_id FROM public.case_stages WHERE code='MOTION_PENDING' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL OR v_status_id IS NULL OR v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing Motion Received seed data'; END IF;
  SELECT current_status_id,current_case_status_id,current_case_stage_id,to_jsonb(cpd) INTO v_prev_status_id,v_prev_case_status_id,v_prev_stage_id,v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,source_table,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_filed,v_effective_time,'Motion Received',v_remarks,v_status_id,v_status_id,v_stage_id,jsonb_build_object('motion_title',v_title,'filed_by_code',v_filed_by_code,'filed_by_label',CASE v_filed_by_code WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,'date_filed',p_date_filed,'time_filed',v_effective_time,'details',v_details,'remarks',v_remarks),'MANUAL_ENTRY','case_motions',p_user_id,p_user_id) RETURNING id INTO v_event_id;
  INSERT INTO public.case_motions(case_id,case_event_id,motion_name,motion_title,filed_by,filed_by_code,date_received,date_filed,time_filed,details_jsonb,motion_status,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_id,v_title,v_title,CASE v_filed_by_code WHEN 'COMPLAINANT' THEN 'Complainant' ELSE 'Respondent' END,v_filed_by_code,p_date_filed,p_date_filed,v_effective_time,v_details,'PENDING',v_remarks,p_user_id,p_user_id) RETURNING id INTO v_motion_id;
  UPDATE public.case_events SET source_id=v_motion_id, updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;
  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at) VALUES (p_case_id,v_status_id,p_date_filed,v_remarks,v_status_id,p_date_filed,v_remarks,v_stage_id,p_date_filed,v_remarks,now()) ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();
  IF coalesce(v_prev_case_status_id,v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,coalesce(v_prev_case_status_id,v_prev_status_id),v_status_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_motions',v_motion_id,'MOTION_RECEIVED',v_old_details,v_new_details,p_case_id,'Motion received recorded.',jsonb_build_object('case_event_id',v_event_id,'motion_id',v_motion_id,'filed_by_code',v_filed_by_code,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id));
  RETURN v_event_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_motion_received_event(bigint,text,text,date,time without time zone,jsonb,text,bigint) TO authenticated;

CREATE OR REPLACE VIEW public.v_case_motions_detail AS
SELECT
  id,
  case_id,
  motion_order,
  motion_name,
  filed_by,
  filed_by_raw,
  date_received,
  date_received_raw,
  date_resolved,
  date_resolved_raw,
  date_approved,
  date_approved_raw,
  motion_status,
  motion_status_raw,
  remarks,
  remarks_raw,
  created_at,
  updated_at,
  case_event_id,
  motion_title,
  filed_by_code,
  date_filed,
  time_filed,
  details_jsonb,
  is_voided,
  voided_at,
  voided_by_user_id,
  void_reason
FROM public.case_motions;

-- public.void_case_event keeps the complete latest implementation and adds only the MOTION_RECEIVED-specific branch above the COURT_FILING branch.
CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
  v_motion_id bigint; v_motion_old jsonb; v_motion_new jsonb;
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
      UPDATE public.case_motions SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_motion_id;
      SELECT to_jsonb(cm) INTO v_motion_new FROM public.case_motions cm WHERE cm.id = v_motion_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motions',v_motion_id,'VOID_MOTION_RECEIVED_FROM_EVENT',v_motion_old,v_motion_new,v_case_id,'Motion Received voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
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

COMMENT ON FUNCTION public.record_motion_received_event(bigint,text,text,date,time without time zone,jsonb,text,bigint) IS 'Records MOTION_RECEIVED with controlled filed_by_code, normalized details_jsonb, PENDING/MOTION_PENDING, audit and history rows only when changed. Verification: rejects non COMPLAINANT/RESPONDENT; omits empty detail rows; defaults omitted time to current Asia/Manila time(0); preserves explicit historical time.';
COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Motion-aware priority: active motion resolution awaiting approval -> PENDING/MOTION_RESO_FOR_APPROVAL; active pending motion -> PENDING/MOTION_PENDING; otherwise existing case resolution/filing/assignment workflow. Verification: voiding one of multiple motions remains MOTION_PENDING; voiding last motion falls back to existing workflow; history rows are inserted only when ids change by apply_case_state_recompute.';
COMMENT ON FUNCTION public.void_case_event(bigint,text,bigint) IS 'Changed for MOTION_RECEIVED: marks linked case_motions row voided, keeps event visible, audits, and invokes shared recompute once while preserving unrelated event branches.';

COMMIT;
