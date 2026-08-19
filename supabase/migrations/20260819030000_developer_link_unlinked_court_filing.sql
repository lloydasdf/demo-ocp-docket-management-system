CREATE OR REPLACE FUNCTION public.get_court_filing_link_correction_candidates(p_case_event_id bigint)
RETURNS TABLE(id bigint, approval_id bigint, case_resolution_id bigint, charge_text text, decision_code text, date_approved date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_case_id bigint;
BEGIN
  PERFORM public.require_any_app_role(ARRAY['DEVELOPER']);
  SELECT cf.case_id INTO v_case_id FROM public.case_court_filings cf JOIN public.case_events ce ON ce.id=cf.case_event_id AND ce.is_voided=false
  WHERE ce.id=p_case_event_id AND cf.is_voided=false AND cf.case_resolution_approval_action_id IS NULL;
  IF v_case_id IS NULL THEN RAISE EXCEPTION 'An active unlinked Court Filing was not found for this event'; END IF;
  RETURN QUERY SELECT aa.id,a.id,a.case_resolution_id,aa.charge_text,aa.decision_code,a.date_approved
  FROM public.case_resolution_approval_actions aa JOIN public.case_resolution_approvals a ON a.id=aa.approval_id AND a.is_voided=false
  LEFT JOIN public.case_resolutions cr ON cr.id=a.case_resolution_id
  WHERE aa.case_id=v_case_id AND aa.decision_code='FOR_FILING' AND (a.case_resolution_id IS NULL OR cr.is_voided=false)
    AND NOT EXISTS (SELECT 1 FROM public.case_court_filings used WHERE used.case_resolution_approval_action_id=aa.id AND used.is_voided=false)
  ORDER BY a.date_approved DESC NULLS LAST,aa.display_order,aa.id;
END $$;

CREATE OR REPLACE FUNCTION public.correct_court_filing_approval_link(p_case_event_id bigint,p_case_resolution_approval_action_id bigint)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_actor bigint:=public.current_app_user_id(); v_filing public.case_court_filings%ROWTYPE; v_approval_id bigint; v_charge text;
  v_old_filing jsonb; v_old_event jsonb; v_old_state jsonb; v_new_state jsonb; v_status_id bigint; v_stage_id bigint; v_status_code text; v_stage_code text;
BEGIN
  PERFORM public.require_any_app_role(ARRAY['DEVELOPER']);
  SELECT cf.* INTO v_filing FROM public.case_court_filings cf JOIN public.case_events ce ON ce.id=cf.case_event_id
  WHERE cf.case_event_id=p_case_event_id AND cf.is_voided=false AND ce.is_voided=false FOR UPDATE OF cf;
  IF v_filing.id IS NULL THEN RAISE EXCEPTION 'An active Court Filing was not found for this event'; END IF;
  IF v_filing.case_resolution_approval_action_id IS NOT NULL THEN RAISE EXCEPTION 'This Court Filing is already linked to an approved filing decision'; END IF;
  SELECT a.id,aa.charge_text INTO v_approval_id,v_charge FROM public.case_resolution_approval_actions aa
  JOIN public.case_resolution_approvals a ON a.id=aa.approval_id AND a.is_voided=false LEFT JOIN public.case_resolutions cr ON cr.id=a.case_resolution_id
  WHERE aa.id=p_case_resolution_approval_action_id AND aa.case_id=v_filing.case_id AND aa.decision_code='FOR_FILING' AND (a.case_resolution_id IS NULL OR cr.is_voided=false);
  IF v_approval_id IS NULL THEN RAISE EXCEPTION 'No active approved FOR_FILING action from this case was found'; END IF;
  IF EXISTS (SELECT 1 FROM public.case_court_filings cf WHERE cf.case_resolution_approval_action_id=p_case_resolution_approval_action_id AND cf.is_voided=false) THEN RAISE EXCEPTION 'This approved filing decision is already linked to another active Court Filing'; END IF;
  v_old_filing:=to_jsonb(v_filing); SELECT to_jsonb(ce) INTO v_old_event FROM public.case_events ce WHERE ce.id=p_case_event_id;
  SELECT to_jsonb(cpd) INTO v_old_state FROM public.case_private_details cpd WHERE cpd.case_id=v_filing.case_id;
  UPDATE public.case_court_filings SET case_resolution_approval_id=v_approval_id,case_resolution_approval_action_id=p_case_resolution_approval_action_id,updated_at=now(),updated_by_user_id=v_actor WHERE id=v_filing.id;
  UPDATE public.case_events SET details_jsonb=COALESCE(details_jsonb,'{}'::jsonb)||jsonb_build_object('case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id,'approved_filing_decision',v_charge,'approved_filing_decision_label',v_charge),updated_at=now(),updated_by_user_id=v_actor WHERE id=p_case_event_id;
  SELECT cs.id,cs.code,st.id,st.code INTO v_status_id,v_status_code,v_stage_id,v_stage_code FROM public.compute_current_case_state(v_filing.case_id) state
  JOIN public.case_statuses cs ON cs.code=state.case_status_code AND cs.is_active=true JOIN public.case_stages st ON st.code=state.case_stage_code AND st.is_active=true;
  INSERT INTO public.case_private_details(case_id,source,current_status_id,current_status_date,current_case_status_id,current_case_status_date,current_case_stage_id,current_case_stage_date,updated_at)
  VALUES(v_filing.case_id,'COURT_FILING_LINK_CORRECTION',v_status_id,CURRENT_DATE,v_status_id,CURRENT_DATE,v_stage_id,CURRENT_DATE,now()) ON CONFLICT(case_id) DO UPDATE SET
    current_status_id=EXCLUDED.current_status_id,current_status_date=CASE WHEN case_private_details.current_status_id IS DISTINCT FROM EXCLUDED.current_status_id THEN CURRENT_DATE ELSE case_private_details.current_status_date END,
    current_case_status_id=EXCLUDED.current_case_status_id,current_case_status_date=CASE WHEN case_private_details.current_case_status_id IS DISTINCT FROM EXCLUDED.current_case_status_id THEN CURRENT_DATE ELSE case_private_details.current_case_status_date END,
    current_case_stage_id=EXCLUDED.current_case_stage_id,current_case_stage_date=CASE WHEN case_private_details.current_case_stage_id IS DISTINCT FROM EXCLUDED.current_case_stage_id THEN CURRENT_DATE ELSE case_private_details.current_case_stage_date END,updated_at=now();
  SELECT to_jsonb(cpd) INTO v_new_state FROM public.case_private_details cpd WHERE cpd.case_id=v_filing.case_id;
  UPDATE public.cases SET updated_at=now(),updated_by_user_id=v_actor WHERE id=v_filing.case_id;
  INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata) VALUES(v_actor,'case_court_filings',v_filing.id,'DEVELOPER_CORRECT_COURT_FILING_LINK',
    jsonb_build_object('filing',v_old_filing,'event',v_old_event,'case_state',v_old_state),jsonb_build_object('filing',(SELECT to_jsonb(cf) FROM public.case_court_filings cf WHERE cf.id=v_filing.id),'event',(SELECT to_jsonb(ce) FROM public.case_events ce WHERE ce.id=p_case_event_id),'case_state',v_new_state),v_filing.case_id,
    'Developer linked an existing Court Filing to its approved FOR_FILING action.',jsonb_build_object('case_event_id',p_case_event_id,'case_resolution_approval_id',v_approval_id,'case_resolution_approval_action_id',p_case_resolution_approval_action_id,'case_status_code',v_status_code,'case_stage_code',v_stage_code,'case_event_created',false));
  RETURN v_filing.id;
END $$;

REVOKE ALL ON FUNCTION public.get_court_filing_link_correction_candidates(bigint) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.correct_court_filing_approval_link(bigint,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_court_filing_link_correction_candidates(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.correct_court_filing_approval_link(bigint,bigint) TO authenticated;
