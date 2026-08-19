-- Normalize standalone Case Decision Approved events into the same approval
-- tables used by linked approvals. The only absent relationship is the optional
-- case resolution itself.

ALTER TABLE public.case_resolution_approvals
  ALTER COLUMN case_resolution_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.record_case_decision_approved_event(
  p_case_id bigint,
  p_case_resolution_id bigint DEFAULT NULL,
  p_approved_by_prosecutor_id bigint DEFAULT NULL,
  p_date_approved date DEFAULT NULL,
  p_time_approved time without time zone DEFAULT NULL,
  p_approval_actions jsonb DEFAULT '[]'::jsonb,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_type_id bigint;
  v_status_id bigint;
  v_stage_id bigint;
  v_previous_status_id bigint;
  v_previous_case_status_id bigint;
  v_previous_stage_id bigint;
  v_event_id bigint;
  v_approval_id bigint;
  v_status_history_id bigint;
  v_stage_history_id bigint;
  v_approver_name text;
  v_approver_position_code text;
  v_approver_position_group_type text;
  v_event_final_status_code text;
  v_event_final_status_label text;
  v_case_status_code text;
  v_case_stage_code text;
  v_case_status_label text;
  v_case_stage_label text;
  v_effective_time time without time zone;
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
  v_old_details jsonb;
  v_new_details jsonb;
  v_action jsonb;
  v_action_count integer;
  v_for_filing_count integer;
  v_dismissal_count integer;
  v_display_order integer := 0;
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_approved_by_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Approved by prosecutor is required'; END IF;
  IF p_date_approved IS NULL THEN RAISE EXCEPTION 'Date approved is required'; END IF;
  v_effective_time := COALESCE(p_time_approved, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  IF jsonb_typeof(COALESCE(p_approval_actions, '[]'::jsonb)) <> 'array' THEN RAISE EXCEPTION 'Approval actions must be an array'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  SELECT pr.full_name, p.code, p.group_type INTO v_approver_name, v_approver_position_code, v_approver_position_group_type
  FROM public.prosecutors pr
  JOIN public.positions p ON p.id = pr.position_id
  WHERE pr.id = p_approved_by_prosecutor_id
    AND pr.is_active = true
    AND p.is_active = true;

  IF v_approver_name IS NULL THEN RAISE EXCEPTION 'Unknown prosecutor id %', p_approved_by_prosecutor_id; END IF;
  IF COALESCE(v_approver_position_group_type, '') <> 'PROSECUTOR' OR COALESCE(v_approver_position_code, '') NOT IN ('CHIEF_PROSECUTOR', 'DEPUTY_PROSECUTOR') THEN
    RAISE EXCEPTION 'Approver must be a Chief Prosecutor or Deputy Prosecutor';
  END IF;

  IF p_case_resolution_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.case_resolutions WHERE id = p_case_resolution_id AND case_id = p_case_id) THEN
      RAISE EXCEPTION 'Resolution % does not belong to case %', p_case_resolution_id, p_case_id;
    END IF;
    IF EXISTS (SELECT 1 FROM public.case_resolutions WHERE id = p_case_resolution_id AND case_id = p_case_id AND is_voided = true) THEN
      RAISE EXCEPTION 'Voided resolution cannot be approved.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.case_resolution_approvals WHERE case_resolution_id = p_case_resolution_id AND is_voided = false) THEN
      RAISE EXCEPTION 'This resolution already has an active approved decision.';
    END IF;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE action.value->>'decision_code' = 'FOR_FILING'), count(*) FILTER (WHERE action.value->>'decision_code' = 'DISMISSAL')
  INTO v_action_count, v_for_filing_count, v_dismissal_count
  FROM jsonb_array_elements(COALESCE(p_approval_actions, '[]'::jsonb)) AS action(value)
  WHERE NULLIF(btrim(COALESCE(action.value->>'charge_text', '')), '') IS NOT NULL
    AND action.value->>'decision_code' IN ('FOR_FILING', 'DISMISSAL');

  IF v_action_count < 1 THEN RAISE EXCEPTION 'At least one approval action is required'; END IF;

  v_event_final_status_code := CASE
    WHEN v_for_filing_count = v_action_count THEN 'FOR_FILING'
    WHEN v_dismissal_count = v_action_count THEN 'DISMISSED'
    ELSE 'MIXED_RESULT'
  END;
  v_event_final_status_label := CASE v_event_final_status_code WHEN 'FOR_FILING' THEN 'For Filing' WHEN 'DISMISSED' THEN 'Dismissed' ELSE 'Mixed Result' END;

  SELECT cpd.current_status_id, cpd.current_case_status_id, cpd.current_case_stage_id, to_jsonb(cpd)
  INTO v_previous_status_id, v_previous_case_status_id, v_previous_stage_id, v_old_details
  FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
  VALUES ('CASE_DECISION_APPROVED', 'Case Decision Approved', 'CASE', 'Manual timeline event for approving a prosecutor recommendation or final case decision.', 130, true, true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, category = EXCLUDED.category, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, is_active = true, updated_at = now()
  RETURNING id INTO v_event_type_id;

  INSERT INTO public.case_events (case_id, event_type_id, event_date, event_time, title, description, details_jsonb, source, created_by_user_id, updated_by_user_id)
  VALUES (p_case_id, v_event_type_id, p_date_approved, v_effective_time, 'Case Decision Approved', 'Decision approved by Prosec ' || v_approver_name || ' on ' || to_char(p_date_approved, 'Mon FMDD, YYYY'),
    jsonb_build_object('approved_by_prosecutor_id', p_approved_by_prosecutor_id, 'approved_by_name', v_approver_name, 'date_approved', p_date_approved, 'time_approved', v_effective_time, 'final_status_code', v_event_final_status_code, 'final_status_label', v_event_final_status_label, 'event_final_status_code', v_event_final_status_code, 'event_final_status_label', v_event_final_status_label, 'remarks', v_remarks),
    'MANUAL_ENTRY', p_user_id, p_user_id)
  RETURNING id INTO v_event_id;

  INSERT INTO public.case_resolution_approvals (case_id, case_event_id, case_resolution_id, approved_by_prosecutor_id, date_approved, time_approved, final_status_code, remarks, created_by_user_id, updated_by_user_id)
  VALUES (p_case_id, v_event_id, p_case_resolution_id, p_approved_by_prosecutor_id, p_date_approved, v_effective_time, v_event_final_status_code, v_remarks, p_user_id, p_user_id)
  RETURNING id INTO v_approval_id;

  FOR v_action IN SELECT * FROM jsonb_array_elements(COALESCE(p_approval_actions, '[]'::jsonb)) LOOP
    IF NULLIF(btrim(COALESCE(v_action->>'charge_text', '')), '') IS NOT NULL AND v_action->>'decision_code' IN ('FOR_FILING', 'DISMISSAL') THEN
      IF p_case_resolution_id IS NOT NULL
        AND NULLIF(v_action->>'source_resolution_charge_action_id', '') IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.case_resolution_charge_actions src
          WHERE src.id = NULLIF(v_action->>'source_resolution_charge_action_id', '')::bigint
            AND src.case_id = p_case_id
            AND src.case_resolution_id = p_case_resolution_id
        ) THEN
        RAISE EXCEPTION 'Selected recommendation action does not belong to this case resolution.';
      END IF;

      v_display_order := v_display_order + 1;
      INSERT INTO public.case_resolution_approval_actions (approval_id, case_id, source_resolution_charge_action_id, case_violation_id, violation_id, charge_text, decision_code, display_order, remarks)
      VALUES (v_approval_id, p_case_id, CASE WHEN p_case_resolution_id IS NOT NULL THEN NULLIF(v_action->>'source_resolution_charge_action_id', '')::bigint ELSE NULL END, NULLIF(v_action->>'case_violation_id', '')::bigint, NULLIF(v_action->>'violation_id', '')::bigint, NULLIF(btrim(v_action->>'charge_text'), ''), v_action->>'decision_code', v_display_order, NULLIF(btrim(COALESCE(v_action->>'remarks', '')), ''));
    END IF;
  END LOOP;

  SELECT case_status_code, case_stage_code INTO v_case_status_code, v_case_stage_code
  FROM public.compute_current_case_state(p_case_id) LIMIT 1;
  SELECT id, display_label INTO v_status_id, v_case_status_label FROM public.case_statuses WHERE code = v_case_status_code AND is_active IS TRUE LIMIT 1;
  SELECT id, display_label INTO v_stage_id, v_case_stage_label FROM public.case_stages WHERE code = v_case_stage_code AND is_active IS TRUE LIMIT 1;
  IF v_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status %', v_case_status_code; END IF;
  IF v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage %', v_case_stage_code; END IF;

  UPDATE public.case_events
  SET source_table = 'case_resolution_approvals',
      source_id = v_approval_id,
      status_id = v_status_id,
      case_status_id = v_status_id,
      case_stage_id = v_stage_id,
      details_jsonb = details_jsonb || jsonb_build_object(
        'case_resolution_id', p_case_resolution_id,
        'case_resolution_approval_id', v_approval_id,
        'case_status_code', v_case_status_code,
        'case_status_label', v_case_status_label,
        'case_stage_code', v_case_stage_code,
        'case_stage_label', v_case_stage_label,
        'case_final_status_code', v_case_status_code,
        'case_final_status_label', v_case_status_label,
        'approval_actions', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', aa.id, 'source_resolution_charge_action_id', aa.source_resolution_charge_action_id, 'case_violation_id', aa.case_violation_id, 'violation_id', aa.violation_id, 'charge_text', aa.charge_text, 'decision_code', aa.decision_code, 'display_order', aa.display_order, 'remarks', aa.remarks) ORDER BY aa.display_order, aa.id) FROM public.case_resolution_approval_actions aa WHERE aa.approval_id = v_approval_id), '[]'::jsonb)
      ),
      updated_by_user_id = p_user_id,
      updated_at = now()
  WHERE id = v_event_id;

  INSERT INTO public.case_private_details (case_id, current_status_id, current_status_date, current_status_remarks, current_case_status_id, current_case_status_date, current_case_status_remarks, current_case_stage_id, current_case_stage_date, current_case_stage_remarks, updated_at)
  VALUES (p_case_id, v_status_id, p_date_approved, v_remarks, v_status_id, p_date_approved, v_remarks, v_stage_id, p_date_approved, v_remarks, now())
  ON CONFLICT (case_id) DO UPDATE SET
    current_status_id = EXCLUDED.current_status_id,
    current_status_date = EXCLUDED.current_status_date,
    current_status_remarks = EXCLUDED.current_status_remarks,
    current_case_status_id = EXCLUDED.current_case_status_id,
    current_case_status_date = EXCLUDED.current_case_status_date,
    current_case_status_remarks = EXCLUDED.current_case_status_remarks,
    current_case_stage_id = EXCLUDED.current_case_stage_id,
    current_case_stage_date = EXCLUDED.current_case_stage_date,
    current_case_stage_remarks = EXCLUDED.current_case_stage_remarks,
    updated_at = now();

  IF COALESCE(v_previous_case_status_id, v_previous_status_id) IS DISTINCT FROM v_status_id THEN
    INSERT INTO public.case_status_history (case_id, from_status_id, to_status_id, changed_by_user_id, changed_at, status_date, remarks, case_event_id)
    VALUES (p_case_id, COALESCE(v_previous_case_status_id, v_previous_status_id), v_status_id, p_user_id, now(), p_date_approved, v_remarks, v_event_id)
    RETURNING id INTO v_status_history_id;
  END IF;

  IF v_previous_stage_id IS DISTINCT FROM v_stage_id THEN
    INSERT INTO public.case_stage_history (case_id, from_stage_id, to_stage_id, changed_by_user_id, changed_at, stage_date, remarks, case_event_id)
    VALUES (p_case_id, v_previous_stage_id, v_stage_id, p_user_id, now(), p_date_approved, v_remarks, v_event_id)
    RETURNING id INTO v_stage_history_id;
  END IF;

  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (p_user_id, 'case_resolution_approvals', v_approval_id, 'CASE_DECISION_APPROVED', v_old_details, v_new_details, p_case_id, 'Case decision approved as ' || v_event_final_status_label || '.', jsonb_build_object('case_event_id', v_event_id, 'status_history_id', v_status_history_id, 'case_stage_history_id', v_stage_history_id, 'event_final_status_code', v_event_final_status_code, 'case_resolution_id', p_case_resolution_id, 'case_resolution_approval_id', v_approval_id, 'case_status_code', v_case_status_code, 'case_stage_code', v_case_stage_code));

  RETURN v_event_id;
END;
$$;


GRANT EXECUTE ON FUNCTION public.record_case_decision_approved_event(bigint, bigint, bigint, date, time without time zone, jsonb, text, bigint) TO authenticated;

COMMENT ON FUNCTION public.record_case_decision_approved_event(bigint, bigint, bigint, date, time without time zone, jsonb, text, bigint) IS 'Always creates normalized case_resolution_approvals and case_resolution_approval_actions records. Standalone approvals use a NULL case_resolution_id; linked approvals retain resolution validation.';
