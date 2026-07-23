-- Reuse the catalog row when a manually entered violation normalizes to an
-- existing canonical title. The unique index is the authority for identity.
DO $$
DECLARE
  v_original_definition text;
  v_definition text;
  v_pattern text := '(?s)  FOR v_item IN SELECT \* FROM jsonb_array_elements\(p_payload->''violations''\) LOOP\n.*?\n  END LOOP;\n\n  INSERT INTO public.case_events';
  v_replacement text := $replacement$
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_payload->'violations') LOOP
    v_violation_id := COALESCE(NULLIF(v_item->>'existingViolationId',''), NULLIF(v_item->>'violationId',''))::bigint;
    IF v_violation_id IS NULL THEN
      INSERT INTO public.violations(title,reference_code,short_label,description,law_reference,created_by_user_id,is_active,canonical_title)
      VALUES (
        btrim(v_item#>>'{newViolation,title}'),
        nullif(btrim(v_item#>>'{newViolation,referenceCode}'),''),
        nullif(btrim(v_item#>>'{newViolation,shortLabel}'),''),
        nullif(btrim(v_item#>>'{newViolation,description}'),''),
        nullif(btrim(v_item#>>'{newViolation,lawReference}'),''),
        v_user_id,
        true,
        regexp_replace(lower(btrim(v_item#>>'{newViolation,title}')), '\s+', ' ', 'g')
      )
      ON CONFLICT (canonical_title) DO NOTHING
      RETURNING id INTO v_violation_id;

      IF v_violation_id IS NULL THEN
        SELECT id
        INTO v_violation_id
        FROM public.violations
        WHERE canonical_title = regexp_replace(lower(btrim(v_item#>>'{newViolation,title}')), '\s+', ' ', 'g');

        IF v_violation_id IS NULL THEN
          RAISE EXCEPTION 'Unable to resolve violation title %', btrim(v_item#>>'{newViolation,title}');
        END IF;

        v_reused_violations := v_reused_violations + 1;
      ELSE
        v_created_violations := v_created_violations + 1;
      END IF;
    ELSE
      SELECT id INTO v_violation_id FROM public.violations WHERE id = v_violation_id;
      IF v_violation_id IS NULL THEN
        RAISE EXCEPTION 'Existing violation not found';
      END IF;
      v_reused_violations := v_reused_violations + 1;
    END IF;

    IF v_violation_id = ANY(v_seen_violation_ids) THEN
      RAISE EXCEPTION 'Duplicate violation id % in payload', v_violation_id;
    END IF;
    v_seen_violation_ids := array_append(v_seen_violation_ids, v_violation_id);
    INSERT INTO public.case_violations(case_id,violation_id,violation_order,raw_violation_text)
    VALUES (v_case_id,v_violation_id,COALESCE((v_item->>'violationOrder')::int,v_violation_count+1),nullif(btrim(v_item->>'rawViolationText'),''));
    v_violation_count := v_violation_count + 1;
  END LOOP;

  INSERT INTO public.case_events$replacement$;
BEGIN
  SELECT pg_get_functiondef('public.create_new_docket_entry(jsonb)'::regprocedure)
  INTO v_original_definition;

  v_definition := regexp_replace(v_original_definition, v_pattern, v_replacement);
  IF v_definition = v_original_definition THEN
    RAISE EXCEPTION 'Could not update create_new_docket_entry violation handling';
  END IF;

  EXECUTE v_definition;
END $$;
