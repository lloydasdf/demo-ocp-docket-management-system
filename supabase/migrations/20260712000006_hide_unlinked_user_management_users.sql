-- Hide application-only users from User Management.
-- Only users with an existing Supabase Auth account should appear in the list.

CREATE OR REPLACE VIEW public.v_user_management_users AS
SELECT
  u.id,
  u.auth_user_id,
  u.email,
  u.is_active,
  u.last_login_at,
  u.created_at,
  u.updated_at,
  u.prosecutor_id,
  p.full_name AS prosecutor_full_name,
  p.short_name AS prosecutor_short_name,
  u.staff_id,
  s.full_name AS staff_full_name,
  s.short_name AS staff_short_name,
  r.id AS role_id,
  r.code AS role_code,
  r.display_label AS role_label,
  r.is_active AS role_is_active
FROM public.users u
JOIN auth.users au ON au.id = u.auth_user_id
LEFT JOIN public.prosecutors p ON p.id = u.prosecutor_id
LEFT JOIN public.staff s ON s.id = u.staff_id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.roles r ON r.id = ur.role_id;

COMMENT ON VIEW public.v_user_management_users IS 'User Management read view with application user, role, prosecutor, and staff context. Only users backed by an existing Supabase Auth account are listed.';

REVOKE ALL ON TABLE public.v_user_management_users FROM PUBLIC;
REVOKE ALL ON TABLE public.v_user_management_users FROM anon;
REVOKE ALL ON TABLE public.v_user_management_users FROM authenticated;
REVOKE ALL ON TABLE public.v_user_management_users FROM service_role;
GRANT SELECT ON TABLE public.v_user_management_users TO authenticated;
GRANT SELECT ON TABLE public.v_user_management_users TO service_role;

-- v_user_management_users now hides rows after the Auth account is gone, so
-- finalization must read public.users directly after Supabase Auth deletion.
CREATE OR REPLACE FUNCTION public.finalize_auth_account_deletion(
  p_target_user_id bigint,
  p_expected_auth_user_id uuid,
  p_actor_user_id bigint,
  p_old_data jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_new jsonb;
  v_current_auth_user_id uuid;
  v_actor_is_authorized boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    JOIN public.user_roles ur ON ur.user_id = u.id
    JOIN public.roles r ON r.id = ur.role_id
    WHERE u.id = p_actor_user_id
      AND u.is_active IS TRUE
      AND r.is_active IS TRUE
      AND upper(r.code) IN ('DEVELOPER', 'CHIEF')
  )
  INTO v_actor_is_authorized;

  IF NOT v_actor_is_authorized THEN
    RAISE EXCEPTION 'You are not authorized to manage users' USING ERRCODE = '42501';
  END IF;

  SELECT u.auth_user_id
  INTO v_current_auth_user_id
  FROM public.users u
  WHERE u.id = p_target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Login account deletion finalization conflict for user %', p_target_user_id USING ERRCODE = '23514';
  END IF;

  IF v_current_auth_user_id IS NOT NULL AND v_current_auth_user_id <> p_expected_auth_user_id THEN
    RAISE EXCEPTION 'Login account deletion finalization conflict for user %', p_target_user_id USING ERRCODE = '23514';
  END IF;

  UPDATE public.users
  SET auth_user_id = NULL,
      is_active = false,
      updated_at = now()
  WHERE id = p_target_user_id
    AND (auth_user_id = p_expected_auth_user_id OR auth_user_id IS NULL);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Login account deletion finalization conflict for user %', p_target_user_id USING ERRCODE = '23514';
  END IF;

  SELECT to_jsonb(u.*) || jsonb_build_object(
    'roles', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'role_id', r.id,
        'role_code', r.code,
        'role_label', r.display_label,
        'role_is_active', r.is_active
      ) ORDER BY r.code)
      FROM public.user_roles ur
      JOIN public.roles r ON r.id = ur.role_id
      WHERE ur.user_id = u.id
    ), '[]'::jsonb),
    'prosecutor_full_name', p.full_name,
    'prosecutor_short_name', p.short_name,
    'staff_full_name', s.full_name,
    'staff_short_name', s.short_name
  )
  INTO v_new
  FROM public.users u
  LEFT JOIN public.prosecutors p ON p.id = u.prosecutor_id
  LEFT JOIN public.staff s ON s.id = u.staff_id
  WHERE u.id = p_target_user_id;

  IF NOT EXISTS (
    SELECT 1
    FROM public.audit_logs al
    WHERE al.entity_name = 'users'
      AND al.entity_id = p_target_user_id
      AND al.action = 'AUTH_LOGIN_ACCOUNT_DELETED'
      AND al.metadata->>'auth_user_id' = p_expected_auth_user_id::text
  ) THEN
    INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
    VALUES (
      p_actor_user_id,
      'users',
      p_target_user_id,
      'AUTH_LOGIN_ACCOUNT_DELETED',
      COALESCE(p_old_data, v_new),
      v_new,
      'Supabase Auth login account deleted; application user identity preserved.',
      jsonb_build_object('auth_user_id', p_expected_auth_user_id, 'application_user_preserved', true)
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) FROM authenticated;
REVOKE ALL ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) FROM service_role;
GRANT EXECUTE ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) TO service_role;
