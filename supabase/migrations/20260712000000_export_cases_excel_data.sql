CREATE OR REPLACE FUNCTION public.export_cases_excel_data(
  p_docket_year integer DEFAULT NULL,
  p_docket_type_id bigint DEFAULT NULL
)
RETURNS TABLE (
  case_id bigint,
  docket_no text,
  complainants text,
  complainant_attributes text,
  respondents text,
  respondent_attributes text,
  violations text,
  case_classification text,
  date_received date,
  current_status text,
  assigned_prosecutor text,
  court_filings_court text,
  court_dates_filed text,
  criminal_case_numbers text,
  charges_filed text,
  court_statuses text,
  motion_titles text,
  motion_filed_by text,
  motion_dates_received text,
  motion_statuses text,
  petition_dates_filed text,
  petition_filed_by text,
  petition_statuses text,
  case_notes text
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
WITH filtered_cases AS (
  SELECT
    c.id,
    c.docket_type_id,
    c.docket_year,
    c.docket_number,
    c.docket_month_code,
    c.date_received,
    concat_ws(
      '-',
      dt.prefix,
      c.docket_year::text,
      NULLIF(c.docket_month_code, ''),
      lpad(c.docket_number::text, 6, '0')
    ) AS docket_no,
    NULLIF(cc.display_label, '') AS classification,
    cpd.current_status_raw,
    cs.display_label AS current_status_label,
    cs.code AS current_status_code
  FROM public.cases c
  JOIN public.docket_types dt ON dt.id = c.docket_type_id
  LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
  LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
  LEFT JOIN public.case_statuses cs ON cs.id = COALESCE(cpd.current_case_status_id, cpd.current_status_id)
  WHERE (p_docket_year IS NULL OR c.docket_year = p_docket_year)
    AND (p_docket_type_id IS NULL OR c.docket_type_id = p_docket_type_id)
    AND COALESCE(c.is_archived, false) IS FALSE
),
participant_rows AS (
  SELECT
    cp.case_id,
    lower(pr.code) AS role_code,
    cp.participant_order,
    cp.id,
    COALESCE(
      NULLIF(p.full_name, ''),
      NULLIF(o.organization_name, ''),
      NULLIF(cp.display_name_snapshot, '')
    ) AS participant_name,
    array_to_string(
      ARRAY_REMOVE(
        ARRAY[
          CASE WHEN COALESCE(NULLIF(cpa.age_text, ''), cpa.age_years::text) IS NOT NULL THEN 'Age: ' || COALESCE(NULLIF(cpa.age_text, ''), cpa.age_years::text) END,
          CASE WHEN COALESCE(NULLIF(cpa.gender_text, ''), cpa.gender_normalized) IS NOT NULL THEN 'Gender: ' || COALESCE(NULLIF(cpa.gender_text, ''), cpa.gender_normalized) END,
          CASE WHEN COALESCE(NULLIF(cpa.minor_text, ''), CASE WHEN cpa.is_minor_at_case IS NULL THEN NULL WHEN cpa.is_minor_at_case THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'Minor: ' || COALESCE(NULLIF(cpa.minor_text, ''), CASE WHEN cpa.is_minor_at_case THEN 'Yes' ELSE 'No' END) END,
          CASE WHEN COALESCE(NULLIF(cpa.senior_text, ''), CASE WHEN cpa.is_senior_at_case IS NULL THEN NULL WHEN cpa.is_senior_at_case THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'Senior: ' || COALESCE(NULLIF(cpa.senior_text, ''), CASE WHEN cpa.is_senior_at_case THEN 'Yes' ELSE 'No' END) END,
          CASE WHEN COALESCE(NULLIF(cpa.pwd_text, ''), CASE WHEN cpa.is_pwd_at_case IS NULL THEN NULL WHEN cpa.is_pwd_at_case THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'PWD: ' || COALESCE(NULLIF(cpa.pwd_text, ''), CASE WHEN cpa.is_pwd_at_case THEN 'Yes' ELSE 'No' END) END,
          CASE WHEN COALESCE(NULLIF(cpa.resident_of_gentri_text, ''), CASE WHEN cpa.is_resident_of_gentri IS NULL THEN NULL WHEN cpa.is_resident_of_gentri THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'Resident of GenTri: ' || COALESCE(NULLIF(cpa.resident_of_gentri_text, ''), CASE WHEN cpa.is_resident_of_gentri THEN 'Yes' ELSE 'No' END) END
        ],
        NULL
      ),
      '; '
    ) AS attributes
  FROM public.case_participants cp
  JOIN filtered_cases fc ON fc.id = cp.case_id
  JOIN public.participant_roles pr ON pr.id = cp.role_id
  LEFT JOIN public.persons p ON p.id = cp.person_id
  LEFT JOIN public.organizations o ON o.id = cp.organization_id
  LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
),
participant_export AS (
  SELECT
    case_id,
    string_agg(COALESCE(participant_name, ''), E'\n' ORDER BY participant_order NULLS LAST, id) FILTER (WHERE role_code IN ('complainant', 'complainants', 'comp')) AS complainants,
    string_agg(COALESCE(attributes, ''), E'\n' ORDER BY participant_order NULLS LAST, id) FILTER (WHERE role_code IN ('complainant', 'complainants', 'comp')) AS complainant_attributes,
    string_agg(COALESCE(participant_name, ''), E'\n' ORDER BY participant_order NULLS LAST, id) FILTER (WHERE role_code IN ('respondent', 'respondents', 'resp')) AS respondents,
    string_agg(COALESCE(attributes, ''), E'\n' ORDER BY participant_order NULLS LAST, id) FILTER (WHERE role_code IN ('respondent', 'respondents', 'resp')) AS respondent_attributes
  FROM participant_rows
  GROUP BY case_id
),
violation_export AS (
  SELECT
    cv.case_id,
    string_agg(
      COALESCE(NULLIF(v.title, ''), NULLIF(cv.raw_violation_text, ''), ''),
      E'\n'
      ORDER BY cv.violation_order NULLS LAST, cv.id
    ) AS violations
  FROM public.case_violations cv
  JOIN filtered_cases fc ON fc.id = cv.case_id
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE COALESCE(cv.is_deleted, false) IS FALSE
  GROUP BY cv.case_id
),
active_assignment AS (
  SELECT DISTINCT ON (ca.case_id)
    ca.case_id,
    COALESCE(NULLIF(p.short_name, ''), NULLIF(p.full_name, '')) AS assigned_prosecutor
  FROM public.case_assignments ca
  JOIN filtered_cases fc ON fc.id = ca.case_id
  LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
  WHERE ca.unassigned_at IS NULL
    AND COALESCE(ca.is_voided, false) IS FALSE
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
),
legacy_court_entries AS (
  SELECT
    cc.case_id,
    0 AS source_order,
    cc.court_order::bigint AS order_key,
    cc.id,
    1 AS child_order,
    0::bigint AS child_id,
    COALESCE(NULLIF(concat_ws(' ', NULLIF(c.name, ''), NULLIF(cc.court_branch, '')), ''), NULLIF(cc.raw_court_text, ''), '') AS court_label,
    COALESCE(to_char(cc.actual_filing_date, 'YYYY-MM-DD'), to_char(cc.date_filed_in_court, 'YYYY-MM-DD'), NULLIF(cc.date_filed_in_court_raw, ''), '') AS date_filed,
    COALESCE(NULLIF(cc.criminal_case_number, ''), '') AS criminal_case_number,
    COALESCE(NULLIF(cc.charge_filed, ''), '') AS charge_filed,
    COALESCE(NULLIF(cc.court_status, ''), '') AS court_status
  FROM public.case_courts cc
  JOIN filtered_cases fc ON fc.id = cc.case_id
  LEFT JOIN public.courts c ON c.id = cc.court_id
),
current_court_base AS (
  SELECT
    cf.case_id,
    cf.id,
    COALESCE(NULLIF(concat_ws(' ', NULLIF(cf.court_name, ''), NULLIF(cf.court_branch, '')), ''), '') AS court_label,
    to_char(cf.date_filed, 'YYYY-MM-DD') AS date_filed,
    NULLIF(cf.criminal_case_no, '') AS fallback_criminal_case_number,
    COALESCE(NULLIF(cf.charge_filed, ''), '') AS charge_filed
  FROM public.case_court_filings cf
  JOIN filtered_cases fc ON fc.id = cf.case_id
  WHERE COALESCE(cf.is_voided, false) IS FALSE
),
current_court_status AS (
  SELECT DISTINCT ON (cs.court_filing_id)
    cs.court_filing_id,
    COALESCE(NULLIF(cs.court_status, ''), '') AS court_status
  FROM public.case_court_filing_statuses cs
  JOIN current_court_base cb ON cb.id = cs.court_filing_id
  WHERE COALESCE(cs.is_voided, false) IS FALSE
  ORDER BY cs.court_filing_id, cs.status_date DESC, cs.sort_order DESC NULLS LAST, cs.id DESC
),
current_court_entries AS (
  SELECT
    cb.case_id,
    1 AS source_order,
    cb.id AS order_key,
    cb.id,
    COALESCE(cc.sort_order, 1) AS child_order,
    COALESCE(cc.id, 0) AS child_id,
    cb.court_label,
    cb.date_filed,
    COALESCE(NULLIF(cc.criminal_case_no, ''), cb.fallback_criminal_case_number, '') AS criminal_case_number,
    cb.charge_filed,
    COALESCE(cs.court_status, '') AS court_status
  FROM current_court_base cb
  LEFT JOIN current_court_status cs ON cs.court_filing_id = cb.id
  LEFT JOIN LATERAL (
    SELECT ccfcc.id, ccfcc.criminal_case_no, ccfcc.sort_order
    FROM public.case_court_filing_criminal_cases ccfcc
    WHERE ccfcc.court_filing_id = cb.id
      AND COALESCE(ccfcc.is_voided, false) IS FALSE
    ORDER BY ccfcc.sort_order NULLS LAST, ccfcc.id
  ) cc ON true
),
unified_court_entries AS (
  SELECT * FROM legacy_court_entries
  UNION ALL
  SELECT * FROM current_court_entries
),
court_export AS (
  SELECT
    case_id,
    string_agg(court_label, E'\n' ORDER BY source_order, order_key NULLS LAST, id, child_order NULLS LAST, child_id) AS court_filings_court,
    string_agg(date_filed, E'\n' ORDER BY source_order, order_key NULLS LAST, id, child_order NULLS LAST, child_id) AS court_dates_filed,
    string_agg(criminal_case_number, E'\n' ORDER BY source_order, order_key NULLS LAST, id, child_order NULLS LAST, child_id) AS criminal_case_numbers,
    string_agg(charge_filed, E'\n' ORDER BY source_order, order_key NULLS LAST, id, child_order NULLS LAST, child_id) AS charges_filed,
    string_agg(court_status, E'\n' ORDER BY source_order, order_key NULLS LAST, id, child_order NULLS LAST, child_id) AS court_statuses
  FROM unified_court_entries
  GROUP BY case_id
),
motion_rows AS (
  SELECT
    cm.case_id,
    cm.motion_order,
    cm.date_received,
    cm.id,
    COALESCE(NULLIF(cm.motion_title, ''), NULLIF(cm.motion_name, ''), '') AS motion_title,
    COALESCE(NULLIF(cm.filed_by, ''), NULLIF(cm.filed_by_raw, ''), '') AS filed_by,
    COALESCE(to_char(cm.date_received, 'YYYY-MM-DD'), NULLIF(cm.date_received_raw, ''), '') AS date_received_text,
    COALESCE(NULLIF(cm.motion_status, ''), NULLIF(cm.motion_status_raw, ''), '') AS motion_status
  FROM public.case_motions cm
  JOIN filtered_cases fc ON fc.id = cm.case_id
  WHERE COALESCE(cm.is_voided, false) IS FALSE
),
motion_export AS (
  SELECT
    case_id,
    string_agg(motion_title, E'\n' ORDER BY motion_order NULLS LAST, date_received NULLS LAST, id) AS motion_titles,
    string_agg(filed_by, E'\n' ORDER BY motion_order NULLS LAST, date_received NULLS LAST, id) AS motion_filed_by,
    string_agg(date_received_text, E'\n' ORDER BY motion_order NULLS LAST, date_received NULLS LAST, id) AS motion_dates_received,
    string_agg(motion_status, E'\n' ORDER BY motion_order NULLS LAST, date_received NULLS LAST, id) AS motion_statuses
  FROM motion_rows
  GROUP BY case_id
),
petition_rows AS (
  SELECT
    p.case_id,
    p.petition_order,
    COALESCE(p.date_filed, p.date_received) AS sort_date,
    p.id,
    COALESCE(to_char(p.date_filed, 'YYYY-MM-DD'), to_char(p.date_received, 'YYYY-MM-DD'), NULLIF(p.date_received_raw, ''), '') AS date_filed_text,
    COALESCE(
      NULLIF(p.filed_by, ''),
      CASE p.filed_by_code WHEN 'COMPLAINANT' THEN 'Complainant' WHEN 'RESPONDENT' THEN 'Respondent' END,
      ''
    ) AS filed_by,
    COALESCE(
      (
        SELECT NULLIF(u.petition_status, '')
        FROM public.case_petition_for_review_updates u
        WHERE u.petition_for_review_id = p.id
          AND COALESCE(u.is_voided, false) IS FALSE
        ORDER BY u.status_date DESC, u.id DESC
        LIMIT 1
      ),
      NULLIF(p.petition_status, ''),
      ''
    ) AS petition_status
  FROM public.case_petitions_for_review p
  JOIN filtered_cases fc ON fc.id = p.case_id
  WHERE COALESCE(p.is_voided, false) IS FALSE
),
petition_export AS (
  SELECT
    case_id,
    string_agg(date_filed_text, E'\n' ORDER BY petition_order NULLS LAST, sort_date NULLS LAST, id) AS petition_dates_filed,
    string_agg(filed_by, E'\n' ORDER BY petition_order NULLS LAST, sort_date NULLS LAST, id) AS petition_filed_by,
    string_agg(petition_status, E'\n' ORDER BY petition_order NULLS LAST, sort_date NULLS LAST, id) AS petition_statuses
  FROM petition_rows
  GROUP BY case_id
),
note_export AS (
  SELECT
    n.case_id,
    string_agg(n.note_text, E'\n' ORDER BY n.created_at DESC, n.id DESC) AS case_notes
  FROM public.notes n
  JOIN filtered_cases fc ON fc.id = n.case_id
  WHERE COALESCE(n.is_deleted, false) IS FALSE
  GROUP BY n.case_id
)
SELECT
  fc.id,
  fc.docket_no,
  pe.complainants,
  pe.complainant_attributes,
  pe.respondents,
  pe.respondent_attributes,
  ve.violations,
  fc.classification,
  fc.date_received,
  COALESCE(NULLIF(fc.current_status_label, ''), NULLIF(fc.current_status_code, ''), NULLIF(fc.current_status_raw, '')),
  aa.assigned_prosecutor,
  ce.court_filings_court,
  ce.court_dates_filed,
  ce.criminal_case_numbers,
  ce.charges_filed,
  ce.court_statuses,
  me.motion_titles,
  me.motion_filed_by,
  me.motion_dates_received,
  me.motion_statuses,
  pfe.petition_dates_filed,
  pfe.petition_filed_by,
  pfe.petition_statuses,
  ne.case_notes
FROM filtered_cases fc
LEFT JOIN participant_export pe ON pe.case_id = fc.id
LEFT JOIN violation_export ve ON ve.case_id = fc.id
LEFT JOIN active_assignment aa ON aa.case_id = fc.id
LEFT JOIN court_export ce ON ce.case_id = fc.id
LEFT JOIN motion_export me ON me.case_id = fc.id
LEFT JOIN petition_export pfe ON pfe.case_id = fc.id
LEFT JOIN note_export ne ON ne.case_id = fc.id
ORDER BY fc.docket_year DESC, fc.docket_type_id, fc.docket_number;
$$;

GRANT EXECUTE ON FUNCTION public.export_cases_excel_data(integer, bigint) TO authenticated;
