# Frontend read audit

_Last updated: 2026-06-21_

## Current status

**Zero browser/client runtime interaction with PostgreSQL base tables has been achieved for `lib/supabase/queries.ts` and the app/component code audited in this pass.**

Browser/client-accessible data access now uses only:

- page/read-model views;
- `v_ref_*` reference views;
- existing Supabase RPC calls;
- Supabase Auth APIs.

The `/cases` page behavior was intentionally preserved: no UI, dropdown, staged loading, sorting, filtering, search behavior, or client-side dropdown-value derivation was changed.

## View/RPC-backed page flows

- `/cases` list uses `v_docket_shell`, `v_docket_participants`, `v_docket_case_violation_classification`, and `v_docket_quickdetails` for staged list hydration.
- `/cases/[caseId]` uses `v_case_details_page` for header/core details and `v_case_timeline` for timeline rows.
- Case detail sub-sections use view-backed helpers for participants, attachments, courts, motions, petitions, assignments, status history, and clearance participant attributes.
- `/persons/[personId]` reads person details from `v_person_details` and associated cases through `v_case_participants_detail` plus the docket read-model views.
- Clearance search still uses the existing read RPCs and enriches results with frontend read views.

## Reference/supporting views used by lookup helpers

The remaining frontend lookup/read helpers are rerouted to these views:

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

## Mutation isolation

Browser mutation helpers that previously inserted or updated base tables are now isolated so they do not perform direct `.from(...).insert(...)`, `.update(...)`, `.delete(...)`, or `.upsert(...)` operations from browser/client code.

- `assignProsecutorToCase` returns a guarded failure until a server-only action or existing RPC-backed implementation is provided.
- `unassignActiveProsecutorFromCase` returns a guarded failure until a server-only action or existing RPC-backed implementation is provided.
- `createNewDocketEntry` returns a guarded failure until a server-only action or existing RPC-backed implementation is provided.
- The internal docket-counter advancement helper is also guarded and no longer writes through the browser client.

Existing Supabase Auth usage and existing RPC calls remain unchanged.

## Audit result

- Direct browser/client `.from(...)` calls now point to views or the existing view-name helper path.
- No browser/client `.from(...)` call targets a PostgreSQL base table.
- No browser/client `.insert(...)`, `.update(...)`, `.delete(...)`, or `.upsert(...)` call remains in the audited app/component/query code.

**Conclusion: zero frontend base-table interaction is achieved for the audited browser/client code.**
