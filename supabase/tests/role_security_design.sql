-- Role-security validation script. Replace the UUID placeholders with one auth.users.id per role before running.
-- Run each block as an authenticated PostgREST/JWT-equivalent context.

begin;

-- Developer
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select * from public.cases limit 1;
select * from public.case_participants limit 1;
select * from public.case_violations limit 1;
select * from public.users limit 1;
select * from public.roles limit 1;
select * from public.user_roles limit 1;
select * from public.v_docket_shell limit 1;
select * from public.v_docket_participants limit 1;
select * from public.v_docket_case_violation_classification limit 1;
select * from public.v_docket_quickdetails limit 1;
reset role;

-- Chief
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select * from public.cases limit 1;
select * from public.case_participants limit 1;
select * from public.case_violations limit 1;
select * from public.users limit 1;
select * from public.roles limit 1;
select * from public.user_roles limit 1;
select * from public.v_docket_shell limit 1;
select * from public.v_docket_participants limit 1;
select * from public.v_docket_case_violation_classification limit 1;
select * from public.v_docket_quickdetails limit 1;
reset role;

-- Admin positive checks
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
set local role authenticated;
select * from public.cases limit 1;
select * from public.case_participants limit 1;
select * from public.case_violations limit 1;
select * from public.v_docket_shell limit 1;
select * from public.v_docket_participants limit 1;
select * from public.v_docket_case_violation_classification limit 1;
select * from public.v_docket_quickdetails limit 1;
reset role;

-- Admin negative checks should raise permission/RLS errors or return no rows under RLS.
-- select * from public.users limit 1;
-- select * from public.roles limit 1;
-- select * from public.user_roles limit 1;
-- select * from public.get_user_management_roles();

-- Prosecutor positive checks
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', true);
set local role authenticated;
select * from public.v_docket_shell limit 1;
select * from public.v_docket_participants limit 1;
select * from public.v_docket_case_violation_classification limit 1;
reset role;

-- Prosecutor negative checks should raise permission/RLS errors or return no rows under RLS.
-- select * from public.cases limit 1;
-- select * from public.case_participants limit 1;
-- select * from public.case_violations limit 1;
-- select * from public.case_private_details limit 1;
-- select * from public.case_attachment_index limit 1;
-- select * from public.case_events limit 1;
-- select * from public.case_motions limit 1;
-- select * from public.case_courts limit 1;
-- select * from public.users limit 1;
-- select * from public.roles limit 1;
-- select * from public.user_roles limit 1;
-- select * from public.v_docket_quickdetails limit 1;

rollback;
