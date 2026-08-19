-- Keep criminal case numbers in the same lifecycle as their parent Court Filing.
-- Previously, void_case_event() voided case_court_filings but left these child
-- rows active, so v_case_criminal_case_numbers continued to show their values.
CREATE OR REPLACE FUNCTION public.void_court_filing_criminal_case_numbers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.is_voided = true AND OLD.is_voided = false THEN
    UPDATE public.case_court_filing_criminal_cases
    SET is_voided = true,
        voided_at = COALESCE(NEW.voided_at, now()),
        voided_by_user_id = NEW.voided_by_user_id,
        void_reason = COALESCE(NEW.void_reason, 'Parent Court Filing voided'),
        updated_at = now(),
        updated_by_user_id = NEW.updated_by_user_id
    WHERE court_filing_id = NEW.id
      AND is_voided = false;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_void_court_filing_criminal_case_numbers
  ON public.case_court_filings;

CREATE TRIGGER trg_void_court_filing_criminal_case_numbers
AFTER UPDATE OF is_voided ON public.case_court_filings
FOR EACH ROW
EXECUTE FUNCTION public.void_court_filing_criminal_case_numbers();

-- Repair numbers left active by Court Filings voided before this migration.
UPDATE public.case_court_filing_criminal_cases ccfc
SET is_voided = true,
    voided_at = COALESCE(cf.voided_at, now()),
    voided_by_user_id = cf.voided_by_user_id,
    void_reason = COALESCE(cf.void_reason, 'Parent Court Filing voided'),
    updated_at = now(),
    updated_by_user_id = cf.updated_by_user_id
FROM public.case_court_filings cf
WHERE cf.id = ccfc.court_filing_id
  AND cf.is_voided = true
  AND ccfc.is_voided = false;

-- Also require an active parent when reading the case-list summary. This makes
-- the view defensive if data is imported or changed with triggers disabled.
CREATE OR REPLACE VIEW public.v_case_criminal_case_numbers
WITH (security_invoker = false)
AS
WITH criminal_case_sources AS (
  SELECT
    cc.case_id,
    btrim(cc.criminal_case_number) AS criminal_case_no
  FROM public.case_courts cc
  WHERE NULLIF(btrim(cc.criminal_case_number), '') IS NOT NULL

  UNION ALL

  SELECT
    ccfc.case_id,
    btrim(ccfc.criminal_case_no) AS criminal_case_no
  FROM public.case_court_filing_criminal_cases ccfc
  JOIN public.case_court_filings cf
    ON cf.id = ccfc.court_filing_id
   AND cf.is_voided = false
  LEFT JOIN public.case_events ce
    ON ce.id = cf.case_event_id
  WHERE ccfc.is_voided = false
    AND (cf.case_event_id IS NULL OR ce.is_voided = false)
    AND NULLIF(btrim(ccfc.criminal_case_no), '') IS NOT NULL
),
deduplicated AS (
  SELECT DISTINCT case_id, criminal_case_no
  FROM criminal_case_sources
)
SELECT
  case_id,
  string_agg(criminal_case_no, ', ' ORDER BY criminal_case_no) AS criminal_case_numbers
FROM deduplicated
WHERE public.has_any_app_role(ARRAY['DEVELOPER', 'ADMIN'])
GROUP BY case_id;

REVOKE ALL ON TABLE public.v_case_criminal_case_numbers FROM anon, authenticated;
GRANT ALL ON TABLE public.v_case_criminal_case_numbers TO service_role;
GRANT SELECT ON TABLE public.v_case_criminal_case_numbers TO authenticated;

COMMENT ON FUNCTION public.void_court_filing_criminal_case_numbers() IS
  'Voids active criminal case numbers when their parent Court Filing is voided.';

COMMENT ON VIEW public.v_case_criminal_case_numbers IS
  'Deduplicated legacy and active Court Filing criminal case numbers for cases-page display and search.';
