-- Developer-only read models for the audit-log screen.
-- UI route guards are not a security boundary, so every view also checks the
-- authenticated application role inside Postgres.

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
  ON public.audit_logs (created_at DESC);

CREATE OR REPLACE VIEW public.v_developer_audit_logs
WITH (security_invoker = true)
AS
SELECT
  al.id,
  al.created_at,
  al.actor_user_id,
  CASE
    WHEN NULLIF(btrim(u.email), '') IS NOT NULL THEN u.email
    WHEN al.actor_user_id IS NOT NULL THEN 'User #' || al.actor_user_id::text
    ELSE 'System'
  END AS actor_display,
  u.email AS actor_email,
  al.case_id,
  CASE
    WHEN c.id IS NULL THEN NULL
    ELSE concat_ws(
      '-',
      NULLIF(btrim(c.region_code), ''),
      dt.prefix,
      right(c.docket_year::text, 2) || COALESCE(NULLIF(btrim(c.docket_month_code), ''), ''),
      lpad(c.docket_number::text, 6, '0')
    )
  END AS docket_display_number,
  al.entity_name,
  al.entity_id,
  al.action,
  al.summary,
  al.old_data,
  al.new_data,
  al.metadata,
  al.ip_address
FROM public.audit_logs al
LEFT JOIN public.users u ON u.id = al.actor_user_id
LEFT JOIN public.cases c ON c.id = al.case_id
LEFT JOIN public.docket_types dt ON dt.id = c.docket_type_id
WHERE public.has_app_role('DEVELOPER');

CREATE OR REPLACE VIEW public.v_developer_audit_activity_summary
WITH (security_invoker = true)
AS
SELECT
  al.entity_name,
  al.action,
  count(*)::bigint AS log_count,
  min(al.created_at) AS first_recorded_at,
  max(al.created_at) AS latest_recorded_at
FROM public.audit_logs al
WHERE public.has_app_role('DEVELOPER')
GROUP BY al.entity_name, al.action;

CREATE OR REPLACE VIEW public.v_developer_audit_log_overview
WITH (security_invoker = true)
AS
SELECT
  count(*)::bigint AS total_log_count,
  count(*) FILTER (WHERE al.created_at >= now() - interval '24 hours')::bigint AS last_24_hours_count,
  count(*) FILTER (WHERE al.created_at >= now() - interval '7 days')::bigint AS last_7_days_count,
  count(DISTINCT al.actor_user_id) FILTER (WHERE al.actor_user_id IS NOT NULL)::bigint AS actor_count,
  max(al.created_at) AS latest_log_at
FROM public.audit_logs al
WHERE public.has_app_role('DEVELOPER')
HAVING public.has_app_role('DEVELOPER');

CREATE OR REPLACE VIEW public.v_developer_audit_actor_summary
WITH (security_invoker = true)
AS
SELECT
  al.actor_user_id,
  COALESCE(NULLIF(btrim(u.email), ''), 'User #' || al.actor_user_id::text) AS actor_display,
  u.email AS actor_email,
  count(*)::bigint AS log_count,
  min(al.created_at) AS first_recorded_at,
  max(al.created_at) AS latest_recorded_at
FROM public.audit_logs al
LEFT JOIN public.users u ON u.id = al.actor_user_id
WHERE public.has_app_role('DEVELOPER')
  AND al.actor_user_id IS NOT NULL
GROUP BY al.actor_user_id, u.email;

REVOKE ALL ON TABLE public.v_developer_audit_logs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v_developer_audit_activity_summary FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v_developer_audit_log_overview FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.v_developer_audit_actor_summary FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE public.v_developer_audit_logs TO authenticated, service_role;
GRANT SELECT ON TABLE public.v_developer_audit_activity_summary TO authenticated, service_role;
GRANT SELECT ON TABLE public.v_developer_audit_log_overview TO authenticated, service_role;
GRANT SELECT ON TABLE public.v_developer_audit_actor_summary TO authenticated, service_role;

COMMENT ON VIEW public.v_developer_audit_logs IS
  'Developer-only detailed audit-log read model with actor and docket display values.';
COMMENT ON VIEW public.v_developer_audit_activity_summary IS
  'Developer-only audit activity counts grouped by entity and action.';
COMMENT ON VIEW public.v_developer_audit_log_overview IS
  'Developer-only audit-log totals for the audit screen summary cards.';
COMMENT ON VIEW public.v_developer_audit_actor_summary IS
  'Developer-only audit activity counts grouped by application user.';
