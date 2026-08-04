-- Create prosecutors through the same audited RPC boundary used by other
-- creatable assignment-event lookups.
CREATE UNIQUE INDEX IF NOT EXISTS prosecutors_active_full_name_norm_uidx
  ON public.prosecutors (lower(regexp_replace(btrim(full_name), '\s+', ' ', 'g')))
  WHERE is_active;

CREATE OR REPLACE FUNCTION public.add_prosecutor(
  p_first_name text,
  p_last_name text,
  p_middle_name text DEFAULT NULL,
  p_suffix text DEFAULT NULL,
  p_short_name text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_first_name text := nullif(regexp_replace(btrim(coalesce(p_first_name, '')), '\s+', ' ', 'g'), '');
  v_middle_name text := nullif(regexp_replace(btrim(coalesce(p_middle_name, '')), '\s+', ' ', 'g'), '');
  v_last_name text := nullif(regexp_replace(btrim(coalesce(p_last_name, '')), '\s+', ' ', 'g'), '');
  v_suffix text := nullif(regexp_replace(btrim(coalesce(p_suffix, '')), '\s+', ' ', 'g'), '');
  v_short_name text := nullif(regexp_replace(btrim(coalesce(p_short_name, '')), '\s+', ' ', 'g'), '');
  v_full_name text;
  v_position_id bigint;
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_first_name IS NULL OR v_last_name IS NULL THEN
    RAISE EXCEPTION 'First name and last name are required.';
  END IF;
  IF greatest(length(v_first_name), length(coalesce(v_middle_name, '')), length(v_last_name), length(coalesce(v_suffix, '')), length(coalesce(v_short_name, ''))) > 100 THEN
    RAISE EXCEPTION 'Each name field must be 100 characters or fewer.';
  END IF;

  v_full_name := concat_ws(' ', v_first_name, v_middle_name, v_last_name, v_suffix);
  v_short_name := coalesce(v_short_name, left(v_first_name, 1) || '. ' || v_last_name || CASE WHEN v_suffix IS NULL THEN '' ELSE ' ' || v_suffix END);

  IF EXISTS (
    SELECT 1 FROM public.prosecutors
    WHERE is_active
      AND lower(regexp_replace(btrim(full_name), '\s+', ' ', 'g')) = lower(v_full_name)
  ) THEN
    RAISE EXCEPTION 'An active prosecutor with this full name already exists.';
  END IF;

  SELECT id INTO v_position_id
  FROM public.positions
  WHERE is_active AND group_type = 'PROSECUTOR' AND code = 'PROSECUTOR'
  ORDER BY id
  LIMIT 1;

  INSERT INTO public.prosecutors(first_name, middle_name, last_name, suffix, full_name, short_name, position_id, position_code, is_active)
  VALUES (v_first_name, v_middle_name, v_last_name, v_suffix, v_full_name, v_short_name, v_position_id, 'PROSECUTOR', true)
  RETURNING id INTO v_id;

  SELECT to_jsonb(p) INTO v_new FROM public.prosecutors p WHERE p.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (p_user_id, 'prosecutors', v_id, 'ADD_PROSECUTOR', NULL, v_new, 'Added prosecutor ' || v_full_name || '.', jsonb_build_object('full_name', v_full_name));
  RETURN v_id;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'An active prosecutor with this full name already exists.';
END;
$$;

REVOKE ALL ON FUNCTION public.add_prosecutor(text,text,text,text,text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_prosecutor(text,text,text,text,text,bigint) TO authenticated;
