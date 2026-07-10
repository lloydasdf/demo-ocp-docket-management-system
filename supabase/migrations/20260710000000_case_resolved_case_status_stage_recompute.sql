BEGIN;

INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
VALUES
  ('PENDING', 'Pending', 20, false, false, true),
  ('FILED', 'Filed', 96, true, true, true),
  ('DISMISSED', 'Dismissed', 100, true, true, true),
  ('MIXED_RESULT', 'Mixed Result', 110, true, true, true)
ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final = EXCLUDED.is_final, is_milestone = EXCLUDED.is_milestone, is_active = true;

INSERT INTO public.case_stages (code, display_label, sort_order, is_final_stage, is_milestone, is_active)
VALUES
  ('FOR_RAFFLE', 'For Raffle', 10, false, false, true),
  ('CASE_RAFFLED', 'Case Raffled', 30, false, true, true),
  ('RESO_FOR_APPROVAL', 'Reso for Approval', 80, false, true, true),
  ('FOR_FILING', 'For Filing', 90, false, true, true),
  ('FILED_OTHER_RESO_FOR_APPROVAL', 'Filed; other resolution for approval', 92, false, true, true),
  ('FILED_OTHER_INFO_FOR_FILING', 'Filed; other info for filing', 94, false, true, true),
  ('FILED', 'Filed', 96, true, true, true),
  ('DISMISSED', 'Dismissed', 100, true, true, true),
  ('MIXED_RESULT', 'Mixed Result', 110, true, true, true)
ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final_stage = EXCLUDED.is_final_stage, is_milestone = EXCLUDED.is_milestone, is_active = true, updated_at = now();

CREATE OR REPLACE FUNCTION public.compute_current_case_state(p_case_id bigint)
RETURNS TABLE(case_status_code text, case_stage_code text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_unapproved_resolution_count integer;
  v_unfiled_for_filing_count integer;
  v_filed_for_filing_count integer;
  v_dismissal_count integer;
  v_active_assignment_count integer;
BEGIN
  SELECT count(*) INTO v_unapproved_resolution_count
  FROM public.case_resolutions cr
  WHERE cr.case_id = p_case_id
    AND cr.is_voided = false
    AND NOT EXISTS (
      SELECT 1 FROM public.case_resolution_approvals a
      WHERE a.case_resolution_id = cr.id AND a.is_voided = false
    );

  SELECT
    count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND EXISTS (
      SELECT 1 FROM public.case_court_filings cf
      WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false
    )),
    count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND NOT EXISTS (
      SELECT 1 FROM public.case_court_filings cf
      WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false
    )),
    count(*) FILTER (WHERE aa.decision_code = 'DISMISSAL')
  INTO v_filed_for_filing_count, v_unfiled_for_filing_count, v_dismissal_count
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id = aa.approval_id AND a.is_voided = false
  JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id AND cr.is_voided = false
  WHERE aa.case_id = p_case_id;

  SELECT count(*) INTO v_active_assignment_count
  FROM public.case_assignments ca
  WHERE ca.case_id = p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE;

  IF COALESCE(v_unapproved_resolution_count, 0) > 0 THEN
    IF COALESCE(v_filed_for_filing_count, 0) > 0 THEN
      RETURN QUERY SELECT 'PENDING'::text, 'FILED_OTHER_RESO_FOR_APPROVAL'::text;
    ELSE
      RETURN QUERY SELECT 'PENDING'::text, 'RESO_FOR_APPROVAL'::text;
    END IF;
  ELSIF COALESCE(v_unfiled_for_filing_count, 0) > 0 THEN
    IF COALESCE(v_filed_for_filing_count, 0) > 0 THEN
      RETURN QUERY SELECT 'PENDING'::text, 'FILED_OTHER_INFO_FOR_FILING'::text;
    ELSE
      RETURN QUERY SELECT 'PENDING'::text, 'FOR_FILING'::text;
    END IF;
  ELSIF COALESCE(v_filed_for_filing_count, 0) > 0 AND COALESCE(v_dismissal_count, 0) > 0 THEN
    RETURN QUERY SELECT 'MIXED_RESULT'::text, 'MIXED_RESULT'::text;
  ELSIF COALESCE(v_filed_for_filing_count, 0) > 0 THEN
    RETURN QUERY SELECT 'FILED'::text, 'FILED'::text;
  ELSIF COALESCE(v_dismissal_count, 0) > 0 THEN
    RETURN QUERY SELECT 'DISMISSED'::text, 'DISMISSED'::text;
  ELSIF COALESCE(v_active_assignment_count, 0) > 0 THEN
    RETURN QUERY SELECT 'PENDING'::text, 'CASE_RAFFLED'::text;
  ELSE
    RETURN QUERY SELECT 'PENDING'::text, 'FOR_RAFFLE'::text;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_case_state_recompute(
  p_case_id bigint,
  p_status_date date DEFAULT CURRENT_DATE,
  p_remarks text DEFAULT NULL,
  p_case_event_id bigint DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status_code text; v_stage_code text; v_status_id bigint; v_stage_id bigint;
  v_prev_legacy_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint;
BEGIN
  SELECT case_status_code, case_stage_code INTO v_status_code, v_stage_code FROM public.compute_current_case_state(p_case_id) LIMIT 1;
  SELECT id INTO v_status_id FROM public.case_statuses WHERE code = v_status_code;
  SELECT id INTO v_stage_id FROM public.case_stages WHERE code = v_stage_code;
  IF v_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status %', v_status_code; END IF;
  IF v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage %', v_stage_code; END IF;

  SELECT current_status_id, current_case_status_id, current_case_stage_id
  INTO v_prev_legacy_status_id, v_prev_case_status_id, v_prev_stage_id
  FROM public.case_private_details WHERE case_id = p_case_id;

  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at)
  VALUES (p_case_id,v_status_id,p_status_date,p_remarks,v_status_id,p_status_date,p_remarks,v_stage_id,p_status_date,p_remarks,now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();

  IF v_prev_case_status_id IS DISTINCT FROM v_status_id THEN
    INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
    VALUES (p_case_id,v_prev_case_status_id,v_status_id,p_user_id,now(),p_status_date,p_remarks,p_case_event_id);
  END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN
    INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
    VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_status_date,p_remarks,p_case_event_id);
  END IF;
END;
$$;
CREATE OR REPLACE FUNCTION public.record_case_resolved_event(
  p_case_id bigint,
  p_recommendation_code text,
  p_date_resolved date,
  p_time_resolved time without time zone DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_charges_for_filing jsonb DEFAULT '[]'::jsonb,
  p_charges_for_dismissal jsonb DEFAULT '[]'::jsonb,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_type_id bigint;
  v_pending_status_id bigint;
  v_reso_stage_id bigint;
  v_previous_case_status_id bigint;
  v_previous_stage_id bigint;
  v_event_id bigint;
  v_resolution_id bigint;
  v_status_history_id bigint;
  v_recommendation_label text;
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
  v_old_details jsonb;
  v_new_details jsonb;
  v_charge jsonb;
  v_display_order integer;
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_recommendation_code NOT IN ('CASE_FOR_FILING', 'CASE_DISMISSAL', 'MIXED_RESULT') THEN RAISE EXCEPTION 'Recommendation is required'; END IF;
  IF p_date_resolved IS NULL THEN RAISE EXCEPTION 'Date resolved is required'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active)
  VALUES ('CASE_RESOLVED', 'Case Resolved', 'CASE', 'Manual timeline event for resolving a case.', 120, true, true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, category = EXCLUDED.category, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, is_active = true, updated_at = now()
  RETURNING id INTO v_event_type_id;

  INSERT INTO public.case_statuses (code, display_label, sort_order, is_final, is_milestone, is_active)
  VALUES ('PENDING', 'Pending', 20, false, false, true)
  ON CONFLICT (code) DO UPDATE SET display_label = EXCLUDED.display_label, sort_order = EXCLUDED.sort_order, is_final = false, is_milestone = false, is_active = true
  RETURNING id INTO v_pending_status_id;

  SELECT id INTO v_reso_stage_id FROM public.case_stages WHERE code = 'RESO_FOR_APPROVAL' AND is_active IS TRUE LIMIT 1;
  IF v_reso_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage RESO_FOR_APPROVAL'; END IF;

  v_recommendation_label := CASE p_recommendation_code
    WHEN 'CASE_FOR_FILING' THEN 'Case for Filing'
    WHEN 'CASE_DISMISSAL' THEN 'Case Dismissal'
    ELSE 'Mixed Result'
  END;

  SELECT cpd.current_case_status_id, cpd.current_case_stage_id, to_jsonb(cpd)
  INTO v_previous_case_status_id, v_previous_stage_id, v_old_details
  FROM public.case_private_details cpd
  WHERE cpd.case_id = p_case_id;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description, status_id, case_status_id, case_stage_id,
    details_jsonb, source, created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id, v_event_type_id, p_date_resolved, p_time_resolved, 'Case Resolved',
    'Case resolved as ' || v_recommendation_label || ' on ' || to_char(p_date_resolved, 'Mon FMDD, YYYY'),
    v_pending_status_id, v_pending_status_id, v_reso_stage_id,
    jsonb_build_object('recommendation_code', p_recommendation_code, 'recommendation_label', v_recommendation_label, 'remarks', v_remarks),
    'MANUAL_ENTRY', p_user_id, p_user_id
  ) RETURNING id INTO v_event_id;

  INSERT INTO public.case_resolutions (case_id, case_event_id, recommendation_code, date_resolved, time_resolved, remarks, created_by_user_id, updated_by_user_id)
  VALUES (p_case_id, v_event_id, p_recommendation_code, p_date_resolved, p_time_resolved, v_remarks, p_user_id, p_user_id)
  RETURNING id INTO v_resolution_id;

  IF p_recommendation_code IN ('CASE_FOR_FILING', 'MIXED_RESULT') THEN
    v_display_order := 0;
    FOR v_charge IN SELECT * FROM jsonb_array_elements(COALESCE(p_charges_for_filing, '[]'::jsonb)) LOOP
      v_display_order := v_display_order + 1;
      IF NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), '') IS NOT NULL THEN
        INSERT INTO public.case_resolution_charge_actions (case_resolution_id, case_id, case_violation_id, violation_id, charge_text, action_code, display_order, remarks)
        VALUES (v_resolution_id, p_case_id, NULLIF(v_charge->>'case_violation_id', '')::bigint, NULLIF(v_charge->>'violation_id', '')::bigint, NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), ''), 'FOR_FILING', v_display_order, NULLIF(btrim(COALESCE(v_charge->>'remarks', '')), ''));
      END IF;
    END LOOP;
  END IF;

  IF p_recommendation_code IN ('CASE_DISMISSAL', 'MIXED_RESULT') THEN
    v_display_order := 0;
    FOR v_charge IN SELECT * FROM jsonb_array_elements(COALESCE(p_charges_for_dismissal, '[]'::jsonb)) LOOP
      v_display_order := v_display_order + 1;
      IF NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), '') IS NOT NULL THEN
        INSERT INTO public.case_resolution_charge_actions (case_resolution_id, case_id, case_violation_id, violation_id, charge_text, action_code, display_order, remarks)
        VALUES (v_resolution_id, p_case_id, NULLIF(v_charge->>'case_violation_id', '')::bigint, NULLIF(v_charge->>'violation_id', '')::bigint, NULLIF(btrim(COALESCE(v_charge->>'charge_text', v_charge #>> '{}')), ''), 'DISMISSAL', v_display_order, NULLIF(btrim(COALESCE(v_charge->>'remarks', '')), ''));
      END IF;
    END LOOP;
  END IF;

  UPDATE public.case_events
  SET source_table = 'case_resolutions',
      source_id = v_resolution_id,
      details_jsonb = details_jsonb || jsonb_build_object(
        'charge_actions',
        COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'id', cra.id,
            'action_code', cra.action_code,
            'charge_text', cra.charge_text,
            'display_order', cra.display_order,
            'remarks', cra.remarks
          ) ORDER BY cra.action_code, cra.display_order, cra.id)
          FROM public.case_resolution_charge_actions cra
          WHERE cra.case_resolution_id = v_resolution_id
        ), '[]'::jsonb)
      ),
      updated_by_user_id = p_user_id,
      updated_at = now()
  WHERE id = v_event_id;

  INSERT INTO public.case_private_details (case_id, current_status_id, current_status_date, current_status_remarks, current_case_status_id, current_case_status_date, current_case_status_remarks, current_case_stage_id, current_case_stage_date, current_case_stage_remarks, updated_at)
  VALUES (p_case_id, v_pending_status_id, p_date_resolved, v_remarks, v_pending_status_id, p_date_resolved, v_remarks, v_reso_stage_id, p_date_resolved, v_remarks, now())
  ON CONFLICT (case_id) DO UPDATE SET
    current_status_id = EXCLUDED.current_status_id,
    current_status_date = EXCLUDED.current_status_date,
    current_status_remarks = EXCLUDED.current_status_remarks,
    current_case_status_id = v_pending_status_id,
    current_case_status_date = p_date_resolved,
    current_case_status_remarks = v_remarks,
    current_case_stage_id = v_reso_stage_id,
    current_case_stage_date = p_date_resolved,
    current_case_stage_remarks = v_remarks,
    updated_at = now();

  IF v_previous_case_status_id IS DISTINCT FROM v_pending_status_id THEN
    INSERT INTO public.case_status_history (case_id, from_status_id, to_status_id, changed_by_user_id, changed_at, status_date, remarks, case_event_id)
    VALUES (p_case_id, v_previous_case_status_id, v_pending_status_id, p_user_id, now(), p_date_resolved, v_remarks, v_event_id)
    RETURNING id INTO v_status_history_id;
  END IF;

  IF v_previous_stage_id IS DISTINCT FROM v_reso_stage_id THEN
    INSERT INTO public.case_stage_history (case_id, from_stage_id, to_stage_id, changed_by_user_id, changed_at, stage_date, remarks, case_event_id)
    VALUES (p_case_id, v_previous_stage_id, v_reso_stage_id, p_user_id, now(), p_date_resolved, v_remarks, v_event_id);
  END IF;

  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (p_user_id, 'case_resolutions', v_resolution_id, 'CASE_RESOLVED', v_old_details, v_new_details, p_case_id, 'Case resolved as ' || v_recommendation_label || '.', jsonb_build_object('case_event_id', v_event_id, 'status_history_id', v_status_history_id, 'recommendation_code', p_recommendation_code));

  RETURN v_event_id;
END;
$$;
CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
  v_previous_assignment_id bigint; v_previous_assignment_old jsonb; v_previous_assignment_new jsonb;
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

  IF lower(coalesce(v_source_table,'')) = 'case_court_filings' OR v_event_type_code = 'COURT_FILING' THEN
    SELECT cf.id, to_jsonb(cf) INTO v_filing_id, v_filing_old FROM public.case_court_filings cf WHERE cf.id = v_source_id OR cf.case_event_id = p_case_event_id ORDER BY CASE WHEN cf.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_filing_id IS NOT NULL THEN
      UPDATE public.case_court_filings SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_filing_id;
      SELECT to_jsonb(cf) INTO v_filing_new FROM public.case_court_filings cf WHERE cf.id = v_filing_id;
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_voided_by_user_id,'case_court_filings',v_filing_id,'VOID_COURT_FILING_FROM_EVENT',v_filing_old,jsonb_build_object('court_filing',v_filing_new,'case_private_details',v_new_details),v_case_id,'Court filing voided and case status recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'status_history_id',v_status_history_id,'reason',p_void_reason,'recomputed_status_code',v_status_code));
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
    END IF;

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

  IF v_event_type_code IN ('CASE_RESOLVED','CASE_DECISION_APPROVED','COURT_FILING','CASE_ASSIGNMENT','CASE_REASSIGNMENT')
     OR lower(coalesce(v_source_table,'')) IN ('case_resolutions','case_resolution_approvals','case_court_filings','case_assignments') THEN
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


GRANT EXECUTE ON FUNCTION public.compute_current_case_state(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_case_state_recompute(bigint, date, text, bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_case_resolved_event(bigint, text, date, time without time zone, text, jsonb, jsonb, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.void_case_event(bigint, text, bigint) TO authenticated;

COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Verification coverage: recording CASE_RESOLVED yields PENDING/RESO_FOR_APPROVAL; voiding it recomputes CASE_RAFFLED when only assignment remains, FOR_RAFFLE with no assignment, RESO_FOR_APPROVAL when another resolution awaits approval, FOR_FILING when approved filing remains, and final FILED/DISMISSED/MIXED_RESULT from active linked resolution approvals and filings.';

-- Verification SQL (run in a seeded transaction and roll back):
-- 1. Recording CASE_RESOLVED -> current_case_status_code = PENDING and current_case_stage_code = RESO_FOR_APPROVAL.
-- 2. Void CASE_RESOLVED through public.void_case_event(); with only active assignment remaining -> PENDING / CASE_RAFFLED.
-- 3. Void CASE_RESOLVED through public.void_case_event(); with no active assignment -> PENDING / FOR_RAFFLE.
-- 4. Void CASE_RESOLVED while another active resolution has no active approval -> stage RESO_FOR_APPROVAL.
-- 5. Void CASE_RESOLVED while an active approval action decision_code = FOR_FILING has no active case_court_filings row -> stage FOR_FILING.
-- 6. With no unfinished workflow, public.compute_current_case_state(case_id) returns FILED/FILED when every FOR_FILING action is filed, DISMISSED/DISMISSED when only dismissal actions remain, and MIXED_RESULT/MIXED_RESULT when filed and dismissal outcomes coexist.

COMMIT;
