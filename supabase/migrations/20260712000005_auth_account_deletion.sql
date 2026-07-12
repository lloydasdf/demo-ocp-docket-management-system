-- Secure Supabase Auth login deletion while preserving public.users identity rows.

DO $$
DECLARE
  v_auth_user_id_attnum smallint;
  v_has_set_null_constraint boolean := false;
  v_constraint record;
BEGIN
  SELECT a.attnum
  INTO v_auth_user_id_attnum
  FROM pg_catalog.pg_attribute a
  WHERE a.attrelid = 'public.users'::regclass
    AND a.attname = 'auth_user_id'
    AND NOT a.attisdropped;

  SELECT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint c
    WHERE c.conrelid = 'public.users'::regclass
      AND c.contype = 'f'
      AND c.confrelid = 'auth.users'::regclass
      AND c.conkey = ARRAY[v_auth_user_id_attnum]
      AND c.confdeltype = 'n'
  )
  INTO v_has_set_null_constraint;

  IF NOT v_has_set_null_constraint THEN
    FOR v_constraint IN
      SELECT c.conname
      FROM pg_catalog.pg_constraint c
      WHERE c.conrelid = 'public.users'::regclass
        AND c.contype = 'f'
        AND c.confrelid = 'auth.users'::regclass
        AND c.conkey = ARRAY[v_auth_user_id_attnum]
    LOOP
      EXECUTE format('ALTER TABLE public.users DROP CONSTRAINT %I', v_constraint.conname);
    END LOOP;

    ALTER TABLE public.users
      ADD CONSTRAINT users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.prepare_auth_account_deletion(p_target_user_id bigint)
RETURNS TABLE(application_user_id bigint, auth_user_id uuid, email text, role_code text, is_active boolean, actor_user_id bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
  v_actor_is_developer boolean := public.has_app_role('DEVELOPER');
  v_actor_is_chief boolean := public.has_app_role('CHIEF');
  v_target record;
  v_active_developer_count integer;
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to manage users' USING ERRCODE = '42501';
  END IF;

  IF v_actor_user_id = p_target_user_id THEN
    RAISE EXCEPTION 'You cannot delete your own login account' USING ERRCODE = '23514';
  END IF;

  SELECT u.id, u.auth_user_id, u.email, u.is_active, upper(r.code) AS role_code
  INTO v_target
  FROM public.users u
  LEFT JOIN public.user_roles ur ON ur.user_id = u.id
  LEFT JOIN public.roles r ON r.id = ur.role_id
  WHERE u.id = p_target_user_id
  FOR UPDATE OF u;

  IF v_target.id IS NULL THEN
    RAISE EXCEPTION 'User % does not exist', p_target_user_id USING ERRCODE = 'P0002';
  END IF;

  IF v_target.auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Login account for user % is already deleted', p_target_user_id USING ERRCODE = '23514';
  END IF;

  IF v_actor_is_chief AND NOT v_actor_is_developer AND v_target.role_code = 'DEVELOPER' THEN
    RAISE EXCEPTION 'CHIEF users cannot delete a DEVELOPER login account' USING ERRCODE = '42501';
  END IF;

  IF v_target.role_code = 'DEVELOPER' THEN
    SELECT count(*)
    INTO v_active_developer_count
    FROM public.users u
    JOIN public.user_roles ur ON ur.user_id = u.id
    JOIN public.roles r ON r.id = ur.role_id
    WHERE u.auth_user_id IS NOT NULL
      AND u.is_active IS TRUE
      AND r.is_active IS TRUE
      AND upper(r.code) = 'DEVELOPER';

    IF v_active_developer_count <= 1 THEN
      RAISE EXCEPTION 'Cannot delete the final active DEVELOPER login account' USING ERRCODE = '23514';
    END IF;
  END IF;

  application_user_id := v_target.id;
  auth_user_id := v_target.auth_user_id;
  email := v_target.email;
  role_code := v_target.role_code;
  is_active := v_target.is_active;
  actor_user_id := v_actor_user_id;
  RETURN NEXT;
END;
$$;

DROP FUNCTION IF EXISTS public.finalize_auth_account_deletion(bigint, uuid);
DROP FUNCTION IF EXISTS public.record_auth_account_deletion_failure(bigint, uuid, text);

CREATE OR REPLACE FUNCTION public.finalize_auth_account_deletion(
  p_target_user_id bigint,
  p_expected_auth_user_id uuid,
  p_actor_user_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_old jsonb;
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

  SELECT to_jsonb(v.*), v.auth_user_id
  INTO v_old, v_current_auth_user_id
  FROM public.v_user_management_users v
  WHERE v.id = p_target_user_id;

  IF v_old IS NULL THEN
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

  SELECT to_jsonb(v.*) INTO v_new FROM public.v_user_management_users v WHERE v.id = p_target_user_id;

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
      v_old,
      v_new,
      'Supabase Auth login account deleted; application user identity preserved.',
      jsonb_build_object('auth_user_id', p_expected_auth_user_id, 'application_user_preserved', true)
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_auth_account_deletion_failure(
  p_target_user_id bigint,
  p_expected_auth_user_id uuid,
  p_error_message text,
  p_actor_user_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_old jsonb;
  v_safe_error text := left(coalesce(p_error_message, 'Supabase Auth deletion failed.'), 500);
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

  SELECT to_jsonb(v.*)
  INTO v_old
  FROM public.v_user_management_users v
  WHERE v.id = p_target_user_id;

  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (
    p_actor_user_id,
    'users',
    p_target_user_id,
    'AUTH_LOGIN_ACCOUNT_DELETE_FAILED',
    v_old,
    v_old,
    'Supabase Auth login account deletion failed; application user was not detached.',
    jsonb_build_object('auth_user_id', p_expected_auth_user_id, 'error_message', v_safe_error)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.prepare_auth_account_deletion(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_auth_account_deletion_failure(bigint, uuid, text, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_auth_account_deletion(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_auth_account_deletion_failure(bigint, uuid, text, bigint) TO service_role;
