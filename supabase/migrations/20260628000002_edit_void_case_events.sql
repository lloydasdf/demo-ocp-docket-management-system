BEGIN;

ALTER TABLE public.case_events
  ADD COLUMN IF NOT EXISTS is_voided boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS void_reason text,
  ADD COLUMN IF NOT EXISTS voided_at timestamptz,
  ADD COLUMN IF NOT EXISTS voided_by_user_id bigint;

CREATE OR REPLACE FUNCTION public.edit_case_event(
  p_case_event_id bigint,
  p_event_date date,
  p_title text,
  p_description text,
  p_details_jsonb jsonb DEFAULT NULL,
  p_edit_reason text DEFAULT NULL,
  p_user_id bigint DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_case_id bigint;
BEGIN
  SELECT to_jsonb(ce), ce.case_id
  INTO v_old, v_case_id
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id
    AND ce.is_voided = false;

  IF v_old IS NULL THEN
    RAISE EXCEPTION 'Active case event % not found', p_case_event_id;
  END IF;

  UPDATE public.case_events
  SET event_date = p_event_date,
      title = nullif(trim(p_title), ''),
      description = nullif(trim(p_description), ''),
      details_jsonb = COALESCE(p_details_jsonb, details_jsonb, '{}'::jsonb),
      updated_by_user_id = p_user_id,
      updated_at = now()
  WHERE id = p_case_event_id;

  SELECT to_jsonb(ce)
  INTO v_new
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id;

  INSERT INTO public.audit_logs (
    actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata
  )
  VALUES (
    p_user_id, 'case_events', p_case_event_id, 'EDIT_CASE_EVENT', v_old, v_new, v_case_id,
    'Edited case timeline activity', jsonb_build_object('reason', p_edit_reason)
  );

  RETURN p_case_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.void_case_event(
  p_case_event_id bigint,
  p_void_reason text,
  p_voided_by_user_id bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_case_id bigint;
BEGIN
  IF nullif(trim(p_void_reason), '') IS NULL THEN
    RAISE EXCEPTION 'Void reason is required';
  END IF;

  SELECT to_jsonb(ce), ce.case_id
  INTO v_old, v_case_id
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id
    AND ce.is_voided = false;

  IF v_old IS NULL THEN
    RAISE EXCEPTION 'Active case event % not found', p_case_event_id;
  END IF;

  UPDATE public.case_events
  SET is_voided = true,
      void_reason = p_void_reason,
      voided_at = now(),
      voided_by_user_id = p_voided_by_user_id,
      updated_by_user_id = p_voided_by_user_id,
      updated_at = now()
  WHERE id = p_case_event_id;

  SELECT to_jsonb(ce)
  INTO v_new
  FROM public.case_events ce
  WHERE ce.id = p_case_event_id;

  INSERT INTO public.audit_logs (
    actor_user_id, entity_name, entity_id, action, old_data, new_data, case_id, summary, metadata
  )
  VALUES (
    p_voided_by_user_id, 'case_events', p_case_event_id, 'VOID_CASE_EVENT', v_old, v_new, v_case_id,
    'Voided case timeline activity', jsonb_build_object('reason', p_void_reason)
  );
END;
$$;

CREATE OR REPLACE VIEW public.v_case_timeline AS
SELECT
  ce.id AS case_event_id,
  ce.case_id,
  dt.prefix AS docket_type,
  c.docket_year,
  c.docket_month_code,
  c.docket_number,
  concat_ws('-', c.region_code, dt.prefix, right(c.docket_year::text, 2) || COALESCE(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0')) AS docket_display_number,
  cet.code AS event_type_code,
  cet.display_label AS event_type_label,
  cet.category AS event_category,
  ce.event_date,
  ce.event_time,
  ce.event_order,
  ce.title,
  ce.description,
  ce.status_id,
  cs.code AS status_code,
  cs.display_label AS status_label,
  ce.prosecutor_id,
  p.short_name AS prosecutor_short_name,
  ce.staff_id,
  st.short_name AS staff_short_name,
  ce.court_id,
  co.name AS court_name,
  ce.details_jsonb,
  ce.source,
  ce.source_table,
  ce.source_id,
  ce.legacy_source_file,
  ce.legacy_source_sheet,
  ce.legacy_row_number,
  ce.legacy_line_order,
  ce.needs_review,
  ce.review_reason,
  ce.is_voided,
  ce.void_reason,
  ce.voided_at,
  ce.voided_by_user_id,
  vu.email AS voided_by_email,
  ce.created_at,
  ce.updated_at
FROM public.case_events ce
JOIN public.cases c ON c.id = ce.case_id
JOIN public.docket_types dt ON dt.id = c.docket_type_id
JOIN public.case_event_types cet ON cet.id = ce.event_type_id
LEFT JOIN public.case_statuses cs ON cs.id = ce.status_id
LEFT JOIN public.prosecutors p ON p.id = ce.prosecutor_id
LEFT JOIN public.staff st ON st.id = ce.staff_id
LEFT JOIN public.courts co ON co.id = ce.court_id
LEFT JOIN public.users vu ON vu.id = ce.voided_by_user_id;

GRANT EXECUTE ON FUNCTION public.edit_case_event(bigint, date, text, text, jsonb, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.void_case_event(bigint, text, bigint) TO authenticated;
GRANT SELECT ON public.v_case_timeline TO authenticated;

COMMIT;
