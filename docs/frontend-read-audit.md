# Frontend Supabase read audit

Generated during the read-model refactor. Scope is browser/client helpers in `lib/supabase/queries.ts` and their frontend consumers.

## Rerouted in this change

- `app/persons/[personId]/page.tsx`
  - `getPersonDetailsById` now reads `public.v_person_details` instead of `public.persons` with nested aliases/addresses.
  - `getCaseParticipantsForPerson` already reads `public.v_case_participants_detail`.
  - `getCaseCompactsByIds` now composes `public.v_docket_shell`, `public.v_docket_case_violation_classification`, and `public.v_docket_quickdetails` instead of `public.v_cases_display`.

## Case-page and clearance reads already view/RPC-backed

- `/cases` list:
  - `public.v_docket_shell`
  - `public.v_docket_participants`
  - `public.v_docket_case_violation_classification`
  - `public.v_docket_quickdetails`
- `/cases/[caseId]` details:
  - `public.v_case_details_page`
  - `public.v_case_participants_detail`
  - `public.v_case_timeline`
  - `public.v_case_attachments`
  - `public.v_case_courts_detail`
  - `public.v_case_motions_detail`
  - `public.v_case_petitions_for_review_detail`
- `/clearance-search`:
  - RPCs: `search_clearance_records`, `search_clearance_possible_matches`, `search_clearance_phonetic_matches`
  - Enrichment views: `public.v_docket_case_violation_classification`, `public.v_clearance_participant_attributes`

## Remaining direct base-table SELECT helpers to review

These helpers still perform browser/client `.select()` reads from base tables and should either be converted to views/RPCs or confirmed as admin/reference-data exceptions:

- Reference data:
  - `getDocketTypes` / `getActiveDocketTypes` → `public.docket_types`
  - `getCaseStatuses` → `public.case_statuses`
  - `getParticipantRoles` → `public.participant_roles`
  - `getAddressTypes` → `public.address_types`
  - `getViolations` / `searchViolations` → `public.violations`
  - `getProsecutors` → `public.prosecutors`
- Legacy/general case helpers:
  - `getCases` / `getCasesFromTable` / `getCaseDetailsById` / `getCaseById` → `public.cases` and related base tables
  - `getLatestCaseDocketYear` / docket sequence helpers → `public.cases`, `public.docket_sequence_counters`
  - `getCaseAssignments` / assignment mutations → `public.case_assignments`
  - `getCaseStatusHistory` → `public.case_status_history`
  - `searchCases` / `getCasesCompact` / `getCompactCases` / `getCaseCompactById` still use legacy `public.v_cases_display` and should be migrated or deprecated.
- Person/search helpers outside the person details route:
  - `getPersons` / `searchPersons` → `public.persons`
- Auth/user helpers:
  - current-user and staff/prosecutor assignment helpers → `public.users` and related assignment tables
- Write flows:
  - `createNewDocketEntry` and assignment helpers intentionally insert/update base tables; these are write paths, not read-model SELECT paths.
