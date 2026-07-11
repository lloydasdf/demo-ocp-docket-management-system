-- Creatable court lookup for Court Filing workflow.
CREATE UNIQUE INDEX IF NOT EXISTS courts_code_ci_uidx ON public.courts (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS courts_active_name_ci_uidx ON public.courts (lower(name)) WHERE is_active;

CREATE OR REPLACE FUNCTION public.add_court(p_display_label text, p_code text DEFAULT NULL, p_court_type text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_name text := NULLIF(btrim(coalesce(p_display_label,'')), '');
  v_code text;
  v_court_type text := NULLIF(btrim(p_court_type), '');
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_name IS NULL THEN RAISE EXCEPTION 'Court Name is required'; END IF;
  v_code := public.generate_lookup_code(coalesce(NULLIF(btrim(p_code), ''), v_name), 'COURT');
  IF EXISTS (SELECT 1 FROM public.courts WHERE is_active AND lower(code)=lower(v_code)) THEN
    RAISE EXCEPTION 'An active court with this code already exists.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.courts WHERE is_active AND lower(name)=lower(v_name)) THEN
    RAISE EXCEPTION 'An active court with this name already exists.';
  END IF;

  INSERT INTO public.courts(code, name, court_type, is_active)
  VALUES (v_code, v_name, v_court_type, true)
  RETURNING id INTO v_id;

  SELECT to_jsonb(c) INTO v_new FROM public.courts c WHERE c.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,summary,metadata)
  VALUES (p_user_id,'courts',v_id,'CREATE_COURT',NULL,v_new,'Court added.',jsonb_build_object('code',v_code,'name',v_name,'court_type',v_court_type));
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_court(text,text,text,bigint) TO authenticated;
