-- Executable verification checks for Supabase Auth login deletion.
-- Run only against an isolated test database. Do not run destructive tests in production.
-- Fill the fixture table below before running the fixture-dependent checks.

BEGIN;

CREATE TEMP TABLE auth_account_deletion_test_fixtures (
  ordinary_target_user_id bigint,
  ordinary_auth_user_id uuid,
  different_auth_user_id uuid,
  developer_actor_user_id bigint,
  chief_auth_user_id uuid,
  chief_actor_user_id bigint,
  developer_target_user_id bigint,
  self_auth_user_id uuid,
  self_app_user_id bigint,
  final_developer_auth_user_id uuid,
  final_developer_app_user_id bigint
) ON COMMIT DROP;

INSERT INTO auth_account_deletion_test_fixtures DEFAULT VALUES;

-- Example fixture setup for an isolated database:
-- UPDATE auth_account_deletion_test_fixtures SET
--   ordinary_target_user_id = 1001,
--   ordinary_auth_user_id = '00000000-0000-0000-0000-000000000101',
--   different_auth_user_id = '00000000-0000-0000-0000-000000000102',
--   developer_actor_user_id = 1,
--   chief_auth_user_id = '00000000-0000-0000-0000-000000000201',
--   chief_actor_user_id = 2,
--   developer_target_user_id = 3,
--   self_auth_user_id = '00000000-0000-0000-0000-000000000301',
--   self_app_user_id = 4,
--   final_developer_auth_user_id = '00000000-0000-0000-0000-000000000401',
--   final_developer_app_user_id = 5;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'delete_auth_user_after_app_user_permanent_delete'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'Old automatic auth deletion trigger still exists';
  END IF;

  IF to_regprocedure('public.delete_auth_user_after_app_user_permanent_delete()') IS NOT NULL THEN
    RAISE EXCEPTION 'Old automatic auth deletion trigger function still exists';
  END IF;

  IF to_regprocedure('public.remove_user_management_user(bigint)') IS NOT NULL
     AND has_function_privilege('authenticated', 'public.remove_user_management_user(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated can still execute remove_user_management_user(bigint)';
  END IF;

  IF to_regprocedure('public.permanently_delete_user_management_user(bigint)') IS NOT NULL
     AND has_function_privilege('authenticated', 'public.permanently_delete_user_management_user(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated can still execute permanently_delete_user_management_user(bigint)';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.users'::regclass
      AND c.contype = 'f'
      AND c.confrelid = 'auth.users'::regclass
      AND c.conkey = ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid = 'public.users'::regclass AND attname = 'auth_user_id')]
      AND c.confdeltype = 'n'
  ) THEN
    RAISE EXCEPTION 'public.users.auth_user_id foreign key is not ON DELETE SET NULL';
  END IF;

  IF has_function_privilege('authenticated', 'public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated can directly execute finalize_auth_account_deletion';
  END IF;

  IF has_function_privilege('authenticated', 'public.record_auth_account_deletion_failure(bigint, uuid, text, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated can directly execute record_auth_account_deletion_failure';
  END IF;

  IF NOT has_function_privilege('service_role', 'public.finalize_auth_account_deletion(bigint, uuid, bigint, jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'service_role cannot execute finalize_auth_account_deletion';
  END IF;

  IF NOT has_function_privilege('service_role', 'public.record_auth_account_deletion_failure(bigint, uuid, text, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'service_role cannot execute record_auth_account_deletion_failure';
  END IF;
END $$;

DO $$
DECLARE
  f auth_account_deletion_test_fixtures%ROWTYPE;
  v_role_count_before integer;
  v_success_audit_count integer;
BEGIN
  SELECT * INTO f FROM auth_account_deletion_test_fixtures LIMIT 1;

  IF f.ordinary_target_user_id IS NULL THEN
    RAISE NOTICE 'Skipping fixture-dependent finalization checks; populate auth_account_deletion_test_fixtures to enable them.';
    RETURN;
  END IF;

  SELECT count(*) INTO v_role_count_before FROM public.user_roles WHERE user_id = f.ordinary_target_user_id;

  UPDATE public.users
  SET auth_user_id = NULL,
      is_active = true
  WHERE id = f.ordinary_target_user_id;

  PERFORM public.finalize_auth_account_deletion(
    f.ordinary_target_user_id,
    f.ordinary_auth_user_id,
    f.developer_actor_user_id,
    jsonb_build_object('id', f.ordinary_target_user_id, 'auth_user_id', f.ordinary_auth_user_id)
  );

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = f.ordinary_target_user_id) THEN
    RAISE EXCEPTION 'public.users row was not preserved after finalization';
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE id = f.ordinary_target_user_id AND auth_user_id IS NOT NULL) THEN
    RAISE EXCEPTION 'auth_user_id was not cleared after finalization';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = f.ordinary_target_user_id AND is_active IS FALSE) THEN
    RAISE EXCEPTION 'is_active was not set false after finalization';
  END IF;

  IF (SELECT count(*) FROM public.user_roles WHERE user_id = f.ordinary_target_user_id) <> v_role_count_before THEN
    RAISE EXCEPTION 'public.user_roles rows changed during finalization';
  END IF;

  PERFORM public.finalize_auth_account_deletion(
    f.ordinary_target_user_id,
    f.ordinary_auth_user_id,
    f.developer_actor_user_id,
    jsonb_build_object('id', f.ordinary_target_user_id, 'auth_user_id', f.ordinary_auth_user_id)
  );

  SELECT count(*)
  INTO v_success_audit_count
  FROM public.audit_logs
  WHERE entity_name = 'users'
    AND entity_id = f.ordinary_target_user_id
    AND action = 'AUTH_LOGIN_ACCOUNT_DELETED'
    AND metadata->>'auth_user_id' = f.ordinary_auth_user_id::text;

  IF v_success_audit_count <> 1 THEN
    RAISE EXCEPTION 'Repeated finalization created duplicate or missing success audit entries: %', v_success_audit_count;
  END IF;

  IF f.different_auth_user_id IS NOT NULL THEN
    UPDATE public.users
    SET auth_user_id = f.different_auth_user_id,
        is_active = true
    WHERE id = f.ordinary_target_user_id;

    BEGIN
      PERFORM public.finalize_auth_account_deletion(
        f.ordinary_target_user_id,
        f.ordinary_auth_user_id,
        f.developer_actor_user_id,
        jsonb_build_object('id', f.ordinary_target_user_id, 'auth_user_id', f.ordinary_auth_user_id)
      );
      RAISE EXCEPTION 'Expected controlled finalization conflict for different non-null auth UUID';
    EXCEPTION WHEN check_violation THEN
      NULL;
    END;
  END IF;
END $$;

DO $$
DECLARE
  f auth_account_deletion_test_fixtures%ROWTYPE;
BEGIN
  SELECT * INTO f FROM auth_account_deletion_test_fixtures LIMIT 1;

  IF f.chief_auth_user_id IS NOT NULL AND f.developer_target_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.sub', f.chief_auth_user_id::text, true);
    BEGIN
      PERFORM public.prepare_auth_account_deletion(f.developer_target_user_id);
      RAISE EXCEPTION 'Expected CHIEF to be unable to prepare deletion for a DEVELOPER target, including multi-role targets';
    EXCEPTION WHEN insufficient_privilege THEN
      NULL;
    END;
  ELSE
    RAISE NOTICE 'Skipping CHIEF-versus-DEVELOPER prepare check; provide chief_auth_user_id and developer_target_user_id fixtures.';
  END IF;

  IF f.self_auth_user_id IS NOT NULL AND f.self_app_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.sub', f.self_auth_user_id::text, true);
    BEGIN
      PERFORM public.prepare_auth_account_deletion(f.self_app_user_id);
      RAISE EXCEPTION 'Expected self-deletion prepare to fail';
    EXCEPTION WHEN check_violation THEN
      NULL;
    END;
  ELSE
    RAISE NOTICE 'Skipping self-deletion prepare check; provide self_auth_user_id and self_app_user_id fixtures.';
  END IF;

  IF f.final_developer_auth_user_id IS NOT NULL AND f.final_developer_app_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.sub', f.final_developer_auth_user_id::text, true);
    BEGIN
      PERFORM public.prepare_auth_account_deletion(f.final_developer_app_user_id);
      RAISE EXCEPTION 'Expected final active Developer deletion prepare to fail';
    EXCEPTION WHEN check_violation THEN
      NULL;
    END;
  ELSE
    RAISE NOTICE 'Skipping final active Developer check; provide final Developer fixtures.';
  END IF;
END $$;

ROLLBACK;
