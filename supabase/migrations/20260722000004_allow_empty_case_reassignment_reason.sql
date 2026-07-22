BEGIN;

-- Temporarily allow Case Reassignment events without a reason. Empty or null
-- reasons remain null while all existing assignment, event, history, and audit
-- behavior is preserved.
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
  v_pending_status_id bigint;
  v_case_reassigned_stage_id bigint;
  v_event_id bigint;
  v_previous_assignment_id bigint;
  v_previous_prosecutor_id bigint;
  v_previous_staff_id bigint;
  v_previous_assignment_old jsonb;
  v_previous_assignment_new jsonb;
  v_new_assignment_id bigint;
  v_new_assignment_new jsonb;
  v_status_history_id bigint;
  v_stage_history_id bigint;
  v_previous_status_id bigint;
  v_previous_case_status_id bigint;
  v_previous_stage_id bigint;
  v_old_details jsonb;
  v_new_details jsonb;
  v_reassigned_at timestamptz;
  v_reassignment_time time without time zone;
  v_previous_prosecutor_name text;
  v_new_prosecutor_name text;
  v_staff_name text;
  v_reason text := NULLIF(btrim(COALESCE(p_reason, '')), '');
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_new_prosecutor_id IS NULL THEN RAISE EXCEPTION 'New prosecutor is required'; END IF;
  IF p_reassignment_date IS NULL THEN RAISE EXCEPTION 'Reassignment date is required'; END IF;

  SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'CASE_REASSIGNMENT' AND is_active IS TRUE LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing active case event type CASE_REASSIGNMENT'; END IF;

  SELECT id INTO v_pending_status_id FROM public.case_statuses WHERE code = 'PENDING' AND is_active IS TRUE LIMIT 1;
  IF v_pending_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status PENDING'; END IF;

  SELECT id INTO v_case_reassigned_stage_id FROM public.case_stages WHERE code = 'CASE_REASSIGNED' AND is_active IS TRUE LIMIT 1;
  IF v_case_reassigned_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage CASE_REASSIGNED'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.prosecutors WHERE id = p_new_prosecutor_id) THEN RAISE EXCEPTION 'Unknown prosecutor id %', p_new_prosecutor_id; END IF;
  IF p_new_staff_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.staff WHERE id = p_new_staff_id) THEN RAISE EXCEPTION 'Unknown staff id %', p_new_staff_id; END IF;

  SELECT cpd.current_status_id, cpd.current_case_status_id, cpd.current_case_stage_id, to_jsonb(cpd)
  INTO v_previous_status_id, v_previous_case_status_id, v_previous_stage_id, v_old_details
  FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  SELECT ca.id, ca.prosecutor_id, ca.staff_id, to_jsonb(ca), COALESCE(p.short_name, p.full_name)
  INTO v_previous_assignment_id, v_previous_prosecutor_id, v_previous_staff_id, v_previous_assignment_old, v_previous_prosecutor_name
  FROM public.case_assignments ca
  LEFT JOIN public.prosecutors p ON p.id = ca.prosecutor_id
  WHERE ca.case_id = p_case_id AND ca.unassigned_at IS NULL AND ca.is_voided IS FALSE
  ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
  LIMIT 1
  FOR UPDATE OF ca;

  v_reassignment_time := COALESCE(p_reassignment_time, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  v_reassigned_at := ((p_reassignment_date::timestamp + v_reassignment_time) AT TIME ZONE 'Asia/Manila');

  SELECT COALESCE(short_name, full_name) INTO v_new_prosecutor_name FROM public.prosecutors WHERE id = p_new_prosecutor_id;
  SELECT COALESCE(short_name, full_name) INTO v_staff_name FROM public.staff WHERE id = p_new_staff_id;

  IF v_previous_assignment_id IS NOT NULL THEN
    UPDATE public.case_assignments
    SET unassigned_at = v_reassigned_at, unassigned_by_user_id = p_user_id, unassignment_reason = v_reason
    WHERE id = v_previous_assignment_id;

    SELECT to_jsonb(ca) INTO v_previous_assignment_new FROM public.case_assignments ca WHERE ca.id = v_previous_assignment_id;
  END IF;

  INSERT INTO public.case_assignments (case_id, prosecutor_id, staff_id, assigned_by_user_id, assigned_at, remarks)
  VALUES (p_case_id, p_new_prosecutor_id, p_new_staff_id, p_user_id, v_reassigned_at, v_remarks)
  RETURNING id INTO v_new_assignment_id;

  INSERT INTO public.case_events (
    case_id, event_type_id, event_date, event_time, title, description,
    status_id, case_status_id, case_stage_id,
    prosecutor_id, staff_id, details_jsonb, source, source_table, source_id,
    created_by_user_id, updated_by_user_id
  ) VALUES (
    p_case_id, v_event_type_id, p_reassignment_date, v_reassignment_time,
    'Case Reassignment',
    CASE
      WHEN v_previous_assignment_id IS NULL THEN 'Reassigned to Prosec ' || COALESCE(v_new_prosecutor_name, p_new_prosecutor_id::text) || ' on ' || to_char(p_reassignment_date, 'Mon FMDD, YYYY')
      ELSE 'Reassigned from Prosec ' || COALESCE(v_previous_prosecutor_name, v_previous_prosecutor_id::text) || ' to Prosec ' || COALESCE(v_new_prosecutor_name, p_new_prosecutor_id::text) || ' on ' || to_char(p_reassignment_date, 'Mon FMDD, YYYY')
    END,
    v_pending_status_id, v_pending_status_id, v_case_reassigned_stage_id,
    p_new_prosecutor_id, p_new_staff_id,
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
      'reassignment_date', p_reassignment_date,
      'reassignment_time', v_reassignment_time,
      'reason', v_reason,
      'remarks', v_remarks,
      'automatic_case_status', 'Pending',
      'automatic_case_stage', 'Case Reassigned'
    ),
    'MANUAL_ENTRY', 'case_assignments', v_new_assignment_id, p_user_id, p_user_id
  ) RETURNING id INTO v_event_id;

  UPDATE public.case_assignments SET case_event_id = v_event_id WHERE id = v_new_assignment_id;

  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
  VALUES (p_case_id,COALESCE(v_previous_case_status_id, v_previous_status_id),v_pending_status_id,p_user_id,now(),p_reassignment_date,v_remarks,v_event_id)
  RETURNING id INTO v_status_history_id;

  INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id)
  VALUES (p_case_id,v_previous_stage_id,v_case_reassigned_stage_id,p_user_id,now(),p_reassignment_date,v_remarks,v_event_id)
  RETURNING id INTO v_stage_history_id;

  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date,updated_at)
  VALUES (p_case_id,v_pending_status_id,p_reassignment_date,v_pending_status_id,p_reassignment_date,v_case_reassigned_stage_id,p_reassignment_date,now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_status_remarks=NULL,current_case_stage_remarks=NULL,updated_at=now();

  SELECT to_jsonb(ca) INTO v_new_assignment_new FROM public.case_assignments ca WHERE ca.id = v_new_assignment_id;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE cpd.case_id = p_case_id;

  IF v_previous_assignment_id IS NOT NULL THEN
    INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
    VALUES (p_user_id, 'case_assignments', v_previous_assignment_id, 'CASE_REASSIGNMENT_OLD_ASSIGNMENT_CLOSED', v_previous_assignment_old, v_previous_assignment_new, p_case_id, 'Closed old assignment during case reassignment.', jsonb_build_object('case_event_id', v_event_id, 'reason', v_reason, 'new_assignment_id', v_new_assignment_id));
  END IF;

  INSERT INTO public.audit_logs (actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata)
  VALUES (p_user_id, 'case_assignments', v_new_assignment_id, 'CASE_REASSIGNMENT_NEW_ASSIGNMENT_CREATED', NULL, v_new_assignment_new, p_case_id, 'Created new assignment during case reassignment.', jsonb_build_object('case_event_id', v_event_id, 'reason', v_reason, 'previous_assignment_id', v_previous_assignment_id, 'case_status_id', v_pending_status_id, 'case_stage_id', v_case_reassigned_stage_id, 'status_history_id', v_status_history_id, 'case_stage_history_id', v_stage_history_id, 'case_private_details', v_new_details));

  RETURN v_event_id;
END;
$$;

NOTIFY pgrst, 'reload schema';

COMMIT;
