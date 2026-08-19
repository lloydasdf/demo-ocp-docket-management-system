-- Developer-only preview and apply workflow for synchronizing the stored current
-- case status/stage with compute_current_case_state(). The apply function writes
-- current state and audit rows only; it intentionally does not create case events
-- or status/stage history rows.

CREATE OR REPLACE FUNCTION public.preview_auto_update_case_states(
  p_docket_year integer,
  p_docket_month_code text,
  p_docket_type_id bigint
)
RETURNS TABLE(
  case_id bigint,
  docket_year integer,
  docket_month_code text,
  docket_type_id bigint,
  docket_type_prefix text,
  docket_type_name text,
  docket_display_number text,
  date_received date,
  complainant text,
  respondent text,
  violations text,
  current_case_status_id bigint,
  current_case_status_code text,
  current_case_status_label text,
  current_case_stage_id bigint,
  current_case_stage_code text,
  current_case_stage_label text,
  computed_case_status_id bigint,
  computed_case_status_code text,
  computed_case_status_label text,
  computed_case_stage_id bigint,
  computed_case_stage_code text,
  computed_case_stage_label text,
  will_update_status boolean,
  will_update_stage boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_month_code text := upper(NULLIF(btrim(p_docket_month_code), ''));
BEGIN
  PERFORM public.require_any_app_role(ARRAY['DEVELOPER']);

  IF p_docket_year IS NULL OR p_docket_type_id IS NULL OR v_month_code IS NULL THEN
    RAISE EXCEPTION 'Docket year, month, and type are required';
  END IF;

  IF v_month_code !~ '^[A-L]$' THEN
    RAISE EXCEPTION 'Invalid docket month code %', v_month_code;
  END IF;

  RETURN QUERY
  WITH participant_names AS (
    SELECT
      cp.case_id,
      lower(concat_ws(' ', pr.code, pr.display_label)) AS role_text,
      cp.participant_order,
      cp.id AS participant_id,
      NULLIF(btrim(cp.display_name_snapshot), '') AS display_name
    FROM public.case_participants cp
    JOIN public.participant_roles pr ON pr.id = cp.role_id
  ),
  participant_summary AS (
    SELECT
      pn.case_id,
      string_agg(pn.display_name, ' | ' ORDER BY pn.participant_order, pn.participant_id)
        FILTER (WHERE pn.role_text LIKE '%complainant%' AND pn.display_name IS NOT NULL) AS complainant,
      string_agg(pn.display_name, ' | ' ORDER BY pn.participant_order, pn.participant_id)
        FILTER (WHERE pn.role_text LIKE '%respondent%' AND pn.display_name IS NOT NULL) AS respondent
    FROM participant_names pn
    GROUP BY pn.case_id
  ),
  violation_summary AS (
    SELECT
      cv.case_id,
      string_agg(
        COALESCE(NULLIF(btrim(cv.raw_violation_text), ''), v.title),
        ', '
        ORDER BY cv.violation_order, cv.id
      ) AS violations
    FROM public.case_violations cv
    LEFT JOIN public.violations v ON v.id = cv.violation_id
    GROUP BY cv.case_id
  ),
  candidates AS (
    SELECT
      c.id AS case_id,
      c.docket_year::integer AS docket_year,
      c.docket_month_code::text AS docket_month_code,
      c.docket_type_id,
      dt.prefix::text AS docket_type_prefix,
      dt.name::text AS docket_type_name,
      concat_ws(
        '-',
        NULLIF(btrim(c.region_code), ''),
        dt.prefix,
        right(c.docket_year::text, 2) || COALESCE(NULLIF(btrim(c.docket_month_code), ''), ''),
        lpad(c.docket_number::text, 6, '0')
      ) AS docket_display_number,
      c.date_received,
      ps.complainant,
      ps.respondent,
      vs.violations,
      cpd.current_status_id AS legacy_status_id,
      cpd.current_case_status_id,
      current_status.code::text AS current_case_status_code,
      current_status.display_label::text AS current_case_status_label,
      cpd.current_case_stage_id,
      current_stage.code::text AS current_case_stage_code,
      current_stage.display_label::text AS current_case_stage_label,
      computed_status.id AS computed_case_status_id,
      computed_status.code::text AS computed_case_status_code,
      computed_status.display_label::text AS computed_case_status_label,
      computed_stage.id AS computed_case_stage_id,
      computed_stage.code::text AS computed_case_stage_code,
      computed_stage.display_label::text AS computed_case_stage_label
    FROM public.cases c
    JOIN public.docket_types dt ON dt.id = c.docket_type_id
    LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
    LEFT JOIN public.case_statuses current_status ON current_status.id = cpd.current_case_status_id
    LEFT JOIN public.case_stages current_stage ON current_stage.id = cpd.current_case_stage_id
    LEFT JOIN participant_summary ps ON ps.case_id = c.id
    LEFT JOIN violation_summary vs ON vs.case_id = c.id
    CROSS JOIN LATERAL public.compute_current_case_state(c.id) computed_state
    JOIN public.case_statuses computed_status
      ON computed_status.code = computed_state.case_status_code
     AND computed_status.is_active IS TRUE
    JOIN public.case_stages computed_stage
      ON computed_stage.code = computed_state.case_stage_code
     AND computed_stage.is_active IS TRUE
    WHERE c.is_archived IS FALSE
      AND c.docket_year = p_docket_year
      AND upper(NULLIF(btrim(c.docket_month_code), '')) = v_month_code
      AND c.docket_type_id = p_docket_type_id
  )
  SELECT
    candidate.case_id,
    candidate.docket_year,
    candidate.docket_month_code,
    candidate.docket_type_id,
    candidate.docket_type_prefix,
    candidate.docket_type_name,
    candidate.docket_display_number,
    candidate.date_received,
    candidate.complainant,
    candidate.respondent,
    candidate.violations,
    candidate.current_case_status_id,
    candidate.current_case_status_code,
    candidate.current_case_status_label,
    candidate.current_case_stage_id,
    candidate.current_case_stage_code,
    candidate.current_case_stage_label,
    candidate.computed_case_status_id,
    candidate.computed_case_status_code,
    candidate.computed_case_status_label,
    candidate.computed_case_stage_id,
    candidate.computed_case_stage_code,
    candidate.computed_case_stage_label,
    candidate.legacy_status_id IS DISTINCT FROM candidate.computed_case_status_id
      OR candidate.current_case_status_id IS DISTINCT FROM candidate.computed_case_status_id AS will_update_status,
    candidate.current_case_stage_id IS DISTINCT FROM candidate.computed_case_stage_id AS will_update_stage
  FROM candidates candidate
  WHERE candidate.legacy_status_id IS DISTINCT FROM candidate.computed_case_status_id
     OR candidate.current_case_status_id IS DISTINCT FROM candidate.computed_case_status_id
     OR candidate.current_case_stage_id IS DISTINCT FROM candidate.computed_case_stage_id
  ORDER BY candidate.docket_display_number;
END;
$$;

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
    SELECT DISTINCT requested.case_id
    FROM unnest(p_case_ids) AS requested(case_id)
    WHERE requested.case_id IS NOT NULL
  ),
  candidates AS (
    SELECT
      c.id AS case_id,
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
    JOIN public.cases c ON c.id = requested.case_id
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
      changed.case_id,
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
    ON CONFLICT (case_id) DO UPDATE SET
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
    RETURNING details.case_id, to_jsonb(details) AS new_details
  ),
  updated_cases AS (
    UPDATE public.cases c
    SET updated_by_user_id = v_actor_user_id,
        updated_at = now()
    FROM updated_details updated
    WHERE c.id = updated.case_id
    RETURNING c.id AS case_id
  ),
  inserted_audits AS (
    INSERT INTO public.audit_logs (
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
      changed.case_id,
      'DEVELOPER_AUTO_CASE_STATE_SYNC',
      changed.old_details,
      updated.new_details,
      changed.case_id,
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
    JOIN updated_details updated ON updated.case_id = changed.case_id
    RETURNING entity_id AS case_id
  )
  SELECT updated.case_id
  FROM updated_cases updated
  JOIN inserted_audits audit ON audit.case_id = updated.case_id
  ORDER BY updated.case_id;
END;
$$;

REVOKE ALL ON FUNCTION public.preview_auto_update_case_states(integer, text, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.apply_auto_update_case_states(bigint[]) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.preview_auto_update_case_states(integer, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_auto_update_case_states(bigint[]) TO authenticated;

COMMENT ON FUNCTION public.preview_auto_update_case_states(integer, text, bigint) IS
  'Developer-only read-only preview of stored case status/stage changes computed for one docket year, month, and type.';
COMMENT ON FUNCTION public.apply_auto_update_case_states(bigint[]) IS
  'Developer-only selected-case status/stage synchronization. Recomputes each case and creates audit logs, but no case events or history rows.';
