BEGIN;

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
  v_manual_status_code text;
  v_manual_stage_code text;
BEGIN
  -- 1. Unfinished motion workflow overrides any explicit state-changing approval.
  SELECT count(*) INTO v_motion_resolution_for_approval_count
  FROM public.case_motion_resolutions cmr
  JOIN public.case_motions cm ON cm.id = cmr.case_motion_id AND cm.is_voided = false
  JOIN public.case_events resolved_event ON resolved_event.id = cmr.case_event_id AND resolved_event.is_voided = false
  JOIN public.case_events received_event ON received_event.id = cm.case_event_id AND received_event.is_voided = false
  WHERE cmr.case_id = p_case_id
    AND cmr.is_voided = false
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_motion_resolution_approvals cmra
      JOIN public.case_events approval_event ON approval_event.id = cmra.case_event_id AND approval_event.is_voided = false
      WHERE cmra.case_motion_resolution_id = cmr.id
        AND cmra.is_voided = false
    );

  SELECT count(*) INTO v_pending_motion_count
  FROM public.case_motions cm
  JOIN public.case_events received_event ON received_event.id = cm.case_event_id AND received_event.is_voided = false
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

  -- 2. Preserve existing unfinished main-case workflow priority before explicit final/manual states.
  SELECT count(*) INTO v_unapproved_resolution_count
  FROM public.case_resolutions cr
  WHERE cr.case_id = p_case_id
    AND cr.is_voided = false
    AND NOT EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id = cr.id AND a.is_voided = false);

  SELECT
    count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false)),
    count(*) FILTER (WHERE aa.decision_code = 'FOR_FILING' AND NOT EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id = aa.id AND cf.is_voided = false)),
    count(*) FILTER (WHERE aa.decision_code = 'DISMISSAL')
  INTO v_filed_for_filing_count, v_unfiled_for_filing_count, v_dismissal_count
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id = aa.approval_id AND a.is_voided = false
  JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id AND cr.is_voided = false
  WHERE aa.case_id = p_case_id;

  IF COALESCE(v_unapproved_resolution_count, 0) > 0 THEN
    IF COALESCE(v_filed_for_filing_count, 0) > 0 THEN
      RETURN QUERY SELECT 'PENDING'::text, 'FILED_OTHER_RESO_FOR_APPROVAL'::text;
    ELSE
      RETURN QUERY SELECT 'PENDING'::text, 'RESO_FOR_APPROVAL'::text;
    END IF;
    RETURN;
  ELSIF COALESCE(v_unfiled_for_filing_count, 0) > 0 THEN
    IF COALESCE(v_filed_for_filing_count, 0) > 0 THEN
      RETURN QUERY SELECT 'PENDING'::text, 'FILED_OTHER_INFO_FOR_FILING'::text;
    ELSE
      RETURN QUERY SELECT 'PENDING'::text, 'FOR_FILING'::text;
    END IF;
    RETURN;
  END IF;

  -- 3. Latest active explicit state-changing Motion Decision Approved event behaves like a stack.
  SELECT cs.code, cst.code INTO v_manual_status_code, v_manual_stage_code
  FROM public.case_motion_resolution_approvals cmra
  JOIN public.case_events ce ON ce.id = cmra.case_event_id AND ce.is_voided = false
  JOIN public.case_statuses cs ON cs.id = cmra.selected_case_status_id AND cs.is_active IS TRUE
  JOIN public.case_stages cst ON cst.id = cmra.selected_case_stage_id AND cst.is_active IS TRUE
  JOIN public.case_motion_resolutions cmr ON cmr.id = cmra.case_motion_resolution_id AND cmr.is_voided = false
  JOIN public.case_events resolved_event ON resolved_event.id = cmr.case_event_id AND resolved_event.is_voided = false
  JOIN public.case_motions cm ON cm.id = cmra.case_motion_id AND cm.id = cmr.case_motion_id AND cm.is_voided = false
  JOIN public.case_events received_event ON received_event.id = cm.case_event_id AND received_event.is_voided = false
  WHERE cmra.case_id = p_case_id
    AND cmra.is_voided = false
    AND cmra.updates_case_status = true
    AND cmra.selected_case_status_id IS NOT NULL
    AND cmra.selected_case_stage_id IS NOT NULL
  ORDER BY cmra.date_approved DESC NULLS LAST, cmra.time_approved DESC NULLS LAST, cmra.case_event_id DESC, cmra.id DESC
  LIMIT 1;

  IF v_manual_status_code IS NOT NULL AND v_manual_stage_code IS NOT NULL THEN
    RETURN QUERY SELECT v_manual_status_code, v_manual_stage_code;
    RETURN;
  END IF;

  -- 4. Existing final-outcome and fallback hierarchy remains unchanged.
  SELECT count(*) INTO v_active_assignment_count
  FROM public.case_assignments ca
  WHERE ca.case_id = p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE;

  IF COALESCE(v_filed_for_filing_count, 0) > 0 AND COALESCE(v_dismissal_count, 0) > 0 THEN
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

COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Motion-aware recompute priority: unfinished motion workflow, unfinished main-case workflow, latest active explicit Motion Decision Approved selected status/stage ordered by date_approved DESC, time_approved DESC NULLS LAST, case_event_id DESC, approval id DESC, then existing final/fallback hierarchy.';

-- Verification SQL/comments:
-- 1. Approval A with updates_case_status=true and FILED/FILED survives unrelated public.apply_case_state_recompute(...) calls while no unfinished higher-priority workflow exists.
-- 2. Later Approval B with updates_case_status=true and DISMISSED/DISMISSED supersedes Approval A by date_approved DESC, time_approved DESC NULLS LAST, case_event_id DESC, id DESC.
-- 3. Voiding Approval B reveals Approval A again; voiding Approval A falls through to the automatic final/fallback hierarchy.
-- 4. A new active Motion Received or active unapproved Motion Resolution temporarily returns PENDING/MOTION_PENDING or PENDING/MOTION_RESO_FOR_APPROVAL before the explicit state stack.
-- 5. Active unapproved Case Resolution and active unfiled FOR_FILING case workflow still override explicit motion approval states with their existing pending stages.
-- 6. Voided approvals, voided approval events, voided Motion Resolutions, voided Motion Received records, incomplete selected status/stage, updates_case_status=false rows, and inactive selected seeds are ignored.
-- 7. Status/stage history conditional behavior remains delegated to public.apply_case_state_recompute(...), which invokes this function once per trigger.

COMMIT;
