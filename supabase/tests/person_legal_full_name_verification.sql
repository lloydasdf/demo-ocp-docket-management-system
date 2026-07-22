-- Verification for public.format_person_legal_full_name().
-- Run with psql against a disposable/local database. The transaction rolls back all rows.
BEGIN;

DO $$
DECLARE
  v_person_id bigint;
BEGIN
  INSERT INTO public.persons(first_name, middle_name, last_name, suffix, full_name)
  VALUES ('lloyd edwin', 'reyes', 'dayao', NULL, 'ignored')
  RETURNING id INTO v_person_id;

  IF (SELECT full_name FROM public.persons WHERE id = v_person_id) <> 'DAYAO, LLOYD EDWIN y REYES' THEN
    RAISE EXCEPTION 'middle-name legal format was not applied';
  END IF;

  UPDATE public.persons
  SET middle_name = 'NMN', suffix = 'jr.'
  WHERE id = v_person_id;

  IF (SELECT full_name FROM public.persons WHERE id = v_person_id) <> 'DAYAO, LLOYD EDWIN NMN JR.' THEN
    RAISE EXCEPTION 'NMN legal format was not applied';
  END IF;
END;
$$;

ROLLBACK;
