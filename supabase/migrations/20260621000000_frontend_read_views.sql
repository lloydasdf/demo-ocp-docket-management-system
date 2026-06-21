-- Frontend read views for case-page and clearance flows.
-- Development note: these views intentionally do not add RLS policies or
-- security filters while the read-refactor is being debugged.

CREATE OR REPLACE VIEW public.v_docket_shell AS
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
  c.created_at
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
WHERE NOT c.is_archived;

CREATE OR REPLACE VIEW public.v_docket_case_violation_classification AS
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
  vs.violations,
  cpd.summary_text,
  cc.display_label AS case_classification_label
FROM public.cases c
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
LEFT JOIN violation_summary vs ON vs.case_id = c.id
WHERE NOT c.is_archived;

CREATE OR REPLACE VIEW public.v_clearance_participant_attributes AS
SELECT
  cp.case_id,
  cp.person_id,
  cpa.age_text,
  cpa.age_years
FROM public.case_participants cp
LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id;

CREATE OR REPLACE VIEW public.v_case_attachments AS
SELECT *
FROM public.case_attachment_index;

CREATE OR REPLACE VIEW public.v_case_courts_detail AS
SELECT
  cc.*,
  jsonb_build_object(
    'code', co.code,
    'court_type', co.court_type,
    'name', co.name
  ) AS courts
FROM public.case_courts cc
LEFT JOIN public.courts co ON co.id = cc.court_id;

CREATE OR REPLACE VIEW public.v_case_motions_detail AS
SELECT
  id,
  case_id,
  motion_order,
  motion_name,
  filed_by,
  filed_by_raw,
  date_received,
  date_received_raw,
  date_resolved,
  date_resolved_raw,
  date_approved,
  date_approved_raw,
  motion_status,
  motion_status_raw,
  remarks,
  remarks_raw,
  created_at,
  updated_at
FROM public.case_motions;

CREATE OR REPLACE VIEW public.v_case_petitions_for_review_detail AS
SELECT
  id,
  case_id,
  petition_title,
  handling_prosecutor_text,
  date_received,
  date_received_raw,
  filed_by,
  petition_status,
  date_resolved,
  date_resolved_raw,
  date_approved,
  date_approved_raw,
  remarks
FROM public.case_petitions_for_review;

CREATE OR REPLACE VIEW public.v_case_participants_detail AS
SELECT
  cp.id,
  cp.case_id,
  cp.person_id,
  cp.organization_id,
  cp.role_id,
  cp.participant_order,
  cp.participant_kind,
  cp.display_name_snapshot,
  cp.created_at,
  CASE
    WHEN cppd.case_participant_id IS NULL THEN NULL::jsonb
    ELSE jsonb_build_object(
      'remarks', cppd.remarks,
      'source', cppd.source,
      'source_detail', cppd.source_detail,
      'legacy_source_file', cppd.legacy_source_file,
      'legacy_source_sheet', cppd.legacy_source_sheet,
      'legacy_row_number', cppd.legacy_row_number,
      'legacy_raw_text', cppd.legacy_raw_text
    )
  END AS case_participant_private_details,
  CASE
    WHEN cpa.case_participant_id IS NULL THEN NULL::jsonb
    ELSE jsonb_build_object(
      'age_text', cpa.age_text,
      'age_years', cpa.age_years,
      'gender_text', cpa.gender_text,
      'gender_normalized', cpa.gender_normalized,
      'is_minor_at_case', cpa.is_minor_at_case,
      'is_senior_at_case', cpa.is_senior_at_case,
      'is_pwd_at_case', cpa.is_pwd_at_case
    )
  END AS case_participant_attributes,
  jsonb_build_object(
    'code', pr.code,
    'display_label', pr.display_label
  ) AS participant_roles,
  CASE
    WHEN p.id IS NULL THEN NULL::jsonb
    ELSE jsonb_build_object(
      'age', p.age,
      'birth_date', p.birth_date,
      'first_name', p.first_name,
      'full_name', p.full_name,
      'gender', p.gender,
      'id', p.id,
      'is_minor', p.is_minor,
      'is_pwd', p.is_pwd,
      'is_senior', p.is_senior,
      'last_name', p.last_name,
      'middle_name', p.middle_name,
      'notes', p.notes,
      'person_descriptor', p.person_descriptor,
      'suffix', p.suffix,
      'person_addresses', COALESCE(pa.person_addresses, '[]'::jsonb)
    )
  END AS persons
FROM public.case_participants cp
LEFT JOIN public.case_participant_private_details cppd ON cppd.case_participant_id = cp.id
LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
LEFT JOIN public.participant_roles pr ON pr.id = cp.role_id
LEFT JOIN public.persons p ON p.id = cp.person_id
LEFT JOIN LATERAL (
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', paddr.id,
      'is_primary', paddr.is_primary,
      'remarks', paddr.remarks,
      'addresses', CASE
        WHEN a.id IS NULL THEN NULL::jsonb
        ELSE jsonb_build_object(
          'barangay', a.barangay,
          'city', a.city,
          'country', a.country,
          'line1', a.line1,
          'line2', a.line2,
          'province', a.province,
          'region', a.region,
          'zip_code', a.zip_code
        )
      END
    )
    ORDER BY paddr.is_primary DESC NULLS LAST, paddr.id
  ) AS person_addresses
  FROM public.person_addresses paddr
  LEFT JOIN public.addresses a ON a.id = paddr.address_id
  WHERE paddr.person_id = p.id
) pa ON true;

CREATE OR REPLACE VIEW public.v_docket_case_labels AS
SELECT
  s.id,
  s.docket_display_number,
  COALESCE(l.violations, l.summary_text) AS label,
  l.violations,
  l.case_classification_label
FROM public.v_docket_shell s
LEFT JOIN public.v_docket_case_violation_classification l ON l.id = s.id;

COMMENT ON VIEW public.v_docket_case_violation_classification IS 'Cases page violation and classification hydration view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_clearance_participant_attributes IS 'Clearance search participant age attribute read view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_case_participants_detail IS 'Case details participant card read view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_case_attachments IS 'Case details attachment read view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_case_courts_detail IS 'Case details court read view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_case_motions_detail IS 'Case details motion read view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_case_petitions_for_review_detail IS 'Case details petition-for-review read view. Intentionally policy-free for development debugging.';
COMMENT ON VIEW public.v_docket_case_labels IS 'Docket label helper view backed by split shell and label views. Intentionally policy-free for development debugging.';
