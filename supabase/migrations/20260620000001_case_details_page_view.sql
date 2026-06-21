-- Centralized read model for the case details page.
-- Development note: this view intentionally does not add RLS policies or
-- security filters while the case-details refactor is being debugged.

CREATE OR REPLACE VIEW public.v_case_details_page AS
WITH latest_assignment AS (
  SELECT DISTINCT ON (ca.case_id)
    ca.case_id,
    ca.prosecutor_id,
    ca.staff_id,
    ca.assigned_at,
    ca.id
  FROM public.case_assignments ca
  WHERE ca.unassigned_at IS NULL
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
), violation_summary AS (
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
  c.date_received,
  c.created_by_user_id,
  c.updated_by_user_id,
  c.is_archived,
  c.created_at,
  c.updated_at,
  c.region_code,
  c.case_classification_id,
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
  cpd.source,
  cpd.remarks,
  cpd.legacy_source_file,
  cpd.legacy_source_sheet,
  cpd.legacy_row_number,
  cpd.legacy_raw_json,
  cpd.is_summary_procedure,
  cpd.summary_text,
  cpd.current_status_id,
  cpd.current_status_date,
  cpd.current_status_approved_date_raw,
  cpd.current_status_approved_date_raw AS status_approved_date_raw,
  NULL::date AS status_approved_date,
  cpd.current_status_raw,
  cpd.current_status_remarks,
  cs.code AS current_status_code,
  cs.display_label AS current_status_label,
  la.prosecutor_id AS current_prosecutor_id,
  p.short_name AS prosecutor_short_name,
  p.full_name AS prosecutor_full_name,
  la.staff_id AS current_staff_id,
  st.short_name AS staff_short_name,
  st.full_name AS staff_full_name,
  la.assigned_at AS current_assigned_at,
  NULL::text AS case_classification_code,
  NULL::text AS case_classification_name,
  cc.display_label AS case_classification_label,
  cc.description AS case_classification_description,
  NULL::text AS gdrive_folder_id,
  NULL::text AS gdrive_folder_link,
  NULL::text AS gdrive_folder_name,
  NULL::text AS gdrive_folder_status,
  NULL::timestamp with time zone AS gdrive_folder_last_scanned_at,
  NULL::text AS court_codes,
  NULL::text AS criminal_case_numbers,
  NULL::boolean AS court_needs_review
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_statuses cs ON cs.id = cpd.current_status_id
LEFT JOIN latest_assignment la ON la.case_id = c.id
LEFT JOIN public.prosecutors p ON p.id = la.prosecutor_id
LEFT JOIN public.staff st ON st.id = la.staff_id
LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
LEFT JOIN violation_summary vs ON vs.case_id = c.id
WHERE NOT c.is_archived;

COMMENT ON VIEW public.v_case_details_page IS 'Centralized case details page read model. Intentionally policy-free for development debugging.';
