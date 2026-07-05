CREATE OR REPLACE FUNCTION public.void_case_event(
  p_case_event_id bigint,
  p_void_reason text,
  p_voided_by_user_id bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_case_id bigint;
  v_event_type_code text;
  v_source_table text;
  v_source_id bigint;
  v_assignment_id bigint;
  v_assignment_old jsonb;
  v_assignment_new jsonb;
BEGIN
  IF nullif(trim(p_void_reason), '') IS NULL THEN
    RAISE EXCEPTION 'Void reason is required';
  END IF;

  SELECT to_jsonb(ce), ce.case_id, cet.code, ce.source_table, ce.source_id
  INTO v_old, v_case_id, v_event_type_code, v_source_table, v_source_id
  FROM public.case_events ce
  LEFT JOIN public.case_event_types cet ON cet.id = ce.event_type_id
  WHERE ce.id = p_case_event_id
    AND ce.is_voided = false;

  IF v_old IS NULL THEN
    RAISE EXCEPTION 'Active case event % not found', p_case_event_id;
  END IF;

  UPDATE public.case_events
  SET is_voided = true,
      void_reason = p_void_reason,
      voided_at = now(),
      voided_by_user_id = p_voided_by_user_id,
      updated_by_user_id = p_voided_by_user_id,
      updated_at = now()
  WHERE id = p_case_event_id;

  SELECT to_jsonb(ce)
  INTO v_new
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id;

  INSERT INTO public.audit_logs (
    actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata
  )
  VALUES (
    p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id,
    'Voided case timeline activity', jsonb_build_object('reason', p_void_reason)
  );

  IF lower(coalesce(v_source_table, '')) = 'case_assignments' OR v_event_type_code = 'CASE_ASSIGNMENT' THEN
    SELECT ca.id, to_jsonb(ca)
    INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id
       OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_assignment_id IS NOT NULL THEN
      UPDATE public.case_assignments
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          unassigned_at = COALESCE(unassigned_at, now())
      WHERE id = v_assignment_id;

      SELECT to_jsonb(ca)
      INTO v_assignment_new
      FROM public.case_assignments ca
      WHERE ca.id = v_assignment_id;

      INSERT INTO public.audit_logs (
        actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata
      )
      VALUES (
        p_voided_by_user_id,
        'case_assignments',
        v_assignment_id,
        'VOID_CASE_ASSIGNMENT_FROM_EVENT',
        v_assignment_old,
        v_assignment_new,
        v_case_id,
        'Assignment row voided because the Case Assignment event was voided.',
        jsonb_build_object('case_event_id', p_case_event_id, 'reason', p_void_reason)
      );
    END IF;
  END IF;
END;
$$;
