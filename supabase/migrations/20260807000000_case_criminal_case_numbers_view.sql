CREATE OR REPLACE VIEW public.v_case_criminal_case_numbers
WITH (security_invoker = false)
AS
WITH criminal_case_sources AS (
  -- Legacy imported criminal case numbers
  SELECT
    cc.case_id,
    btrim(cc.criminal_case_number) AS criminal_case_no
  FROM public.case_courts cc
  WHERE NULLIF(btrim(cc.criminal_case_number), '') IS NOT NULL

  UNION ALL

  -- New UI-created criminal case numbers
  SELECT
    ccfc.case_id,
    btrim(ccfc.criminal_case_no) AS criminal_case_no
  FROM public.case_court_filing_criminal_cases ccfc
  WHERE ccfc.is_voided = false
    AND NULLIF(btrim(ccfc.criminal_case_no), '') IS NOT NULL
),
deduplicated AS (
  SELECT DISTINCT
    case_id,
    criminal_case_no
  FROM criminal_case_sources
)
SELECT
  case_id,
  string_agg(criminal_case_no, ', ' ORDER BY criminal_case_no) AS criminal_case_numbers
FROM deduplicated
WHERE public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN', 'PROSECUTOR'])
GROUP BY case_id;

REVOKE ALL ON TABLE public.v_case_criminal_case_numbers FROM anon, authenticated;
GRANT ALL ON TABLE public.v_case_criminal_case_numbers TO service_role;
GRANT SELECT ON TABLE public.v_case_criminal_case_numbers TO authenticated;

COMMENT ON VIEW public.v_case_criminal_case_numbers IS
  'Deduplicated legacy and UI-created criminal case numbers for cases-page display and search.';
