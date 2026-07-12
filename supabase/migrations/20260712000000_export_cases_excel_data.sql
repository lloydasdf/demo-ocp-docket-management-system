CREATE OR REPLACE FUNCTION public.export_cases_excel_data(
  p_docket_year integer DEFAULT NULL,
  p_docket_type_id bigint DEFAULT NULL
)
RETURNS TABLE (
  case_id bigint, docket_no text, complainants text, complainant_attributes text, respondents text, respondent_attributes text,
  violations text, case_classification text, date_received date, current_status text, assigned_prosecutor text,
  court_filings_court text, court_dates_filed text, criminal_case_numbers text, charges_filed text, court_statuses text,
  motion_titles text, motion_filed_by text, motion_dates_received text, motion_statuses text,
  petition_dates_filed text, petition_filed_by text, petition_statuses text, case_notes text
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = public
AS $$
WITH filtered_cases AS (
  SELECT c.id, c.docket_type_id, c.docket_year, c.docket_number, c.docket_month_code, c.region_code, c.date_received,
         concat_ws('-', c.region_code, dt.prefix, right(c.docket_year::text,2) || COALESCE(c.docket_month_code,''), lpad(c.docket_number::text,6,'0')) AS docket_no,
         cc.display_label AS classification, cpd.current_status_raw,
         cs.display_label AS current_status_label, cs.code AS current_status_code
  FROM public.cases c
  JOIN public.docket_types dt ON dt.id = c.docket_type_id
  LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
  LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
  LEFT JOIN public.case_statuses cs ON cs.id = COALESCE(cpd.current_case_status_id, cpd.current_status_id)
  WHERE (p_docket_year IS NULL OR c.docket_year = p_docket_year)
    AND (p_docket_type_id IS NULL OR c.docket_type_id = p_docket_type_id)
    AND COALESCE(c.is_archived, false) IS FALSE
), participant_rows AS (
  SELECT cp.case_id, lower(pr.code) AS role_code, cp.participant_order, cp.id,
         COALESCE(p.full_name, o.organization_name, cp.display_name_snapshot) AS participant_name,
         array_to_string(ARRAY_REMOVE(ARRAY[
           CASE WHEN COALESCE(NULLIF(cpa.age_text,''), cpa.age_years::text) IS NOT NULL THEN 'Age: ' || COALESCE(NULLIF(cpa.age_text,''), cpa.age_years::text) END,
           CASE WHEN COALESCE(NULLIF(cpa.gender_text,''), cpa.gender_normalized) IS NOT NULL THEN 'Gender: ' || COALESCE(NULLIF(cpa.gender_text,''), cpa.gender_normalized) END,
           CASE WHEN COALESCE(NULLIF(cpa.minor_text,''), CASE WHEN cpa.is_minor_at_case IS NULL THEN NULL WHEN cpa.is_minor_at_case THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'Minor: ' || COALESCE(NULLIF(cpa.minor_text,''), CASE WHEN cpa.is_minor_at_case THEN 'Yes' ELSE 'No' END) END,
           CASE WHEN COALESCE(NULLIF(cpa.senior_text,''), CASE WHEN cpa.is_senior_at_case IS NULL THEN NULL WHEN cpa.is_senior_at_case THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'Senior: ' || COALESCE(NULLIF(cpa.senior_text,''), CASE WHEN cpa.is_senior_at_case THEN 'Yes' ELSE 'No' END) END,
           CASE WHEN COALESCE(NULLIF(cpa.pwd_text,''), CASE WHEN cpa.is_pwd_at_case IS NULL THEN NULL WHEN cpa.is_pwd_at_case THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'PWD: ' || COALESCE(NULLIF(cpa.pwd_text,''), CASE WHEN cpa.is_pwd_at_case THEN 'Yes' ELSE 'No' END) END,
           CASE WHEN COALESCE(NULLIF(cpa.resident_of_gentri_text,''), CASE WHEN cpa.is_resident_of_gentri IS NULL THEN NULL WHEN cpa.is_resident_of_gentri THEN 'Yes' ELSE 'No' END) IS NOT NULL THEN 'Resident of GenTri: ' || COALESCE(NULLIF(cpa.resident_of_gentri_text,''), CASE WHEN cpa.is_resident_of_gentri THEN 'Yes' ELSE 'No' END) END
         ], NULL), '; ') AS attributes
  FROM public.case_participants cp
  JOIN filtered_cases fc ON fc.id = cp.case_id
  JOIN public.participant_roles pr ON pr.id = cp.role_id
  LEFT JOIN public.persons p ON p.id = cp.person_id
  LEFT JOIN public.organizations o ON o.id = cp.organization_id
  LEFT JOIN public.case_participant_attributes cpa ON cpa.case_participant_id = cp.id
), participant_export AS (
  SELECT case_id,
    string_agg(participant_name, E'\n' ORDER BY participant_order, id) FILTER (WHERE role_code IN ('complainant','complainants','comp')) complainants,
    string_agg(COALESCE(attributes,''), E'\n' ORDER BY participant_order, id) FILTER (WHERE role_code IN ('complainant','complainants','comp')) complainant_attributes,
    string_agg(participant_name, E'\n' ORDER BY participant_order, id) FILTER (WHERE role_code IN ('respondent','respondents','resp')) respondents,
    string_agg(COALESCE(attributes,''), E'\n' ORDER BY participant_order, id) FILTER (WHERE role_code IN ('respondent','respondents','resp')) respondent_attributes
  FROM participant_rows GROUP BY case_id
), violation_export AS (
  SELECT cv.case_id, string_agg(COALESCE(v.title, cv.raw_violation_text), E'\n' ORDER BY cv.violation_order, cv.id) violations
  FROM public.case_violations cv JOIN filtered_cases fc ON fc.id=cv.case_id LEFT JOIN public.violations v ON v.id=cv.violation_id
  WHERE COALESCE(cv.is_deleted,false) IS FALSE GROUP BY cv.case_id
), active_assignment AS (
  SELECT DISTINCT ON (ca.case_id) ca.case_id, COALESCE(p.short_name,p.full_name) assigned_prosecutor
  FROM public.case_assignments ca JOIN filtered_cases fc ON fc.id=ca.case_id LEFT JOIN public.prosecutors p ON p.id=ca.prosecutor_id
  WHERE ca.unassigned_at IS NULL AND COALESCE(ca.is_voided,false) IS FALSE ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
), current_court_entries AS (
  SELECT cf.case_id, 1000000 + cf.id AS order_key, cf.id,
    concat_ws(' ', NULLIF(cf.court_name,''), NULLIF(cf.court_branch,'')) AS court_label, cf.date_filed::text date_filed,
    COALESCE((SELECT string_agg(cc.criminal_case_no, E'\n' ORDER BY cc.sort_order, cc.id) FROM public.case_court_filing_criminal_cases cc WHERE cc.court_filing_id=cf.id AND COALESCE(cc.is_voided,false) IS FALSE), cf.criminal_case_no) criminal_case_no,
    cf.charge_filed,
    COALESCE((SELECT cs2.court_status FROM public.case_court_filing_statuses cs2 WHERE cs2.court_filing_id=cf.id AND COALESCE(cs2.is_voided,false) IS FALSE ORDER BY cs2.status_date DESC, cs2.sort_order DESC NULLS LAST, cs2.id DESC LIMIT 1), cf.court_status) court_status
  FROM public.case_court_filings cf JOIN filtered_cases fc ON fc.id=cf.case_id WHERE COALESCE(cf.is_voided,false) IS FALSE
), legacy_court_entries AS (
  SELECT cc.case_id, cc.court_order AS order_key, cc.id, COALESCE(NULLIF(concat_ws(' ', c.name, cc.court_branch),''), cc.raw_court_text) court_label,
    COALESCE(cc.actual_filing_date, cc.date_filed_in_court)::text date_filed, cc.criminal_case_number, cc.charge_filed, cc.court_status
  FROM public.case_courts cc JOIN filtered_cases fc ON fc.id=cc.case_id LEFT JOIN public.courts c ON c.id=cc.court_id
), unified_court_entries AS (SELECT * FROM legacy_court_entries UNION ALL SELECT * FROM current_court_entries), court_export AS (
  SELECT case_id, string_agg(COALESCE(court_label,''), E'\n' ORDER BY order_key,id) court_filings_court, string_agg(COALESCE(date_filed,''), E'\n' ORDER BY order_key,id) court_dates_filed, string_agg(COALESCE(criminal_case_number,''), E'\n' ORDER BY order_key,id) criminal_case_numbers, string_agg(COALESCE(charge_filed,''), E'\n' ORDER BY order_key,id) charges_filed, string_agg(COALESCE(court_status,''), E'\n' ORDER BY order_key,id) court_statuses FROM unified_court_entries GROUP BY case_id
), motion_export AS (
  SELECT cm.case_id, string_agg(COALESCE(cm.motion_title,cm.motion_name,''), E'\n' ORDER BY cm.date_received NULLS LAST, cm.id) motion_titles, string_agg(COALESCE(cm.filed_by,''), E'\n' ORDER BY cm.date_received NULLS LAST, cm.id) motion_filed_by, string_agg(COALESCE(cm.date_received::text,''), E'\n' ORDER BY cm.date_received NULLS LAST, cm.id) motion_dates_received, string_agg(COALESCE(cm.motion_status,''), E'\n' ORDER BY cm.date_received NULLS LAST, cm.id) motion_statuses FROM public.case_motions cm JOIN filtered_cases fc ON fc.id=cm.case_id WHERE COALESCE(cm.is_voided,false) IS FALSE GROUP BY cm.case_id
), petition_export AS (
  SELECT p.case_id, string_agg(COALESCE(p.date_filed,p.date_received)::text, E'\n' ORDER BY COALESCE(p.date_filed,p.date_received) NULLS LAST, p.id) petition_dates_filed, string_agg(COALESCE(p.filed_by, CASE p.filed_by_code WHEN 'COMPLAINANT' THEN 'Complainant' WHEN 'RESPONDENT' THEN 'Respondent' END, ''), E'\n' ORDER BY COALESCE(p.date_filed,p.date_received) NULLS LAST, p.id) petition_filed_by, string_agg(COALESCE((SELECT u.petition_status FROM public.case_petition_for_review_updates u WHERE u.petition_for_review_id=p.id AND COALESCE(u.is_voided,false) IS FALSE ORDER BY u.status_date DESC, u.id DESC LIMIT 1), p.petition_status, ''), E'\n' ORDER BY COALESCE(p.date_filed,p.date_received) NULLS LAST, p.id) petition_statuses FROM public.case_petitions_for_review p JOIN filtered_cases fc ON fc.id=p.case_id WHERE COALESCE(p.is_voided,false) IS FALSE GROUP BY p.case_id
), note_export AS (
  SELECT n.case_id, string_agg(n.note_text, E'\n' ORDER BY n.created_at DESC, n.id DESC) case_notes FROM public.notes n JOIN filtered_cases fc ON fc.id=n.case_id WHERE COALESCE(n.is_deleted,false) IS FALSE GROUP BY n.case_id
)
SELECT fc.id, fc.docket_no, pe.complainants, pe.complainant_attributes, pe.respondents, pe.respondent_attributes, ve.violations, fc.classification, fc.date_received, COALESCE(fc.current_status_label,fc.current_status_code,fc.current_status_raw), aa.assigned_prosecutor, ce.court_filings_court, ce.court_dates_filed, ce.criminal_case_numbers, ce.charges_filed, ce.court_statuses, me.motion_titles, me.motion_filed_by, me.motion_dates_received, me.motion_statuses, pfe.petition_dates_filed, pfe.petition_filed_by, pfe.petition_statuses, ne.case_notes
FROM filtered_cases fc LEFT JOIN participant_export pe ON pe.case_id=fc.id LEFT JOIN violation_export ve ON ve.case_id=fc.id LEFT JOIN active_assignment aa ON aa.case_id=fc.id LEFT JOIN court_export ce ON ce.case_id=fc.id LEFT JOIN motion_export me ON me.case_id=fc.id LEFT JOIN petition_export pfe ON pfe.case_id=fc.id LEFT JOIN note_export ne ON ne.case_id=fc.id
ORDER BY fc.docket_year DESC, fc.docket_type_id, fc.docket_number;
$$;

GRANT EXECUTE ON FUNCTION public.export_cases_excel_data(integer, bigint) TO authenticated;
