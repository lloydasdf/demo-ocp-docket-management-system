-- Implement application-role database security for DEVELOPER, CHIEF, ADMIN, and PROSECUTOR.

CREATE OR REPLACE FUNCTION public.current_app_role_codes()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT COALESCE(array_agg(DISTINCT upper(r.code) ORDER BY upper(r.code)), ARRAY[]::text[])
  FROM public.users u
  JOIN public.user_roles ur ON ur.user_id = u.id
  JOIN public.roles r ON r.id = ur.role_id
  WHERE u.auth_user_id = auth.uid()
    AND u.is_active IS TRUE
    AND r.is_active IS TRUE;
$$;

CREATE OR REPLACE FUNCTION public.has_app_role(p_role_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT upper(p_role_code) = ANY (public.current_app_role_codes());
$$;

CREATE OR REPLACE FUNCTION public.has_any_app_role(p_role_codes text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM unnest(p_role_codes) AS requested(code)
    WHERE upper(requested.code) = ANY (public.current_app_role_codes())
  );
$$;


CREATE OR REPLACE FUNCTION public.require_any_app_role(p_role_codes text[])
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF public.has_any_app_role(p_role_codes) THEN
    RETURN true;
  END IF;

  RAISE EXCEPTION 'permission denied for application role' USING ERRCODE = '42501';
END;
$$;

CREATE OR REPLACE FUNCTION public.can_manage_users()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF']);
$$;

CREATE OR REPLACE FUNCTION public.can_assign_role(p_target_role_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT public.has_app_role('DEVELOPER')
         OR (upper(p_target_role_code) <> 'DEVELOPER' AND public.has_app_role('CHIEF'));
$$;

CREATE OR REPLACE FUNCTION public.get_user_management_roles()
RETURNS TABLE(id bigint, code text, display_label text, is_active boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to view user-management roles' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT r.id, r.code, r.display_label, r.is_active
  FROM public.roles r
  WHERE r.is_active IS TRUE
  ORDER BY r.display_label, r.code;
END;
$$;

CREATE OR REPLACE FUNCTION public._app_role_can_access_table(p_table_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT CASE
    WHEN p_table_name = ANY (ARRAY['users', 'roles', 'user_roles'])
      THEN public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF'])
    ELSE public.has_any_app_role(ARRAY['DEVELOPER', 'CHIEF', 'ADMIN'])
  END;
$$;

DO $$
DECLARE
  r record;
  policy_name text;
BEGIN
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename NOT LIKE '\_%' ESCAPE '\'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon', r.tablename);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM authenticated', r.tablename);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role', r.tablename);

    IF r.tablename = ANY (ARRAY['users', 'roles', 'user_roles']) THEN
      EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated', r.tablename);
    ELSE
      EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO authenticated', r.tablename);
    END IF;

    FOR policy_name IN
      SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = r.tablename
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', policy_name, r.tablename);
    END LOOP;

    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL TO authenticated USING (public._app_role_can_access_table(%L)) WITH CHECK (public._app_role_can_access_table(%L))',
      'app_role_table_access', r.tablename, r.tablename, r.tablename
    );
  END LOOP;
END $$;

CREATE OR REPLACE VIEW public.v_docket_shell
WITH (security_invoker = false)
AS
SELECT c.id,
       c.docket_type_id,
       c.docket_year,
       c.docket_number,
       c.docket_month_code,
       concat_ws('-', dt.prefix, c.docket_year::text, NULLIF(c.docket_month_code, ''), lpad(c.docket_number::text, 6, '0')) AS docket_display_number,
       dt.prefix AS docket_type_prefix,
       dt.name AS docket_type_name,
       c.created_at
FROM public.cases c
JOIN public.docket_types dt ON dt.id = c.docket_type_id
WHERE c.is_archived IS FALSE
  AND public.has_any_app_role(ARRAY['DEVELOPER','CHIEF','ADMIN','PROSECUTOR']);

CREATE OR REPLACE VIEW public.v_docket_participants
WITH (security_invoker = false)
AS
WITH participant_names AS (
  SELECT cp.case_id,
         lower(concat_ws(' ', pr.code, pr.display_label)) AS role_text,
         cp.participant_order,
         cp.id AS case_participant_id,
         NULLIF(btrim(cp.display_name_snapshot), '') AS display_name
  FROM public.case_participants cp
  JOIN public.participant_roles pr ON pr.id = cp.role_id
)
SELECT case_id AS id,
       string_agg(display_name, ' | ' ORDER BY participant_order, case_participant_id) FILTER (WHERE role_text LIKE '%complainant%' AND display_name IS NOT NULL) AS complainant,
       string_agg(display_name, ' | ' ORDER BY participant_order, case_participant_id) FILTER (WHERE role_text LIKE '%respondent%' AND display_name IS NOT NULL) AS respondent
FROM participant_names
WHERE public.has_any_app_role(ARRAY['DEVELOPER','CHIEF','ADMIN','PROSECUTOR'])
GROUP BY case_id;

CREATE OR REPLACE VIEW public.v_docket_case_violation_classification
WITH (security_invoker = false)
AS
WITH violation_summary AS (
  SELECT cv.case_id,
         string_agg(COALESCE(NULLIF(btrim(cv.raw_violation_text), ''), v.title), ', ' ORDER BY cv.violation_order, cv.id) AS violations
  FROM public.case_violations cv
  LEFT JOIN public.violations v ON v.id = cv.violation_id
  GROUP BY cv.case_id
)
SELECT c.id,
       vs.violations,
       NULL::text AS summary_text,
       cc.display_label AS case_classification_label
FROM public.cases c
LEFT JOIN public.case_classifications cc ON cc.id = c.case_classification_id
LEFT JOIN violation_summary vs ON vs.case_id = c.id
WHERE c.is_archived IS FALSE
  AND public.has_any_app_role(ARRAY['DEVELOPER','CHIEF','ADMIN','PROSECUTOR']);

CREATE OR REPLACE VIEW public.v_docket_quickdetails
WITH (security_invoker = false)
AS
WITH latest_assignment AS (
  SELECT DISTINCT ON (ca.case_id) ca.case_id, ca.prosecutor_id, ca.assigned_at, ca.id
  FROM public.case_assignments ca
  WHERE ca.unassigned_at IS NULL AND ca.is_voided IS FALSE
  ORDER BY ca.case_id, ca.assigned_at DESC NULLS LAST, ca.id DESC
)
SELECT c.id,
       c.date_received,
       cs.code AS current_status_code,
       cs.display_label AS current_status_label,
       p.full_name AS prosecutor_full_name,
       p.short_name AS prosecutor_short_name,
       cpd.current_status_id,
       cpd.current_status_date,
       cpd.current_case_status_id,
       cpd.current_case_status_date,
       cpd.current_case_status_remarks,
       broad_status.code AS current_case_status_code,
       broad_status.display_label AS current_case_status_label,
       cpd.current_case_stage_id,
       cpd.current_case_stage_date,
       cpd.current_case_stage_remarks,
       stage.code AS current_case_stage_code,
       stage.display_label AS current_case_stage_label
FROM public.cases c
LEFT JOIN public.case_private_details cpd ON cpd.case_id = c.id
LEFT JOIN public.case_statuses cs ON cs.id = cpd.current_status_id
LEFT JOIN public.case_statuses broad_status ON broad_status.id = cpd.current_case_status_id
LEFT JOIN public.case_stages stage ON stage.id = cpd.current_case_stage_id
LEFT JOIN latest_assignment la ON la.case_id = c.id
LEFT JOIN public.prosecutors p ON p.id = la.prosecutor_id
WHERE c.is_archived IS FALSE
  AND public.require_any_app_role(ARRAY['DEVELOPER','CHIEF','ADMIN']);

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT table_name
    FROM information_schema.views
    WHERE table_schema = 'public'
      AND table_name <> ALL (ARRAY['v_docket_shell','v_docket_participants','v_docket_case_violation_classification','v_docket_quickdetails'])
  LOOP
    EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', r.table_name);
  END LOOP;
END $$;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT table_name
    FROM information_schema.views
    WHERE table_schema = 'public'
  LOOP
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon', r.table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM authenticated', r.table_name);
    EXECUTE format('GRANT ALL ON TABLE public.%I TO service_role', r.table_name);
  END LOOP;
END $$;

GRANT SELECT ON public.v_docket_shell TO authenticated;
GRANT SELECT ON public.v_docket_participants TO authenticated;
GRANT SELECT ON public.v_docket_case_violation_classification TO authenticated;
GRANT SELECT ON public.v_docket_quickdetails TO authenticated;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS signature, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND (p.proname LIKE 'get_%' OR p.proname LIKE 'search_%' OR p.proname LIKE 'format_%' OR p.proname LIKE 'export_%')
      AND p.proname NOT IN ('get_user_management_roles')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY INVOKER', r.signature);
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.get_user_management_roles() FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.remove_user_management_user(bigint) FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.permanently_delete_user_management_user(bigint) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_management_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_user_management_role(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_management_blocked(bigint, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_user_management_user(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.permanently_delete_user_management_user(bigint) TO authenticated;

COMMENT ON VIEW public.v_docket_shell IS 'Cases page docket shell view. Security definer; allowed to Developer, Chief, Admin, and Prosecutor via internal role check.';
COMMENT ON VIEW public.v_docket_participants IS 'Cases page participant display-name view. Security definer; uses display_name_snapshot as the prosecutor-safe name source.';
COMMENT ON VIEW public.v_docket_case_violation_classification IS 'Cases page violation/classification view. Security definer; does not expose private summary_text.';
COMMENT ON VIEW public.v_docket_quickdetails IS 'Cases page private quick-details view. Security definer; available only to Developer, Chief, and Admin.';
