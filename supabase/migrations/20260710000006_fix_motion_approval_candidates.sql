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
  SELECT cs.code, cst.code INTO v_manual_status_code, v_manual_stage_code
  FROM public.case_motion_resolution_approvals cmra
  JOIN public.case_events ce ON ce.id = cmra.case_event_id AND ce.is_voided = false
  JOIN public.case_statuses cs ON cs.id = cmra.selected_case_status_id AND cs.is_active IS TRUE
  JOIN public.case_stages cst ON cst.id = cmra.selected_case_stage_id AND cst.is_active IS TRUE
  JOIN public.case_motion_resolutions cmr ON cmr.id = cmra.case_motion_resolution_id AND cmr.is_voided = false
  JOIN public.case_motions cm ON cm.id = cmra.case_motion_id AND cm.is_voided = false
  WHERE cmra.case_id = p_case_id
    AND cmra.is_voided = false
    AND cmra.updates_case_status = true
    AND cmra.selected_case_status_id IS NOT NULL
    AND cmra.selected_case_stage_id IS NOT NULL
  ORDER BY cmra.date_approved DESC NULLS LAST, cmra.time_approved DESC NULLS LAST, ce.event_date DESC NULLS LAST, ce.event_time DESC NULLS LAST, ce.id DESC, cmra.id DESC
  LIMIT 1;

  IF v_manual_status_code IS NOT NULL AND v_manual_stage_code IS NOT NULL THEN
    RETURN QUERY SELECT v_manual_status_code, v_manual_stage_code;
    RETURN;
  END IF;

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

DROP VIEW IF EXISTS public.v_case_motion_resolutions_detail;
CREATE VIEW public.v_case_motion_resolutions_detail AS
SELECT
  cmr.id,
  cmr.case_id,
  cmr.case_motion_id,
  cmr.case_event_id,
  cmr.recommendation_id,
  rr.code AS recommendation_code,
  rr.display_label AS recommendation_label,
  cmr.date_resolved,
  cmr.time_resolved,
  cmr.remarks,
  cmr.is_voided,
  cm.motion_title,
  cm.filed_by,
  cm.filed_by_code,
  cm.date_filed,
  cm.assigned_prosecutor_id,
  coalesce(ap.short_name, ap.full_name) AS assigned_prosecutor_name,
  NULL::bigint AS active_motion_decision_approval_id
FROM public.case_motion_resolutions cmr
JOIN public.case_events resolved_event ON resolved_event.id = cmr.case_event_id AND resolved_event.is_voided = false
JOIN public.case_motions cm ON cm.id = cmr.case_motion_id AND cm.is_voided = false
JOIN public.case_events received_event ON received_event.id = cm.case_event_id AND received_event.is_voided = false
LEFT JOIN public.prosecutors ap ON ap.id = cm.assigned_prosecutor_id
LEFT JOIN public.motion_resolution_recommendations rr ON rr.id = cmr.recommendation_id
WHERE cmr.is_voided = false
  AND NOT EXISTS (
    SELECT 1
    FROM public.case_motion_resolution_approvals cmra
    JOIN public.case_events approval_event ON approval_event.id = cmra.case_event_id AND approval_event.is_voided = false
    WHERE cmra.case_motion_resolution_id = cmr.id
      AND cmra.is_voided = false
  );
GRANT SELECT ON public.v_case_motion_resolutions_detail TO authenticated, service_role;

COMMENT ON VIEW public.v_case_motion_resolutions_detail IS 'Eligible Motion Resolution approval candidates only. Uses exact active linked records and ignores voided historical approvals; does not use case_motions legacy date/status fields for eligibility.';
COMMENT ON FUNCTION public.compute_current_case_state(bigint) IS 'Motion-aware exact-record priority with active manual Motion Decision Approval status/stage preservation; active unapproved motion resolutions ignore voided approvals and return PENDING/MOTION_RESO_FOR_APPROVAL.';

-- Verification SQL/comments:
-- 1. Create Motion Received, then Motion Resolved; v_case_motion_resolutions_detail returns that Motion Resolution.
-- 2. Create Motion Decision Approved; v_case_motion_resolutions_detail no longer returns that exact resolution while approval row and event are active.
-- 3. Void Motion Decision Approved; case_motion_resolution_approvals.is_voided=true and the case_event is voided, while case_motion_resolutions.is_voided=false and date_resolved/time_resolved/recommendation_id remain unchanged.
-- 4. After voiding the approval, public.compute_current_case_state(case_id) returns PENDING / MOTION_RESO_FOR_APPROVAL and v_case_motion_resolutions_detail returns the same Motion Resolution again.
-- 5. A second approval can be recorded after the first approval is voided; voided historical approvals do not block eligibility.
-- 6. One active approval per Motion Resolution remains enforced by case_motion_resolution_approvals_one_active_uidx.
-- 7. An active approval with updates_case_status=true and selected status/stage remains the recompute output until that approval is voided; voiding it restores PENDING / MOTION_RESO_FOR_APPROVAL for the still-active Motion Resolution.

COMMIT;
