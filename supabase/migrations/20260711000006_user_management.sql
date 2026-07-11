-- User Management view, RPCs, and Auth synchronization.
-- Security policies intentionally omitted for troubleshooting stage.

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
LEFT JOIN public.prosecutors p ON p.id = u.prosecutor_id
LEFT JOIN public.staff s ON s.id = u.staff_id
LEFT JOIN public.user_roles ur ON ur.user_id = u.id
LEFT JOIN public.roles r ON r.id = ur.role_id;

COMMENT ON VIEW public.v_user_management_users IS 'User Management read view with application user, role, prosecutor, and staff context. Security policies will be implemented later.';

CREATE OR REPLACE FUNCTION public.sync_auth_user_to_app_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_existing_user public.users%ROWTYPE;
  v_created_at timestamp with time zone := COALESCE(NEW.created_at, now());
  v_updated_at timestamp with time zone := COALESCE(NEW.updated_at, NEW.created_at, now());
BEGIN
  IF NEW.email IS NULL OR btrim(NEW.email) = '' THEN
    RAISE NOTICE 'Skipping public.users synchronization for auth.users % because email is null or empty', NEW.id;
    RETURN NEW;
  END IF;

  SELECT *
  INTO v_existing_user
  FROM public.users
  WHERE lower(email::text) = lower(NEW.email::text)
  ORDER BY id
  LIMIT 1;

  IF v_existing_user.id IS NOT NULL THEN
    IF v_existing_user.auth_user_id IS NOT NULL AND v_existing_user.auth_user_id <> NEW.id THEN
      RAISE EXCEPTION 'Cannot synchronize auth user %. Public user % with email % is already linked to auth user %', NEW.id, v_existing_user.id, NEW.email, v_existing_user.auth_user_id;
    END IF;

    UPDATE public.users
    SET auth_user_id = NEW.id,
        email = NEW.email,
        updated_at = v_updated_at
    WHERE id = v_existing_user.id;

    RETURN NEW;
  END IF;

  INSERT INTO public.users(auth_user_id, email, password_hash, is_active, created_at, updated_at)
  VALUES (NEW.id, NEW.email, 'managed-by-supabase-auth', true, v_created_at, v_updated_at);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_auth_user_email_to_app_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_existing_linked_user public.users%ROWTYPE;
  v_email_match_user public.users%ROWTYPE;
  v_updated_at timestamp with time zone := COALESCE(NEW.updated_at, now());
BEGIN
  IF NEW.email IS NULL OR btrim(NEW.email) = '' THEN
    RAISE NOTICE 'Skipping public.users email synchronization for auth.users % because email is null or empty', NEW.id;
    RETURN NEW;
  END IF;

  SELECT *
  INTO v_existing_linked_user
  FROM public.users
  WHERE auth_user_id = NEW.id
  LIMIT 1;

  SELECT *
  INTO v_email_match_user
  FROM public.users
  WHERE lower(email::text) = lower(NEW.email::text)
    AND (v_existing_linked_user.id IS NULL OR id <> v_existing_linked_user.id)
  ORDER BY id
  LIMIT 1;

  IF v_existing_linked_user.id IS NOT NULL THEN
    IF v_email_match_user.id IS NOT NULL THEN
      RAISE EXCEPTION 'Cannot update auth user % email to %. Public user % already uses that email', NEW.id, NEW.email, v_email_match_user.id;
    END IF;

    UPDATE public.users
    SET email = NEW.email,
        updated_at = v_updated_at
    WHERE id = v_existing_linked_user.id;

    RETURN NEW;
  END IF;

  IF v_email_match_user.id IS NOT NULL THEN
    IF v_email_match_user.auth_user_id IS NOT NULL AND v_email_match_user.auth_user_id <> NEW.id THEN
      RAISE EXCEPTION 'Cannot synchronize auth user %. Public user % with email % is already linked to auth user %', NEW.id, v_email_match_user.id, NEW.email, v_email_match_user.auth_user_id;
    END IF;

    UPDATE public.users
    SET auth_user_id = NEW.id,
        email = NEW.email,
        updated_at = v_updated_at
    WHERE id = v_email_match_user.id;

    RETURN NEW;
  END IF;

  INSERT INTO public.users(auth_user_id, email, password_hash, is_active, created_at, updated_at)
  VALUES (NEW.id, NEW.email, 'managed-by-supabase-auth', true, COALESCE(NEW.created_at, now()), v_updated_at);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_auth_user_after_app_user_permanent_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  -- This trigger is only for permanent application-user deletion.
  -- Normal User Management removal is a soft remove: it keeps public.users,
  -- clears roles, sets is_active = false, and therefore does not fire this trigger.
  IF OLD.auth_user_id IS NOT NULL THEN
    DELETE FROM auth.users
    WHERE id = OLD.auth_user_id;
  END IF;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS sync_auth_user_to_app_user_on_insert ON auth.users;
CREATE TRIGGER sync_auth_user_to_app_user_on_insert
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_auth_user_to_app_user();

DROP TRIGGER IF EXISTS sync_auth_user_email_to_app_user_on_update ON auth.users;
CREATE TRIGGER sync_auth_user_email_to_app_user_on_update
AFTER UPDATE OF email ON auth.users
FOR EACH ROW
WHEN (OLD.email IS DISTINCT FROM NEW.email)
EXECUTE FUNCTION public.sync_auth_user_email_to_app_user();

DROP TRIGGER IF EXISTS delete_auth_user_after_app_user_permanent_delete ON public.users;
CREATE TRIGGER delete_auth_user_after_app_user_permanent_delete
AFTER DELETE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.delete_auth_user_after_app_user_permanent_delete();

-- Backfill existing Auth users safely and idempotently. Matching is case-insensitive.
WITH auth_users_deduped AS (
  SELECT DISTINCT ON (lower(au.email::text))
    au.id,
    au.email,
    au.created_at,
    au.updated_at
  FROM auth.users au
  WHERE au.email IS NOT NULL
    AND btrim(au.email) <> ''
  ORDER BY lower(au.email::text), au.created_at NULLS LAST, au.id
)
UPDATE public.users u
SET auth_user_id = au.id,
    email = au.email,
    updated_at = COALESCE(au.updated_at, u.updated_at, now())
FROM auth_users_deduped au
WHERE u.auth_user_id IS NULL
  AND lower(u.email::text) = lower(au.email::text)
  AND NOT EXISTS (
    SELECT 1
    FROM public.users linked
    WHERE linked.auth_user_id = au.id
      AND linked.id <> u.id
  );

WITH auth_users_deduped AS (
  SELECT DISTINCT ON (lower(au.email::text))
    au.id,
    au.email,
    au.created_at,
    au.updated_at
  FROM auth.users au
  WHERE au.email IS NOT NULL
    AND btrim(au.email) <> ''
  ORDER BY lower(au.email::text), au.created_at NULLS LAST, au.id
)
INSERT INTO public.users(auth_user_id, email, password_hash, is_active, created_at, updated_at)
SELECT
  au.id,
  au.email,
  'managed-by-supabase-auth',
  true,
  COALESCE(au.created_at, now()),
  COALESCE(au.updated_at, au.created_at, now())
FROM auth_users_deduped au
WHERE NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.auth_user_id = au.id
       OR lower(u.email::text) = lower(au.email::text)
  );

CREATE OR REPLACE FUNCTION public.get_user_management_roles()
RETURNS TABLE(id bigint, code text, display_label text, is_active boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT r.id, r.code, r.display_label, r.is_active
  FROM public.roles r
  WHERE r.is_active = true
  ORDER BY r.display_label, r.code;
$$;

CREATE OR REPLACE FUNCTION public.assign_user_management_role(p_user_id bigint, p_role_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
  v_old jsonb;
  v_new jsonb;
  v_role record;
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to manage users';
  END IF;

  SELECT * INTO v_role FROM public.roles WHERE id = p_role_id AND is_active = true;
  IF v_role.id IS NULL THEN
    RAISE EXCEPTION 'Selected role does not exist or is inactive';
  END IF;

  IF NOT public.can_assign_role(v_role.code) THEN
    RAISE EXCEPTION 'You are not authorized to assign role %', v_role.code;
  END IF;

  SELECT to_jsonb(v.*) INTO v_old FROM public.v_user_management_users v WHERE v.id = p_user_id;
  IF v_old IS NULL THEN
    RAISE EXCEPTION 'User % does not exist', p_user_id;
  END IF;

  DELETE FROM public.user_roles WHERE user_id = p_user_id;
  INSERT INTO public.user_roles(user_id, role_id) VALUES (p_user_id, p_role_id);

  SELECT to_jsonb(v.*) INTO v_new FROM public.v_user_management_users v WHERE v.id = p_user_id;

  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (
    v_actor_user_id,
    'users',
    p_user_id,
    'USER_ROLE_CHANGED',
    v_old,
    v_new,
    'User role changed.',
    jsonb_build_object('role_id', p_role_id, 'role_code', v_role.code)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_user_management_blocked(p_user_id bigint, p_is_blocked boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to manage users';
  END IF;

  IF v_actor_user_id = p_user_id THEN
    RAISE EXCEPTION 'You cannot block or unblock your own active application user';
  END IF;

  SELECT to_jsonb(v.*) INTO v_old FROM public.v_user_management_users v WHERE v.id = p_user_id;
  IF v_old IS NULL THEN
    RAISE EXCEPTION 'User % does not exist', p_user_id;
  END IF;

  UPDATE public.users
  SET is_active = NOT p_is_blocked,
      updated_at = now()
  WHERE id = p_user_id;

  SELECT to_jsonb(v.*) INTO v_new FROM public.v_user_management_users v WHERE v.id = p_user_id;

  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (
    v_actor_user_id,
    'users',
    p_user_id,
    CASE WHEN p_is_blocked THEN 'USER_BLOCKED' ELSE 'USER_UNBLOCKED' END,
    v_old,
    v_new,
    CASE WHEN p_is_blocked THEN 'User blocked.' ELSE 'User unblocked.' END,
    jsonb_build_object('is_blocked', p_is_blocked)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_user_management_user(p_user_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
  v_old jsonb;
  v_new jsonb;
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to manage users';
  END IF;

  IF v_actor_user_id = p_user_id THEN
    RAISE EXCEPTION 'You cannot remove your own active application user';
  END IF;

  SELECT to_jsonb(v.*) INTO v_old FROM public.v_user_management_users v WHERE v.id = p_user_id;
  IF v_old IS NULL THEN
    RAISE EXCEPTION 'User % does not exist', p_user_id;
  END IF;

  DELETE FROM public.user_roles WHERE user_id = p_user_id;
  UPDATE public.users
  SET is_active = false,
      updated_at = now()
  WHERE id = p_user_id;

  SELECT to_jsonb(v.*) INTO v_new FROM public.v_user_management_users v WHERE v.id = p_user_id;

  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (
    v_actor_user_id,
    'users',
    p_user_id,
    'USER_REMOVED',
    v_old,
    v_new,
    'User removed from application access.',
    jsonb_build_object('soft_delete', true, 'auth_account_deleted', false)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.permanently_delete_user_management_user(p_user_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id bigint := public.current_app_user_id();
  v_old jsonb;
  v_auth_user_id uuid;
BEGIN
  IF NOT public.can_manage_users() THEN
    RAISE EXCEPTION 'You are not authorized to manage users';
  END IF;

  IF v_actor_user_id = p_user_id THEN
    RAISE EXCEPTION 'You cannot permanently delete your own active application user';
  END IF;

  SELECT to_jsonb(v.*), v.auth_user_id
  INTO v_old, v_auth_user_id
  FROM public.v_user_management_users v
  WHERE v.id = p_user_id;

  IF v_old IS NULL THEN
    RAISE EXCEPTION 'User % does not exist', p_user_id;
  END IF;

  INSERT INTO public.audit_logs(actor_user_id, entity_name, entity_id, action, old_data, new_data, summary, metadata)
  VALUES (
    v_actor_user_id,
    'users',
    p_user_id,
    'USER_PERMANENTLY_DELETED',
    v_old,
    NULL,
    'User permanently deleted from application database.',
    jsonb_build_object('hard_delete', true, 'auth_user_id', v_auth_user_id, 'auth_delete_trigger', v_auth_user_id IS NOT NULL)
  );

  DELETE FROM public.user_roles WHERE user_id = p_user_id;
  DELETE FROM public.users WHERE id = p_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'User permanently deleted.', 'user_id', p_user_id, 'auth_user_id', v_auth_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.sync_auth_user_to_app_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_auth_user_to_app_user() FROM anon;
REVOKE ALL ON FUNCTION public.sync_auth_user_to_app_user() FROM authenticated;
REVOKE ALL ON FUNCTION public.sync_auth_user_to_app_user() FROM service_role;
REVOKE ALL ON FUNCTION public.sync_auth_user_email_to_app_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_auth_user_email_to_app_user() FROM anon;
REVOKE ALL ON FUNCTION public.sync_auth_user_email_to_app_user() FROM authenticated;
REVOKE ALL ON FUNCTION public.sync_auth_user_email_to_app_user() FROM service_role;
REVOKE ALL ON FUNCTION public.delete_auth_user_after_app_user_permanent_delete() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_auth_user_after_app_user_permanent_delete() FROM anon;
REVOKE ALL ON FUNCTION public.delete_auth_user_after_app_user_permanent_delete() FROM authenticated;
REVOKE ALL ON FUNCTION public.delete_auth_user_after_app_user_permanent_delete() FROM service_role;

REVOKE ALL ON TABLE public.v_user_management_users FROM PUBLIC;
REVOKE ALL ON TABLE public.v_user_management_users FROM anon;
REVOKE ALL ON TABLE public.v_user_management_users FROM authenticated;
REVOKE ALL ON TABLE public.v_user_management_users FROM service_role;
GRANT SELECT ON TABLE public.v_user_management_users TO authenticated;
GRANT SELECT ON TABLE public.v_user_management_users TO service_role;

REVOKE ALL ON FUNCTION public.get_user_management_roles() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_management_roles() FROM anon;
REVOKE ALL ON FUNCTION public.get_user_management_roles() FROM authenticated;
REVOKE ALL ON FUNCTION public.get_user_management_roles() FROM service_role;
GRANT EXECUTE ON FUNCTION public.get_user_management_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_management_roles() TO service_role;

REVOKE ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) FROM anon;
REVOKE ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) FROM authenticated;
REVOKE ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) FROM service_role;
GRANT EXECUTE ON FUNCTION public.assign_user_management_role(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_user_management_role(bigint, bigint) TO service_role;

REVOKE ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) FROM authenticated;
REVOKE ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) FROM service_role;
GRANT EXECUTE ON FUNCTION public.set_user_management_blocked(bigint, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_management_blocked(bigint, boolean) TO service_role;

REVOKE ALL ON FUNCTION public.remove_user_management_user(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.remove_user_management_user(bigint) FROM anon;
REVOKE ALL ON FUNCTION public.remove_user_management_user(bigint) FROM authenticated;
REVOKE ALL ON FUNCTION public.remove_user_management_user(bigint) FROM service_role;
GRANT EXECUTE ON FUNCTION public.remove_user_management_user(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_user_management_user(bigint) TO service_role;

REVOKE ALL ON FUNCTION public.permanently_delete_user_management_user(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.permanently_delete_user_management_user(bigint) FROM anon;
REVOKE ALL ON FUNCTION public.permanently_delete_user_management_user(bigint) FROM authenticated;
REVOKE ALL ON FUNCTION public.permanently_delete_user_management_user(bigint) FROM service_role;
GRANT EXECUTE ON FUNCTION public.permanently_delete_user_management_user(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.permanently_delete_user_management_user(bigint) TO service_role;
