-- Keep the selected-case Excel export wrapper in sync with export_cases_excel_data.
-- The base export now includes date_approved, so this wrapper must expose the
-- same column list instead of SELECT * returning one extra column.
DROP FUNCTION IF EXISTS public.export_cases_excel_data_for_cases(bigint[]);

CREATE FUNCTION public.export_cases_excel_data_for_cases(
  p_case_ids bigint[]
)
RETURNS TABLE (
  case_id bigint,
  docket_type_id bigint,
  docket_type_prefix text,
  docket_type_label text,
  docket_type_sort_order integer,
  docket_year integer,
  docket_month_code text,
  docket_number integer,
  docket_no text,
  complainants text,
  complainant_attributes text,
  respondents text,
  respondent_attributes text,
  violations text,
  case_classification text,
  date_approved date,
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
  SELECT
    export_data.case_id,
    export_data.docket_type_id,
    export_data.docket_type_prefix,
    export_data.docket_type_label,
    export_data.docket_type_sort_order,
    export_data.docket_year,
    export_data.docket_month_code,
    export_data.docket_number,
    export_data.docket_no,
    export_data.complainants,
    export_data.complainant_attributes,
    export_data.respondents,
    export_data.respondent_attributes,
    export_data.violations,
    export_data.case_classification,
    export_data.date_approved,
    export_data.date_received,
    export_data.current_status,
    export_data.assigned_prosecutor,
    export_data.court_filings_court,
    export_data.court_dates_filed,
    export_data.criminal_case_numbers,
    export_data.charges_filed,
    export_data.court_statuses,
    export_data.motion_titles,
    export_data.motion_filed_by,
    export_data.motion_dates_received,
    export_data.motion_statuses,
    export_data.petition_dates_filed,
    export_data.petition_filed_by,
    export_data.petition_statuses,
    export_data.case_notes
  FROM public.export_cases_excel_data() AS export_data
  WHERE export_data.case_id = ANY(p_case_ids);
$$;

REVOKE ALL ON FUNCTION public.export_cases_excel_data_for_cases(bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.export_cases_excel_data_for_cases(bigint[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
