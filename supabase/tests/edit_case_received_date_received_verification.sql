-- Repeatable verification for CASE_RECEIVED event edits syncing canonical cases.date_received.
-- Run with psql against a disposable/local database. The transaction rolls back all rows.
BEGIN;

DO $$
DECLARE
  v_suffix text := left(replace(gen_random_uuid()::text, '-', ''), 10);
  v_docket_type_id bigint;
  v_status_id bigint;
  v_event_type_id bigint;
  v_case_id bigint;
  v_event_id bigint;
  v_status_history_id bigint;
BEGIN
  INSERT INTO public.docket_types(name,prefix,sort_order,is_active)
  VALUES ('Case Received Edit Verification ' || v_suffix, 'CRE' || left(v_suffix, 3), 0, true)
  RETURNING id INTO v_docket_type_id;

  INSERT INTO public.case_statuses(code,display_label,sort_order,is_active)
  VALUES ('CRE_EDIT_' || v_suffix, 'Case Received Edit Verification', 0, true)
  RETURNING id INTO v_status_id;

  SELECT id INTO v_event_type_id
  FROM public.case_event_types
  WHERE code = 'CASE_RECEIVED' AND is_active IS TRUE
  LIMIT 1;
  IF v_event_type_id IS NULL THEN RAISE EXCEPTION 'Required CASE_RECEIVED event type is missing'; END IF;

  INSERT INTO public.cases(docket_type_id,docket_year,docket_number,date_received,is_archived)
  VALUES (v_docket_type_id,2099,1,'2099-01-15',false)
  RETURNING id INTO v_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,event_order,title,description,status_id,source,source_table)
  VALUES (v_case_id,v_event_type_id,'2099-01-15','08:00:00',1,'Case received','Original received date',v_status_id,'MANUAL_ENTRY','case_status_history')
  RETURNING id INTO v_event_id;

  INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_at,status_date,remarks,case_event_id)
  VALUES (v_case_id,NULL,v_status_id,now(),'2099-01-15','Original received date',v_event_id)
  RETURNING id INTO v_status_history_id;

  UPDATE public.case_events SET source_id = v_status_history_id WHERE id = v_event_id;

  PERFORM public.edit_case_event_specific(
    v_event_id,
    'CASE_RECEIVED',
    jsonb_build_object('event_date','2099-02-03','event_time','10:30:00','remarks','Corrected received date'),
    'verification edit',
    NULL
  );

  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id AND date_received = '2099-02-03'::date) THEN
    RAISE EXCEPTION 'cases.date_received was not synced to edited Case Received date';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.case_events WHERE id = v_event_id AND event_date = '2099-02-03'::date AND event_time = '10:30:00'::time) THEN
    RAISE EXCEPTION 'case_events was not updated with edited Case Received timestamp';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.case_status_history WHERE id = v_status_history_id AND status_date = '2099-02-03'::date AND remarks = 'Corrected received date') THEN
    RAISE EXCEPTION 'case_status_history was not updated with edited Case Received date';
  END IF;
END $$;

ROLLBACK;
