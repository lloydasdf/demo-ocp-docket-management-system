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

-- Permanent application-user deletion is intentionally disabled. The OCP
-- application identity in public.users must be preserved for roles, personnel
-- links, case assignments, audit history, and historical foreign-key references.
-- Deleting a public.users row must not cascade into deleting an auth.users row.
DROP TRIGGER IF EXISTS delete_auth_user_after_app_user_permanent_delete
ON public.users;

DROP FUNCTION IF EXISTS public.delete_auth_user_after_app_user_permanent_delete();
DROP FUNCTION IF EXISTS public.remove_user_management_user(bigint);
DROP FUNCTION IF EXISTS public.permanently_delete_user_management_user(bigint);

DROP FUNCTION IF EXISTS public.prepare_auth_account_deletion(bigint);
DROP FUNCTION IF EXISTS public.finalize_auth_account_deletion(bigint, uuid);
DROP FUNCTION IF EXISTS public.finalize_auth_account_deletion(bigint, uuid, bigint);
DROP FUNCTION IF EXISTS public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb);
DROP FUNCTION IF EXISTS public.record_auth_account_deletion_failure(bigint, uuid, text);
DROP FUNCTION IF EXISTS public.record_auth_account_deletion_failure(bigint, uuid, text, bigint);
DROP FUNCTION IF EXISTS public.record_auth_account_finalization_failure(bigint, uuid, text, bigint);

CREATE OR REPLACE FUNCTION public.prepare_auth_account_deletion(p_target_user_id bigint)
RETURNS TABLE(application_user_id bigint, auth_user_id uuid, email text, target_is_developer boolean, is_active boolean, actor_user_id bigint, old_data jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
  v_actor_is_developer boolean := public.has_app_role('DEVELOPER');
  v_actor_is_chief boolean := public.has_app_role('CHIEF');
  v_target record;
  v_target_is_developer boolean := false;
  v_active_developer_count integer;
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to manage users' USING ERRCODE = '42501';
  END IF;

  IF v_actor_user_id = p_target_user_id THEN
    RAISE EXCEPTION 'You cannot delete your own login account' USING ERRCODE = '23514';
  END IF;

  SELECT u.id, u.auth_user_id, u.email, u.is_active
  INTO v_target
  FROM public.users u
  WHERE u.id = p_target_user_id
  FOR UPDATE;

  IF v_target.id IS NULL THEN
    RAISE EXCEPTION 'User % does not exist', p_target_user_id USING ERRCODE = 'P0002';
  END IF;

  IF v_target.auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Login account for user % is already deleted', p_target_user_id USING ERRCODE = '23514';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = p_target_user_id
      AND r.is_active IS TRUE
      AND upper(r.code) = 'DEVELOPER'
  )
  INTO v_target_is_developer;

  IF v_actor_is_chief AND NOT v_actor_is_developer AND v_target_is_developer THEN
    RAISE EXCEPTION 'CHIEF users cannot delete a DEVELOPER login account' USING ERRCODE = '42501';
  END IF;

  IF v_target_is_developer THEN
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
  target_is_developer := v_target_is_developer;
  is_active := v_target.is_active;
  actor_user_id := v_actor_user_id;
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
  INTO old_data
  FROM public.users u
  LEFT JOIN public.prosecutors p ON p.id = u.prosecutor_id
  LEFT JOIN public.staff s ON s.id = u.staff_id
  WHERE u.id = p_target_user_id;
  RETURN NEXT;
END;
$$;

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

  SELECT v.auth_user_id
  INTO v_current_auth_user_id
  FROM public.v_user_management_users v
  WHERE v.id = p_target_user_id;

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
      COALESCE(p_old_data, v_new),
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

CREATE OR REPLACE FUNCTION public.record_auth_account_finalization_failure(
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
  v_safe_error text := left(coalesce(p_error_message, 'Database finalization failed after Auth deletion.'), 500);
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.audit_logs al
    WHERE al.entity_name = 'users'
      AND al.entity_id = p_target_user_id
      AND al.action = 'AUTH_LOGIN_ACCOUNT_FINALIZE_FAILED'
      AND al.metadata->>'auth_user_id' = p_expected_auth_user_id::text
  ) THEN
    INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
    VALUES (
      p_actor_user_id,
      'users',
      p_target_user_id,
      'AUTH_LOGIN_ACCOUNT_FINALIZE_FAILED',
      v_old,
      v_old,
      'Supabase Auth login account was deleted, but database finalization failed and needs repair.',
      jsonb_build_object('auth_user_id', p_expected_auth_user_id, 'application_user_preserved', true, 'repair_required', true, 'error_message', v_safe_error)
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.prepare_auth_account_deletion(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_auth_account_deletion_failure(bigint, uuid, text, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_auth_account_finalization_failure(bigint, uuid, text, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_auth_account_deletion(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_auth_account_deletion_failure(bigint, uuid, text, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_auth_account_finalization_failure(bigint, uuid, text, bigint) TO service_role;
