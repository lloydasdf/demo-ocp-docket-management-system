BEGIN;

-- A Court Filing may be linked to an approved FOR_FILING decision, but the link is optional.
-- Standalone and linked filings use the same timeline, audit, and case state workflow.
ALTER TABLE public.case_court_filings
  ALTER COLUMN case_resolution_approval_id DROP NOT NULL,
  ALTER COLUMN case_resolution_approval_action_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.record_court_filing_event(
  p_case_id bigint,
  p_case_resolution_approval_action_id bigint,
  p_court_id bigint DEFAULT NULL,
  p_court_name text DEFAULT NULL,
  p_court_branch text DEFAULT NULL,
  p_charge_filed text DEFAULT NULL,
  p_date_filed date DEFAULT NULL,
  p_time_filed time without time zone DEFAULT NULL,
  p_information_count integer DEFAULT NULL,
  p_criminal_case_no text DEFAULT NULL,
  p_remarks text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_event_type_id bigint; v_event_id bigint; v_filing_id bigint; v_approval_id bigint; v_resolution_id bigint;
  v_case_status_code text; v_case_stage_code text; v_case_status_label text; v_case_stage_label text;
  v_status_id bigint; v_stage_id bigint; v_prev_status_id bigint; v_prev_case_status_id bigint; v_prev_stage_id bigint;
  v_status_history_id bigint; v_stage_history_id bigint;
  v_effective_time time without time zone;
  v_remarks text := NULLIF(btrim(COALESCE(p_remarks, '')), '');
  v_old_details jsonb; v_new_details jsonb; v_court_id bigint; v_court_name text; v_court_code text; v_court_code_candidate text; v_code_suffix integer := 0; v_charge text := NULLIF(btrim(COALESCE(p_charge_filed, '')), '');
BEGIN
  IF p_case_id IS NULL THEN RAISE EXCEPTION 'Case id is required'; END IF;
  IF p_court_id IS NULL AND NULLIF(btrim(COALESCE(p_court_name, '')), '') IS NULL THEN RAISE EXCEPTION 'Court is required'; END IF;
  IF v_charge IS NULL THEN RAISE EXCEPTION 'Charge filed is required'; END IF;
  IF p_date_filed IS NULL THEN RAISE EXCEPTION 'Date filed is required'; END IF;
  v_effective_time := COALESCE(p_time_filed, (now() AT TIME ZONE 'Asia/Manila')::time(0));
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RAISE EXCEPTION 'Unknown case id %', p_case_id; END IF;

  IF p_case_resolution_approval_action_id IS NOT NULL THEN
    SELECT aa.approval_id, a.case_resolution_id INTO v_approval_id, v_resolution_id
    FROM public.case_resolution_approval_actions aa
    JOIN public.case_resolution_approvals a ON a.id = aa.approval_id
    JOIN public.case_resolutions cr ON cr.id = a.case_resolution_id
    WHERE aa.id = p_case_resolution_approval_action_id AND aa.case_id = p_case_id
      AND aa.decision_code = 'FOR_FILING' AND a.is_voided = false AND cr.is_voided = false;
    IF v_approval_id IS NULL THEN RAISE EXCEPTION 'No active approved FOR_FILING decision was found for this case.'; END IF;
  END IF;

  IF p_court_id IS NOT NULL THEN
    SELECT c.id, c.name INTO v_court_id, v_court_name FROM public.courts c WHERE c.id = p_court_id;
    IF v_court_id IS NULL THEN RAISE EXCEPTION 'Unknown court id %', p_court_id; END IF;
  ELSE
    SELECT c.id, c.name INTO v_court_id, v_court_name FROM public.courts c WHERE lower(btrim(c.name)) = lower(btrim(p_court_name)) ORDER BY c.id LIMIT 1;
    IF v_court_id IS NULL THEN
      v_court_name := NULLIF(btrim(p_court_name), '');
      v_court_code_candidate := upper(regexp_replace(v_court_name, '[^a-zA-Z0-9]+', '_', 'g'));
      v_court_code_candidate := trim(both '_' FROM COALESCE(NULLIF(v_court_code_candidate, ''), 'COURT'));
      v_court_code := left(v_court_code_candidate, 64);
      WHILE EXISTS (SELECT 1 FROM public.courts WHERE code = v_court_code) LOOP
        v_code_suffix := v_code_suffix + 1;
        v_court_code := left(v_court_code_candidate, greatest(1, 63 - length(v_code_suffix::text))) || '_' || v_code_suffix::text;
      END LOOP;
      INSERT INTO public.courts(code, name, court_type, is_active) VALUES (v_court_code, v_court_name, NULL, true) RETURNING id, name INTO v_court_id, v_court_name;
    END IF;
  END IF;

  INSERT INTO public.case_event_types (code, display_label, category, description, sort_order, is_system, is_active) VALUES ('COURT_FILING','Court Filing','COURT','Manual timeline event for recording filing in court.',140,true,true) ON CONFLICT (code) DO UPDATE SET display_label=EXCLUDED.display_label,is_active=true,updated_at=now() RETURNING id INTO v_event_type_id;

  SELECT current_status_id, current_case_status_id, current_case_stage_id, to_jsonb(cpd) INTO v_prev_status_id, v_prev_case_status_id, v_prev_stage_id, v_old_details FROM public.case_private_details cpd WHERE case_id=p_case_id;

  INSERT INTO public.case_events(case_id,event_type_id,event_date,event_time,title,description,status_id,case_status_id,case_stage_id,details_jsonb,source,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_type_id,p_date_filed,v_effective_time,'Court Filing','Filed in ' || v_court_name || ' on ' || to_char(p_date_filed, 'Mon FMDD, YYYY'),NULL,NULL,NULL,
    jsonb_build_object('court',v_court_name,'court_id',v_court_id,'court_branch',NULLIF(btrim(COALESCE(p_court_branch,'')),''),'charge_filed',v_charge,'date_filed',p_date_filed,'time_filed',v_effective_time,'information_count',p_information_count,'criminal_case_no',NULLIF(btrim(COALESCE(p_criminal_case_no,'')),''),'remarks',v_remarks,'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id),
    'MANUAL_ENTRY',p_user_id,p_user_id) RETURNING id INTO v_event_id;

  INSERT INTO public.case_court_filings(case_id,case_event_id,case_resolution_approval_id,case_resolution_approval_action_id,court_id,court_name,court_branch,charge_filed,date_filed,time_filed,information_count,criminal_case_no,remarks,created_by_user_id,updated_by_user_id)
  VALUES (p_case_id,v_event_id,v_approval_id,p_case_resolution_approval_action_id,v_court_id,v_court_name,NULLIF(btrim(COALESCE(p_court_branch,'')),''),v_charge,p_date_filed,v_effective_time,p_information_count,NULLIF(btrim(COALESCE(p_criminal_case_no,'')),''),v_remarks,p_user_id,p_user_id) RETURNING id INTO v_filing_id;

  SELECT case_status_code, case_stage_code INTO v_case_status_code, v_case_stage_code FROM public.compute_current_case_state(p_case_id) LIMIT 1;
  SELECT id, display_label INTO v_status_id, v_case_status_label FROM public.case_statuses WHERE code = v_case_status_code AND is_active IS TRUE LIMIT 1;
  SELECT id, display_label INTO v_stage_id, v_case_stage_label FROM public.case_stages WHERE code = v_case_stage_code AND is_active IS TRUE LIMIT 1;
  IF v_status_id IS NULL THEN RAISE EXCEPTION 'Missing active case status %', v_case_status_code; END IF;
  IF v_stage_id IS NULL THEN RAISE EXCEPTION 'Missing active case stage %', v_case_stage_code; END IF;

  UPDATE public.case_events SET source_table='case_court_filings', source_id=v_filing_id, status_id=v_status_id, case_status_id=v_status_id, case_stage_id=v_stage_id, details_jsonb=details_jsonb || jsonb_build_object('case_status_code',v_case_status_code,'case_status_label',v_case_status_label,'case_stage_code',v_case_stage_code,'case_stage_label',v_case_stage_label), updated_at=now(), updated_by_user_id=p_user_id WHERE id=v_event_id;

  INSERT INTO public.case_private_details(case_id,current_status_id,current_status_date,current_status_remarks,current_case_status_id,current_case_status_date,current_case_status_remarks,current_case_stage_id,current_case_stage_date,current_case_stage_remarks,updated_at)
  VALUES (p_case_id,v_status_id,p_date_filed,v_remarks,v_status_id,p_date_filed,v_remarks,v_stage_id,p_date_filed,v_remarks,now())
  ON CONFLICT (case_id) DO UPDATE SET current_status_id=EXCLUDED.current_status_id,current_status_date=EXCLUDED.current_status_date,current_status_remarks=EXCLUDED.current_status_remarks,current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=EXCLUDED.current_case_status_date,current_case_status_remarks=EXCLUDED.current_case_status_remarks,current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=EXCLUDED.current_case_stage_date,current_case_stage_remarks=EXCLUDED.current_case_stage_remarks,updated_at=now();

  IF COALESCE(v_prev_case_status_id, v_prev_status_id) IS DISTINCT FROM v_status_id THEN INSERT INTO public.case_status_history(case_id,from_status_id,to_status_id,changed_by_user_id,changed_at,status_date,remarks,case_event_id) VALUES (p_case_id,COALESCE(v_prev_case_status_id, v_prev_status_id),v_status_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_status_history_id; END IF;
  IF v_prev_stage_id IS DISTINCT FROM v_stage_id THEN INSERT INTO public.case_stage_history(case_id,from_stage_id,to_stage_id,changed_by_user_id,changed_at,stage_date,remarks,case_event_id) VALUES (p_case_id,v_prev_stage_id,v_stage_id,p_user_id,now(),p_date_filed,v_remarks,v_event_id) RETURNING id INTO v_stage_history_id; END IF;
  SELECT to_jsonb(cpd) INTO v_new_details FROM public.case_private_details cpd WHERE case_id=p_case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES (p_user_id,'case_court_filings',v_filing_id,'COURT_FILING',v_old_details,v_new_details,p_case_id,'Court filing recorded.',jsonb_build_object('case_event_id',v_event_id,'status_history_id',v_status_history_id,'case_stage_history_id',v_stage_history_id,'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id,'case_status_code',v_case_status_code,'case_stage_code',v_case_stage_code));
  RETURN v_event_id;
END;
$$;


GRANT EXECUTE ON FUNCTION public.record_court_filing_event(bigint,bigint,bigint,text,text,text,date,time without time zone,integer,text,text,bigint) TO authenticated;

COMMIT;
