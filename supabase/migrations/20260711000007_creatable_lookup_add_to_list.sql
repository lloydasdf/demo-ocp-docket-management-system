-- Reusable add-to-list RPCs for frontend-owned lookups.
CREATE UNIQUE INDEX IF NOT EXISTS participant_roles_code_ci_uidx ON public.participant_roles (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS participant_roles_active_label_ci_uidx ON public.participant_roles (lower(display_label)) WHERE is_active;
CREATE UNIQUE INDEX IF NOT EXISTS address_types_code_ci_uidx ON public.address_types (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS address_types_active_label_ci_uidx ON public.address_types (lower(display_label)) WHERE is_active;
CREATE UNIQUE INDEX IF NOT EXISTS case_classifications_active_label_ci_uidx ON public.case_classifications (lower(display_label)) WHERE is_active;

CREATE OR REPLACE FUNCTION public.generate_lookup_code(p_label text, p_fallback text DEFAULT 'LOOKUP')
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT trim(both '_' FROM coalesce(nullif(upper(regexp_replace(coalesce(nullif(btrim(p_label), ''), p_fallback), '[^a-zA-Z0-9]+', '_', 'g')), ''), p_fallback));
$$;

CREATE OR REPLACE FUNCTION public.add_participant_role(p_display_label text, p_code text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_label text := NULLIF(btrim(coalesce(p_display_label,'')), '');
  v_code text;
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_label IS NULL THEN RAISE EXCEPTION 'Participant Role Label is required'; END IF;
  v_code := public.generate_lookup_code(coalesce(NULLIF(btrim(p_code), ''), v_label), 'PARTICIPANT_ROLE');
  IF EXISTS (SELECT 1 FROM public.participant_roles WHERE is_active AND (lower(code)=lower(v_code) OR lower(display_label)=lower(v_label))) THEN
    RAISE EXCEPTION 'An active participant role with this code or label already exists.';
  END IF;
  INSERT INTO public.participant_roles(code, display_label, is_active) VALUES (v_code, v_label, true) RETURNING id INTO v_id;
  SELECT to_jsonb(r) INTO v_new FROM public.participant_roles r WHERE r.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,summary,metadata)
  VALUES (p_user_id,'participant_roles',v_id,'CREATE_PARTICIPANT_ROLE',NULL,v_new,'Participant role added.',jsonb_build_object('code',v_code,'display_label',v_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_address_type(p_display_label text, p_code text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_label text := NULLIF(btrim(coalesce(p_display_label,'')), '');
  v_code text;
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_label IS NULL THEN RAISE EXCEPTION 'Address Type Label is required'; END IF;
  v_code := public.generate_lookup_code(coalesce(NULLIF(btrim(p_code), ''), v_label), 'ADDRESS_TYPE');
  IF EXISTS (SELECT 1 FROM public.address_types WHERE is_active AND (lower(code)=lower(v_code) OR lower(display_label)=lower(v_label))) THEN
    RAISE EXCEPTION 'An active address type with this code or label already exists.';
  END IF;
  INSERT INTO public.address_types(code, display_label, is_active) VALUES (v_code, v_label, true) RETURNING id INTO v_id;
  SELECT to_jsonb(r) INTO v_new FROM public.address_types r WHERE r.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,summary,metadata)
  VALUES (p_user_id,'address_types',v_id,'CREATE_ADDRESS_TYPE',NULL,v_new,'Address type added.',jsonb_build_object('code',v_code,'display_label',v_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_case_classification(p_display_label text, p_description text DEFAULT NULL, p_user_id bigint DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_label text := NULLIF(btrim(coalesce(p_display_label,'')), '');
  v_id bigint;
  v_new jsonb;
BEGIN
  IF v_label IS NULL THEN RAISE EXCEPTION 'Case Classification Label is required'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_classifications WHERE is_active AND lower(display_label)=lower(v_label)) THEN
    RAISE EXCEPTION 'An active case classification with this label already exists.';
  END IF;
  INSERT INTO public.case_classifications(display_label, description, is_active) VALUES (v_label, NULLIF(btrim(p_description), ''), true) RETURNING id INTO v_id;
  SELECT to_jsonb(r) INTO v_new FROM public.case_classifications r WHERE r.id = v_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,summary,metadata)
  VALUES (p_user_id,'case_classifications',v_id,'CREATE_CASE_CLASSIFICATION',NULL,v_new,'Case classification added.',jsonb_build_object('display_label',v_label));
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_participant_role(text,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_address_type(text,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_case_classification(text,text,bigint) TO authenticated;
