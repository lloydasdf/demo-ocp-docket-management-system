BEGIN;

-- Edit reasons are audit metadata, not a business requirement.  Keep this safe for
-- installations that have an older, dedicated edit_reason column.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='case_events' AND column_name='edit_reason') THEN
    ALTER TABLE public.case_events ALTER COLUMN edit_reason DROP NOT NULL;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.edit_court_filing_event(
  p_case_event_id bigint, p_court_id bigint DEFAULT NULL, p_court_name text DEFAULT NULL,
  p_court_branch text DEFAULT NULL, p_charge_filed text DEFAULT NULL, p_date_filed date DEFAULT NULL,
  p_time_filed time without time zone DEFAULT NULL, p_information_count integer DEFAULT NULL,
  p_criminal_case_numbers jsonb DEFAULT '[]'::jsonb, p_court_statuses jsonb DEFAULT '[]'::jsonb,
  p_additional_details_jsonb jsonb DEFAULT '[]'::jsonb, p_remarks text DEFAULT NULL,
  p_edit_reason text DEFAULT NULL, p_user_id bigint DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE
  e public.case_events%ROWTYPE; f public.case_court_filings%ROWTYPE; old_data jsonb; new_data jsonb;
  numbers jsonb := '[]'::jsonb; statuses jsonb := '[]'::jsonb; details jsonb := '[]'::jsonb; item jsonb; txt text; dt date; i integer := 0;
  v_court_name text := nullif(btrim(coalesce(p_court_name,'')), ''); v_charge text := nullif(btrim(coalesce(p_charge_filed,'')), ''); v_reason text := nullif(btrim(coalesce(p_edit_reason,'')), ''); v_remarks text := nullif(btrim(coalesce(p_remarks,'')), '');
BEGIN
  SELECT ce.* INTO e FROM public.case_events ce JOIN public.case_event_types t ON t.id=ce.event_type_id WHERE ce.id=p_case_event_id AND ce.is_voided=false AND t.code='COURT_FILING' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active Court Filing event % not found', p_case_event_id; END IF;
  SELECT * INTO f FROM public.case_court_filings WHERE case_event_id=e.id AND case_id=e.case_id AND is_voided=false FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Active Court Filing source record cannot be resolved'; END IF;
  IF v_court_name IS NULL OR v_charge IS NULL OR p_date_filed IS NULL THEN RAISE EXCEPTION 'Court, Charge Filed, and Date Filed are required'; END IF;
  IF p_information_count IS NOT NULL AND p_information_count < 0 THEN RAISE EXCEPTION 'Information Count must be a non-negative integer'; END IF;
  IF jsonb_typeof(coalesce(p_criminal_case_numbers,'[]'::jsonb)) <> 'array' OR jsonb_typeof(coalesce(p_court_statuses,'[]'::jsonb)) <> 'array' OR jsonb_typeof(coalesce(p_additional_details_jsonb,'[]'::jsonb)) <> 'array' THEN RAISE EXCEPTION 'Court Filing list fields must be JSON arrays'; END IF;
  old_data := jsonb_build_object('event',to_jsonb(e),'court_filing',to_jsonb(f));
  FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p_criminal_case_numbers,'[]'::jsonb)) LOOP
    txt := nullif(btrim(item->>'criminal_case_no'),''); IF txt IS NOT NULL AND NOT numbers @> jsonb_build_array(txt) THEN numbers := numbers || jsonb_build_array(txt); END IF;
  END LOOP;
  FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p_court_statuses,'[]'::jsonb)) LOOP
    txt := nullif(btrim(item->>'court_status'),'');
    IF txt IS NULL AND nullif(btrim(item->>'status_date'),'') IS NULL THEN CONTINUE; END IF;
    IF txt IS NULL OR nullif(btrim(item->>'status_date'),'') IS NULL THEN RAISE EXCEPTION 'Court Status and Status Date are required'; END IF;
    dt := (item->>'status_date')::date; IF NOT statuses @> jsonb_build_array(jsonb_build_object('court_status',txt,'status_date',dt)) THEN statuses := statuses || jsonb_build_array(jsonb_build_object('court_status',txt,'status_date',dt)); END IF;
  END LOOP;
  FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p_additional_details_jsonb,'[]'::jsonb)) LOOP
    IF nullif(btrim(item->>'detail'),'') IS NOT NULL OR nullif(btrim(item->>'value'),'') IS NOT NULL THEN details := details || jsonb_build_array(jsonb_build_object('detail',btrim(coalesce(item->>'detail','')),'value',btrim(coalesce(item->>'value','')))); END IF;
  END LOOP;
  UPDATE public.case_court_filing_criminal_cases SET is_voided=true,voided_at=now(),voided_by_user_id=p_user_id,void_reason='Removed by Court Filing edit',updated_at=now(),updated_by_user_id=p_user_id WHERE court_filing_id=f.id AND is_voided=false AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(numbers) n WHERE lower(n.value)=lower(criminal_case_no));
  FOR txt IN SELECT value FROM jsonb_array_elements_text(numbers) LOOP i:=i+1; INSERT INTO public.case_court_filing_criminal_cases(case_id,court_filing_id,criminal_case_no,sort_order,created_by_user_id,updated_by_user_id) VALUES(e.case_id,f.id,txt,i,p_user_id,p_user_id) ON CONFLICT (court_filing_id,(lower(criminal_case_no))) WHERE is_voided=false DO UPDATE SET sort_order=EXCLUDED.sort_order,updated_at=now(),updated_by_user_id=p_user_id; END LOOP;
  UPDATE public.case_court_filing_statuses SET is_voided=true,voided_at=now(),voided_by_user_id=p_user_id,void_reason='Removed by Court Filing edit',updated_at=now(),updated_by_user_id=p_user_id WHERE court_filing_id=f.id AND is_voided=false AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(statuses) s WHERE lower(s.value->>'court_status')=lower(court_status) AND (s.value->>'status_date')::date=status_date);
  i:=0; FOR item IN SELECT value FROM jsonb_array_elements(statuses) LOOP i:=i+1; INSERT INTO public.case_court_filing_statuses(case_id,court_filing_id,court_status,status_date,sort_order,remarks,created_by_user_id,updated_by_user_id) VALUES(e.case_id,f.id,item->>'court_status',(item->>'status_date')::date,i,v_remarks,p_user_id,p_user_id) ON CONFLICT (court_filing_id,(lower(court_status)),status_date) WHERE is_voided=false DO UPDATE SET sort_order=EXCLUDED.sort_order,remarks=EXCLUDED.remarks,updated_at=now(),updated_by_user_id=p_user_id; END LOOP;
  UPDATE public.case_court_filings SET court_id=p_court_id,court_name=v_court_name,court_branch=nullif(btrim(coalesce(p_court_branch,'')),''),charge_filed=v_charge,date_filed=p_date_filed,time_filed=p_time_filed,information_count=p_information_count,criminal_case_no=CASE WHEN jsonb_array_length(numbers)=0 THEN NULL ELSE numbers->>0 END,court_status=CASE WHEN jsonb_array_length(statuses)=0 THEN NULL ELSE (statuses->(jsonb_array_length(statuses)-1))->>'court_status' END,additional_details_jsonb=details,court_status_update_remarks=v_remarks,remarks=v_remarks,updated_by_user_id=p_user_id,updated_at=now() WHERE id=f.id;
  UPDATE public.case_events SET event_date=p_date_filed,event_time=p_time_filed,description=v_remarks,details_jsonb=coalesce(details_jsonb,'{}'::jsonb) || jsonb_build_object('court_filing_id',f.id,'court_id',p_court_id,'court',v_court_name,'court_name',v_court_name,'court_branch',nullif(btrim(coalesce(p_court_branch,'')),''),'charge_filed',v_charge,'date_filed',p_date_filed,'time_filed',p_time_filed,'criminal_case_numbers',numbers,'court_statuses',statuses,'information_count',p_information_count,'additional_details',details,'remarks',v_remarks),updated_by_user_id=p_user_id,updated_at=now() WHERE id=e.id;
  SELECT jsonb_build_object('event',to_jsonb(ce),'court_filing',to_jsonb(cf)) INTO new_data FROM public.case_events ce JOIN public.case_court_filings cf ON cf.case_event_id=ce.id WHERE ce.id=e.id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES(p_user_id,'case_events',e.id,'EDIT_COURT_FILING',old_data,new_data,e.case_id,'Court filing edited.',jsonb_build_object('reason',v_reason,'court_filing_id',f.id));
  RETURN e.id;
END; $$;
GRANT EXECUTE ON FUNCTION public.edit_court_filing_event(bigint,bigint,text,text,text,date,time without time zone,integer,jsonb,jsonb,jsonb,text,text,bigint) TO authenticated, service_role;
-- The legacy generic editor remains callable by older clients; blank reasons are
-- normalized to NULL while still producing an audit entry.
CREATE OR REPLACE FUNCTION public.edit_case_event(
  p_case_event_id bigint, p_event_date date, p_title text, p_description text,
  p_details_jsonb jsonb DEFAULT NULL::jsonb, p_edit_reason text DEFAULT NULL::text,
  p_user_id bigint DEFAULT NULL::bigint
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE old_data jsonb; new_data jsonb; case_id_value bigint; reason text := nullif(btrim(coalesce(p_edit_reason,'')), '');
BEGIN
  SELECT to_jsonb(ce), ce.case_id INTO old_data, case_id_value FROM public.case_events ce WHERE ce.id=p_case_event_id AND ce.is_voided=false FOR UPDATE;
  IF old_data IS NULL THEN RAISE EXCEPTION 'Active timeline event % not found', p_case_event_id; END IF;
  UPDATE public.case_events SET event_date=coalesce(p_event_date,event_date),title=coalesce(nullif(btrim(coalesce(p_title,'')),''),title),description=nullif(btrim(coalesce(p_description,'')),''),details_jsonb=coalesce(p_details_jsonb,details_jsonb),updated_by_user_id=p_user_id,updated_at=now() WHERE id=p_case_event_id;
  SELECT to_jsonb(ce) INTO new_data FROM public.case_events ce WHERE ce.id=p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES(p_user_id,'case_events',p_case_event_id,'EDIT_CASE_EVENT',old_data,new_data,case_id_value,'Edited case timeline activity',jsonb_build_object('reason',reason));
  RETURN p_case_event_id;
END; $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
