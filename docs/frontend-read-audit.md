# Frontend read audit

_Last updated: 2026-06-21_

## Current status

The case list, case details, clearance enrichment, and person details page flows have been moved toward view-backed reads, but **zero frontend interaction with base tables has not yet been achieved**.

This change adds the missing reference/supporting read views needed for the next reroute step without changing the `/cases` staged loading, sorting, filters, dropdown values, or existing client-side data derivation.

## Confirmed view/RPC-backed page flows

- `/cases` list uses `v_docket_shell`, `v_docket_participants`, `v_docket_case_violation_classification`, and `v_docket_quickdetails` for staged list hydration.
- `/cases/[caseId]` uses `v_case_details_page` for header/core details and `v_case_timeline` for timeline rows.
- Case sub-sections use view-backed helpers for participants, attachments, courts, motions, petitions, and clearance participant attributes.
- `/persons/[personId]` reads person details from `v_person_details` and associated cases through `v_case_participants_detail` plus the docket read-model views.
- Clearance search still uses existing read RPCs and enriches results with frontend read views.

## Reference/supporting views now available

The migration `supabase/migrations/20260621000002_reference_read_views.sql` creates or refreshes these lookup/read views for the remaining frontend helper reroutes:

- `v_ref_docket_types`
- `v_ref_case_statuses`
- `v_ref_case_classifications`
- `v_ref_participant_roles`
- `v_ref_address_types`
- `v_ref_courts`
- `v_ref_violations`
- `v_ref_prosecutors`
- `v_ref_users`
- `v_address_suggestions`
- `v_docket_sequence_lookup`
- `v_recent_audit_logs`
- `v_case_assignment_detail`
- `v_case_status_history_detail`

All of these views are development-open read models: no RLS policies, no permission filters, no `security_invoker`, `SELECT` granted to `authenticated`, and PostgREST schema reload requested.

## Remaining direct frontend `.from(...)` interactions to reroute

`lib/supabase/queries.ts` still contains direct base-table reads/mutations in older helpers and form-oriented utilities. These must be rerouted or isolated before we can say zero base-table browser interaction is complete.

### Lookup/read helpers still requiring reroute

- `docket_types`
- `case_statuses`
- `cases`
- `case_participants`
- `persons`
- `prosecutors`
- `violations`
- `audit_logs`
- `participant_roles`
- `address_types`
- `users`
- `docket_sequence_counters`
- `addresses`

### Browser mutation helpers still requiring removal/isolation

- `assignProsecutorToCase`
- `unassignActiveProsecutorFromCase`
- `createNewDocketEntry`
- internal docket-counter writes used by docket creation

These should be removed from browser code or replaced by server-only code / existing RPC-backed flows before declaring the frontend fully read-view-only.

## Conclusion

**Zero frontend interaction with PostgreSQL base tables has not yet been achieved.** The missing database-side read models now exist, but `lib/supabase/queries.ts` still needs a focused follow-up to reroute the remaining lookup helpers and isolate/remove browser mutation helpers.
