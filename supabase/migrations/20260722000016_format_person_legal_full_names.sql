-- Store every person name in the legal docket format:
-- SURNAME, GIVEN NAME y MIDDLE NAME [SUFFIX]
CREATE OR REPLACE FUNCTION public.format_person_legal_full_name()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_first_name text := nullif(regexp_replace(btrim(NEW.first_name), '\s+', ' ', 'g'), '');
  v_middle_name text := nullif(regexp_replace(btrim(NEW.middle_name), '\s+', ' ', 'g'), '');
  v_last_name text := nullif(regexp_replace(btrim(NEW.last_name), '\s+', ' ', 'g'), '');
  v_suffix text := nullif(regexp_replace(btrim(NEW.suffix), '\s+', ' ', 'g'), '');
  v_given_name text;
BEGIN
  -- Keep legacy records that only have full_name usable while still normalizing
  -- their capitalization and spacing.
  IF v_first_name IS NULL AND v_middle_name IS NULL AND v_last_name IS NULL AND v_suffix IS NULL THEN
    NEW.full_name := upper(nullif(regexp_replace(btrim(NEW.full_name), '\s+', ' ', 'g'), ''));
    IF NEW.full_name IS NULL THEN
      RAISE EXCEPTION 'A person must have a name';
    END IF;
    RETURN NEW;
  END IF;

  v_given_name := concat_ws(
    ' ',
    upper(v_first_name),
    CASE
      WHEN upper(v_middle_name) = 'NMN' THEN 'NMN'
      WHEN v_middle_name IS NOT NULL THEN concat('y ', upper(v_middle_name))
    END,
    upper(v_suffix)
  );

  NEW.full_name := CASE
    WHEN v_last_name IS NOT NULL AND v_given_name <> '' THEN concat(upper(v_last_name), ', ', v_given_name)
    WHEN v_last_name IS NOT NULL THEN upper(v_last_name)
    ELSE v_given_name
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS format_person_legal_full_name ON public.persons;
CREATE TRIGGER format_person_legal_full_name
BEFORE INSERT OR UPDATE OF first_name, middle_name, last_name, suffix, full_name
ON public.persons
FOR EACH ROW
EXECUTE FUNCTION public.format_person_legal_full_name();

-- Bring current records in line with the same canonical format.
UPDATE public.persons
SET full_name = full_name;
