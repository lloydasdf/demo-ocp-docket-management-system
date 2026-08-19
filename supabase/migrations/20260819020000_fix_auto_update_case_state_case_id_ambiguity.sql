-- Keep the deployed RPC signature while avoiding collisions with its case_id
-- output variable inside PL/pgSQL statements.

CREATE OR REPLACE FUNCTION public.apply_auto_update_case_states(
  p_case_ids bigint[]
)
RETURNS TABLE(case_id bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
BEGIN
  PERFORM public.require_any_app_role(ARRAY['DEVELOPER']);

  IF COALESCE(cardinality(p_case_ids), 0) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH requested_cases AS (
    SELECT DISTINCT requested.requested_case_id
    FROM unnest(p_case_ids) AS requested(requested_case_id)
    WHERE requested.requested_case_id IS NOT NULL
  ),
  candidates AS (
    SELECT
      c.id AS candidate_case_id,
      cpd.current_status_id AS legacy_status_id,
      cpd.current_case_status_id,
      cpd.current_case_stage_id,
      to_jsonb(cpd) AS old_details,
      computed_status.id AS computed_case_status_id,
      computed_status.code AS computed_case_status_code,
      computed_status.display_label AS computed_case_status_label,
      computed_stage.id AS computed_case_stage_id,
      computed_stage.code AS computed_case_stage_code,
      computed_stage.display_label AS computed_case_stage_label
    FROM requested_cases requested
    JOIN public.cases c ON c.id = requested.requested_case_id
    LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
    CROSS JOIN LATERAL public.compute_current_case_state(c.id) computed_state
    JOIN public.case_statuses computed_status
      ON computed_status.code = computed_state.case_status_code
     AND computed_status.is_active IS TRUE
    JOIN public.case_stages computed_stage
      ON computed_stage.code = computed_state.case_stage_code
     AND computed_stage.is_active IS TRUE
    WHERE c.is_archived IS FALSE
  ),
  changed_cases AS (
    SELECT candidate.*
    FROM candidates candidate
    WHERE candidate.legacy_status_id IS DISTINCT FROM candidate.computed_case_status_id
       OR candidate.current_case_status_id IS DISTINCT FROM candidate.computed_case_status_id
       OR candidate.current_case_stage_id IS DISTINCT FROM candidate.computed_case_stage_id
  ),
  updated_details AS (
    INSERT INTO public.case_private_details AS details (
      case_id,
      source,
      current_status_id,
      current_status_date,
      current_status_remarks,
      current_case_status_id,
      current_case_status_date,
      current_case_status_remarks,
      current_case_stage_id,
      current_case_stage_date,
      current_case_stage_remarks,
      updated_at
    )
    SELECT
      changed.candidate_case_id,
      'AUTO_STATE_SYNC',
      changed.computed_case_status_id,
      CURRENT_DATE,
      NULL,
      changed.computed_case_status_id,
      CURRENT_DATE,
      NULL,
      changed.computed_case_stage_id,
      CURRENT_DATE,
      NULL,
      now()
    FROM changed_cases changed
    ON CONFLICT ON CONSTRAINT case_private_details_pkey DO UPDATE SET
      current_status_id = EXCLUDED.current_status_id,
      current_status_date = CASE
        WHEN details.current_status_id IS DISTINCT FROM EXCLUDED.current_status_id THEN EXCLUDED.current_status_date
        ELSE details.current_status_date
      END,
      current_status_remarks = CASE
        WHEN details.current_status_id IS DISTINCT FROM EXCLUDED.current_status_id THEN NULL
        ELSE details.current_status_remarks
      END,
      current_case_status_id = EXCLUDED.current_case_status_id,
      current_case_status_date = CASE
        WHEN details.current_case_status_id IS DISTINCT FROM EXCLUDED.current_case_status_id THEN EXCLUDED.current_case_status_date
        ELSE details.current_case_status_date
      END,
      current_case_status_remarks = CASE
        WHEN details.current_case_status_id IS DISTINCT FROM EXCLUDED.current_case_status_id THEN NULL
        ELSE details.current_case_status_remarks
      END,
      current_case_stage_id = EXCLUDED.current_case_stage_id,
      current_case_stage_date = CASE
        WHEN details.current_case_stage_id IS DISTINCT FROM EXCLUDED.current_case_stage_id THEN EXCLUDED.current_case_stage_date
        ELSE details.current_case_stage_date
      END,
      current_case_stage_remarks = CASE
        WHEN details.current_case_stage_id IS DISTINCT FROM EXCLUDED.current_case_stage_id THEN NULL
        ELSE details.current_case_stage_remarks
      END,
      updated_at = now()
    RETURNING details.case_id AS updated_case_id, to_jsonb(details) AS new_details
  ),
  updated_cases AS (
    UPDATE public.cases c
    SET updated_by_user_id = v_actor_user_id,
        updated_at = now()
    FROM updated_details updated
    WHERE c.id = updated.updated_case_id
    RETURNING c.id AS updated_case_id
  ),
  inserted_audits AS (
    INSERT INTO public.audit_logs AS audit_log (
      actor_user_id,
      entity_name,
      entity_id,
      action,
      old_data,
      new_data,
      case_id,
      summary,
      metadata
    )
    SELECT
      v_actor_user_id,
      'case_private_details',
      changed.candidate_case_id,
      'DEVELOPER_AUTO_CASE_STATE_SYNC',
      changed.old_details,
      updated.new_details,
      changed.candidate_case_id,
      'Current case status and stage synchronized from compute_current_case_state().',
      jsonb_build_object(
        'source_function', 'compute_current_case_state',
        'case_event_created', false,
        'previous_case_status_id', changed.current_case_status_id,
        'computed_case_status_id', changed.computed_case_status_id,
        'computed_case_status_code', changed.computed_case_status_code,
        'computed_case_status_label', changed.computed_case_status_label,
        'previous_case_stage_id', changed.current_case_stage_id,
        'computed_case_stage_id', changed.computed_case_stage_id,
        'computed_case_stage_code', changed.computed_case_stage_code,
        'computed_case_stage_label', changed.computed_case_stage_label
      )
    FROM changed_cases changed
    JOIN updated_details updated ON updated.updated_case_id = changed.candidate_case_id
    RETURNING audit_log.entity_id AS audited_case_id
  )
  SELECT updated.updated_case_id
  FROM updated_cases updated
  JOIN inserted_audits audit ON audit.audited_case_id = updated.updated_case_id
  ORDER BY updated.updated_case_id;
END;
$$;

COMMENT ON FUNCTION public.apply_auto_update_case_states(bigint[]) IS
  'Developer-only selected-case status/stage synchronization. Uses unambiguous internal identifiers and creates no case events or history rows.';
