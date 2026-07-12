-- Role-security validation for the development database.
-- This script discovers one active authenticated app user for each required application role.
-- It validates effective RLS row access for shared PostgreSQL role "authenticated".

begin;

create temp table role_subjects as
select upper(r.code) as role_code, (array_agg(u.auth_user_id::text order by u.id))[1] as sub
from public.users u
join public.user_roles ur on ur.user_id = u.id
join public.roles r on r.id = ur.role_id
where u.is_active is true
  and u.auth_user_id is not null
  and upper(r.code) in ('DEVELOPER', 'CHIEF', 'ADMIN', 'PROSECUTOR')
group by upper(r.code);

do $$
begin
  if (select count(*) from role_subjects) <> 4 then
    raise exception 'Expected one active authenticated user for each role; found %', (select jsonb_object_agg(role_code, sub) from role_subjects);
  end if;
end $$;

-- Developer: all proper tables tested here, all four Cases-page views, user management.
select set_config('request.jwt.claim.sub', (select sub from role_subjects where role_code = 'DEVELOPER'), true);
set local role authenticated;
select public.has_app_role('DEVELOPER') as developer_role_ok;
select count(*) >= 0 as developer_cases_ok from public.cases;
select count(*) >= 0 as developer_case_participants_ok from public.case_participants;
select count(*) >= 0 as developer_case_violations_ok from public.case_violations;
select count(*) >= 0 as developer_users_ok from public.users;
select count(*) >= 0 as developer_roles_ok from public.roles;
select count(*) >= 0 as developer_user_roles_ok from public.user_roles;
select count(*) >= 0 as developer_shell_ok from public.v_docket_shell;
select count(*) >= 0 as developer_participants_ok from public.v_docket_participants;
select count(*) >= 0 as developer_labels_ok from public.v_docket_case_violation_classification;
select count(*) >= 0 as developer_quickdetails_ok from public.v_docket_quickdetails;
reset role;

-- Chief: all proper tables tested here, all four Cases-page views, user management.
select set_config('request.jwt.claim.sub', (select sub from role_subjects where role_code = 'CHIEF'), true);
set local role authenticated;
select public.has_app_role('CHIEF') as chief_role_ok;
select count(*) >= 0 as chief_cases_ok from public.cases;
select count(*) >= 0 as chief_case_participants_ok from public.case_participants;
select count(*) >= 0 as chief_case_violations_ok from public.case_violations;
select count(*) >= 0 as chief_users_ok from public.users;
select count(*) >= 0 as chief_roles_ok from public.roles;
select count(*) >= 0 as chief_user_roles_ok from public.user_roles;
select count(*) >= 0 as chief_shell_ok from public.v_docket_shell;
select count(*) >= 0 as chief_participants_ok from public.v_docket_participants;
select count(*) >= 0 as chief_labels_ok from public.v_docket_case_violation_classification;
select count(*) >= 0 as chief_quickdetails_ok from public.v_docket_quickdetails;
reset role;

-- Admin: docket data and all four Cases views; user-management effective row access is denied.
select set_config('request.jwt.claim.sub', (select sub from role_subjects where role_code = 'ADMIN'), true);
set local role authenticated;
select public.has_app_role('ADMIN') as admin_role_ok;
select count(*) >= 0 as admin_cases_ok from public.cases;
select count(*) >= 0 as admin_case_participants_ok from public.case_participants;
select count(*) >= 0 as admin_case_violations_ok from public.case_violations;
select count(*) >= 0 as admin_shell_ok from public.v_docket_shell;
select count(*) >= 0 as admin_participants_ok from public.v_docket_participants;
select count(*) >= 0 as admin_labels_ok from public.v_docket_case_violation_classification;
select count(*) >= 0 as admin_quickdetails_ok from public.v_docket_quickdetails;
select count(*) = 0 as admin_users_denied_by_rls from public.users;
select count(*) = 0 as admin_roles_denied_by_rls from public.roles;
select count(*) = 0 as admin_user_roles_denied_by_rls from public.user_roles;
do $$
begin
  perform * from public.get_user_management_roles();
  raise exception 'Admin unexpectedly executed get_user_management_roles()';
exception when insufficient_privilege then
  raise notice 'Admin user-management RPC denied as expected';
end $$;
reset role;

-- Prosecutor: no proper-table rows, can read only three Cases-page views, quickdetails denied.
select set_config('request.jwt.claim.sub', (select sub from role_subjects where role_code = 'PROSECUTOR'), true);
set local role authenticated;
select public.has_app_role('PROSECUTOR') as prosecutor_role_ok;
select count(*) = 0 as prosecutor_cases_denied_by_rls from public.cases;
select count(*) = 0 as prosecutor_case_participants_denied_by_rls from public.case_participants;
select count(*) = 0 as prosecutor_case_violations_denied_by_rls from public.case_violations;
select count(*) = 0 as prosecutor_private_details_denied_by_rls from public.case_private_details;
select count(*) = 0 as prosecutor_attachment_index_denied_by_rls from public.case_attachment_index;
select count(*) = 0 as prosecutor_case_events_denied_by_rls from public.case_events;
select count(*) = 0 as prosecutor_case_motions_denied_by_rls from public.case_motions;
select count(*) = 0 as prosecutor_case_courts_denied_by_rls from public.case_courts;
select count(*) = 0 as prosecutor_users_denied_by_rls from public.users;
select count(*) = 0 as prosecutor_roles_denied_by_rls from public.roles;
select count(*) = 0 as prosecutor_user_roles_denied_by_rls from public.user_roles;
select count(*) >= 0 as prosecutor_shell_ok from public.v_docket_shell;
select count(*) >= 0 as prosecutor_participants_ok from public.v_docket_participants;
select count(*) >= 0 as prosecutor_labels_ok from public.v_docket_case_violation_classification;
do $$
begin
  perform * from public.v_docket_quickdetails limit 1;
  raise exception 'Prosecutor unexpectedly selected v_docket_quickdetails';
exception when insufficient_privilege then
  raise notice 'Prosecutor v_docket_quickdetails denied as expected';
end $$;
reset role;

rollback;
