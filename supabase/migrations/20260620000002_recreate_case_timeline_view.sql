-- Recreate the case timeline read model used by the case details page.
-- This remains separate from v_case_details_page so the centralized details view
-- stays focused on the case header/core details instead of timeline rows.
--
-- Development note: this view intentionally does not add RLS policies or
-- security filters while the case-details refactor is being debugged.

CREATE OR REPLACE VIEW public.v_case_timeline AS
SELECT
  ce.id AS case_event_id,
  ce.case_id,
  dt.prefix AS docket_type,
  c.docket_year,
  c.docket_month_code,
  c.docket_number,
  concat_ws(
    '-',
    c.region_code,
    dt.prefix,
    right(c.docket_year::text, 2) || COALESCE(c.docket_month_code, ''),
    lpad(c.docket_number::text, 6, '0')
  ) AS docket_display_number,
  cet.code AS event_type_code,
  cet.display_label AS event_type_label,
  cet.category AS event_category,
  ce.event_date,
  ce.event_time,
  ce.event_order,
  ce.title,
  ce.description,
  ce.status_id,
  cs.code AS status_code,
  cs.display_label AS status_label,
  ce.prosecutor_id,
  p.short_name AS prosecutor_short_name,
  ce.staff_id,
  st.short_name AS staff_short_name,
  ce.court_id,
  co.name AS court_name,
  ce.details_jsonb,
  ce.source,
  ce.source_table,
  ce.source_id,
  ce.legacy_source_file,
  ce.legacy_source_sheet,
  ce.legacy_row_number,
  ce.legacy_line_order,
  ce.needs_review,
  ce.review_reason,
  ce.is_voided,
  ce.created_at,
  ce.updated_at
FROM public.case_events ce
JOIN public.cases c ON c.id = ce.case_id
JOIN public.docket_types dt ON dt.id = c.docket_type_id
JOIN public.case_event_types cet ON cet.id = ce.event_type_id
LEFT JOIN public.case_statuses cs ON cs.id = ce.status_id
LEFT JOIN public.prosecutors p ON p.id = ce.prosecutor_id
LEFT JOIN public.staff st ON st.id = ce.staff_id
LEFT JOIN public.courts co ON co.id = ce.court_id;

COMMENT ON VIEW public.v_case_timeline IS 'Case details page timeline read model, kept separate from v_case_details_page to avoid over-complicating the centralized details view. Intentionally policy-free for development debugging.';
