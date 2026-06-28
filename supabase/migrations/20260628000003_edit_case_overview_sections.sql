CREATE OR REPLACE FUNCTION public.edit_case_overview_section(p_payload jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_case_id bigint := (p_payload->>'caseId')::bigint;
  v_section text := lower(btrim(p_payload->>'section'));
  v_reason text := nullif(btrim(p_payload->>'reason'), '');
  v_user_id bigint := nullif(p_payload->>'userId','')::bigint;
  v_old jsonb;
  v_new jsonb;
  v_event_type_id bigint;
  v_event_id bigint;
  v_assignment_id bigint;
  v_from_status_id bigint;
  v_to_status_id bigint;
  v_status_date date;
  v_status_remarks text;
  v_prosecutor_id bigint;
  v_assigned_at timestamptz;
  v_assignment_remarks text;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_section IS NULL THEN RAISE EXCEPTION 'section is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_old
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  IF v_section = 'docket_info' THEN
    UPDATE public.cases SET
      docket_type_id = COALESCE(nullif(p_payload#>>'{data,docketTypeId}','')::bigint, docket_type_id),
      docket_year = COALESCE(nullif(p_payload#>>'{data,docketYear}','')::int, docket_year),
      docket_number = COALESCE(nullif(p_payload#>>'{data,docketNumber}','')::int, docket_number),
      docket_month_code = COALESCE(nullif(btrim(p_payload#>>'{data,docketMonthCode}'),''), docket_month_code),
      date_received = COALESCE(nullif(p_payload#>>'{data,dateReceived}','')::date, date_received),
      updated_by_user_id = v_user_id,
      updated_at = now()
    WHERE id = v_case_id;
  ELSIF v_section = 'case_details' THEN
    UPDATE public.cases SET
      case_classification_id = nullif(p_payload#>>'{data,caseClassificationId}','')::bigint,
      updated_by_user_id = v_user_id,
      updated_at = now()
    WHERE id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    UPDATE public.case_private_details SET
      is_summary_procedure = COALESCE(nullif(p_payload#>>'{data,isSummaryProcedure}','')::boolean, false),
      summary_text = nullif(btrim(p_payload#>>'{data,summaryText}'),''),
      remarks = nullif(btrim(p_payload#>>'{data,remarks}'),'')
    WHERE case_id = v_case_id;
  ELSIF v_section = 'status' THEN
    v_to_status_id := nullif(p_payload#>>'{data,statusId}','')::bigint;
    v_status_date := COALESCE(nullif(p_payload#>>'{data,statusDate}','')::date, current_date);
    v_status_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_to_status_id IS NULL THEN RAISE EXCEPTION 'statusId is required'; END IF;
    SELECT current_status_id INTO v_from_status_id FROM public.case_private_details WHERE case_id = v_case_id;
    INSERT INTO public.case_private_details(case_id, source) VALUES (v_case_id, 'MANUAL_ENTRY') ON CONFLICT (case_id) DO NOTHING;
    SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'STATUS_UPDATED' AND is_active IS TRUE LIMIT 1;
    IF v_event_type_id IS NULL THEN SELECT id INTO v_event_type_id FROM public.case_event_types WHERE code = 'CASE_RECEIVED' LIMIT 1; END IF;
    IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Missing case event type STATUS_UPDATED or CASE_RECEIVED'; END IF;
    INSERT INTO public.case_events(case_id,event_type_id,event_date,title,description,status_id,source,source_table,created_by_user_id,updated_by_user_id)
    VALUES (v_case_id,v_event_type_id,v_status_date,'Status updated',v_status_remarks,v_to_status_id,'MANUAL_EDIT','case_status_history',v_user_id,v_user_id) RETURNING id INTO v_event_id;
    INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id)
    VALUES (v_case_id,v_from_status_id,v_to_status_id,v_user_id,now(),v_status_date,v_status_remarks,v_event_id);
    UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
    UPDATE public.case_private_details SET current_status_id = v_to_status_id, current_status_date = v_status_date, current_status_remarks = v_status_remarks WHERE case_id = v_case_id;
  ELSIF v_section = 'assignment' THEN
    v_prosecutor_id := nullif(p_payload#>>'{data,prosecutorId}','')::bigint;
    v_assigned_at := COALESCE(nullif(p_payload#>>'{data,assignedAt}','')::timestamptz, now());
    v_assignment_remarks := COALESCE(nullif(btrim(p_payload#>>'{data,remarks}'),''), v_reason);
    IF v_prosecutor_id IS NULL THEN RAISE EXCEPTION 'prosecutorId is required'; END IF;
    SELECT id INTO v_event_type_id
    FROM public.case_event_types
    WHERE code = 'CASE_RAFFLED'
      AND is_active IS TRUE
    LIMIT 1;

    IF v_event_type_id IS NULL THEN
      SELECT id INTO v_event_type_id
      FROM public.case_event_types
      WHERE code = 'CASE_ASSIGNED'
        AND is_active IS TRUE
      LIMIT 1;
    END IF;

    IF v_event_type_id IS NULL THEN
      RAISE EXCEPTION 'Missing case event type CASE_RAFFLED or CASE_ASSIGNED';
    END IF;

    INSERT INTO public.case_assignments(case_id,prosecutor_id,assigned_by_user_id,assigned_at,remarks)
    VALUES (v_case_id,v_prosecutor_id,v_user_id,v_assigned_at,v_assignment_remarks) RETURNING id INTO v_assignment_id;
    INSERT INTO public.case_events(case_id,event_type_id,event_date,title,description,prosecutor_id,source,source_table,source_id,created_by_user_id,updated_by_user_id)
    VALUES (v_case_id,v_event_type_id,v_assigned_at::date,'Case assigned',v_assignment_remarks,v_prosecutor_id,'MANUAL_EDIT','case_assignments',v_assignment_id,v_user_id,v_user_id) RETURNING id INTO v_event_id;
    UPDATE public.case_assignments SET case_event_id = v_event_id WHERE id = v_assignment_id;
    UPDATE public.cases SET updated_by_user_id = v_user_id, updated_at = now() WHERE id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Editing section % is not implemented yet', v_section;
  END IF;

  SELECT jsonb_build_object('cases', to_jsonb(c), 'case_private_details', to_jsonb(cpd)) INTO v_new
  FROM public.cases c LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id WHERE c.id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'EDIT_CASE_OVERVIEW_' || upper(v_section), 'cases', v_case_id, v_case_id, 'Edited case overview ' || replace(v_section, '_', ' '), jsonb_build_object('reason', v_reason, 'section', v_section), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.edit_case_overview_section(jsonb) TO anon, authenticated, service_role;


ALTER TABLE public.case_addresses
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS delete_reason text;

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS deleted_by_user_id bigint REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS delete_reason text;

CREATE OR REPLACE FUNCTION public.manage_case_places(p_payload jsonb)
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
  v_place jsonb := coalesce(p_payload->'place', '{}'::jsonb);
  v_case_address_id bigint := nullif(v_place->>'id','')::bigint;
  v_address_id bigint := nullif(v_place->>'addressId','')::bigint;
  v_address_type_id bigint;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(ca) || jsonb_build_object('address', to_jsonb(a), 'address_type', to_jsonb(at)) ORDER BY ca.id), '[]'::jsonb)
  INTO v_old
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  WHERE ca.case_id = v_case_id;

  IF v_action IN ('add', 'edit') THEN
    v_address_type_id := nullif(v_place->>'addressTypeId','')::bigint;
    IF v_address_type_id IS NULL THEN
      SELECT id INTO v_address_type_id
      FROM public.address_types
      WHERE is_active IS TRUE
        AND (
          upper(code) IN ('PLACE_OF_COMMISSION', 'COMMISSION_PLACE', 'POC')
          OR display_label ILIKE '%commission%'
        )
      ORDER BY CASE WHEN upper(code) = 'PLACE_OF_COMMISSION' THEN 0 ELSE 1 END, id
      LIMIT 1;
    END IF;
    IF v_address_type_id IS NULL THEN RAISE EXCEPTION 'Missing address type for Place of Commission'; END IF;
    IF v_action = 'add' THEN
      INSERT INTO public.addresses(line1,line2,barangay,city,province,region,zip_code,country,latitude,longitude)
      VALUES (nullif(btrim(v_place->>'line1'),''), nullif(btrim(v_place->>'line2'),''), nullif(btrim(v_place->>'barangay'),''), nullif(btrim(v_place->>'city'),''), nullif(btrim(v_place->>'province'),''), nullif(btrim(v_place->>'region'),''), nullif(btrim(v_place->>'zipCode'),''), coalesce(nullif(btrim(v_place->>'country'),''), 'Philippines'), nullif(v_place->>'latitude','')::numeric, nullif(v_place->>'longitude','')::numeric)
      RETURNING id INTO v_address_id;
      INSERT INTO public.case_addresses(case_id,address_id,address_type_id,is_primary,remarks)
      VALUES (v_case_id, v_address_id, v_address_type_id, coalesce(nullif(v_place->>'isPrimary','')::boolean,false), nullif(btrim(v_place->>'remarks'),''));
    ELSE
      IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
      SELECT address_id INTO v_address_id FROM public.case_addresses WHERE id = v_case_address_id AND case_id = v_case_id;
      IF v_address_id IS NULL THEN RAISE EXCEPTION 'Place % not found', v_case_address_id; END IF;
      UPDATE public.addresses SET line1=nullif(btrim(v_place->>'line1'),''), line2=nullif(btrim(v_place->>'line2'),''), barangay=nullif(btrim(v_place->>'barangay'),''), city=nullif(btrim(v_place->>'city'),''), province=nullif(btrim(v_place->>'province'),''), region=nullif(btrim(v_place->>'region'),''), zip_code=nullif(btrim(v_place->>'zipCode'),''), country=coalesce(nullif(btrim(v_place->>'country'),''), 'Philippines'), latitude=nullif(v_place->>'latitude','')::numeric, longitude=nullif(v_place->>'longitude','')::numeric WHERE id = v_address_id;
      UPDATE public.case_addresses SET address_type_id=v_address_type_id, is_primary=coalesce(nullif(v_place->>'isPrimary','')::boolean,false), remarks=nullif(btrim(v_place->>'remarks'),'') WHERE id = v_case_address_id AND case_id = v_case_id;
    END IF;
  ELSIF v_action = 'remove' THEN
    IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_addresses SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason WHERE id = v_case_address_id AND case_id = v_case_id;
  ELSIF v_action = 'restore' THEN
    IF v_case_address_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.case_addresses SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL WHERE id = v_case_address_id AND case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Unsupported places action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(ca) || jsonb_build_object('address', to_jsonb(a), 'address_type', to_jsonb(at)) ORDER BY ca.id), '[]'::jsonb)
  INTO v_new
  FROM public.case_addresses ca
  JOIN public.addresses a ON a.id = ca.address_id
  LEFT JOIN public.address_types at ON at.id = ca.address_type_id
  WHERE ca.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_PLACES_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed places of commission', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.manage_case_notes(p_payload jsonb)
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
  v_note jsonb := coalesce(p_payload->'note', '{}'::jsonb);
  v_note_id bigint := nullif(v_note->>'id','')::bigint;
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'caseId is required'; END IF;
  IF v_action IS NULL THEN RAISE EXCEPTION 'action is required'; END IF;
  IF v_reason IS NULL THEN RAISE EXCEPTION 'reason is required'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN RAISE EXCEPTION 'Case % not found', v_case_id; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.created_at DESC, n.id DESC), '[]'::jsonb) INTO v_old FROM public.notes n WHERE n.case_id = v_case_id;

  IF v_action = 'add' THEN
    IF nullif(btrim(v_note->>'noteText'),'') IS NULL THEN RAISE EXCEPTION 'noteText is required'; END IF;
    INSERT INTO public.notes(case_id,created_by_user_id,note_text,is_private)
    VALUES (v_case_id, v_user_id, nullif(btrim(v_note->>'noteText'),''), coalesce(nullif(v_note->>'isPrivate','')::boolean,false));
  ELSIF v_action = 'edit' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    IF nullif(btrim(v_note->>'noteText'),'') IS NULL THEN RAISE EXCEPTION 'noteText is required'; END IF;
    UPDATE public.notes SET note_text = nullif(btrim(v_note->>'noteText'),''), is_private = coalesce(nullif(v_note->>'isPrivate','')::boolean,false), updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSIF v_action = 'remove' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.notes SET is_deleted = true, deleted_at = now(), deleted_by_user_id = v_user_id, delete_reason = v_reason, updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSIF v_action = 'restore' THEN
    IF v_note_id IS NULL THEN RAISE EXCEPTION 'id is required'; END IF;
    UPDATE public.notes SET is_deleted = false, deleted_at = NULL, deleted_by_user_id = NULL, delete_reason = NULL, updated_at = now() WHERE id = v_note_id AND case_id = v_case_id;
  ELSE
    RAISE EXCEPTION 'Unsupported notes action %', v_action;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(n) ORDER BY n.created_at DESC, n.id DESC), '[]'::jsonb) INTO v_new FROM public.notes n WHERE n.case_id = v_case_id;

  INSERT INTO public.audit_logs(actor_user_id, action, entity_name, entity_id, case_id, summary, metadata, old_data, new_data)
  VALUES (v_user_id, 'MANAGE_CASE_NOTES_' || upper(v_action), 'cases', v_case_id, v_case_id, 'Managed case notes', jsonb_build_object('reason', v_reason, 'action', v_action), v_old, v_new);
  RETURN v_case_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_case_places(jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.manage_case_notes(jsonb) TO anon, authenticated, service_role;
