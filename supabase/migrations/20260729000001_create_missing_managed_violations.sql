CREATE OR REPLACE FUNCTION public.manage_case_violations(p_payload jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_action text := lower(btrim(p_payload->>'action'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_violation jsonb := coalesce(p_payload->'violation', '{}'::jsonb);
  v_case_violation_id bigint := nullif(v_violation->>'id','')::bigint;
  v_violation_id bigint := nullif(v_violation->>'violationId','')::bigint;
  v_violation_title text := nullif(btrim(v_violation->>'violationTitle'), '');
  v_canonical_title text;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(cv) || jsonb_build_object('violation', to_jsonb(v)) ORDER BY cv.violation_order NULLS LAST, cv.id), '[]'::jsonb)
  INTO v_old
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE cv.case_id = v_case_id;

  IF v_action IN ('add', 'edit') THEN
    IF v_violation_id IS NULL THEN
      IF v_violation_title IS NULL THEN RAISE EXCEPTION 'violationTitle is required'; END IF;
      v_canonical_title := regexp_replace(lower(v_violation_title), '\s+', ' ', 'g');

      INSERT INTO public.violations(title, created_by_user_id, is_active, canonical_title)
      VALUES (v_violation_title, v_user_id, true, v_canonical_title)
      ON CONFLICT (canonical_title) DO UPDATE SET is_active = true
      RETURNING id INTO v_violation_id;
    ELSIF NOT EXISTS (SELECT 1 FROM public.violations WHERE id = v_violation_id) THEN
      RAISE EXCEPTION 'Violation % not found', v_violation_id;
    END IF;

    IF v_action = 'add' THEN
      INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text)
      VALUES (v_case_id, v_violation_id, (SELECT COALESCE(max(cv.violation_order), 0) + 1 FROM public.case_violations cv WHERE cv.case_id = v_case_id), NULL);
    ELSE
      IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
      IF EXISTS (SELECT 1 FROM public.case_violations WHERE id = v_case_violation_id AND case_id = v_case_id AND is_deleted IS TRUE) THEN RAISE EXCEPTION 'Restore violation before editing'; END IF;
      UPDATE public.case_violations
      SET violation_id = v_violation_id,
          raw_violation_text = NULL
      WHERE id = v_case_violation_id AND case_id = v_case_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
    END IF;
  ELSIF v_action = 'remove' THEN
    IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_violations
    SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason
    WHERE id = v_case_violation_id AND case_id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
  ELSIF v_action = 'restore' THEN
    IF v_case_violation_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_violations
    SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL
    WHERE id = v_case_violation_id AND case_id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Case violation % not found', v_case_violation_id; END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported violations action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(cv) || jsonb_build_object('violation', to_jsonb(v)) ORDER BY cv.violation_order NULLS LAST, cv.id), '[]'::jsonb)
  INTO v_new
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  WHERE cv.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_VIOLATIONS_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed case violations', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;
