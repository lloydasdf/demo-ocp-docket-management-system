-- Split the cases page read model into lightweight views.
-- Supabase GitHub integration applies files from supabase/migrations when the
-- connected branch is merged; keep this file in the repository root's
-- supabase/ folder because the dashboard working directory is configured as '.'.
--
-- Development note: these views intentionally do not add RLS policies or
-- security filters while the cases-page refactor is being debugged.

CREATE OR REPLACE VIEW public.v_docket_shell AS
WITH violation_summary AS (
  SELECT
    cv.case_id,
    string_agg(
      COALESCE(NULLIF(btrim(cv.raw_violation_text), ''), v.title),
      ', '
      ORDER BY cv.violation_order NULLS LAST, cv.id
    ) AS violations
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  GROUP BY cv.case_id
)
SELECT
  c.id,
  c.docket_type_id,
  c.docket_year,
  c.docket_number,
  c.docket_month_code,
  concat_ws(
    '-',
    dt.prefix,
    c.docket_year::text,
    NULLIF(c.docket_month_code, ''),
    lpad(c.docket_number::text, 6, '0')
  ) AS docket_display_number,
  dt.prefix AS docket_type_prefix,
  dt.name AS docket_type_name,
  vs.violations,
  cpd.summary_text,
  cc.display_label AS case_classification_label,
  c.created_at
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
LEFT JOIN violation_summary vs ON vs.case_id = c.id
WHERE NOT c.is_archived;

CREATE OR REPLACE VIEW public.v_docket_participants AS
WITH participant_names AS (
  SELECT
    cp.case_id,
    lower(concat_ws(' ', pr.code, pr.display_label)) AS role_text,
    cp.participant_order,
    cp.id AS case_participant_id,
    COALESCE(
      NULLIF(btrim(p.full_name), ''),
      NULLIF(btrim(o.organization_name), ''),
      NULLIF(btrim(cp.display_name_snapshot), '')
    ) AS display_name
  FROM public.case_participants cp
  JOIN public.participant_roles pr ON pr.id = cp.role_id
  LEFT JOIN public.persons p ON p.id = cp.person_id
  LEFT JOIN public.organizations o ON o.id = cp.organization_id
)
SELECT
  pn.case_id AS id,
  string_agg(pn.display_name, ' | ' ORDER BY pn.participant_order NULLS LAST, pn.case_participant_id)
    FILTER (WHERE pn.role_text LIKE '%complainant%' AND pn.display_name IS NOT NULL) AS complainant,
  string_agg(pn.display_name, ' | ' ORDER BY pn.participant_order NULLS LAST, pn.case_participant_id)
    FILTER (WHERE pn.role_text LIKE '%respondent%' AND pn.display_name IS NOT NULL) AS respondent
FROM participant_names pn
GROUP BY pn.case_id;

CREATE OR REPLACE VIEW public.v_docket_quickdetails AS
WITH latest_assignment AS (
  SELECT DISTINCT ON (ca.case_id)
    ca.case_id,
    ca.prosecutor_id,
    ca.assigned_at,
    ca.id
  FROM public.case_assignments ca
  WHERE ca.unassigned_at IS NULL
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
)
SELECT
  c.id,
  c.date_received,
  cs.code AS current_status_code,
  cs.display_label AS current_status_label,
  p.full_name AS prosecutor_full_name,
  p.short_name AS prosecutor_short_name
FROM public.cases c
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_statuses cs ON cs.id = cpd.current_status_id
LEFT JOIN latest_assignment la ON la.case_id = c.id
LEFT JOIN public.prosecutors p ON p.id = la.prosecutor_id
WHERE NOT c.is_archived;

COMMENT ON VIEW public.v_docket_shell IS 'Cases page shell read model for fast full-count/list rendering. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_docket_participants IS 'Cases page participant names read model. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_docket_quickdetails IS 'Cases page quick details read model for prosecutor, status, and received date. Intentionally policy-free for development debugging.';
