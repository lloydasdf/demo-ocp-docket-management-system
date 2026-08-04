-- Create prosecutors through the same audited RPC boundary used by other
-- creatable assignment-event lookups.
CREATE UNIQUE INDEX IF NOT EXISTS prosecutors_active_full_name_norm_uidx
  ON public.prosecutors (lower(regexp_replace(btrim(full_name), '\s+', ' ', 'g')))
  WHERE is_active;

CREATE OR REPLACE FUNCTION public.add_prosecutor(
  p_fiscal_code text,
  p_user_id bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fiscal_code text := nullif(regexp_replace(btrim(coalesce(p_fiscal_code, '')), '\s+', ' ', 'g'), '');
  v_position_id bigint;
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_fiscal_code IS NULL THEN
    RAISE EXCEPTION 'Fiscal Code is required.';
  END IF;
  IF length(v_fiscal_code) > 100 THEN
    RAISE EXCEPTION 'Fiscal Code must be 100 characters or fewer.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.prosecutors
    WHERE is_active
      AND lower(regexp_replace(btrim(full_name), '\s+', ' ', 'g')) = lower(v_fiscal_code)
  ) THEN
    RAISE EXCEPTION 'An active prosecutor with this full name already exists.';
  END IF;

  SELECT id INTO v_position_id
  FROM public.positions
  WHERE is_active AND group_type = 'PROSECUTOR' AND code = 'PROSECUTOR'
  ORDER BY id
  LIMIT 1;

  -- first_name and last_name remain required by the production schema. Until
  -- the full prosecutor profile is collected, retain the Fiscal Code in both.
  INSERT INTO public.prosecutors(first_name, last_name, full_name, short_name, position_id, position_code, is_active)
  VALUES (v_fiscal_code, v_fiscal_code, v_fiscal_code, v_fiscal_code, v_position_id, 'PROSECUTOR', true)
  RETURNING id INTO v_id;

  SELECT to_jsonb(p) INTO v_new FROM public.prosecutors p WHERE p.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (p_user_id, 'prosecutors', v_id, 'ADD_PROSECUTOR', NULL, v_new, 'Added prosecutor Fiscal Code ' || v_fiscal_code || '.', jsonb_build_object('fiscal_code', v_fiscal_code));
  RETURN v_id;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'An active prosecutor with this full name already exists.';
END;
$$;

REVOKE ALL ON FUNCTION public.add_prosecutor(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_prosecutor(text,bigint) TO authenticated;
