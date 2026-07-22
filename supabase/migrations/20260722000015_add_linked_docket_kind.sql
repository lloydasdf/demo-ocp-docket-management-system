-- Some deployed environments already have this table from an earlier
-- implementation.  Make the kind explicit and use it in the RPC insert.
ALTER TABLE public.case_docket_links
  ADD COLUMN IF NOT EXISTS linked_docket_kind text;

UPDATE public.case_docket_links l
SET linked_docket_kind = upper(dt.prefix)
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
WHERE c.id = l.linked_case_id
  AND l.linked_docket_kind IS NULL;

ALTER TABLE public.case_docket_links
  ALTER COLUMN linked_docket_kind SET NOT NULL;

CREATE OR REPLACE FUNCTION public.create_linked_docket_entry(p_payload jsonb, p_pe_case_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE
  v_result jsonb;
  v_new_case_id bigint;
  v_user_id bigint;
  v_pe_prefix text;
  v_target_prefix text;
BEGIN
  SELECT id INTO v_user_id FROM public.users WHERE auth_user_id = auth.uid() AND is_active IS TRUE;
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authenticated application user is required'; END IF;
  SELECT dt.prefix INTO v_pe_prefix FROM public.cases c JOIN public.docket_types dt ON dt.id = c.docket_type_id WHERE c.id = p_pe_case_id AND NOT c.is_archived;
  IF upper(coalesce(v_pe_prefix, '')) <> 'PE' THEN RAISE EXCEPTION 'Only a PE docket can be linked'; END IF;
  SELECT upper(prefix) INTO v_target_prefix FROM public.docket_types WHERE id = (p_payload->>'docketTypeId')::bigint;
  IF v_target_prefix NOT IN ('INV', 'INQ') THEN RAISE EXCEPTION 'Linked PE dockets must be created as INV or INQ'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_docket_links WHERE pe_case_id = p_pe_case_id) THEN RAISE EXCEPTION 'This PE docket is already linked'; END IF;
  v_result := public.create_new_docket_entry(p_payload);
  v_new_case_id := coalesce(nullif(v_result->>'caseId', '')::bigint, nullif(v_result->>'case_id', '')::bigint, nullif(v_result->>'caseid', '')::bigint, nullif(v_result->>'id', '')::bigint);
  IF v_new_case_id IS NULL THEN RAISE EXCEPTION 'Docket creation did not return a case id; link was not created'; END IF;
  INSERT INTO public.case_docket_links(pe_case_id, linked_case_id, linked_docket_kind, created_by_user_id)
  VALUES (p_pe_case_id, v_new_case_id, v_target_prefix, v_user_id);
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_linked_docket_entry(jsonb, bigint) TO authenticated;
