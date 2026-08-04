CREATE OR REPLACE FUNCTION public.edit_case_assignment_event(
  p_case_event_id bigint,
  p_expected_event_type_code text,
  p_prosecutor_id bigint,
  p_event_date date,
  p_event_time time without time zone DEFAULT NULL,
  p_staff_id bigint DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event public.case_events%rowtype;
  v_assignment public.case_assignments%rowtype;
  v_code text;
  v_assigned_at timestamptz;
  v_prosecutor_name text;
  v_staff_name text;
  v_previous_assignment_id bigint;
  v_previous_prosecutor_name text;
  v_old_event jsonb;
  v_old_assignment jsonb;
  v_new_event jsonb;
  v_new_assignment jsonb;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_remarks text := nullif(btrim(coalesce(p_remarks, '')), '');
BEGIN
  IF p_expected_event_type_code NOT IN ('CASE_ASSIGNMENT', 'CASE_REASSIGNMENT') THEN RAISE EXCEPTION 'Unsupported assignment event type'; END IF;
  IF p_prosecutor_id IS NULL THEN RAISE EXCEPTION 'Assigned prosecutor is required'; END IF;
  IF p_event_date IS NULL THEN RAISE EXCEPTION 'Assignment date is required'; END IF;

  SELECT ce, cet.code INTO v_event, v_code
  FROM public.case_events ce JOIN public.case_event_types cet ON cet.id = ce.event_type_id
  WHERE ce.id = p_case_event_id AND ce.is_voided IS FALSE
  FOR UPDATE OF ce;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active assignment event % not found', p_case_event_id; END IF;
  IF v_code IS DISTINCT FROM p_expected_event_type_code THEN RAISE EXCEPTION 'This activity is %, not %', v_code, p_expected_event_type_code; END IF;
  IF v_event.source_table IS DISTINCT FROM 'case_assignments' OR v_event.source_id IS NULL THEN RAISE EXCEPTION 'Assignment source record cannot be resolved'; END IF;

  SELECT * INTO v_assignment FROM public.case_assignments
  WHERE id = v_event.source_id AND case_event_id = p_case_event_id AND is_voided IS FALSE
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active assignment source record cannot be resolved'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = p_prosecutor_id AND is_active IS TRUE) THEN RAISE EXCEPTION 'Assigned prosecutor must be active'; END IF;
  IF p_staff_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.staff WHERE id = p_staff_id AND is_active IS TRUE) THEN RAISE EXCEPTION 'Assigned staff must be active'; END IF;

  SELECT coalesce(short_name, full_name) INTO v_prosecutor_name FROM public.prosecutors WHERE id = p_prosecutor_id;
  SELECT coalesce(short_name, full_name) INTO v_staff_name FROM public.staff WHERE id = p_staff_id;
  v_assigned_at := ((p_event_date::timestamp + coalesce(p_event_time, '00:00'::time)) AT TIME ZONE 'Asia/Manila');
  IF v_assignment.unassigned_at IS NOT NULL AND v_assigned_at > v_assignment.unassigned_at THEN
    RAISE EXCEPTION 'Assignment date cannot be later than its unassignment date';
  END IF;
  v_previous_assignment_id := nullif(v_event.details_jsonb->>'previous_assignment_id', '')::bigint;
  SELECT coalesce(p.short_name, p.full_name) INTO v_previous_prosecutor_name
  FROM public.case_assignments ca LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
  WHERE ca.id = v_previous_assignment_id;
  IF v_previous_assignment_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_assignments WHERE id = v_previous_assignment_id AND assigned_at > v_assigned_at) THEN
    RAISE EXCEPTION 'Reassignment date cannot be earlier than the previous assignment date';
  END IF;
  v_old_event := to_jsonb(v_event);
  v_old_assignment := to_jsonb(v_assignment);

  UPDATE public.case_assignments
  SET prosecutor_id = p_prosecutor_id, staff_id = p_staff_id, assigned_at = v_assigned_at, remarks = v_remarks
  WHERE id = v_assignment.id;

  IF v_code = 'CASE_REASSIGNMENT' AND v_previous_assignment_id IS NOT NULL THEN
    UPDATE public.case_assignments
    SET unassigned_at = v_assigned_at, unassignment_reason = v_reason
    WHERE id = v_previous_assignment_id AND case_id = v_event.case_id AND is_voided IS FALSE;
  END IF;

  UPDATE public.case_events
  SET event_date = p_event_date,
      event_time = p_event_time,
      prosecutor_id = p_prosecutor_id,
      staff_id = p_staff_id,
      description = v_remarks,
      details_jsonb = coalesce(details_jsonb, '{}'::jsonb) || jsonb_build_object(
        'new_prosecutor_id', p_prosecutor_id, 'new_prosecutor_name', v_prosecutor_name,
        'staff_id', p_staff_id, 'staff_name', v_staff_name, 'remarks', v_remarks,
        'reason', CASE WHEN v_code = 'CASE_REASSIGNMENT' THEN v_reason ELSE NULL END,
        'reassignment_date', CASE WHEN v_code = 'CASE_REASSIGNMENT' THEN to_jsonb(p_event_date) ELSE details_jsonb->'reassignment_date' END,
        'reassignment_time', CASE WHEN v_code = 'CASE_REASSIGNMENT' THEN to_jsonb(p_event_time) ELSE details_jsonb->'reassignment_time' END
      ),
      updated_by_user_id = p_user_id,
      updated_at = now()
  WHERE id = p_case_event_id;

  UPDATE public.case_status_history SET status_date = p_event_date WHERE case_event_id = p_case_event_id;
  UPDATE public.case_stage_history SET stage_date = p_event_date WHERE case_event_id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new_event FROM public.case_events ce WHERE ce.id = p_case_event_id;
  SELECT to_jsonb(ca) INTO v_new_assignment FROM public.case_assignments ca WHERE ca.id = v_assignment.id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (p_user_id, 'case_events', p_case_event_id, 'EDIT_' || v_code, v_old_event, v_new_event, v_event.case_id,
    'Edited ' || CASE WHEN v_code = 'CASE_REASSIGNMENT' THEN 'case reassignment' ELSE 'case assignment' END || ' event.',
    jsonb_build_object('assignment_id', v_assignment.id, 'old_assignment', v_old_assignment, 'new_assignment', v_new_assignment, 'previous_assignment_id', v_previous_assignment_id, 'previous_prosecutor_name', v_previous_prosecutor_name));
  RETURN p_case_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.edit_case_assignment_event(bigint,text,bigint,date,time without time zone,bigint,text,text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.edit_case_assignment_event(bigint,text,bigint,date,time without time zone,bigint,text,text,bigint) TO authenticated;
