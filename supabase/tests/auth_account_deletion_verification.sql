-- Verification plan for Supabase Auth login deletion.
-- Run against an isolated Supabase test database with fixture users/roles.
-- The protected HTTP route covers Auth Admin API success/failure; these SQL checks focus on database invariants.

begin;

-- Expected coverage:
-- 1. DEVELOPER can prepare/finalize an ordinary user's Auth login deletion.
-- 2. CHIEF can prepare/finalize an ordinary user's Auth login deletion.
-- 3. CHIEF cannot prepare deletion of a DEVELOPER login.
-- 4. ADMIN cannot prepare deletion.
-- 5. PROSECUTOR cannot prepare deletion.
-- 6. Self-deletion is rejected by prepare_auth_account_deletion.
-- 7. The final active DEVELOPER login is rejected.
-- 8. A target whose auth_user_id is NULL raises a controlled conflict.
-- 9. record_auth_account_deletion_failure preserves public.users.auth_user_id.
-- 10. finalize_auth_account_deletion leaves public.users in place.
-- 11. finalize_auth_account_deletion sets is_active=false.
-- 12. finalize_auth_account_deletion sets auth_user_id=NULL.
-- 13. finalize_auth_account_deletion leaves public.user_roles intact.
-- 14. Historical rows that reference public.users(id) remain valid because the user row is preserved.
-- 15. finalize_auth_account_deletion and record_auth_account_deletion_failure insert audit_logs rows.
-- 16. Unauthenticated API calls should return 401 (covered by route handler/manual HTTP test).
-- 17. Unauthorized API calls should return 403 (database 42501 mapped by route handler).

-- Example invariant query after a successful finalize call:
-- select u.id, u.auth_user_id, u.is_active, ur.role_id
-- from public.users u
-- left join public.user_roles ur on ur.user_id = u.id
-- where u.id = :target_application_user_id;
-- Expected: one public.users row exists, auth_user_id is null, is_active is false, role_id is unchanged.

-- Example audit query:
-- select action, entity_name, entity_id, summary
-- from public.audit_logs
-- where entity_name = 'users'
--   and entity_id = :target_application_user_id
--   and action in ('AUTH_LOGIN_ACCOUNT_DELETED', 'AUTH_LOGIN_ACCOUNT_DELETE_FAILED')
-- order by created_at desc;

rollback;
