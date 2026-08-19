CREATE OR REPLACE FUNCTION public.compute_current_case_state(
  p_case_id bigint
)
RETURNS TABLE(case_status_code text, case_stage_code text)
LANGUAGE plpgsql
AS $function$
DECLARE
  v_active_petition_count integer;
  v_petition_status_code text;
  v_petition_stage_code text;

  v_motion_resolution_for_approval_count integer;
  v_pending_motion_count integer;
  v_unapproved_resolution_count integer;
  v_unfiled_for_filing_count integer;
  v_filed_for_filing_count integer;
  v_dismissal_count integer;
  v_active_assignment_count integer;

  v_explicit_status_code text;
  v_explicit_stage_code text;
  v_explicit_event_date date;
  v_explicit_event_time time without time zone;
  v_explicit_case_event_id bigint;

  v_automatic_status_code text;
  v_automatic_stage_code text;
  v_automatic_event_date date;
  v_automatic_event_time time without time zone;
  v_automatic_case_event_id bigint;
BEGIN
  SELECT count(*)
  INTO v_active_petition_count
  FROM public.case_petitions_for_review p
  JOIN public.case_events ce
    ON ce.id = p.case_event_id
   AND ce.is_voided = false
  WHERE p.case_id = p_case_id
    AND p.is_voided = false;

  SELECT cs.code, cst.code
  INTO v_petition_status_code, v_petition_stage_code
  FROM public.case_petition_for_review_updates u
  JOIN public.case_petitions_for_review p
    ON p.id = u.petition_for_review_id
   AND p.is_voided = false
  JOIN public.case_events pe
    ON pe.id = p.case_event_id
   AND pe.is_voided = false
  JOIN public.case_statuses cs
    ON cs.id = u.selected_case_status_id
   AND cs.is_active IS TRUE
  JOIN public.case_stages cst
    ON cst.id = u.selected_case_stage_id
   AND cst.is_active IS TRUE
  WHERE u.case_id = p_case_id
    AND u.is_voided = false
    AND u.updates_case_status = true
  ORDER BY u.status_date DESC, pe.id DESC, u.id DESC
  LIMIT 1;

  SELECT count(*)
  INTO v_motion_resolution_for_approval_count
  FROM public.case_motion_resolutions cmr
  JOIN public.case_motions cm
    ON cm.id = cmr.case_motion_id
   AND cm.is_voided = false
  JOIN public.case_events re
    ON re.id = cmr.case_event_id
   AND re.is_voided = false
  JOIN public.case_events me
    ON me.id = cm.case_event_id
   AND me.is_voided = false
  WHERE cmr.case_id = p_case_id
    AND cmr.is_voided = false
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_motion_resolution_approvals a
      JOIN public.case_events ae
        ON ae.id = a.case_event_id
       AND ae.is_voided = false
      WHERE a.case_motion_resolution_id = cmr.id
        AND a.is_voided = false
    );

  SELECT count(*)
  INTO v_pending_motion_count
  FROM public.case_motions cm
  JOIN public.case_events ce
    ON ce.id = cm.case_event_id
   AND ce.is_voided = false
  WHERE cm.case_id = p_case_id
    AND cm.is_voided = false
    AND cm.case_event_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_motion_resolutions cmr
      WHERE cmr.case_motion_id = cm.id
        AND cmr.is_voided = false
    );

  IF COALESCE(v_motion_resolution_for_approval_count, 0) > 0 THEN
    RETURN QUERY SELECT 'PENDING'::text, 'MOTION_RESO_FOR_APPROVAL'::text;
    RETURN;
  ELSIF COALESCE(v_pending_motion_count, 0) > 0 THEN
    RETURN QUERY SELECT 'PENDING'::text, 'MOTION_PENDING'::text;
    RETURN;
  END IF;

  SELECT count(*)
  INTO v_unapproved_resolution_count
  FROM public.case_resolutions cr
  WHERE cr.case_id = p_case_id
    AND cr.is_voided = false
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_resolution_approvals a
      WHERE a.case_resolution_id = cr.id
        AND a.is_voided = false
    );

  SELECT
    count(*) FILTER (
      WHERE aa.decision_code = 'FOR_FILING'
        AND EXISTS (
          SELECT 1 FROM public.case_court_filings cf
          WHERE cf.case_resolution_approval_action_id = aa.id
            AND cf.is_voided = false
        )
    ),
    count(*) FILTER (
      WHERE aa.decision_code = 'FOR_FILING'
        AND NOT EXISTS (
          SELECT 1 FROM public.case_court_filings cf
          WHERE cf.case_resolution_approval_action_id = aa.id
            AND cf.is_voided = false
        )
    ),
    count(*) FILTER (WHERE aa.decision_code = 'DISMISSAL')
  INTO v_filed_for_filing_count, v_unfiled_for_filing_count, v_dismissal_count
  FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a
    ON a.id = aa.approval_id
   AND a.is_voided = false
  JOIN public.case_resolutions cr
    ON cr.id = a.case_resolution_id
   AND cr.is_voided = false
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

  IF COALESCE(v_active_petition_count, 0) > 0 AND v_petition_status_code IS NULL THEN
    RETURN QUERY SELECT 'PENDING'::text, 'PENDING_PETREV'::text;
    RETURN;
  END IF;

  SELECT explicit_state.status_code,
         explicit_state.stage_code,
         explicit_state.event_date,
         explicit_state.event_time,
         explicit_state.case_event_id
  INTO v_explicit_status_code,
       v_explicit_stage_code,
       v_explicit_event_date,
       v_explicit_event_time,
       v_explicit_case_event_id
  FROM (
    SELECT cs.code AS status_code, cst.code AS stage_code, ce.event_date, ce.event_time,
           ce.id AS case_event_id, msu.id AS source_id
    FROM public.case_manual_status_updates msu
    JOIN public.case_events ce ON ce.id = msu.case_event_id AND ce.is_voided = false
    JOIN public.case_event_types cet ON cet.id = ce.event_type_id AND cet.code = 'CASE_STATUS_UPDATED'
    JOIN public.case_statuses cs ON cs.id = msu.selected_case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id = msu.selected_case_stage_id AND cst.is_active IS TRUE
    WHERE msu.case_id = p_case_id
      AND msu.is_voided = false
      AND (COALESCE(v_active_petition_count, 0) = 0 OR v_petition_status_code IS NOT NULL)

    UNION ALL

    SELECT cs.code, cst.code, ce.event_date, ce.event_time, ce.id, a.id
    FROM public.case_motion_resolution_approvals a
    JOIN public.case_events ce ON ce.id = a.case_event_id AND ce.is_voided = false
    JOIN public.case_statuses cs ON cs.id = a.selected_case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id = a.selected_case_stage_id AND cst.is_active IS TRUE
    WHERE a.case_id = p_case_id
      AND a.is_voided = false
      AND a.updates_case_status = true
      AND a.selected_case_status_id IS NOT NULL
      AND a.selected_case_stage_id IS NOT NULL

    UNION ALL

    SELECT cs.code, cst.code, u.status_date, NULL::time without time zone, pe.id, u.id
    FROM public.case_petition_for_review_updates u
    JOIN public.case_petitions_for_review p ON p.id = u.petition_for_review_id AND p.is_voided = false
    JOIN public.case_events pe ON pe.id = p.case_event_id AND pe.is_voided = false
    JOIN public.case_statuses cs ON cs.id = u.selected_case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id = u.selected_case_stage_id AND cst.is_active IS TRUE
    WHERE u.case_id = p_case_id
      AND u.is_voided = false
      AND u.updates_case_status = true

    UNION ALL

    SELECT cs.code, cst.code, ce.event_date, ce.event_time, ce.id, ce.id
    FROM public.case_events ce
    JOIN public.case_event_types cet ON cet.id = ce.event_type_id AND cet.code = 'CUSTOM_EVENT'
    JOIN public.case_statuses cs ON cs.id = ce.case_status_id AND cs.is_active IS TRUE
    JOIN public.case_stages cst ON cst.id = ce.case_stage_id AND cst.is_active IS TRUE
    WHERE ce.case_id = p_case_id
      AND ce.is_voided = false
      AND COALESCE((ce.details_jsonb ->> 'updates_case_status')::boolean, false) = true
  ) explicit_state
  ORDER BY explicit_state.event_date DESC,
           explicit_state.event_time DESC NULLS LAST,
           explicit_state.case_event_id DESC,
           explicit_state.source_id DESC
  LIMIT 1;

  SELECT count(*)
  INTO v_active_assignment_count
  FROM public.case_assignments ca
  WHERE ca.case_id = p_case_id
    AND ca.unassigned_at IS NULL
    AND ca.is_voided IS FALSE;

  IF COALESCE(v_filed_for_filing_count, 0) > 0 AND COALESCE(v_dismissal_count, 0) > 0 THEN
    v_automatic_status_code := 'MIXED_RESULT';
    v_automatic_stage_code := 'MIXED_RESULT';
  ELSIF COALESCE(v_filed_for_filing_count, 0) > 0 THEN
    v_automatic_status_code := 'FILED';
    v_automatic_stage_code := 'FILED';
  ELSIF COALESCE(v_dismissal_count, 0) > 0 THEN
    v_automatic_status_code := 'DISMISSED';
    v_automatic_stage_code := 'DISMISSED';
  ELSIF COALESCE(v_active_assignment_count, 0) > 0 THEN
    v_automatic_status_code := 'PENDING';
    v_automatic_stage_code := 'CASE_RAFFLED';
  ELSE
    v_automatic_status_code := 'PENDING';
    v_automatic_stage_code := 'FOR_RAFFLE';
  END IF;

  SELECT automatic_state.event_date, automatic_state.event_time, automatic_state.case_event_id
  INTO v_automatic_event_date, v_automatic_event_time, v_automatic_case_event_id
  FROM (
    SELECT ce.event_date, ce.event_time, ce.id AS case_event_id
    FROM public.case_court_filings cf
    JOIN public.case_events ce ON ce.id = cf.case_event_id AND ce.is_voided = false
    WHERE cf.case_id = p_case_id
      AND cf.is_voided = false
      AND v_automatic_status_code IN ('FILED', 'MIXED_RESULT')

    UNION ALL

    SELECT ce.event_date, ce.event_time, ce.id
    FROM public.case_resolution_approval_actions aa
    JOIN public.case_resolution_approvals a ON a.id = aa.approval_id AND a.is_voided = false
    JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id AND cr.is_voided = false
    JOIN public.case_events ce ON ce.id = a.case_event_id AND ce.is_voided = false
    WHERE aa.case_id = p_case_id
      AND aa.decision_code = 'DISMISSAL'
      AND v_automatic_status_code IN ('DISMISSED', 'MIXED_RESULT')

    UNION ALL

    SELECT ce.event_date, ce.event_time, ce.id
    FROM public.case_assignments ca
    JOIN public.case_events ce ON ce.id = ca.case_event_id AND ce.is_voided = false
    WHERE ca.case_id = p_case_id
      AND ca.unassigned_at IS NULL
      AND ca.is_voided IS FALSE
      AND v_automatic_stage_code = 'CASE_RAFFLED'
  ) automatic_state
  ORDER BY automatic_state.event_date DESC,
           automatic_state.event_time DESC NULLS LAST,
           automatic_state.case_event_id DESC
  LIMIT 1;

  IF v_explicit_status_code IS NOT NULL
     AND (
       v_automatic_event_date IS NULL
       OR (v_explicit_event_date, COALESCE(v_explicit_event_time, '00:00:00'::time), v_explicit_case_event_id)
          >= (v_automatic_event_date, COALESCE(v_automatic_event_time, '00:00:00'::time), v_automatic_case_event_id)
     ) THEN
    RETURN QUERY SELECT v_explicit_status_code, v_explicit_stage_code;
  ELSE
    RETURN QUERY SELECT v_automatic_status_code, v_automatic_stage_code;
  END IF;
END;
$function$;
