-- User Management view and RPCs.
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

GRANT ALL ON TABLE public.v_user_management_users TO anon;
GRANT ALL ON TABLE public.v_user_management_users TO authenticated;
GRANT ALL ON TABLE public.v_user_management_users TO service_role;
GRANT ALL ON FUNCTION public.get_user_management_roles() TO anon;
GRANT ALL ON FUNCTION public.get_user_management_roles() TO authenticated;
GRANT ALL ON FUNCTION public.get_user_management_roles() TO service_role;
GRANT ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) TO anon;
GRANT ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) TO authenticated;
GRANT ALL ON FUNCTION public.assign_user_management_role(bigint, bigint) TO service_role;
GRANT ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) TO anon;
GRANT ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) TO authenticated;
GRANT ALL ON FUNCTION public.set_user_management_blocked(bigint, boolean) TO service_role;
GRANT ALL ON FUNCTION public.remove_user_management_user(bigint) TO anon;
GRANT ALL ON FUNCTION public.remove_user_management_user(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.remove_user_management_user(bigint) TO service_role;
