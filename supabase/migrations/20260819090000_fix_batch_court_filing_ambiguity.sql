-- Fix PL/pgSQL name resolution in the batch Court Filing function. The prior
-- local variable had the same name as case_court_filing_criminal_cases.court_filing_id,
-- making the partial ON CONFLICT target ambiguous.

CREATE OR REPLACE FUNCTION public.record_court_filing_events_batch(
  p_case_id bigint, p_filings jsonb, p_court_id bigint DEFAULT NULL, p_court_name text DEFAULT NULL,
  p_court_branch text DEFAULT NULL, p_date_filed date DEFAULT NULL, p_time_filed time without time zone DEFAULT NULL,
  p_information_count integer DEFAULT NULL, p_criminal_case_numbers jsonb DEFAULT '[]'::jsonb,
  p_remarks text DEFAULT NULL, p_user_id bigint DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  filing jsonb; event_id bigint; first_event_id bigint; v_court_filing_id bigint; number_text text; number_order integer;
  normalized_numbers jsonb;
BEGIN
  IF jsonb_typeof(COALESCE(p_filings, '[]'::jsonb)) <> 'array' OR jsonb_array_length(COALESCE(p_filings, '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'At least one Court Filing charge is required';
  END IF;
  IF jsonb_typeof(COALESCE(p_criminal_case_numbers, '[]'::jsonb)) <> 'array' THEN RAISE EXCEPTION 'Criminal Case Numbers must be an array'; END IF;
  SELECT COALESCE(jsonb_agg(value ORDER BY first_ordinality), '[]'::jsonb) INTO normalized_numbers
  FROM (SELECT DISTINCT ON (lower(btrim(value))) btrim(value) value, ordinality first_ordinality FROM jsonb_array_elements_text(COALESCE(p_criminal_case_numbers,'[]'::jsonb)) WITH ORDINALITY n(value, ordinality) WHERE btrim(value) <> '' ORDER BY lower(btrim(value)), ordinality) numbers;

  FOR filing IN SELECT value FROM jsonb_array_elements(p_filings) item(value) LOOP
    event_id := public.record_court_filing_event(p_case_id, NULLIF(filing->>'case_resolution_approval_action_id','')::bigint, p_court_id, p_court_name, p_court_branch, filing->>'charge_filed', p_date_filed, p_time_filed, p_information_count, normalized_numbers->>0, p_remarks, p_user_id);
    first_event_id := COALESCE(first_event_id, event_id);
    SELECT id INTO v_court_filing_id FROM public.case_court_filings WHERE case_event_id=event_id AND is_voided=false;
    number_order := 0;
    FOR number_text IN SELECT value FROM jsonb_array_elements_text(normalized_numbers) LOOP
      number_order := number_order + 1;
      INSERT INTO public.case_court_filing_criminal_cases(case_id,court_filing_id,criminal_case_no,sort_order,created_by_user_id,updated_by_user_id)
      VALUES(p_case_id,v_court_filing_id,number_text,number_order,p_user_id,p_user_id)
      ON CONFLICT (court_filing_id,(lower(criminal_case_no))) WHERE is_voided=false DO UPDATE SET sort_order=EXCLUDED.sort_order,updated_at=now(),updated_by_user_id=p_user_id;
    END LOOP;
    UPDATE public.case_events SET details_jsonb=COALESCE(details_jsonb,'{}'::jsonb)||jsonb_build_object('criminal_case_numbers',normalized_numbers),updated_at=now(),updated_by_user_id=p_user_id WHERE id=event_id;
  END LOOP;
  RETURN first_event_id;
END $$;

GRANT EXECUTE ON FUNCTION public.record_court_filing_events_batch(bigint,jsonb,bigint,text,text,date,time without time zone,integer,jsonb,text,bigint) TO authenticated;
