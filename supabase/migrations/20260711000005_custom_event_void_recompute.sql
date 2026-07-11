CREATE OR REPLACE FUNCTION public.void_case_event(p_case_event_id bigint, p_void_reason text, p_voided_by_user_id bigint DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb; v_new jsonb; v_case_id bigint; v_event_type_code text; v_source_table text; v_source_id bigint;
  v_filing_id bigint; v_filing_old jsonb; v_filing_new jsonb; v_approval_id bigint; v_resolution_id bigint;
  v_assignment_id bigint; v_assignment_old jsonb; v_assignment_new jsonb;
  v_motion_id bigint; v_motion_old jsonb; v_motion_new jsonb;
  v_petition_id bigint; v_petition_old jsonb; v_petition_new jsonb;
  v_manual_update_id bigint; v_manual_update_old jsonb; v_manual_update_new jsonb;
  v_motion_resolution_id bigint; v_motion_resolution_old jsonb; v_motion_resolution_new jsonb; v_motion_approval_count integer;
  v_motion_decision_approval_id bigint; v_motion_decision_approval_old jsonb; v_motion_decision_approval_new jsonb;
  v_previous_assignment_id bigint; v_previous_assignment_old jsonb; v_previous_assignment_new jsonb; v_latest_assignment_id bigint;
  v_status_code text; v_status_label text; v_status_id bigint; v_prev_status_id bigint; v_status_history_id bigint; v_old_details jsonb; v_new_details jsonb;
BEGIN
  IF nullif(trim(p_void_reason), '') IS NULL THEN RAISE EXCEPTION 'Void reason is required'; END IF;
  SELECT to_jsonb(ce), ce.case_id, cet.code, ce.source_table, ce.source_id INTO v_old, v_case_id, v_event_type_code, v_source_table, v_source_id
  FROM public.case_events ce LEFT JOIN public.case_event_types cet ON cet.id = ce.event_type_id WHERE ce.id = p_case_event_id AND ce.is_voided = false;
  IF v_old IS NULL THEN RAISE EXCEPTION 'Active case event % not found', p_case_event_id; END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolution_approvals' OR v_event_type_code = 'CASE_DECISION_APPROVED' THEN
    SELECT a.id INTO v_approval_id FROM public.case_resolution_approvals a WHERE a.id = v_source_id OR a.case_event_id = p_case_event_id LIMIT 1;
    IF v_approval_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_court_filings cf JOIN public.case_resolution_approval_actions aa ON aa.id = cf.case_resolution_approval_action_id WHERE aa.approval_id = v_approval_id AND cf.is_voided = false) THEN
      RAISE EXCEPTION 'This approval has a court filing. Void the court filing first.';
    END IF;
  END IF;
  IF lower(coalesce(v_source_table,'')) = 'case_resolutions' OR v_event_type_code = 'CASE_RESOLVED' THEN
    SELECT cr.id INTO v_resolution_id FROM public.case_resolutions cr WHERE cr.id = v_source_id OR cr.case_event_id = p_case_event_id LIMIT 1;
    IF v_resolution_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.case_court_filings cf JOIN public.case_resolution_approval_actions aa ON aa.id = cf.case_resolution_approval_action_id JOIN public.case_resolution_approvals a ON a.id = aa.approval_id WHERE a.case_resolution_id = v_resolution_id AND cf.is_voided = false) THEN
      RAISE EXCEPTION 'This resolution has a court filing. Void the court filing first.';
    END IF;
  END IF;

  SELECT current_status_id, to_jsonb(cpd) INTO v_prev_status_id, v_old_details FROM public.case_private_details cpd WHERE cpd.case_id = v_case_id;
  UPDATE public.case_events SET is_voided = true, void_reason = p_void_reason, voided_at = now(), voided_by_user_id = p_voided_by_user_id, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = p_case_event_id;
  SELECT to_jsonb(ce) INTO v_new FROM public.case_events ce WHERE ce.id = p_case_event_id;
  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata) VALUES (p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id, 'Voided case timeline activity', jsonb_build_object('reason', p_void_reason));

  IF v_event_type_code = 'CUSTOM_EVENT' THEN
    IF lower(coalesce(v_old#>>'{details_jsonb,updates_case_status}', 'false')) = 'true' THEN
      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      SELECT to_jsonb(cpd) INTO v_new_details
      FROM public.case_private_details cpd
      WHERE cpd.case_id = v_case_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_events',
        p_case_event_id,
        'VOID_CUSTOM_EVENT_STATUS_STAGE_RECOMPUTED',
        v_old_details,
        v_new_details,
        v_case_id,
        'Custom Event voided; case status and case stage recomputed from active workflow records.',
        jsonb_build_object(
          'case_event_id',p_case_event_id,
          'reason',p_void_reason,
          'updates_case_status',true,
          'previous_case_status_id',COALESCE(v_old_details->>'current_case_status_id', v_old_details->>'current_status_id'),
          'previous_case_status_label',(SELECT display_label FROM public.case_statuses WHERE id = NULLIF(COALESCE(v_old_details->>'current_case_status_id', v_old_details->>'current_status_id'), '')::bigint),
          'previous_case_stage_id',v_old_details->>'current_case_stage_id',
          'previous_case_stage_label',(SELECT display_label FROM public.case_stages WHERE id = NULLIF(v_old_details->>'current_case_stage_id', '')::bigint),
          'recomputed_case_status_id',COALESCE(v_new_details->>'current_case_status_id', v_new_details->>'current_status_id'),
          'recomputed_case_status_label',(SELECT display_label FROM public.case_statuses WHERE id = NULLIF(COALESCE(v_new_details->>'current_case_status_id', v_new_details->>'current_status_id'), '')::bigint),
          'recomputed_case_stage_id',v_new_details->>'current_case_stage_id',
          'recomputed_case_stage_label',(SELECT display_label FROM public.case_stages WHERE id = NULLIF(v_new_details->>'current_case_stage_id', '')::bigint)
        )
      );
    END IF;
    RETURN;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_petitions_for_review' OR v_event_type_code = 'PETITION_FOR_REVIEW' THEN
    SELECT p.id, to_jsonb(p) INTO v_petition_id, v_petition_old
    FROM public.case_petitions_for_review p
    WHERE p.id = v_source_id OR p.case_event_id = p_case_event_id
    ORDER BY CASE WHEN p.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;
    IF v_petition_id IS NOT NULL THEN
      UPDATE public.case_petitions_for_review
      SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now()
      WHERE id = v_petition_id;
      SELECT to_jsonb(p) INTO v_petition_new FROM public.case_petitions_for_review p WHERE p.id = v_petition_id;
      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_petitions_for_review',v_petition_id,'VOID_PETITION_FOR_REVIEW_FROM_EVENT',v_petition_old,v_petition_new,v_case_id,'Petition for Review voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_manual_status_updates' OR v_event_type_code = 'CASE_STATUS_UPDATED' THEN
    SELECT msu.id, to_jsonb(msu) INTO v_manual_update_id, v_manual_update_old
    FROM public.case_manual_status_updates msu
    WHERE msu.id = v_source_id OR msu.case_event_id = p_case_event_id
    ORDER BY CASE WHEN msu.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;
    IF v_manual_update_id IS NOT NULL THEN
      UPDATE public.case_manual_status_updates
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          updated_at = now()
      WHERE id = v_manual_update_id;
      SELECT to_jsonb(msu) INTO v_manual_update_new FROM public.case_manual_status_updates msu WHERE msu.id = v_manual_update_id;
      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_manual_status_updates',v_manual_update_id,'VOID_CASE_STATUS_UPDATED_FROM_EVENT',v_manual_update_old,v_manual_update_new,v_case_id,'Manual Case Status Updated event voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_motions' OR v_event_type_code = 'MOTION_RECEIVED' THEN
    SELECT cm.id, to_jsonb(cm) INTO v_motion_id, v_motion_old FROM public.case_motions cm WHERE cm.id = v_source_id OR cm.case_event_id = p_case_event_id ORDER BY CASE WHEN cm.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_motion_id IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM public.case_motion_resolutions cmr WHERE cmr.case_motion_id = v_motion_id AND cmr.is_voided = false) THEN
        RAISE EXCEPTION 'This motion already has a resolution. Void the motion resolution first.';
      END IF;
      UPDATE public.case_motions SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_motion_id;
      SELECT to_jsonb(cm) INTO v_motion_new FROM public.case_motions cm WHERE cm.id = v_motion_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motions',v_motion_id,'VOID_MOTION_RECEIVED_FROM_EVENT',v_motion_old,v_motion_new,v_case_id,'Motion Received voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_motion_resolution_approvals' OR v_event_type_code = 'MOTION_DECISION_APPROVED' THEN
    SELECT cmra.id, to_jsonb(cmra) INTO v_motion_decision_approval_id, v_motion_decision_approval_old
    FROM public.case_motion_resolution_approvals cmra
    WHERE cmra.id = v_source_id OR cmra.case_event_id = p_case_event_id
    ORDER BY CASE WHEN cmra.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_motion_decision_approval_id IS NOT NULL THEN
      UPDATE public.case_motion_resolution_approvals
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          updated_by_user_id = p_voided_by_user_id,
          updated_at = now()
      WHERE id = v_motion_decision_approval_id;

      SELECT to_jsonb(cmra) INTO v_motion_decision_approval_new
      FROM public.case_motion_resolution_approvals cmra
      WHERE cmra.id = v_motion_decision_approval_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motion_resolution_approvals',v_motion_decision_approval_id,'VOID_MOTION_DECISION_APPROVED_FROM_EVENT',v_motion_decision_approval_old,v_motion_decision_approval_new,v_case_id,'Motion Decision Approved voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_motion_resolutions' OR v_event_type_code = 'MOTION_RESOLVED' THEN
    SELECT cmr.id, to_jsonb(cmr) INTO v_motion_resolution_id, v_motion_resolution_old
    FROM public.case_motion_resolutions cmr
    WHERE cmr.id = v_source_id OR cmr.case_event_id = p_case_event_id
    ORDER BY CASE WHEN cmr.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_motion_resolution_id IS NOT NULL THEN
      SELECT count(*) INTO v_motion_approval_count
      FROM public.case_motion_resolution_approvals cmra
      WHERE cmra.case_motion_resolution_id = v_motion_resolution_id
        AND cmra.is_voided = false;
      IF COALESCE(v_motion_approval_count, 0) > 0 THEN
        RAISE EXCEPTION 'This motion resolution already has an approved decision. Void the approval event first.';
      END IF;

      UPDATE public.case_motion_resolutions
      SET is_voided = true,
          voided_at = now(),
          voided_by_user_id = p_voided_by_user_id,
          void_reason = p_void_reason,
          updated_by_user_id = p_voided_by_user_id,
          updated_at = now()
      WHERE id = v_motion_resolution_id;

      SELECT to_jsonb(cmr) INTO v_motion_resolution_new
      FROM public.case_motion_resolutions cmr
      WHERE cmr.id = v_motion_resolution_id;

      UPDATE public.case_motions cm
      SET motion_status = 'PENDING',
          updated_by_user_id = p_voided_by_user_id,
          updated_at = now()
      FROM public.case_motion_resolutions cmr
      WHERE cm.id = cmr.case_motion_id
        AND cmr.id = v_motion_resolution_id
        AND cm.is_voided = false;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_motion_resolutions',v_motion_resolution_id,'VOID_MOTION_RESOLVED_FROM_EVENT',v_motion_resolution_old,v_motion_resolution_new,v_case_id,'Motion Resolved voided and case status/stage recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_court_filings' OR v_event_type_code = 'COURT_FILING' THEN
    SELECT cf.id, to_jsonb(cf) INTO v_filing_id, v_filing_old FROM public.case_court_filings cf WHERE cf.id = v_source_id OR cf.case_event_id = p_case_event_id ORDER BY CASE WHEN cf.id = v_source_id THEN 0 ELSE 1 END LIMIT 1;
    IF v_filing_id IS NOT NULL THEN
      UPDATE public.case_court_filings SET is_voided = true, voided_at = now(), voided_by_user_id = p_voided_by_user_id, void_reason = p_void_reason, updated_by_user_id = p_voided_by_user_id, updated_at = now() WHERE id = v_filing_id;
      SELECT to_jsonb(cf) INTO v_filing_new FROM public.case_court_filings cf WHERE cf.id = v_filing_id;

      PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

      SELECT to_jsonb(cpd) INTO v_new_details
      FROM public.case_private_details cpd
      WHERE cpd.case_id = v_case_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (p_voided_by_user_id,'case_court_filings',v_filing_id,'VOID_COURT_FILING_FROM_EVENT',v_filing_old,jsonb_build_object('court_filing',v_filing_new,'case_private_details',v_new_details),v_case_id,'Court filing voided and case status recomputed.',jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason));
    END IF;
  END IF;

  IF v_event_type_code = 'CASE_ASSIGNMENT' THEN
    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
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

      SELECT to_jsonb(ca) INTO v_assignment_new
      FROM public.case_assignments ca
      WHERE ca.id = v_assignment_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_assignments',
        v_assignment_id,
        'VOID_CASE_ASSIGNMENT_FROM_EVENT',
        v_assignment_old,
        v_assignment_new,
        v_case_id,
        'Assignment row voided because the Case Assignment event was voided.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason)
      );
    END IF;
  ELSIF v_event_type_code = 'CASE_REASSIGNMENT' THEN
    v_previous_assignment_id := NULLIF(v_old#>>'{details_jsonb,previous_assignment_id}', '')::bigint;

    SELECT ca.id, to_jsonb(ca) INTO v_assignment_id, v_assignment_old
    FROM public.case_assignments ca
    WHERE ca.id = v_source_id OR ca.case_event_id = p_case_event_id
    ORDER BY CASE WHEN ca.id = v_source_id THEN 0 ELSE 1 END
    LIMIT 1;

    SELECT ca.id INTO v_latest_assignment_id
    FROM public.case_assignments ca
    WHERE ca.case_id = v_case_id
      AND ca.is_voided IS FALSE
    ORDER BY ca.assigned_at DESC NULLS LAST, ca.id DESC
    LIMIT 1;

    IF v_assignment_id IS NULL OR v_latest_assignment_id IS DISTINCT FROM v_assignment_id THEN
      RAISE EXCEPTION 'This reassignment has already been superseded by a later assignment. Void the latest reassignment first.';
    END IF;

    UPDATE public.case_assignments
    SET is_voided = true,
        voided_at = now(),
        voided_by_user_id = p_voided_by_user_id,
        void_reason = p_void_reason,
        unassigned_at = COALESCE(unassigned_at, now())
    WHERE id = v_assignment_id;

    SELECT to_jsonb(ca) INTO v_assignment_new
    FROM public.case_assignments ca
    WHERE ca.id = v_assignment_id;

    IF v_previous_assignment_id IS NOT NULL THEN
      SELECT to_jsonb(ca) INTO v_previous_assignment_old
      FROM public.case_assignments ca
      WHERE ca.id = v_previous_assignment_id
        AND ca.case_id = v_case_id
      FOR UPDATE;

      IF v_previous_assignment_old IS NOT NULL THEN
        UPDATE public.case_assignments
        SET unassigned_at = NULL,
            unassigned_by_user_id = NULL,
            unassignment_reason = NULL
        WHERE id = v_previous_assignment_id
          AND case_id = v_case_id
          AND is_voided IS FALSE;

        SELECT to_jsonb(ca) INTO v_previous_assignment_new
        FROM public.case_assignments ca
        WHERE ca.id = v_previous_assignment_id;
      END IF;
    END IF;

    INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
    VALUES (
      p_voided_by_user_id,
      'case_assignments',
      v_assignment_id,
      'VOID_CASE_REASSIGNMENT_NEW_ASSIGNMENT',
      v_assignment_old,
      v_assignment_new,
      v_case_id,
      'Reassignment-created assignment row voided because the Case Reassignment event was voided.',
      jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'previous_assignment_id',v_previous_assignment_id)
    );

    IF v_previous_assignment_old IS NOT NULL THEN
      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_assignments',
        v_previous_assignment_id,
        'RESTORE_PREVIOUS_ASSIGNMENT_FROM_REASSIGNMENT_VOID',
        v_previous_assignment_old,
        v_previous_assignment_new,
        v_case_id,
        'Previous assignment restored because the Case Reassignment event was voided.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'voided_assignment_id',v_assignment_id)
      );
    END IF;
  ELSIF lower(coalesce(v_source_table,'')) = 'case_assignments' THEN
    UPDATE public.case_assignments
    SET is_voided = true,
        voided_at = now(),
        voided_by_user_id = p_voided_by_user_id,
        void_reason = p_void_reason,
        unassigned_at = COALESCE(unassigned_at, now())
    WHERE id = v_source_id OR case_event_id = p_case_event_id;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolutions' OR v_event_type_code = 'CASE_RESOLVED' THEN
    SELECT cr.id INTO v_resolution_id FROM public.case_resolutions cr WHERE cr.id = v_source_id OR cr.case_event_id = p_case_event_id LIMIT 1;
    IF v_resolution_id IS NOT NULL THEN
      IF EXISTS (SELECT 1 FROM public.case_resolution_approvals a WHERE a.case_resolution_id = v_resolution_id AND a.is_voided = false) THEN
        RAISE EXCEPTION 'This resolution already has approved decisions. Void the approval events first.';
      END IF;
      UPDATE public.case_resolutions SET is_voided=true, voided_at=now(), voided_by_user_id=p_voided_by_user_id, void_reason=p_void_reason, updated_by_user_id=p_voided_by_user_id, updated_at=now() WHERE id=v_resolution_id;
    END IF;
  END IF;

  IF lower(coalesce(v_source_table,'')) = 'case_resolution_approvals' OR v_event_type_code = 'CASE_DECISION_APPROVED' THEN
    SELECT a.id INTO v_approval_id FROM public.case_resolution_approvals a WHERE a.id = v_source_id OR a.case_event_id = p_case_event_id LIMIT 1;
    IF v_approval_id IS NOT NULL THEN
      UPDATE public.case_resolution_approvals SET is_voided=true, voided_at=now(), voided_by_user_id=p_voided_by_user_id, void_reason=p_void_reason, updated_by_user_id=p_voided_by_user_id, updated_at=now() WHERE id=v_approval_id;
    END IF;
  END IF;

  IF v_event_type_code IN ('CASE_RESOLVED','CASE_DECISION_APPROVED','CASE_ASSIGNMENT','CASE_REASSIGNMENT')
     OR lower(coalesce(v_source_table,'')) IN ('case_resolutions','case_resolution_approvals','case_assignments') THEN
    PERFORM public.apply_case_state_recompute(v_case_id, CURRENT_DATE, NULL, p_case_event_id, p_voided_by_user_id);

    IF v_event_type_code = 'CASE_REASSIGNMENT' THEN
      SELECT to_jsonb(cpd) INTO v_new_details
      FROM public.case_private_details cpd
      WHERE cpd.case_id = v_case_id;

      INSERT INTO public.audit_logs(actor_user_id,entity_name,entity_id,action,old_data,new_data,case_id,summary,metadata)
      VALUES (
        p_voided_by_user_id,
        'case_private_details',
        v_case_id,
        'CASE_REASSIGNMENT_VOID_STATUS_STAGE_RECOMPUTED',
        v_old_details,
        v_new_details,
        v_case_id,
        'Case Reassignment voided; case status and case stage recomputed from active workflow records.',
        jsonb_build_object('case_event_id',p_case_event_id,'reason',p_void_reason,'restored_assignment_id',v_previous_assignment_id,'voided_assignment_id',v_assignment_id)
      );
    END IF;
  END IF;

END;
$$;



GRANT EXECUTE ON FUNCTION public.void_case_event(bigint, text, bigint) TO authenticated;
COMMENT ON FUNCTION public.void_case_event(bigint,text,bigint) IS 'Adds CUSTOM_EVENT void recomputation exactly once when details_jsonb.updates_case_status is true, preserving the visible voided event and avoiding source-table side effects.';
