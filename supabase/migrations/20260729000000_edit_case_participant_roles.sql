-- Extend identity correction so the participant's case role can be corrected in
-- the same transaction as their identity and case-specific details.
ALTER FUNCTION public.manage_case_participants(jsonb)
  RENAME TO manage_case_participants_without_role_edit;

CREATE FUNCTION public.manage_case_participants(p_payload jsonb)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result bigint;
  v_participant jsonb := coalesce(p_payload->'participant', '{}'::jsonb);
  v_participant_id bigint := nullif(v_participant->>'id', '')::bigint;
  v_role_id bigint := nullif(v_participant->>'roleId', '')::bigint;
  v_old_role_id bigint;
BEGIN
  IF lower(btrim(p_payload->>'action')) = 'edit_main_details' THEN
    IF v_role_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.participant_roles
      WHERE id = v_role_id AND is_active = true
    ) THEN
      RAISE EXCEPTION 'A valid participant role is required';
    END IF;

    SELECT role_id INTO v_old_role_id
    FROM public.case_participants
    WHERE id = v_participant_id
      AND case_id = nullif(p_payload->>'caseId', '')::bigint;
  END IF;

  v_result := public.manage_case_participants_without_role_edit(p_payload);

  IF lower(btrim(p_payload->>'action')) = 'edit_main_details'
     AND v_old_role_id IS DISTINCT FROM v_role_id THEN
    UPDATE public.case_participants
    SET role_id = v_role_id
    WHERE id = v_participant_id
      AND case_id = nullif(p_payload->>'caseId', '')::bigint;

    INSERT INTO public.audit_logs(
      actor_user_id, action, entity_name, entity_id, case_id, summary, metadata,
      old_data, new_data
    ) VALUES (
      nullif(p_payload->>'userId', '')::bigint,
      'MANAGE_CASE_PARTICIPANTS_EDIT_ROLE',
      'case_participants',
      v_participant_id,
      nullif(p_payload->>'caseId', '')::bigint,
      'Corrected case participant role',
      jsonb_build_object('reason', nullif(btrim(p_payload->>'reason'), '')),
      jsonb_build_object('role_id', v_old_role_id),
      jsonb_build_object('role_id', v_role_id)
    );
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_case_participants(jsonb)
  TO anon, authenticated, service_role;
