-- Export the selected case IDs so client-side search and filter results can be
-- downloaded without widening the result set again on the server.
CREATE OR REPLACE FUNCTION public.export_cases_excel_data_for_cases(
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
  SELECT *
  FROM public.export_cases_excel_data()
  WHERE case_id = ANY(p_case_ids);
$$;

REVOKE ALL ON FUNCTION public.export_cases_excel_data_for_cases(bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.export_cases_excel_data_for_cases(bigint[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
