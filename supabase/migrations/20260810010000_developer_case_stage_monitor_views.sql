-- Developer-only case-stage monitoring read models.
-- Queue predicates intentionally mirror public.compute_current_case_state so
-- this dashboard and the case-detail timeline agree about pending work.

CREATE INDEX IF NOT EXISTS idx_case_resolution_approvals_resolution_active
  ON public.case_resolution_approvals (case_resolution_id)
  WHERE is_voided IS FALSE;

CREATE INDEX IF NOT EXISTS idx_case_motion_resolution_approvals_resolution_active
  ON public.case_motion_resolution_approvals (case_motion_resolution_id)
  WHERE is_voided IS FALSE;

CREATE INDEX IF NOT EXISTS idx_case_events_active_latest
  ON public.case_events (case_id, event_date DESC, event_time DESC, event_order DESC, id DESC)
  WHERE is_voided IS FALSE;

CREATE OR REPLACE VIEW public.v_developer_case_stage_monitor
WITH (security_invoker = true)
AS
WITH unapproved_case_resolutions AS (
  SELECT
    cr.case_id,
    count(*)::bigint AS pending_count,
    min(cr.date_resolved) AS oldest_pending_date
  FROM public.case_resolutions cr
  WHERE cr.is_voided IS FALSE
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_resolution_approvals approval
      WHERE approval.case_resolution_id = cr.id
        AND approval.is_voided IS FALSE
    )
  GROUP BY cr.case_id
), unfiled_filing_actions AS (
  SELECT
    action.case_id,
    count(*)::bigint AS pending_count,
    min(approval.date_approved) AS oldest_pending_date
  FROM public.case_resolution_approval_actions action
  JOIN public.case_resolution_approvals approval
    ON approval.id = action.approval_id
   AND approval.is_voided IS FALSE
  JOIN public.case_resolutions resolution
    ON resolution.id = approval.case_resolution_id
   AND resolution.is_voided IS FALSE
  WHERE action.decision_code = 'FOR_FILING'
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_court_filings filing
      WHERE filing.case_resolution_approval_action_id = action.id
        AND filing.is_voided IS FALSE
    )
  GROUP BY action.case_id
), unresolved_motions AS (
  SELECT
    motion.case_id,
    count(*)::bigint AS pending_count,
    min(COALESCE(motion.date_filed, motion.date_received, motion.created_at::date)) AS oldest_pending_date
  FROM public.case_motions motion
  JOIN public.case_events motion_event
    ON motion_event.id = motion.case_event_id
   AND motion_event.is_voided IS FALSE
  WHERE motion.is_voided IS FALSE
    AND motion.case_event_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_motion_resolutions resolution
      WHERE resolution.case_motion_id = motion.id
        AND resolution.is_voided IS FALSE
    )
  GROUP BY motion.case_id
), unapproved_motion_resolutions AS (
  SELECT
    resolution.case_id,
    count(DISTINCT resolution.id)::bigint AS pending_count,
    min(resolution.date_resolved) AS oldest_pending_date
  FROM public.case_motion_resolutions resolution
  JOIN public.case_motions motion
    ON motion.id = resolution.case_motion_id
   AND motion.is_voided IS FALSE
  JOIN public.case_events resolution_event
    ON resolution_event.id = resolution.case_event_id
   AND resolution_event.is_voided IS FALSE
  JOIN public.case_events motion_event
    ON motion_event.id = motion.case_event_id
   AND motion_event.is_voided IS FALSE
  WHERE resolution.is_voided IS FALSE
    AND NOT EXISTS (
      SELECT 1
      FROM public.case_motion_resolution_approvals approval
      JOIN public.case_events approval_event
        ON approval_event.id = approval.case_event_id
       AND approval_event.is_voided IS FALSE
      WHERE approval.case_motion_resolution_id = resolution.id
        AND approval.is_voided IS FALSE
    )
  GROUP BY resolution.case_id
), latest_event AS (
  SELECT DISTINCT ON (event.case_id)
    event.case_id,
    event.id AS event_id,
    event_type.code AS event_type_code,
    event_type.display_label AS event_type_label,
    event.title,
    event.event_date,
    event.event_time,
    COALESCE(
      event.event_date + COALESCE(event.event_time, time '00:00'),
      event.created_at AT TIME ZONE 'Asia/Manila'
    ) AS event_at
  FROM public.case_events event
  JOIN public.case_event_types event_type ON event_type.id = event.event_type_id
  WHERE event.is_voided IS FALSE
  ORDER BY
    event.case_id,
    event.event_date DESC NULLS LAST,
    event.event_time DESC NULLS LAST,
    event.event_order DESC,
    event.id DESC
), monitor_base AS (
  SELECT
    detail.id AS case_id,
    detail.docket_display_number,
    detail.date_received,
    greatest(current_date - detail.date_received, 0) AS case_age_days,
    detail.case_classification_label,
    detail.violations,
    detail.current_case_status_id,
    detail.current_case_status_code,
    detail.current_case_status_label,
    detail.current_case_status_date,
    detail.current_case_status_remarks,
    detail.current_case_stage_id,
    detail.current_case_stage_code,
    detail.current_case_stage_label,
    detail.current_case_stage_date,
    detail.current_case_stage_remarks,
    stage.sort_order AS current_case_stage_sort_order,
    stage.is_final_stage,
    stage.is_milestone,
    greatest(current_date - COALESCE(detail.current_case_stage_date, detail.date_received), 0) AS days_in_current_stage,
    detail.current_prosecutor_id,
    COALESCE(detail.prosecutor_full_name, detail.prosecutor_short_name) AS prosecutor_display,
    detail.current_assigned_at,
    COALESCE(case_resolution.pending_count, 0)::bigint AS unapproved_case_resolution_count,
    case_resolution.oldest_pending_date AS oldest_unapproved_case_resolution_date,
    COALESCE(filing.pending_count, 0)::bigint AS unfiled_for_filing_count,
    filing.oldest_pending_date AS oldest_unfiled_for_filing_date,
    COALESCE(motion.pending_count, 0)::bigint AS unresolved_motion_count,
    motion.oldest_pending_date AS oldest_unresolved_motion_date,
    COALESCE(motion_resolution.pending_count, 0)::bigint AS unapproved_motion_resolution_count,
    motion_resolution.oldest_pending_date AS oldest_unapproved_motion_resolution_date,
    latest.event_id AS latest_event_id,
    latest.event_type_code AS latest_event_type_code,
    latest.event_type_label AS latest_event_type_label,
    latest.title AS latest_event_title,
    latest.event_date AS latest_event_date,
    latest.event_time AS latest_event_time,
    latest.event_at AS latest_event_at
  FROM public.v_case_details_page detail
  LEFT JOIN public.case_stages stage ON stage.id = detail.current_case_stage_id
  LEFT JOIN unapproved_case_resolutions case_resolution ON case_resolution.case_id = detail.id
  LEFT JOIN unfiled_filing_actions filing ON filing.case_id = detail.id
  LEFT JOIN unresolved_motions motion ON motion.case_id = detail.id
  LEFT JOIN unapproved_motion_resolutions motion_resolution ON motion_resolution.case_id = detail.id
  LEFT JOIN latest_event latest ON latest.case_id = detail.id
  WHERE public.has_app_role('DEVELOPER')
    AND detail.is_archived IS FALSE
)
SELECT
  monitor_base.*,
  (monitor_base.current_prosecutor_id IS NULL) AS has_no_active_prosecutor,
  (monitor_base.unapproved_case_resolution_count > 0) AS has_unapproved_case_resolution,
  (monitor_base.unfiled_for_filing_count > 0) AS has_unfiled_for_filing,
  (monitor_base.unresolved_motion_count > 0) AS has_unresolved_motion,
  (monitor_base.unapproved_motion_resolution_count > 0) AS has_unapproved_motion_resolution,
  (monitor_base.current_case_stage_code = 'PENDING_PETREV') AS is_pending_petition_for_review,
  (
    monitor_base.current_prosecutor_id IS NULL
    OR monitor_base.unapproved_case_resolution_count > 0
    OR monitor_base.unfiled_for_filing_count > 0
    OR monitor_base.unresolved_motion_count > 0
    OR monitor_base.unapproved_motion_resolution_count > 0
    OR monitor_base.current_case_stage_code = 'PENDING_PETREV'
  ) AS has_attention,
  (
    CASE WHEN monitor_base.current_prosecutor_id IS NULL THEN 1 ELSE 0 END
    + monitor_base.unapproved_case_resolution_count
    + monitor_base.unfiled_for_filing_count
    + monitor_base.unresolved_motion_count
    + monitor_base.unapproved_motion_resolution_count
    + CASE WHEN monitor_base.current_case_stage_code = 'PENDING_PETREV' THEN 1 ELSE 0 END
  )::bigint AS attention_item_count,
  LEAST(
    CASE WHEN monitor_base.current_prosecutor_id IS NULL THEN monitor_base.date_received ELSE NULL END,
    monitor_base.oldest_unapproved_case_resolution_date,
    monitor_base.oldest_unfiled_for_filing_date,
    monitor_base.oldest_unresolved_motion_date,
    monitor_base.oldest_unapproved_motion_resolution_date,
    CASE WHEN monitor_base.current_case_stage_code = 'PENDING_PETREV' THEN monitor_base.current_case_stage_date ELSE NULL END
  ) AS oldest_attention_date,
  -- New view columns must be appended for CREATE OR REPLACE VIEW compatibility.
  case_record.docket_year,
  case_record.docket_type_id,
  docket_type.prefix AS docket_type_prefix,
  docket_type.name AS docket_type_name
FROM monitor_base
JOIN public.cases case_record ON case_record.id = monitor_base.case_id
JOIN public.docket_types docket_type ON docket_type.id = case_record.docket_type_id;

CREATE OR REPLACE VIEW public.v_developer_case_stage_monitor_overview
WITH (security_invoker = true)
AS
SELECT
  count(*)::bigint AS total_active_case_count,
  count(*) FILTER (WHERE monitor.has_attention)::bigint AS attention_case_count,
  count(*) FILTER (WHERE monitor.has_no_active_prosecutor)::bigint AS unassigned_prosecutor_count,
  count(*) FILTER (WHERE monitor.has_unapproved_case_resolution)::bigint AS unapproved_case_resolution_count,
  count(*) FILTER (WHERE monitor.has_unfiled_for_filing)::bigint AS unfiled_for_filing_count,
  count(*) FILTER (WHERE monitor.has_unresolved_motion)::bigint AS unresolved_motion_count,
  count(*) FILTER (WHERE monitor.has_unapproved_motion_resolution)::bigint AS unapproved_motion_resolution_count,
  count(*) FILTER (WHERE monitor.is_pending_petition_for_review)::bigint AS pending_petition_for_review_count,
  min(monitor.oldest_attention_date) AS oldest_attention_date,
  max(monitor.latest_event_at) AS latest_event_at,
  -- Keep new dimensions after every pre-existing overview column.
  monitor.docket_year,
  monitor.docket_type_id,
  monitor.docket_type_prefix,
  monitor.docket_type_name
FROM public.v_developer_case_stage_monitor monitor
WHERE public.has_app_role('DEVELOPER')
GROUP BY GROUPING SETS (
  (
    monitor.docket_year,
    monitor.docket_type_id,
    monitor.docket_type_prefix,
    monitor.docket_type_name
  ),
  (monitor.docket_year),
  (
    monitor.docket_type_id,
    monitor.docket_type_prefix,
    monitor.docket_type_name
  ),
  ()
)
HAVING public.has_app_role('DEVELOPER')
ORDER BY
  monitor.docket_year DESC NULLS FIRST,
  monitor.docket_type_name NULLS FIRST,
  monitor.docket_type_prefix NULLS FIRST;

CREATE OR REPLACE VIEW public.v_developer_case_stage_distribution
WITH (security_invoker = true)
AS
SELECT
  COALESCE(monitor.current_case_stage_code, 'UNSPECIFIED') AS stage_code,
  COALESCE(monitor.current_case_stage_label, 'Unspecified stage') AS stage_label,
  COALESCE(monitor.current_case_stage_sort_order, 2147483647) AS stage_sort_order,
  bool_or(COALESCE(monitor.is_final_stage, false)) AS is_final_stage,
  count(*)::bigint AS case_count,
  count(*) FILTER (WHERE monitor.has_attention)::bigint AS attention_case_count,
  max(monitor.latest_event_at) AS latest_event_at,
  -- Keep new dimensions after every pre-existing distribution column.
  monitor.docket_year,
  monitor.docket_type_id,
  monitor.docket_type_prefix,
  monitor.docket_type_name
FROM public.v_developer_case_stage_monitor monitor
WHERE public.has_app_role('DEVELOPER')
GROUP BY GROUPING SETS (
  (
    monitor.docket_year,
    monitor.docket_type_id,
    monitor.docket_type_prefix,
    monitor.docket_type_name,
    COALESCE(monitor.current_case_stage_code, 'UNSPECIFIED'),
    COALESCE(monitor.current_case_stage_label, 'Unspecified stage'),
    COALESCE(monitor.current_case_stage_sort_order, 2147483647)
  ),
  (
    monitor.docket_year,
    COALESCE(monitor.current_case_stage_code, 'UNSPECIFIED'),
    COALESCE(monitor.current_case_stage_label, 'Unspecified stage'),
    COALESCE(monitor.current_case_stage_sort_order, 2147483647)
  ),
  (
    monitor.docket_type_id,
    monitor.docket_type_prefix,
    monitor.docket_type_name,
    COALESCE(monitor.current_case_stage_code, 'UNSPECIFIED'),
    COALESCE(monitor.current_case_stage_label, 'Unspecified stage'),
    COALESCE(monitor.current_case_stage_sort_order, 2147483647)
  ),
  (
    COALESCE(monitor.current_case_stage_code, 'UNSPECIFIED'),
    COALESCE(monitor.current_case_stage_label, 'Unspecified stage'),
    COALESCE(monitor.current_case_stage_sort_order, 2147483647)
  )
)
ORDER BY
  monitor.docket_year DESC NULLS FIRST,
  monitor.docket_type_name NULLS FIRST,
  monitor.docket_type_prefix NULLS FIRST,
  stage_sort_order,
  stage_label;

REVOKE ALL ON TABLE public.v_developer_case_stage_monitor FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v_developer_case_stage_monitor_overview FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v_developer_case_stage_distribution FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE public.v_developer_case_stage_monitor TO authenticated, service_role;
GRANT SELECT ON TABLE public.v_developer_case_stage_monitor_overview TO authenticated, service_role;
GRANT SELECT ON TABLE public.v_developer_case_stage_distribution TO authenticated, service_role;

COMMENT ON VIEW public.v_developer_case_stage_monitor IS
  'Developer-only active-case stage monitor with actionable queue flags derived from the canonical case workflow.';
COMMENT ON VIEW public.v_developer_case_stage_monitor_overview IS
  'Developer-only case-stage monitoring totals and oldest outstanding workflow date.';
COMMENT ON VIEW public.v_developer_case_stage_distribution IS
  'Developer-only active-case counts grouped by current workflow stage.';
