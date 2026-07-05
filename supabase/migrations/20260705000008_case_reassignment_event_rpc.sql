ALTER TABLE public.case_assignments
  ADD COLUMN IF NOT EXISTS unassigned_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS unassignment_reason text;

CREATE OR REPLACE FUNCTION public.record_case_reassignment_event(
  p_case_id bigint,
  p_new_prosecutor_id bigint,
  p_reassignment_date date,
  p_reassignment_time time without time zone DEFAULT NULL,
  p_new_staff_id bigint DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_type_id bigint;
  v_event_id bigint;
  v_previous_assignment_id bigint;
  v_previous_prosecutor_id bigint;
  v_previous_staff_id bigint;
  v_previous_assignment_old jsonb;
  v_previous_assignment_new jsonb;
  v_new_assignment_id bigint;
  v_new_assignment_new jsonb;
  v_reassigned_at timestamptz;
  v_previous_prosecutor_name text;
  v_new_prosecutor_name text;
  v_staff_name text;
  v_reason text := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_new_prosecutor_id IS NULL THEN RAISE EXCEPTION 'New prosecutor is required'; END IF;
  IF p_reassignment_date IS NULL THEN RAISE EXCEPTION 'Reassignment date is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'Reason is required'; END IF;

  SELECT id INTO v_event_type_id
  FROM public.case_event_types
  WHERE code = 'CASE_REASSIGNMENT' AND is_active IS TRUE
  LIMIT 1;

  IF v_event_type_id IS NULL THEN
    RAISE EXCEPTION 'Missing active case event type CASE_REASSIGNMENT';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN
    RAISE EXCEPTION 'Unknown case id %', p_case_id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = p_new_prosecutor_id) THEN
    RAISE EXCEPTION 'Unknown prosecutor id %', p_new_prosecutor_id;
  END IF;

  IF p_new_staff_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.staff WHERE id = p_new_staff_id) THEN
    RAISE EXCEPTION 'Unknown staff id %', p_new_staff_id;
  END IF;

  SELECT ca.id, ca.prosecutor_id, ca.staff_id, to_jsonb(ca), COALESCE(p.short_name, p.full_name)
  INTO v_previous_assignment_id, v_previous_prosecutor_id, v_previous_staff_id, v_previous_assignment_old, v_previous_prosecutor_name
  FROM public.case_assignments ca
  LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
  WHERE ca.case_id = p_case_id
    AND ca.unassigned_at IS NULL
    AND ca.is_voided IS FALSE
  ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
  LIMIT 1
  FOR UPDATE OF ca;

  IF v_previous_assignment_id IS NULL THEN
    RAISE EXCEPTION 'This case has no active assignment to reassign.';
  END IF;

  v_reassigned_at := (p_reassignment_date::timestamp + COALESCE(p_reassignment_time, '00:00'::time))::timestamptz;

  SELECT COALESCE(short_name, full_name) INTO v_new_prosecutor_name
  FROM public.prosecutors
  WHERE id = p_new_prosecutor_id;

  SELECT COALESCE(short_name, full_name) INTO v_staff_name
  FROM public.staff
  WHERE id = p_new_staff_id;

  UPDATE public.case_assignments
  SET unassigned_at = v_reassigned_at,
      unassigned_by_user_id = p_user_id,
      unassignment_reason = v_reason
  WHERE id = v_previous_assignment_id;

  SELECT to_jsonb(ca) INTO v_previous_assignment_new
  FROM public.case_assignments ca
  WHERE ca.id = v_previous_assignment_id;

  INSERT INTO public.case_assignments (case_id, prosecutor_id, staff_id, assigned_by_user_id, assigned_at, remarks)
  VALUES (p_case_id, p_new_prosecutor_id, p_new_staff_id, p_user_id, v_reassigned_at, v_remarks)
  RETURNING id INTO v_new_assignment_id;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description,
    prosecutor_id, staff_id, details_jsonb, source, source_table, source_id,
    created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id,
    v_event_type_id,
    p_reassignment_date,
    p_reassignment_time,
    'Case Reassignment',
    'Reassigned to Prosec ' || COALESCE(v_new_prosecutor_name, p_new_prosecutor_id::text) || ' on ' || to_char(p_reassignment_date, 'Mon FMDD, YYYY'),
    p_new_prosecutor_id,
    p_new_staff_id,
    jsonb_build_object(
      'action', 'case_reassignment',
      'previous_assignment_id', v_previous_assignment_id,
      'previous_prosecutor_id', v_previous_prosecutor_id,
      'previous_prosecutor_name', v_previous_prosecutor_name,
      'new_assignment_id', v_new_assignment_id,
      'new_prosecutor_id', p_new_prosecutor_id,
      'new_prosecutor_name', v_new_prosecutor_name,
      'staff_id', p_new_staff_id,
      'staff_name', v_staff_name,
      'reason', v_reason,
      'remarks', v_remarks
    ),
    'MANUAL_ENTRY',
    'case_assignments',
    v_new_assignment_id,
    p_user_id,
    p_user_id
  ) RETURNING id INTO v_event_id;

  UPDATE public.case_assignments
  SET case_event_id = v_event_id
  WHERE id = v_new_assignment_id;

  SELECT to_jsonb(ca) INTO v_new_assignment_new
  FROM public.case_assignments ca
  WHERE ca.id = v_new_assignment_id;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES
    (p_user_id, 'case_assignments', v_previous_assignment_id, 'CASE_REASSIGNMENT_OLD_ASSIGNMENT_CLOSED', v_previous_assignment_old, v_previous_assignment_new, p_case_id, 'Closed old assignment during case reassignment.', jsonb_build_object('case_event_id', v_event_id, 'reason', v_reason, 'new_assignment_id', v_new_assignment_id)),
    (p_user_id, 'case_assignments', v_new_assignment_id, 'CASE_REASSIGNMENT_NEW_ASSIGNMENT_CREATED', NULL, v_new_assignment_new, p_case_id, 'Created new assignment during case reassignment.', jsonb_build_object('case_event_id', v_event_id, 'reason', v_reason, 'previous_assignment_id', v_previous_assignment_id));

  RETURN v_event_id;
END;
$$;
