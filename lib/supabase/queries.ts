import {
  getSupabaseBrowserClient,
  getSupabaseEnvironmentStatus,
} from "@/lib/supabase/client";
import type {
  Json,
  RelationName,
  SupabaseQueryError,
  SupabaseQueryResult,
  TableName,
  TableRow,
  ViewRow,
} from "@/lib/supabase/types";

type CaseParticipantPrivateDetailsRecord = {
  remarks: string | null;
  source: string | null;
  source_detail: string | null;
  legacy_source_file: string | null;
  legacy_source_sheet: string | null;
  legacy_row_number: number | null;
  legacy_raw_text: string | null;
};

type CasePrivateDetailsRecord = {
  current_status_id: number | null;
  current_status_date: string | null;
  current_status_raw: string | null;
  current_status_remarks: string | null;
  current_status_approved_date_raw: string | null;
  current_case_status_id?: number | null;
  current_case_status_date?: string | null;
  current_case_status_remarks?: string | null;
  current_case_stage_id?: number | null;
  current_case_stage_date?: string | null;
  current_case_stage_remarks?: string | null;
  is_summary_procedure: boolean | null;
  remarks: string | null;
  source: string | null;
  summary_text: string | null;
  current_status: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  current_case_status?: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  current_case_stage?: { code: string | null; display_label: string | null } | null;
};

function withFlattenedCasePrivateDetails<T extends { case_private_details?: CasePrivateDetailsRecord | null }>(
  record: T,
): T & {
  current_status_id?: number | null;
  current_status_date?: string | null;
  current_status_raw?: string | null;
  current_status_remarks?: string | null;
  current_status?: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  current_case_status_id?: number | null;
  current_case_status_date?: string | null;
  current_case_status_remarks?: string | null;
  current_case_stage_id?: number | null;
  current_case_stage_date?: string | null;
  current_case_stage_remarks?: string | null;
  current_case_status?: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  current_case_stage?: { code: string | null; display_label: string | null } | null;
  is_summary_procedure?: boolean | null;
  remarks?: string | null;
  source?: string | null;
  summary_text?: string | null;
} {
  const details = record.case_private_details ?? null;

  return {
    ...record,
    current_status_id: details?.current_status_id ?? null,
    current_status_date: details?.current_status_date ?? null,
    current_status_raw: details?.current_status_raw ?? null,
    current_status_remarks: details?.current_status_remarks ?? null,
    current_status: details?.current_status ?? null,
    current_case_status_id: details?.current_case_status_id ?? null,
    current_case_status_date: details?.current_case_status_date ?? null,
    current_case_status_remarks: details?.current_case_status_remarks ?? null,
    current_case_stage_id: details?.current_case_stage_id ?? null,
    current_case_stage_date: details?.current_case_stage_date ?? null,
    current_case_stage_remarks: details?.current_case_stage_remarks ?? null,
    current_case_status: details?.current_case_status ?? null,
    current_case_stage: details?.current_case_stage ?? null,
    is_summary_procedure: details?.is_summary_procedure ?? null,
    remarks: details?.remarks ?? null,
    source: details?.source ?? null,
    summary_text: details?.summary_text ?? null,
  };
}

type SupabaseErrorLike = {
  message?: string;
  code?: string;
  details?: string;
  hint?: string;
};

function isSupabaseErrorLike(error: unknown): error is SupabaseErrorLike {
  return typeof error === "object" && error !== null && "message" in error;
}

function getClearanceSearchRpcName(operation: string) {
  if (operation === "searchClearanceRecords") {
    return "search_clearance_records";
  }

  if (operation === "searchClearancePossibleMatches") {
    return "search_clearance_possible_matches";
  }

  if (operation === "searchClearancePhoneticMatches") {
    return "search_clearance_phonetic_matches";
  }

  return null;
}

function isMissingClearanceSearchFunction(
  error: SupabaseErrorLike,
  operation: string,
) {
  const rpcName = getClearanceSearchRpcName(operation);

  if (!rpcName) {
    return false;
  }

  const message = error.message ?? "";
  const details = error.details ?? "";

  return (
    error.code === "PGRST202" ||
    message.includes(rpcName) ||
    details.includes(rpcName)
  );
}

function toQueryError(
  error: unknown,
  operation: string,
  table?: RelationName,
): SupabaseQueryError {
  if (isSupabaseErrorLike(error)) {
    if (isMissingClearanceSearchFunction(error, operation)) {
      return {
        message: `Database setup required: the ${getClearanceSearchRpcName(operation)} SQL function is not installed in Supabase yet. Run the clearance search migration, then refresh this page.`,
        code: error.code,
        details: error.details,
        hint: error.hint,
        table,
        operation,
      };
    }

    return {
      message: error.message ?? "Supabase query failed.",
      code: error.code,
      details: error.details,
      hint: error.hint,
      table,
      operation,
    };
  }

  if (error instanceof Error) {
    return {
      message: error.message,
      table,
      operation,
    };
  }

  return {
    message: "Supabase query failed with an unknown error.",
    table,
    operation,
  };
}

function ok<TData>(data: TData): SupabaseQueryResult<TData> {
  return { data, error: null };
}

function fail<TData>(error: SupabaseQueryError): SupabaseQueryResult<TData> {
  return { data: null, error };
}

async function runSupabaseQuery<TData>(
  operation: string,
  table: RelationName,
  query: () => Promise<{ data: TData | null; error: unknown }>,
  fallbackData: TData,
): Promise<SupabaseQueryResult<TData>> {
  const environment = getSupabaseEnvironmentStatus();

  if (!environment.isConfigured) {
    return fail({
      message:
        "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable live database reads.",
      table,
      operation,
    });
  }

  try {
    const { data, error } = await query();

    if (error) {
      return fail(toQueryError(error, operation, table));
    }

    return ok(data ?? fallbackData);
  } catch (error) {
    return fail(toQueryError(error, operation, table));
  }
}

function normalizeLimit(
  limit: number | undefined,
  defaultLimit: number,
  maxLimit: number,
) {
  if (!Number.isFinite(limit)) {
    return defaultLimit;
  }

  return Math.min(Math.max(Math.trunc(limit ?? defaultLimit), 1), maxLimit);
}

function escapeIlikeTerm(term: string) {
  return term.replace(/[%,]/g, "").trim();
}

export type ClearanceSearchType = "name" | "alias" | "all";

export interface ClearanceSearchParams {
  query: string;
  searchType?: ClearanceSearchType;
  limit?: number;
}

export interface ClearanceSearchResult {
  id: string;
  personId: number | null;
  organizationId: number | null;
  participantKind: "PERSON" | "ORGANIZATION";
  caseId: number;
  docketNumber: string;
  caseNumber: string;
  violations: string;
  respondentName: string;
  respondentAliases: string[];
  age: string | null;
  status: string;
  lastUpdated: string;
  confidenceScore: number;
  matchDetails: string;
  matchType: "exact" | "alias" | "variant" | "fuzzy" | "phonetic";
  roleLabel: string;
  isVoided: boolean;
  isCorrected: boolean;
  replacedByPersonId: number | null;
  activePersonId: number | null;
  correctionReason: string | null;
  correctedAt: string | null;
  correctedBy: string | null;
  oldSnapshotJson: Json | null;
  newSnapshotJson: Json | null;
  resultGroup: "active" | "inactive";
  matchSource: "active_name" | "voided_previous_name";
}

type ClearanceRpcRow = {
  person_id: number | null;
  organization_id?: number | null;
  participant_kind?: "PERSON" | "ORGANIZATION" | null;
  case_id: number;
  docket_number: string | null;
  case_number: string | null;
  violations: string | null;
  full_name: string | null;
  aliases: string[] | null;
  age: string | null;
  status: string | null;
  last_updated: string | null;
  confidence_score: number | null;
  match_details: string | null;
  match_type: ClearanceSearchResult["matchType"] | null;
  role_label: string | null;
  is_voided?: boolean | null;
  assigned_prosecutor_id?: number | null;
  assigned_prosecutor_name?: string | null;
  active_motion_resolution_id?: number | null;
  active_motion_resolution_recommendation_id?: number | null;
  active_motion_resolution_recommendation_code?: string | null;
  active_motion_resolution_recommendation_label?: string | null;
  is_corrected?: boolean | null;
  replaced_by_person_id?: number | null;
  active_person_id?: number | null;
  correction_reason?: string | null;
  corrected_at?: string | null;
  corrected_by?: string | null;
  old_snapshot_json?: Json | null;
  new_snapshot_json?: Json | null;
  result_group?: "active" | "inactive" | null;
  match_source?: "active_name" | "voided_previous_name" | null;
};

function normalizeClearanceSearchRow(
  row: ClearanceRpcRow,
): ClearanceSearchResult {
  const confidence = Math.round(Number(row.confidence_score ?? 0));
  const docketNumber = row.docket_number ?? `Case #${row.case_id}`;
  const caseNumber = row.case_number ?? docketNumber;

  return {
    id: `${row.result_group ?? "active"}-${row.match_source ?? "active_name"}-${row.case_id}-${row.participant_kind ?? "PERSON"}-${row.person_id ?? row.organization_id}`,
    personId: row.person_id,
    organizationId: row.organization_id ?? null,
    participantKind: row.participant_kind ?? (row.organization_id ? "ORGANIZATION" : "PERSON"),
    caseId: row.case_id,
    docketNumber,
    caseNumber,
    violations: row.violations ?? "—",
    respondentName: row.full_name ?? "Unknown person",
    respondentAliases: row.aliases ?? [],
    age: row.age,
    status: row.status?.trim() || "Unknown",
    lastUpdated: row.last_updated ?? new Date(0).toISOString(),
    confidenceScore: Math.min(Math.max(confidence, 0), 100),
    matchDetails: row.match_details ?? "Exact normalized match",
    matchType: row.match_type ?? "exact",
    roleLabel: row.role_label ?? "Participant",
    isVoided: row.is_voided === true,
    isCorrected: row.is_corrected === true,
    replacedByPersonId: row.replaced_by_person_id ?? null,
    activePersonId: row.active_person_id ?? null,
    correctionReason: row.correction_reason ?? null,
    correctedAt: row.corrected_at ?? null,
    correctedBy: row.corrected_by ?? null,
    oldSnapshotJson: row.old_snapshot_json ?? null,
    newSnapshotJson: row.new_snapshot_json ?? null,
    resultGroup: row.result_group ?? (row.is_voided ? "inactive" : "active"),
    matchSource: row.match_source ?? (row.is_voided ? "voided_previous_name" : "active_name"),
  };
}

export type CasesCompactQueryParams = {
  docketType?: string;
  docketYear?: number;
  search?: string;
  limit?: number;
};

export async function verifySupabaseConnection(): Promise<
  SupabaseQueryResult<{
    checkedTable: "v_ref_docket_types";
    rowCount: number;
    checkedAt: string;
  }>
> {
  const checkedAt = new Date().toISOString();

  return runSupabaseQuery(
    "verifySupabaseConnection",
    "v_ref_docket_types" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = (await supabase
        .from("v_ref_docket_types" as never)
        .select("id")
        .limit(1)) as unknown as { data: { id: number }[] | null; error: unknown };
      return { data: data ? { checkedTable: "v_ref_docket_types" as const, rowCount: data.length, checkedAt } : null, error };
    },
    { checkedTable: "v_ref_docket_types", rowCount: 0, checkedAt },
  );
}

export async function getDocketTypes(): Promise<SupabaseQueryResult<TableRow<"docket_types">[]>> {
  return runSupabaseQuery("getDocketTypes", "v_ref_docket_types" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_docket_types" as never).select("*").order("sort_order" as never, { ascending: true })) as unknown as { data: TableRow<"docket_types">[] | null; error: unknown };
  }, []);
}

export type CaseStageReferenceRecord = {
  id: number;
  code: string;
  display_label: string;
  sort_order: number;
  is_final_stage: boolean;
  is_milestone: boolean;
  is_active: boolean;
  created_at?: string | null;
  updated_at?: string | null;
};

export async function getCaseStatuses(): Promise<SupabaseQueryResult<TableRow<"case_statuses">[]>> {
  return runSupabaseQuery("getCaseStatuses", "v_ref_case_statuses" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_case_statuses" as never).select("*").order("sort_order" as never, { ascending: true })) as unknown as { data: TableRow<"case_statuses">[] | null; error: unknown };
  }, []);
}

export async function getCaseStages(): Promise<SupabaseQueryResult<CaseStageReferenceRecord[]>> {
  return runSupabaseQuery("getCaseStages", "v_ref_case_stages" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_case_stages" as never).select("*").order("sort_order" as never, { ascending: true })) as unknown as { data: CaseStageReferenceRecord[] | null; error: unknown };
  }, []);
}

export async function getCases(limit?: number): Promise<SupabaseQueryResult<TableRow<"cases">[]>> {
  const result = await getDocketShellDisplay({ limit: normalizeLimit(limit, 50, 250) });
  return result as unknown as SupabaseQueryResult<TableRow<"cases">[]>;
}

export type DocketShellRecord = {
  id: number;
  docket_type_id: number;
  docket_year: number;
  docket_number: number;
  docket_month_code: string | null;
  docket_display_number: string | null;
  docket_type_prefix: string | null;
  docket_type_name: string | null;
  created_at: string;
};

export type DocketParticipantsRecord = {
  id: number;
  complainant: string | null;
  respondent: string | null;
};

export type DocketCaseLabelsRecord = {
  id: number;
  violations: string | null;
  summary_text: string | null;
  case_classification_label: string | null;
};

export type DocketQuickDetailsRecord = {
  id: number;
  date_received: string | null;
  current_status_code: string | null;
  current_status_label: string | null;
  current_status_id?: number | null;
  current_status_date?: string | null;
  current_case_status_id: number | null;
  current_case_status_code: string | null;
  current_case_status_label: string | null;
  current_case_status_date: string | null;
  current_case_status_remarks: string | null;
  current_case_stage_id: number | null;
  current_case_stage_code: string | null;
  current_case_stage_label: string | null;
  current_case_stage_date: string | null;
  current_case_stage_remarks: string | null;
  prosecutor_full_name: string | null;
  prosecutor_short_name: string | null;
};

export type CasesDisplayRecord = DocketShellRecord & DocketParticipantsRecord & DocketCaseLabelsRecord & DocketQuickDetailsRecord;

const DOCKET_SHELL_COLUMNS =
  "id, docket_type_id, docket_year, docket_number, docket_month_code, docket_display_number, docket_type_prefix, docket_type_name, created_at";

const DOCKET_PARTICIPANTS_COLUMNS = "id, complainant, respondent";

const DOCKET_CASE_LABELS_COLUMNS =
  "id, violations, summary_text, case_classification_label";

const DOCKET_QUICK_DETAILS_COLUMNS =
  "id, date_received, current_status_code, current_status_label, prosecutor_full_name, prosecutor_short_name, current_status_id, current_status_date, current_case_status_id, current_case_status_code, current_case_status_label, current_case_status_date, current_case_status_remarks, current_case_stage_id, current_case_stage_code, current_case_stage_label, current_case_stage_date, current_case_stage_remarks";

const EMPTY_DOCKET_PARTICIPANTS: Omit<DocketParticipantsRecord, "id"> = {
  complainant: null,
  respondent: null,
};

const EMPTY_DOCKET_CASE_LABELS: Omit<DocketCaseLabelsRecord, "id"> = {
  violations: null,
  summary_text: null,
  case_classification_label: null,
};

const EMPTY_DOCKET_QUICK_DETAILS: Omit<DocketQuickDetailsRecord, "id"> = {
  date_received: null,
  current_status_code: null,
  current_status_label: null,
  current_status_id: null,
  current_status_date: null,
  current_case_status_id: null,
  current_case_status_code: null,
  current_case_status_label: null,
  current_case_status_date: null,
  current_case_status_remarks: null,
  current_case_stage_id: null,
  current_case_stage_code: null,
  current_case_stage_label: null,
  current_case_stage_date: null,
  current_case_stage_remarks: null,
  prosecutor_full_name: null,
  prosecutor_short_name: null,
};

function mergeDocketViews(
  shellRows: DocketShellRecord[],
  participants: DocketParticipantsRecord[],
  labels: DocketCaseLabelsRecord[],
  quickDetails: DocketQuickDetailsRecord[],
): CasesDisplayRecord[] {
  const participantsByCaseId = new Map(participants.map((participant) => [participant.id, participant]));
  const labelsByCaseId = new Map(labels.map((label) => [label.id, label]));
  const quickDetailsByCaseId = new Map(quickDetails.map((detail) => [detail.id, detail]));

  return shellRows.map((shellRow) => ({
    ...shellRow,
    ...(participantsByCaseId.get(shellRow.id) ?? EMPTY_DOCKET_PARTICIPANTS),
    ...(labelsByCaseId.get(shellRow.id) ?? EMPTY_DOCKET_CASE_LABELS),
    ...(quickDetailsByCaseId.get(shellRow.id) ?? EMPTY_DOCKET_QUICK_DETAILS),
  }));
}

async function getRowsByCaseIds<Row extends { id: number }>(
  operation: string,
  viewName: string,
  columns: string,
  caseIds: number[],
): Promise<SupabaseQueryResult<Row[]>> {
  const safeCaseIds = Array.from(new Set(caseIds.filter((caseId) => Number.isFinite(caseId))));
  const caseIdChunkSize = 1000;

  if (safeCaseIds.length === 0) {
    return ok([]);
  }

  return runSupabaseQuery(
    operation,
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const chunks = [] as Promise<{
        data: Row[] | null;
        error: unknown;
      }>[];

      for (let start = 0; start < safeCaseIds.length; start += caseIdChunkSize) {
        const caseIdChunk = safeCaseIds.slice(start, start + caseIdChunkSize);
        const query = supabase
          .from(viewName as never)
          .select(columns)
          .in("id" as never, caseIdChunk) as unknown as Promise<{
            data: Row[] | null;
            error: unknown;
          }>;

        chunks.push(query);
      }

      const responses = await Promise.all(chunks);
      const rows: Row[] = [];

      for (const response of responses) {
        if (response.error) {
          return { data: null, error: response.error };
        }

        rows.push(...(response.data ?? []));
      }

      return { data: rows, error: null };
    },
    [],
  );
}

export async function getDocketParticipantsForCases(
  caseIds: number[],
): Promise<SupabaseQueryResult<DocketParticipantsRecord[]>> {
  return getRowsByCaseIds<DocketParticipantsRecord>(
    "getDocketParticipantsForCases",
    "v_docket_participants",
    DOCKET_PARTICIPANTS_COLUMNS,
    caseIds,
  );
}

export async function getDocketCaseLabelsForCases(
  caseIds: number[],
): Promise<SupabaseQueryResult<DocketCaseLabelsRecord[]>> {
  return getRowsByCaseIds<DocketCaseLabelsRecord>(
    "getDocketCaseLabelsForCases",
    "v_docket_case_violation_classification",
    DOCKET_CASE_LABELS_COLUMNS,
    caseIds,
  );
}

export async function getDocketQuickDetailsForCases(
  caseIds: number[],
): Promise<SupabaseQueryResult<DocketQuickDetailsRecord[]>> {
  return getRowsByCaseIds<DocketQuickDetailsRecord>(
    "getDocketQuickDetailsForCases",
    "v_docket_quickdetails",
    DOCKET_QUICK_DETAILS_COLUMNS,
    caseIds,
  );
}

function dedupeRowsById<Row extends { id: number | null }>(rows: Row[]): Row[] {
  const seenCaseIds = new Set<number>();
  const uniqueRows: Row[] = [];

  for (const row of rows) {
    if (row.id === null) {
      uniqueRows.push(row);
      continue;
    }

    if (seenCaseIds.has(row.id)) {
      continue;
    }

    seenCaseIds.add(row.id);
    uniqueRows.push(row);
  }

  return uniqueRows;
}

export async function getDocketShellDisplay(
  params: CasesCompactQueryParams = {},
): Promise<SupabaseQueryResult<DocketShellRecord[]>> {
  const { docketType, docketYear, limit } = params;

  return runSupabaseQuery(
    "getDocketShellDisplay",
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const pageSize = limit === undefined ? 1000 : normalizeLimit(limit, 50, 500);
      const shouldFetchAllPages = limit === undefined;
      const allShellRows: DocketShellRecord[] = [];

      for (let start = 0; ; start += pageSize) {
        let query = supabase
          .from("v_docket_shell" as never)
          .select(DOCKET_SHELL_COLUMNS)
          .order("created_at" as never, { ascending: false, nullsFirst: false })
          .order("id" as never, { ascending: false })
          .range(start, start + pageSize - 1);

        if (docketType && docketType !== "All") {
          query = query.eq("docket_type_prefix" as never, docketType);
        }

        if (docketYear !== undefined) {
          query = query.eq("docket_year" as never, docketYear);
        }

        const response = (await query) as unknown as {
          data: DocketShellRecord[] | null;
          error: unknown;
        };

        if (response.error) {
          return { data: null, error: response.error };
        }

        const page = response.data ?? [];
        allShellRows.push(...page);

        if (!shouldFetchAllPages || page.length < pageSize) {
          break;
        }
      }

      return { data: dedupeRowsById(allShellRows), error: null };
    },
    [],
  );
}

export async function getDocketParticipantsDisplay(
  params: CasesCompactQueryParams = {},
): Promise<SupabaseQueryResult<(DocketShellRecord & DocketParticipantsRecord)[]>> {
  const shellResult = await getDocketShellDisplay(params);

  if (shellResult.error) {
    return shellResult;
  }

  const participantsResult = await getDocketParticipantsForCases(
    shellResult.data.map((caseDetail) => caseDetail.id),
  );

  if (participantsResult.error) {
    return participantsResult;
  }

  const participantsByCaseId = new Map(
    participantsResult.data.map((participant) => [participant.id, participant]),
  );

  return {
    data: shellResult.data.map((shellRow) => ({
      ...shellRow,
      ...(participantsByCaseId.get(shellRow.id) ?? EMPTY_DOCKET_PARTICIPANTS),
    })),
    error: null,
  };
}

export async function getCasesDisplay(
  params: CasesCompactQueryParams = {},
): Promise<SupabaseQueryResult<CasesDisplayRecord[]>> {
  const shellResult = await getDocketShellDisplay(params);

  if (shellResult.error) {
    return shellResult;
  }

  const caseIds = shellResult.data.map((caseDetail) => caseDetail.id);
  const participantsResult = await getDocketParticipantsForCases(caseIds);

  if (participantsResult.error) {
    return participantsResult;
  }

  const labelsResult = await getDocketCaseLabelsForCases(caseIds);

  if (labelsResult.error) {
    return labelsResult;
  }

  const quickDetailsResult = await getDocketQuickDetailsForCases(caseIds);

  if (quickDetailsResult.error) {
    return quickDetailsResult;
  }

  return {
    data: mergeDocketViews(shellResult.data, participantsResult.data, labelsResult.data, quickDetailsResult.data),
    error: null,
  };
}

export type CasePartyParticipantRecord = Pick<
  TableRow<"case_participants">,
  "case_id" | "display_name_snapshot"
> & {
  participant_roles: Pick<TableRow<"participant_roles">, "code" | "display_label"> | null;
  persons: Pick<TableRow<"persons">, "full_name"> | null;
  organizations: Pick<TableRow<"organizations">, "organization_name"> | null;
};

export async function getCasePartyParticipantsForCases(caseIds: number[]): Promise<SupabaseQueryResult<CasePartyParticipantRecord[]>> {
  const result = await getCaseParticipantsForCases(caseIds);
  return result as unknown as SupabaseQueryResult<CasePartyParticipantRecord[]>;
}

export type CaseClassificationSummaryRecord = Pick<TableRow<"cases">, "id"> & {
  case_classifications:
    | Pick<TableRow<"case_classifications">, "display_label">
    | null;
};

export async function getCaseClassificationsForCases(caseIds: number[]): Promise<SupabaseQueryResult<CaseClassificationSummaryRecord[]>> {
  const result = await getDocketCaseLabelsForCases(caseIds);
  if (result.error) return { data: null, error: result.error };
  return { data: result.data.map((row) => ({ id: row.id, case_classifications: row.case_classification_label ? { display_label: row.case_classification_label } : null })), error: null };
}

export type CasesTableQueryParams = CasesCompactQueryParams;

export type CasesTableRecord = TableRow<"cases"> & {
  docket_display_number?: string | null;
  current_status_date?: string | null;
  current_status_raw?: string | null;
  current_status_remarks?: string | null;
  status_approved_date?: string | null;
  status_approved_date_raw?: string | null;
  case_classification_id?: number | null;
  docket_types: Pick<TableRow<"docket_types">, "name" | "prefix"> | null;
  case_classifications:
    | { code?: string | null; display_label?: string | null; name?: string | null }
    | null;
  case_violations:
    | (Pick<TableRow<"case_violations">, "raw_violation_text" | "violation_order"> & {
        violations: Pick<
          TableRow<"violations">,
          "canonical_title" | "short_label" | "title"
        > | null;
      })[]
    | null;
  case_assignments:
    | (Pick<TableRow<"case_assignments">, "assigned_at" | "unassigned_at"> & {
        prosecutors: Pick<TableRow<"prosecutors">, "full_name" | "short_name"> | null;
      })[]
    | null;
  case_private_details: CasePrivateDetailsRecord | null;
};

export async function getCasesFromTable(params: CasesTableQueryParams = {}): Promise<SupabaseQueryResult<CasesTableRecord[]>> {
  const result = await getCasesDisplay(params);
  return result as unknown as SupabaseQueryResult<CasesTableRecord[]>;
}

export async function getLatestCaseDocketYear(docketType: string): Promise<SupabaseQueryResult<number | null>> {
  return runSupabaseQuery("getLatestCaseDocketYear", "v_docket_shell" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    const response = (await supabase.from("v_docket_shell" as never).select("docket_year").eq("docket_type_prefix" as never, docketType).order("docket_year" as never, { ascending: false }).limit(1).maybeSingle()) as unknown as { data: Pick<DocketShellRecord, "docket_year"> | null; error: unknown };
    return { data: response.data?.docket_year ?? null, error: response.error };
  }, null);
}

export async function getCasesCompact(params: CasesCompactQueryParams = {}): Promise<SupabaseQueryResult<ViewRow<"v_cases_display">[]>> {
  const result = await getCasesDisplay(params);
  return result as unknown as SupabaseQueryResult<ViewRow<"v_cases_display">[]>;
}

export async function getCompactCases(
  params?: number | CasesCompactQueryParams,
): Promise<SupabaseQueryResult<ViewRow<"v_cases_display">[]>> {
  if (typeof params === "number") {
    return getCasesCompact({ limit: params });
  }

  return getCasesCompact(params);
}

export type CaseDetailsRecord = TableRow<"cases"> & {
  case_private_details: CasePrivateDetailsRecord | null;
  current_status_id?: number | null;
  current_status_date?: string | null;
  current_status_raw?: string | null;
  current_status_remarks?: string | null;
  current_status?: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  current_case_status_id?: number | null;
  current_case_status_date?: string | null;
  current_case_status_remarks?: string | null;
  current_case_stage_id?: number | null;
  current_case_stage_date?: string | null;
  current_case_stage_remarks?: string | null;
  current_case_status?: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  current_case_stage?: { code: string | null; display_label: string | null } | null;
  status_approved_date?: string | null;
  status_approved_date_raw?: string | null;
  case_classification_id?: number | null;
  docket_types: { name?: string | null; prefix?: string | null } | null;
  case_classifications:
    | { code?: string | null; display_label?: string | null; name?: string | null }
    | null;
};

export type CaseDetailsPageViewRecord = Pick<
  CaseDetailsRecord,
  | "id"
  | "docket_type_id"
  | "docket_year"
  | "docket_number"
  | "docket_month_code"
  | "date_received"
  | "created_by_user_id"
  | "updated_by_user_id"
  | "is_archived"
  | "created_at"
  | "updated_at"
  | "region_code"
  | "case_classification_id"
  | "current_status_id"
  | "current_status_date"
  | "current_status_raw"
  | "current_status_remarks"
  | "current_case_status_id"
  | "current_case_status_date"
  | "current_case_status_remarks"
  | "current_case_stage_id"
  | "current_case_stage_date"
  | "current_case_stage_remarks"
  | "status_approved_date"
  | "status_approved_date_raw"
> & {
  docket_display_number: string | null;
  docket_type_prefix: string | null;
  docket_type_name: string | null;
  violations: string | null;
  summary_text: string | null;
  source: string | null;
  remarks: string | null;
  legacy_source_file: string | null;
  legacy_source_sheet: string | null;
  legacy_row_number: number | null;
  legacy_raw_json: Json | null;
  is_summary_procedure: boolean | null;
  current_status_code: string | null;
  current_status_label: string | null;
  current_status: { code?: string | null; display_label?: string | null } | null;
  current_case_status_code: string | null;
  current_case_status_label: string | null;
  current_case_status: { code?: string | null; display_label?: string | null } | null;
  current_case_stage_code: string | null;
  current_case_stage_label: string | null;
  current_case_stage: { code?: string | null; display_label?: string | null } | null;
  current_prosecutor_id: number | null;
  prosecutor_short_name: string | null;
  prosecutor_full_name: string | null;
  current_staff_id: number | null;
  staff_short_name: string | null;
  staff_full_name: string | null;
  current_assigned_at: string | null;
  case_classification_code: string | null;
  case_classification_name: string | null;
  case_classification_label: string | null;
  case_classification_description: string | null;
  case_addresses: Json | null;
  notes: Json | null;
  case_classifications:
    | { code?: string | null; display_label?: string | null; name?: string | null }
    | null;
  docket_types: { name?: string | null; prefix?: string | null } | null;
  gdrive_folder_id: string | null;
  gdrive_folder_link: string | null;
  gdrive_folder_name: string | null;
  gdrive_folder_status: string | null;
  gdrive_folder_last_scanned_at: string | null;
  court_codes: string | null;
  criminal_case_numbers: string | null;
  court_needs_review: boolean | null;
};

type CaseDetailsPageViewRawRecord = Omit<
  CaseDetailsPageViewRecord,
  "case_classifications" | "current_status" | "current_case_status" | "current_case_stage" | "docket_types"
>;

function withCaseDetailsPageRelations(
  record: CaseDetailsPageViewRawRecord,
): CaseDetailsPageViewRecord {
  return {
    ...record,
    current_status: record.current_status_code || record.current_status_label
      ? {
          code: record.current_status_code,
          display_label: record.current_status_label,
        }
      : null,
    current_case_status: record.current_case_status_code || record.current_case_status_label
      ? {
          code: record.current_case_status_code,
          display_label: record.current_case_status_label,
        }
      : null,
    current_case_stage: record.current_case_stage_code || record.current_case_stage_label
      ? {
          code: record.current_case_stage_code,
          display_label: record.current_case_stage_label,
        }
      : null,
    docket_types: record.docket_type_name || record.docket_type_prefix
      ? {
          name: record.docket_type_name,
          prefix: record.docket_type_prefix,
        }
      : null,
    case_classifications:
      record.case_classification_code || record.case_classification_label || record.case_classification_name
        ? {
            code: record.case_classification_code,
            display_label: record.case_classification_label,
            name: record.case_classification_name,
          }
        : null,
  };
}

export async function getCaseDetailsPageById(
  caseId: number,
): Promise<SupabaseQueryResult<CaseDetailsPageViewRecord | null>> {
  return runSupabaseQuery(
    "getCaseDetailsPageById",
    "v_case_details_page" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const response = (await supabase
        .from("v_case_details_page" as never)
        .select("*")
        .eq("id" as never, caseId)
        .maybeSingle()) as unknown as {
        data: CaseDetailsPageViewRawRecord | null;
        error: unknown;
      };

      if (response.error) {
        return { data: null, error: response.error };
      }

      if (!response.data) {
        return { data: null, error: null };
      }

      return {
        data: withCaseDetailsPageRelations(response.data),
        error: null,
      };
    },
    null,
  );
}

export type PersonAddressRecord = Pick<
  TableRow<"person_addresses">,
  "id" | "is_primary" | "remarks"
> & {
  addresses: Pick<
    TableRow<"addresses">,
    | "barangay"
    | "city"
    | "country"
    | "line1"
    | "line2"
    | "province"
    | "region"
    | "zip_code"
  > | null;
};

export type CaseParticipantPersonRecord = Pick<
  TableRow<"persons">,
  | "age"
  | "birth_date"
  | "first_name"
  | "full_name"
  | "gender"
  | "id"
  | "is_minor"
  | "is_pwd"
  | "is_senior"
  | "last_name"
  | "middle_name"
  | "notes"
  | "person_descriptor"
  | "suffix"
> & {
  person_addresses: PersonAddressRecord[] | null;
};

export type CaseParticipantAttributeRecord = Pick<
  TableRow<"case_participant_attributes">,
  | "age_text"
  | "age_years"
  | "gender_text"
  | "gender_normalized"
  | "is_minor_at_case"
  | "is_senior_at_case"
  | "is_pwd_at_case"
>;

export type ParticipantContactInformationRecord = {
  id: number;
  participant_contact_information_id?: number | null;
  contact_type: "PHONE" | "EMAIL" | "OTHER" | string;
  contact_value: string;
  label?: string | null;
  is_primary?: boolean | null;
  remarks?: string | null;
};

export type CaseParticipantRecord = TableRow<"case_participants"> & {
  contact_informations?: ParticipantContactInformationRecord[] | null;
  case_participant_private_details: CaseParticipantPrivateDetailsRecord | null;
  case_participant_attributes: CaseParticipantAttributeRecord | null;
  participant_roles: Pick<
    TableRow<"participant_roles">,
    "code" | "display_label"
  > | null;
  persons: (CaseParticipantPersonRecord & { person_aliases?: Json | null }) | null;
  organizations?: { id: number; organization_name: string; contact_person?: string | null; contact_number?: string | null; email?: string | null; details_jsonb?: Json | null; organization_aliases?: Json | null; organization_addresses?: PersonAddressRecord[] | null } | null;
};

export type CaseAssignmentRecord = TableRow<"case_assignments"> & {
  prosecutors: Pick<TableRow<"prosecutors">, "full_name" | "short_name"> | null;
  staff: Pick<TableRow<"staff">, "full_name" | "short_name"> | null;
};

export type CaseStatusHistoryRecord = TableRow<"case_status_history"> & {
  from_status: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  to_status: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
};

export type CaseTimelineEventRecord = {
  case_event_id: number;
  case_id: number;
  docket_display_number: string | null;
  event_type_code: string | null;
  event_type_label: string | null;
  event_category: string | null;
  event_date: string | null;
  event_time: string | null;
  event_order: number | null;
  title: string | null;
  description: string | null;
  status_code: string | null;
  status_label: string | null;
  case_status_id: number | null;
  case_status_code: string | null;
  case_status_label: string | null;
  case_stage_id: number | null;
  case_stage_code: string | null;
  case_stage_label: string | null;
  prosecutor_short_name: string | null;
  staff_short_name: string | null;
  court_name: string | null;
  details_jsonb: Json | null;
  source: string | null;
  source_table: string | null;
  source_id: number | null;
  legacy_source_file: string | null;
  legacy_row_number: number | null;
  legacy_line_order: number | null;
  needs_review: boolean | null;
  review_reason: string | null;
  is_voided: boolean | null;
  void_reason: string | null;
  voided_at: string | null;
  voided_by_user_id: number | null;
  voided_by_email: string | null;
};

export type PersonDetailsRecord = TableRow<"persons"> & {
  person_aliases:
    | Pick<
        TableRow<"person_aliases">,
        "alias_name" | "alias_type" | "is_active"
      >[]
    | null;
  person_addresses: PersonAddressRecord[] | null;
};

export async function getPersonDetailsById(
  personId: number,
): Promise<SupabaseQueryResult<PersonDetailsRecord | null>> {
  return runSupabaseQuery(
    "getPersonDetailsById",
    "v_person_details" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("v_person_details" as never)
        .select("*")
        .eq("id" as never, personId)
        .maybeSingle();

      return query as unknown as Promise<{
        data: PersonDetailsRecord | null;
        error: unknown;
      }>;
    },
    null,
  );
}

export async function getCaseParticipantsForPerson(
  personId: number,
): Promise<SupabaseQueryResult<CaseParticipantRecord[]>> {
  return runSupabaseQuery(
    "getCaseParticipantsForPerson",
    "v_case_participants_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("v_case_participants_detail" as never)
        .select("*")
        .eq("person_id", personId)
        .order("case_id", { ascending: false })
        .order("participant_order", { ascending: true, nullsFirst: false })
        .order("id", { ascending: true });

      return query as unknown as Promise<{
        data: CaseParticipantRecord[] | null;
        error: unknown;
      }>;
    },
    [],
  );
}

export async function getCaseCompactsByIds(
  caseIds: number[],
): Promise<SupabaseQueryResult<CasesDisplayRecord[]>> {
  const safeCaseIds = Array.from(
    new Set(caseIds.filter((caseId) => Number.isFinite(caseId))),
  );

  if (safeCaseIds.length === 0) {
    return ok([]);
  }

  const shellResult = await getRowsByCaseIds<DocketShellRecord>(
    "getCaseCompactsByIds",
    "v_docket_shell",
    DOCKET_SHELL_COLUMNS,
    safeCaseIds,
  );

  if (shellResult.error) {
    return shellResult;
  }

  const labelsResult = await getDocketCaseLabelsForCases(safeCaseIds);

  if (labelsResult.error) {
    return labelsResult;
  }

  const quickDetailsResult = await getDocketQuickDetailsForCases(safeCaseIds);

  if (quickDetailsResult.error) {
    return quickDetailsResult;
  }

  return {
    data: mergeDocketViews(shellResult.data, [], labelsResult.data, quickDetailsResult.data),
    error: null,
  };
}


export async function getCaseCompactById(caseId: number): Promise<SupabaseQueryResult<ViewRow<"v_cases_display"> | null>> {
  const result = await getCaseCompactsByIds([caseId]);
  if (result.error) return { data: null, error: result.error };
  return { data: (result.data[0] ?? null) as unknown as ViewRow<"v_cases_display"> | null, error: null };
}

export async function getCaseDetailsById(caseId: number): Promise<SupabaseQueryResult<CaseDetailsRecord | null>> {
  const result = await getCaseDetailsPageById(caseId);
  return result as unknown as SupabaseQueryResult<CaseDetailsRecord | null>;
}

export async function getCaseById(caseId: number): Promise<SupabaseQueryResult<TableRow<"cases"> | null>> {
  const result = await getCaseDetailsPageById(caseId);
  return result as unknown as SupabaseQueryResult<TableRow<"cases"> | null>;
}

export async function searchCases(query: string, limit?: number): Promise<SupabaseQueryResult<ViewRow<"v_cases_display">[]>> {
  const safeLimit = normalizeLimit(limit, 25, 100);
  const safeQuery = query.trim().toLocaleLowerCase();
  if (!safeQuery) return getCompactCases(safeLimit);
  const result = await getCasesDisplay();
  if (result.error) return { data: null, error: result.error };
  return { data: result.data.filter((row) => [row.docket_display_number, row.summary_text, row.violations, row.prosecutor_full_name].filter(Boolean).some((value) => String(value).toLocaleLowerCase().includes(safeQuery))).slice(0, safeLimit) as unknown as ViewRow<"v_cases_display">[], error: null };
}

export async function getPersons(limit?: number): Promise<SupabaseQueryResult<TableRow<"persons">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);
  return runSupabaseQuery("getPersons", "v_person_details" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_person_details" as never).select("*").order("full_name" as never, { ascending: true }).limit(safeLimit)) as unknown as { data: TableRow<"persons">[] | null; error: unknown };
  }, []);
}

export type PersonDetailsSearchRow = TableRow<"persons"> & { person_aliases?: Json | null; person_addresses?: Json | null };

export async function searchPersons(query: string, limit?: number): Promise<SupabaseQueryResult<PersonDetailsSearchRow[]>> {
  const safeLimit = normalizeLimit(limit, 25, 100);
  const tokens = query
    .split(/\s+/)
    .map((token) => escapeIlikeTerm(token))
    .filter(Boolean);

  if (tokens.length === 0) return getPersons(safeLimit);

  return runSupabaseQuery("searchPersons", "v_person_details" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    const orFilter = tokens
      .flatMap((token) => [
        `full_name.ilike.%${token}%`,
        `first_name.ilike.%${token}%`,
        `middle_name.ilike.%${token}%`,
        `last_name.ilike.%${token}%`,
      ])
      .join(",");
    const result = (await supabase
      .from("v_person_details" as never)
      .select("*")
      .or(orFilter)
      .order("full_name" as never, { ascending: true })
      .limit(Math.min(safeLimit * 5, 100))) as unknown as { data: PersonDetailsSearchRow[] | null; error: unknown };

    if (result.error || !result.data) return result;

    const filtered = result.data.filter((person) => {
      const searchable = [person.full_name, person.first_name, person.middle_name, person.last_name]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return tokens.every((token) => searchable.includes(token.toLowerCase().replace(/[%_\\]/g, "")));
    });

    return { data: filtered.slice(0, safeLimit), error: null };
  }, []);
}

export type OrganizationDetailsSearchRow = { id: number; organization_name: string; aliases?: Json | null };

export async function searchOrganizations(query: string, limit?: number): Promise<SupabaseQueryResult<OrganizationDetailsSearchRow[]>> {
  const safeLimit = normalizeLimit(limit, 8, 25);
  const safeQuery = escapeIlikeTerm(query);
  if (!safeQuery) return ok([]);
  return runSupabaseQuery("searchOrganizations", "v_organization_search" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase
      .from("v_organization_search" as never)
      .select("*")
      .ilike("organization_name" as never, `%${safeQuery}%`)
      .order("organization_name" as never, { ascending: true })
      .limit(safeLimit)) as unknown as { data: OrganizationDetailsSearchRow[] | null; error: unknown };
  }, []);
}


export type OrganizationDetailsRecord = TableRow<"organizations"> & {
  details_jsonb?: Json | null;
  organization_aliases?: { id: number; alias_name: string; is_active: boolean | null }[] | Json | null;
};

export async function getOrganizationDetailsById(
  organizationId: number,
): Promise<SupabaseQueryResult<OrganizationDetailsRecord | null>> {
  return runSupabaseQuery(
    "getOrganizationDetailsById",
    "v_organization_details" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("v_organization_details" as never)
        .select("*")
        .eq("id" as never, organizationId)
        .maybeSingle();

      return query as unknown as Promise<{
        data: OrganizationDetailsRecord | null;
        error: unknown;
      }>;
    },
    null,
  );
}

export async function getCaseParticipantsForOrganization(
  organizationId: number,
): Promise<SupabaseQueryResult<CaseParticipantRecord[]>> {
  return runSupabaseQuery(
    "getCaseParticipantsForOrganization",
    "v_case_participants_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("v_case_participants_detail" as never)
        .select("*")
        .eq("organization_id" as never, organizationId)
        .order("case_id", { ascending: false })
        .order("participant_order", { ascending: true, nullsFirst: false })
        .order("id", { ascending: true });

      return query as unknown as Promise<{
        data: CaseParticipantRecord[] | null;
        error: unknown;
      }>;
    },
    [],
  );
}

export async function getProsecutors(limit?: number): Promise<SupabaseQueryResult<TableRow<"prosecutors">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);
  return runSupabaseQuery("getProsecutors", "v_ref_prosecutors" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_prosecutors" as never).select("*").order("full_name" as never, { ascending: true }).limit(safeLimit)) as unknown as { data: TableRow<"prosecutors">[] | null; error: unknown };
  }, []);
}


export async function getStaff(limit?: number): Promise<SupabaseQueryResult<TableRow<"staff">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);
  return runSupabaseQuery("getStaff", "staff", async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("staff" as never).select("*").eq("is_active" as never, true).order("full_name" as never, { ascending: true }).limit(safeLimit)) as unknown as { data: TableRow<"staff">[] | null; error: unknown };
  }, []);
}

export async function getCaseParticipants(
  caseId: number,
): Promise<SupabaseQueryResult<CaseParticipantRecord[]>> {
  return runSupabaseQuery(
    "getCaseParticipants",
    "v_case_participants_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("v_case_participants_detail" as never)
        .select("*")
        .eq("case_id", caseId)
        .order("participant_order", { ascending: true, nullsFirst: false })
        .order("id", { ascending: true });

      return query as unknown as Promise<{
        data: CaseParticipantRecord[] | null;
        error: unknown;
      }>;
    },
    [],
  );
}


export type CaseOverviewEditSection =
  | "docket_info"
  | "case_details"
  | "status"
  | "assignment"
  | "places"
  | "notes"
  | "violations";

export interface EditCaseOverviewSectionInput {
  caseId: number;
  section: CaseOverviewEditSection;
  reason: string;
  data: Record<string, unknown>;
}

export async function editCaseOverviewSection(
  input: EditCaseOverviewSectionInput,
): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) {
    return fail({
      message: "Supabase is not configured.",
      table: "cases",
      operation: "editCaseOverviewSection",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user available."),
          "editCaseOverviewSection",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc(
      "edit_case_overview_section" as never,
      {
        p_payload: {
          caseId: input.caseId,
          section: input.section,
          reason: input.reason,
          userId: currentUserQuery.data.id,
          data: input.data,
        },
      } as never,
    );

    if (error) {
      return fail(toQueryError(error, "editCaseOverviewSection", "cases"));
    }

    return ok(Number(data ?? input.caseId));
  } catch (error) {
    return fail(toQueryError(error, "editCaseOverviewSection", "cases"));
  }
}


export type CasePlaceRecord = {
  id: number;
  case_id: number;
  address_id: number;
  address_type_id: number;
  is_primary: boolean;
  remarks: string | null;
  created_at?: string | null;
  is_deleted?: boolean | null;
  deleted_at?: string | null;
  deleted_by_user_id?: number | null;
  delete_reason?: string | null;
  addresses: {
    id: number;
    line1: string | null;
    line2: string | null;
    barangay: string | null;
    city: string | null;
    province: string | null;
    region: string | null;
    zip_code: string | null;
    country: string | null;
    latitude: number | string | null;
    longitude: number | string | null;
  } | null;
  address_types: { id: number; display_label: string | null; code: string | null } | null;
};

export type ManageCasePlaceAction = "add" | "edit" | "remove" | "restore";

export interface ManageCasePlacesInput {
  caseId: number;
  action: ManageCasePlaceAction;
  reason: string;
  place: Record<string, unknown>;
}


export type CaseViolationManagementRecord = TableRow<"case_violations"> & {
  is_deleted?: boolean | null;
  deleted_at?: string | null;
  deleted_by_user_id?: number | null;
  delete_reason?: string | null;
  violations: Pick<TableRow<"violations">, "id" | "title" | "short_label" | "reference_code" | "law_reference" | "description"> | null;
};

export type ManageCaseViolationAction = "add" | "edit" | "remove" | "restore";

export interface ManageCaseViolationsInput {
  caseId: number;
  action: ManageCaseViolationAction;
  reason: string;
  violation: Record<string, unknown>;
}

export type CaseNoteManagementRecord = {
  id: number;
  case_id: number;
  created_by_user_id: number;
  note_text: string;
  is_private: boolean;
  created_at: string;
  updated_at: string;
  is_deleted?: boolean | null;
  deleted_at?: string | null;
  deleted_by_user_id?: number | null;
  delete_reason?: string | null;
};

export type ManageCaseNoteAction = "add" | "edit" | "remove" | "restore";

export interface ManageCaseNotesInput {
  caseId: number;
  action: ManageCaseNoteAction;
  reason: string;
  note: Record<string, unknown>;
}

export type CaseOverviewChangeHistoryRecord = {
  id: number;
  action: string;
  summary: string | null;
  metadata: Json | null;
  old_data: Json | null;
  new_data: Json | null;
  created_at: string;
};


export async function getCaseManagedViolations(
  caseId: number,
  includeDeleted = false,
): Promise<SupabaseQueryResult<CaseViolationManagementRecord[]>> {
  return runSupabaseQuery(
    "getCaseManagedViolations",
    "case_violations",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      let query = supabase
        .from("case_violations" as never)
        .select("*, violations(id,title,short_label,reference_code,law_reference,description)" as never)
        .eq("case_id" as never, caseId)
        .order("violation_order" as never, { ascending: true })
        .order("id" as never, { ascending: true });

      if (!includeDeleted) {
        query = query.eq("is_deleted" as never, false);
      }

      return (await query) as unknown as {
        data: CaseViolationManagementRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function manageCaseViolations(
  input: ManageCaseViolationsInput,
): Promise<SupabaseQueryResult<number>> {
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "manageCaseViolations", "users"));
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("manage_case_violations" as never, {
      p_payload: {
        caseId: input.caseId,
        action: input.action,
        reason: input.reason,
        userId: currentUserQuery.data.id,
        violation: input.violation,
      },
    } as never);

    if (error) return fail(toQueryError(error, "manageCaseViolations", "cases"));
    return ok(Number(data ?? input.caseId));
  } catch (error) {
    return fail(toQueryError(error, "manageCaseViolations", "cases"));
  }
}

export async function getCasePlaces(
  caseId: number,
  includeDeleted = false,
): Promise<SupabaseQueryResult<CasePlaceRecord[]>> {
  return runSupabaseQuery(
    "getCasePlaces",
    "case_addresses",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      let query = supabase
        .from("case_addresses" as never)
        .select("*, addresses(*), address_types(id,code,display_label)" as never)
        .eq("case_id" as never, caseId)
        .order("is_primary" as never, { ascending: false })
        .order("id" as never, { ascending: true });

      if (!includeDeleted) {
        query = query.eq("is_deleted" as never, false);
      }

      return (await query) as unknown as {
        data: CasePlaceRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function manageCasePlaces(
  input: ManageCasePlacesInput,
): Promise<SupabaseQueryResult<number>> {
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "manageCasePlaces", "users"));
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("manage_case_places" as never, {
      p_payload: {
        caseId: input.caseId,
        action: input.action,
        reason: input.reason,
        userId: currentUserQuery.data.id,
        place: input.place,
      },
    } as never);

    if (error) return fail(toQueryError(error, "manageCasePlaces", "cases"));
    return ok(Number(data ?? input.caseId));
  } catch (error) {
    return fail(toQueryError(error, "manageCasePlaces", "cases"));
  }
}

export async function getCaseManagedNotes(
  caseId: number,
  includeDeleted = false,
): Promise<SupabaseQueryResult<CaseNoteManagementRecord[]>> {
  return runSupabaseQuery(
    "getCaseManagedNotes",
    "notes",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      let query = supabase
        .from("notes" as never)
        .select("*" as never)
        .eq("case_id" as never, caseId)
        .order("created_at" as never, { ascending: false });

      if (!includeDeleted) {
        query = query.eq("is_deleted" as never, false);
      }

      return (await query) as unknown as {
        data: CaseNoteManagementRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function manageCaseNotes(
  input: ManageCaseNotesInput,
): Promise<SupabaseQueryResult<number>> {
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "manageCaseNotes", "users"));
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("manage_case_notes" as never, {
      p_payload: {
        caseId: input.caseId,
        action: input.action,
        reason: input.reason,
        userId: currentUserQuery.data.id,
        note: input.note,
      },
    } as never);

    if (error) return fail(toQueryError(error, "manageCaseNotes", "cases"));
    return ok(Number(data ?? input.caseId));
  } catch (error) {
    return fail(toQueryError(error, "manageCaseNotes", "cases"));
  }
}
export type ManageCaseParticipantAction =
  | "edit_main_details"
  | "add_alias"
  | "edit_alias"
  | "remove_alias"
  | "add_address"
  | "edit_address"
  | "remove_address"
  | "add_contact"
  | "edit_contact"
  | "remove_contact";

export interface ManageCaseParticipantsInput {
  caseId: number;
  action: ManageCaseParticipantAction;
  reason: string;
  participant: Record<string, unknown>;
}

export async function manageCaseParticipants(
  input: ManageCaseParticipantsInput,
): Promise<SupabaseQueryResult<number>> {
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "manageCaseParticipants", "users"));
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("manage_case_participants" as never, {
      p_payload: {
        caseId: input.caseId,
        action: input.action,
        reason: input.reason,
        userId: currentUserQuery.data.id,
        participant: input.participant,
      },
    } as never);

    if (error) return fail(toQueryError(error, "manageCaseParticipants", "case_participants"));
    return ok(Number(data ?? input.caseId));
  } catch (error) {
    return fail(toQueryError(error, "manageCaseParticipants", "case_participants"));
  }
}



export type CaseParticipantCorrectionRecord = {
  id: number;
  case_id: number;
  case_participant_id: number;
  old_person_id: number | null;
  new_person_id: number | null;
  old_organization_id?: number | null;
  new_organization_id?: number | null;
  old_snapshot_json: Json | null;
  new_snapshot_json: Json | null;
  reason: string | null;
  corrected_by_user_id: number | null;
  corrected_by_display: string | null;
  corrected_at: string | null;
};

export async function getCaseParticipantCorrections(
  caseParticipantId: number,
): Promise<SupabaseQueryResult<CaseParticipantCorrectionRecord[]>> {
  return runSupabaseQuery(
    "getCaseParticipantCorrections",
    "v_case_participant_corrections" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return (await supabase
        .from("v_case_participant_corrections" as never)
        .select("*" as never)
        .eq("case_participant_id" as never, caseParticipantId)
        .order("corrected_at" as never, { ascending: false })) as unknown as {
        data: CaseParticipantCorrectionRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function getCaseOverviewChangeHistory(
  caseId: number,
): Promise<SupabaseQueryResult<CaseOverviewChangeHistoryRecord[]>> {
  return runSupabaseQuery(
    "getCaseOverviewChangeHistory",
    "audit_logs",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return (await supabase
        .from("audit_logs" as never)
        .select("id,action,summary,metadata,old_data,new_data,created_at" as never)
        .eq("case_id" as never, caseId)
        .or("action.like.EDIT_CASE_OVERVIEW%,action.like.MANAGE_CASE_PLACES%,action.like.MANAGE_CASE_NOTES%" as never)
        .order("created_at" as never, { ascending: false })) as unknown as {
        data: CaseOverviewChangeHistoryRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function getCaseParticipantsForCases(
  caseIds: number[],
): Promise<SupabaseQueryResult<CaseParticipantRecord[]>> {
  const safeCaseIds = Array.from(
    new Set(caseIds.filter((caseId) => Number.isFinite(caseId))),
  );
  const caseIdChunkSize = 100;

  if (safeCaseIds.length === 0) {
    return { data: [], error: null };
  }

  return runSupabaseQuery(
    "getCaseParticipantsForCases",
    "v_case_participants_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const allParticipants: CaseParticipantRecord[] = [];

      for (let start = 0; start < safeCaseIds.length; start += caseIdChunkSize) {
        const caseIdChunk = safeCaseIds.slice(start, start + caseIdChunkSize);
        const query = supabase
          .from("v_case_participants_detail" as never)
          .select("*")
          .in("case_id" as never, caseIdChunk)
          .order("case_id" as never, { ascending: true })
          .order("participant_order" as never, { ascending: true, nullsFirst: false })
          .order("id" as never, { ascending: true });

        const { data, error } = (await query) as unknown as {
          data: CaseParticipantRecord[] | null;
          error: unknown;
        };

        if (error) {
          return { data: null, error };
        }

        allParticipants.push(...(data ?? []));
      }

      return { data: allParticipants, error: null };
    },
    [],
  );
}

export async function getCaseAssignments(caseId: number): Promise<SupabaseQueryResult<CaseAssignmentRecord[]>> {
  return runSupabaseQuery("getCaseAssignments", "v_case_assignment_detail" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_case_assignment_detail" as never).select("*").eq("case_id" as never, caseId).order("assigned_at" as never, { ascending: false })) as unknown as { data: CaseAssignmentRecord[] | null; error: unknown };
  }, []);
}

export interface AssignProsecutorInput {
  caseId: number;
  prosecutorId: number;
  remarks?: string;
}

export async function assignProsecutorToCase(input: AssignProsecutorInput): Promise<SupabaseQueryResult<TableRow<"case_assignments">>> {
  void input;
  return fail({ message: "Direct browser mutations are disabled during the frontend read-view refactor. Re-enable assignment through a server-only action or existing RPC.", table: "case_assignments", operation: "assignProsecutorToCase" });
}

export async function unassignActiveProsecutorFromCase(caseId: number): Promise<SupabaseQueryResult<TableRow<"case_assignments">[]>> {
  void caseId;
  return fail({ message: "Direct browser mutations are disabled during the frontend read-view refactor. Re-enable unassignment through a server-only action or existing RPC.", table: "case_assignments", operation: "unassignActiveProsecutorFromCase" });
}

export async function getCaseStatusHistory(caseId: number): Promise<SupabaseQueryResult<CaseStatusHistoryRecord[]>> {
  return runSupabaseQuery("getCaseStatusHistory", "v_case_status_history_detail" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_case_status_history_detail" as never).select("*").eq("case_id" as never, caseId).order("changed_at" as never, { ascending: false })) as unknown as { data: CaseStatusHistoryRecord[] | null; error: unknown };
  }, []);
}

export type CaseCourtRecord = TableRow<"case_courts"> & {
  courts: Pick<TableRow<"courts">, "code" | "court_type" | "name"> | null;
};

export async function getCaseCourtDetails(
  caseId: number,
): Promise<SupabaseQueryResult<CaseCourtRecord[]>> {
  return runSupabaseQuery(
    "getCaseCourtDetails",
    "v_case_courts_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("v_case_courts_detail" as never)
        .select("*")
        .eq("case_id", caseId)
        .order("court_order", { ascending: true })
        .order("created_at", { ascending: true });

      return query as unknown as Promise<{
        data: CaseCourtRecord[] | null;
        error: unknown;
      }>;
    },
    [],
  );
}

export type CasePetitionForReviewRecord = {
  id: number;
  case_id: number;
  petition_title: string | null;
  handling_prosecutor_text: string | null;
  date_received: string | null;
  date_received_raw: string | null;
  filed_by: string | null;
  petition_status: string | null;
  date_resolved: string | null;
  date_resolved_raw: string | null;
  date_approved: string | null;
  date_approved_raw: string | null;
  remarks: string | null;
};

export type CaseMotionRecord = TableRow<"case_motions"> & {
  case_event_id?: number | null;
  motion_title?: string | null;
  filed_by_code?: string | null;
  date_filed?: string | null;
  time_filed?: string | null;
  details_jsonb?: unknown;
  is_voided?: boolean | null;
  assigned_prosecutor_id?: number | null;
  assigned_prosecutor_name?: string | null;
  active_motion_resolution_id?: number | null;
  active_motion_resolution_recommendation_id?: number | null;
  active_motion_resolution_recommendation_code?: string | null;
  active_motion_resolution_recommendation_label?: string | null;
  motion_order?: number | null;
  date_received_raw?: string | null;
  date_resolved?: string | null;
  date_resolved_raw?: string | null;
  date_approved?: string | null;
  date_approved_raw?: string | null;
  filed_by_raw?: string | null;
  motion_status_raw?: string | null;
  remarks_raw?: string | null;
};

export async function getCaseMotions(
  caseId: number,
): Promise<SupabaseQueryResult<CaseMotionRecord[]>> {
  return runSupabaseQuery(
    "getCaseMotions",
    "v_case_motions_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return (await supabase
        .from("v_case_motions_detail" as never)
        .select("*")
        .eq("case_id", caseId)
        .order("motion_order", { ascending: true, nullsFirst: false })
        .order("date_received", { ascending: false, nullsFirst: false })
        .order("created_at", { ascending: false })) as {
        data: CaseMotionRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function getCasePetitionsForReview(
  caseId: number,
): Promise<SupabaseQueryResult<CasePetitionForReviewRecord[]>> {
  return runSupabaseQuery(
    "getCasePetitionsForReview",
    "v_case_petitions_for_review_detail" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return (await supabase
        .from("v_case_petitions_for_review_detail" as never)
        .select(
          "id, case_id, petition_title, handling_prosecutor_text, date_received, date_received_raw, filed_by, petition_status, date_resolved, date_resolved_raw, date_approved, date_approved_raw, remarks",
        )
        .eq("case_id" as never, caseId)
        .order("date_received" as never, { ascending: false, nullsFirst: false })) as {
        data: CasePetitionForReviewRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}

export async function getCaseAttachmentsIndex(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<"case_attachment_index">[]>> {
  return runSupabaseQuery(
    "getCaseAttachmentsIndex",
    "v_case_attachments" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("v_case_attachments" as never)
        .select("*")
        .eq("case_id", caseId)
        .order("last_seen_at", { ascending: false });
    },
    [],
  );
}

export async function getCaseTimelineEvents(
  caseId: number,
): Promise<SupabaseQueryResult<CaseTimelineEventRecord[]>> {
  return runSupabaseQuery(
    "getCaseTimelineEvents",
    "v_case_timeline" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return (await supabase
        .from("v_case_timeline" as never)
        .select("*")
        .eq("case_id", caseId)
        .order("event_date", { ascending: true, nullsFirst: false })
        .order("event_order", { ascending: true, nullsFirst: false })
        .order("case_event_id", { ascending: true })) as {
        data: CaseTimelineEventRecord[] | null;
        error: unknown;
      };
    },
    [],
  );
}


export interface RecordCaseAssignmentEventInput {
  caseId: number;
  prosecutorId: number;
  assignmentDate: string;
  assignmentTime?: string | null;
  staffId?: number | null;
  remarks?: string | null;
}

export async function recordCaseAssignmentEvent(
  input: RecordCaseAssignmentEventInput,
): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) {
    return fail({
      message: "Supabase is not configured.",
      table: "case_assignments",
      operation: "recordCaseAssignmentEvent",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user available."),
          "recordCaseAssignmentEvent",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_case_assignment_event" as never, {
      p_case_id: input.caseId,
      p_prosecutor_id: input.prosecutorId,
      p_assignment_date: input.assignmentDate,
      p_assignment_time: input.assignmentTime?.trim() || null,
      p_staff_id: input.staffId ?? null,
      p_remarks: input.remarks?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);

    if (error) {
      return fail(toQueryError(error, "recordCaseAssignmentEvent", "case_assignments"));
    }

    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordCaseAssignmentEvent", "case_assignments"));
  }
}


export interface RecordCaseReassignmentEventInput {
  caseId: number;
  prosecutorId: number;
  reassignmentDate: string;
  reassignmentTime?: string | null;
  staffId?: number | null;
  reason: string;
  remarks?: string | null;
}

export async function recordCaseReassignmentEvent(
  input: RecordCaseReassignmentEventInput,
): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) {
    return fail({
      message: "Supabase is not configured.",
      table: "case_assignments",
      operation: "recordCaseReassignmentEvent",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user available."),
          "recordCaseReassignmentEvent",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_case_reassignment_event" as never, {
      p_case_id: input.caseId,
      p_new_prosecutor_id: input.prosecutorId,
      p_reassignment_date: input.reassignmentDate,
      p_reassignment_time: input.reassignmentTime?.trim() || null,
      p_new_staff_id: input.staffId ?? null,
      p_reason: input.reason.trim(),
      p_remarks: input.remarks?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);

    if (error) {
      return fail(toQueryError(error, "recordCaseReassignmentEvent", "case_assignments"));
    }

    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordCaseReassignmentEvent", "case_assignments"));
  }
}


export type CaseResolutionChargeInput = {
  chargeText: string;
  caseViolationId?: number | null;
  violationId?: number | null;
};

export type CaseResolutionApprovalActionInput = CaseResolutionChargeInput & {
  decisionCode: "FOR_FILING" | "DISMISSAL";
  sourceResolutionChargeActionId?: number | null;
};

export type CaseResolutionActionRecord = {
  id: number;
  case_resolution_id: number;
  case_id: number;
  case_violation_id: number | null;
  violation_id: number | null;
  charge_text: string;
  action_code: "FOR_FILING" | "DISMISSAL";
  display_order: number | null;
  remarks: string | null;
};

export type CaseResolutionWithActionsRecord = {
  id: number;
  case_id: number;
  case_event_id: number;
  recommendation_code: string;
  date_resolved: string;
  time_resolved: string | null;
  remarks: string | null;
  created_at: string;
  charge_actions: CaseResolutionActionRecord[];
};

export async function getCaseResolutionsWithActions(
  caseId: number,
): Promise<SupabaseQueryResult<CaseResolutionWithActionsRecord[]>> {
  return runSupabaseQuery("getCaseResolutionsWithActions", "case_resolutions" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    const resolutionsResult = await supabase
      .from("case_resolutions" as never)
      .select("*" as never)
      .eq("case_id" as never, caseId)
      .eq("is_voided" as never, false)
      .order("date_resolved" as never, { ascending: false, nullsFirst: false })
      .order("created_at" as never, { ascending: false }) as unknown as { data: Omit<CaseResolutionWithActionsRecord, "charge_actions">[] | null; error: unknown };

    if (resolutionsResult.error || !resolutionsResult.data?.length) {
      return { data: [], error: resolutionsResult.error };
    }

    const activeApprovalsResult = await supabase
      .from("case_resolution_approvals" as never)
      .select("case_resolution_id" as never)
      .eq("case_id" as never, caseId)
      .eq("is_voided" as never, false) as unknown as { data: { case_resolution_id: number | null }[] | null; error: unknown };

    if (activeApprovalsResult.error) {
      return { data: [], error: activeApprovalsResult.error };
    }

    const approvedResolutionIds = new Set((activeApprovalsResult.data ?? [])
      .map((approval) => approval.case_resolution_id)
      .filter((id): id is number => id !== null));
    const selectableResolutions = resolutionsResult.data.filter((resolution) => !approvedResolutionIds.has(resolution.id));

    if (selectableResolutions.length === 0) {
      return { data: [], error: null };
    }

    const resolutionIds = selectableResolutions.map((resolution) => resolution.id);
    const actionsResult = await supabase
      .from("case_resolution_charge_actions" as never)
      .select("*" as never)
      .in("case_resolution_id" as never, resolutionIds)
      .order("action_code" as never, { ascending: true })
      .order("display_order" as never, { ascending: true }) as unknown as { data: CaseResolutionActionRecord[] | null; error: unknown };

    if (actionsResult.error) {
      return { data: [], error: actionsResult.error };
    }

    const actionsByResolutionId = new Map<number, CaseResolutionActionRecord[]>();
    for (const action of actionsResult.data ?? []) {
      const currentActions = actionsByResolutionId.get(action.case_resolution_id) ?? [];
      currentActions.push(action);
      actionsByResolutionId.set(action.case_resolution_id, currentActions);
    }

    return {
      data: selectableResolutions.map((resolution) => ({
        ...resolution,
        charge_actions: actionsByResolutionId.get(resolution.id) ?? [],
      })),
      error: null,
    };
  }, []);
}

export interface RecordCaseResolvedEventInput {
  caseId: number;
  recommendationCode: "CASE_FOR_FILING" | "CASE_DISMISSAL" | "MIXED_RESULT";
  dateResolved: string;
  timeResolved?: string | null;
  remarks?: string | null;
  chargesForFiling?: CaseResolutionChargeInput[];
  chargesForDismissal?: CaseResolutionChargeInput[];
}

function chargesToRpcPayload(charges: CaseResolutionChargeInput[] | undefined) {
  return (charges ?? [])
    .map((charge) => ({
      charge_text: charge.chargeText.trim(),
      case_violation_id: charge.caseViolationId ?? null,
      violation_id: charge.violationId ?? null,
    }))
    .filter((charge) => charge.charge_text);
}

function approvalActionsToRpcPayload(actions: CaseResolutionApprovalActionInput[] | undefined) {
  return (actions ?? [])
    .map((action) => ({
      charge_text: action.chargeText.trim(),
      case_violation_id: action.caseViolationId ?? null,
      violation_id: action.violationId ?? null,
      source_resolution_charge_action_id: action.sourceResolutionChargeActionId ?? null,
      decision_code: action.decisionCode,
    }))
    .filter((action) => action.charge_text && (action.decision_code === "FOR_FILING" || action.decision_code === "DISMISSAL"));
}

export async function recordCaseResolvedEvent(
  input: RecordCaseResolvedEventInput,
): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) {
    return fail({
      message: "Supabase is not configured.",
      table: "case_resolutions" as RelationName,
      operation: "recordCaseResolvedEvent",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user available."),
          "recordCaseResolvedEvent",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_case_resolved_event" as never, {
      p_case_id: input.caseId,
      p_recommendation_code: input.recommendationCode,
      p_date_resolved: input.dateResolved,
      p_time_resolved: input.timeResolved?.trim() || null,
      p_remarks: input.remarks?.trim() || null,
      p_charges_for_filing: chargesToRpcPayload(input.chargesForFiling),
      p_charges_for_dismissal: chargesToRpcPayload(input.chargesForDismissal),
      p_user_id: currentUserQuery.data.id,
    } as never);

    if (error) {
      return fail(toQueryError(error, "recordCaseResolvedEvent", "case_resolutions" as RelationName));
    }

    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordCaseResolvedEvent", "case_resolutions" as RelationName));
  }
}

export interface RecordCaseDecisionApprovedEventInput {
  caseId: number;
  caseResolutionId: number;
  approvedByProsecutorId: number;
  dateApproved: string;
  timeApproved?: string | null;
  approvalActions: CaseResolutionApprovalActionInput[];
  remarks?: string | null;
}

export async function recordCaseDecisionApprovedEvent(
  input: RecordCaseDecisionApprovedEventInput,
): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) {
    return fail({ message: "Supabase is not configured.", table: "case_resolution_approvals" as RelationName, operation: "recordCaseDecisionApprovedEvent" });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "recordCaseDecisionApprovedEvent", "users"));
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_case_decision_approved_event" as never, {
      p_case_id: input.caseId,
      p_case_resolution_id: input.caseResolutionId,
      p_approved_by_prosecutor_id: input.approvedByProsecutorId,
      p_date_approved: input.dateApproved,
      p_time_approved: input.timeApproved?.trim() || null,
      p_approval_actions: approvalActionsToRpcPayload(input.approvalActions),
      p_remarks: input.remarks?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);

    if (error) {
      return fail(toQueryError(error, "recordCaseDecisionApprovedEvent", "case_resolution_approvals" as RelationName));
    }

    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordCaseDecisionApprovedEvent", "case_resolution_approvals" as RelationName));
  }
}



export type CourtReferenceRecord = Pick<TableRow<"courts">, "id" | "code" | "name" | "court_type"> & { is_active?: boolean | null };

export async function getCourts(limit = 500): Promise<SupabaseQueryResult<CourtReferenceRecord[]>> {
  return runSupabaseQuery("getCourts", "courts" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    const activeQuery = await supabase
      .from("courts" as never)
      .select("id, code, name, court_type, is_active" as never)
      .eq("is_active" as never, true)
      .order("name" as never, { ascending: true })
      .limit(limit) as unknown as { data: CourtReferenceRecord[] | null; error: SupabaseErrorLike | null };

    if (!activeQuery.error) return activeQuery;

    const message = [activeQuery.error.message, activeQuery.error.details, activeQuery.error.hint].filter(Boolean).join(" ").toLowerCase();
    if (!message.includes("is_active")) return activeQuery;

    return await supabase
      .from("courts" as never)
      .select("id, code, name, court_type" as never)
      .order("name" as never, { ascending: true })
      .limit(limit) as unknown as Promise<{ data: CourtReferenceRecord[] | null; error: unknown }>;
  }, []);
}

export type CourtFilingDecisionRecord = {
  id: number;
  approval_id: number;
  case_resolution_id: number | null;
  charge_text: string;
  decision_code: "FOR_FILING";
  date_approved: string;
};

export async function getAvailableCourtFilingDecisions(caseId: number): Promise<SupabaseQueryResult<CourtFilingDecisionRecord[]>> {
  return runSupabaseQuery("getAvailableCourtFilingDecisions", "case_resolution_approval_actions" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    const result = await supabase
      .from("case_resolution_approval_actions" as never)
      .select("id, approval_id, case_id, charge_text, decision_code, case_resolution_approvals!inner(id, case_resolution_id, date_approved, is_voided, case_resolutions!inner(id, is_voided)), case_court_filings(id, is_voided)" as never)
      .eq("case_id" as never, caseId)
      .eq("decision_code" as never, "FOR_FILING")
      .eq("case_resolution_approvals.is_voided" as never, false)
      .eq("case_resolution_approvals.case_resolutions.is_voided" as never, false) as unknown as { data: any[] | null; error: unknown };

    if (result.error) return { data: [], error: result.error };

    const data = (result.data ?? [])
      .filter((row) => !(row.case_court_filings ?? []).some((filing: { is_voided?: boolean | null }) => filing.is_voided === false))
      .map((row) => ({
        id: Number(row.id),
        approval_id: Number(row.approval_id),
        case_resolution_id: row.case_resolution_approvals?.case_resolution_id ?? null,
        charge_text: row.charge_text,
        decision_code: "FOR_FILING" as const,
        date_approved: row.case_resolution_approvals?.date_approved ?? "",
      }));

    return { data, error: null };
  }, []);
}

export interface RecordCourtFilingEventInput {
  caseId: number;
  caseResolutionApprovalActionId: number;
  courtId?: number | null;
  courtName: string;
  courtBranch?: string | null;
  chargeFiled: string;
  dateFiled: string;
  timeFiled?: string | null;
  informationCount?: number | null;
  criminalCaseNo?: string | null;
  remarks?: string | null;
}

export async function recordCourtFilingEvent(input: RecordCourtFilingEventInput): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) return fail({ message: "Supabase is not configured.", table: "case_court_filings" as RelationName, operation: "recordCourtFilingEvent" });
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "recordCourtFilingEvent", "users"));
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_court_filing_event" as never, {
      p_case_id: input.caseId,
      p_case_resolution_approval_action_id: input.caseResolutionApprovalActionId,
      p_court_id: input.courtId ?? null,
      p_court_name: input.courtName.trim(),
      p_court_branch: input.courtBranch?.trim() || null,
      p_charge_filed: input.chargeFiled.trim(),
      p_date_filed: input.dateFiled,
      p_time_filed: input.timeFiled?.trim() || null,
      p_information_count: input.informationCount ?? null,
      p_criminal_case_no: input.criminalCaseNo?.trim() || null,
      p_remarks: input.remarks?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);
    if (error) return fail(toQueryError(error, "recordCourtFilingEvent", "case_court_filings" as RelationName));
    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordCourtFilingEvent", "case_court_filings" as RelationName));
  }
}


export type MotionDetailInput = { detail: string; value: string };

export interface RecordMotionReceivedEventInput {
  caseId: number;
  motionTitle: string;
  filedByCode: "COMPLAINANT" | "RESPONDENT";
  dateFiled: string;
  timeFiled?: string | null;
  details?: MotionDetailInput[];
  assignedProsecutorId?: number | null;
  remarks?: string | null;
}

export async function recordMotionReceivedEvent(input: RecordMotionReceivedEventInput): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) return fail({ message: "Supabase is not configured.", table: "case_motions" as RelationName, operation: "recordMotionReceivedEvent" });
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "recordMotionReceivedEvent", "users"));
    const normalizedDetails = (input.details ?? [])
      .map((row) => ({ detail: row.detail.trim(), value: row.value.trim() }))
      .filter((row) => row.detail || row.value);
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_motion_received_event" as never, {
      p_case_id: input.caseId,
      p_motion_title: input.motionTitle.trim(),
      p_filed_by_code: input.filedByCode,
      p_date_filed: input.dateFiled,
      p_time_filed: input.timeFiled?.trim() || null,
      p_details_jsonb: normalizedDetails,
      p_remarks: input.remarks?.trim() || null,
      p_assigned_prosecutor_id: input.assignedProsecutorId ?? null,
      p_user_id: currentUserQuery.data.id,
    } as never);
    if (error) return fail(toQueryError(error, "recordMotionReceivedEvent", "case_motions" as RelationName));
    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordMotionReceivedEvent", "case_motions" as RelationName));
  }
}


export type MotionResolutionRecommendationRecord = {
  id: number;
  code: string;
  display_label: string;
  sort_order: number | null;
  is_active: boolean | null;
};

export async function getMotionResolutionRecommendations(): Promise<SupabaseQueryResult<MotionResolutionRecommendationRecord[]>> {
  return runSupabaseQuery("getMotionResolutionRecommendations", "motion_resolution_recommendations" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase
      .from("motion_resolution_recommendations" as never)
      .select("id, code, display_label, sort_order, is_active")
      .eq("is_active" as never, true)
      .order("sort_order" as never, { ascending: true })
      .order("display_label" as never, { ascending: true })) as unknown as { data: MotionResolutionRecommendationRecord[] | null; error: unknown };
  }, []);
}

export async function addMotionResolutionRecommendation(input: { displayLabel: string; code?: string | null }): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) return fail({ message: "Supabase is not configured.", table: "motion_resolution_recommendations" as RelationName, operation: "addMotionResolutionRecommendation" });
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "addMotionResolutionRecommendation", "users"));
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("add_motion_resolution_recommendation" as never, {
      p_display_label: input.displayLabel.trim(),
      p_code: input.code?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);
    if (error) return fail(toQueryError(error, "addMotionResolutionRecommendation", "motion_resolution_recommendations" as RelationName));
    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "addMotionResolutionRecommendation", "motion_resolution_recommendations" as RelationName));
  }
}

export interface RecordMotionResolvedEventInput {
  caseId: number;
  caseMotionId: number;
  recommendationId: number;
  dateResolved: string;
  timeResolved?: string | null;
  remarks?: string | null;
}

export async function recordMotionResolvedEvent(input: RecordMotionResolvedEventInput): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) return fail({ message: "Supabase is not configured.", table: "case_motion_resolutions" as RelationName, operation: "recordMotionResolvedEvent" });
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "recordMotionResolvedEvent", "users"));
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_motion_resolved_event" as never, {
      p_case_id: input.caseId,
      p_case_motion_id: input.caseMotionId,
      p_recommendation_id: input.recommendationId,
      p_date_resolved: input.dateResolved,
      p_time_resolved: input.timeResolved?.trim() || null,
      p_remarks: input.remarks?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);
    if (error) return fail(toQueryError(error, "recordMotionResolvedEvent", "case_motion_resolutions" as RelationName));
    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordMotionResolvedEvent", "case_motion_resolutions" as RelationName));
  }
}


export type MotionResolutionApprovalCandidateRecord = {
  id: number;
  case_id: number;
  case_motion_id: number;
  recommendation_id: number;
  recommendation_code: string | null;
  recommendation_label: string | null;
  date_resolved: string | null;
  time_resolved: string | null;
  motion_title: string | null;
  filed_by: string | null;
  filed_by_code: string | null;
  date_filed: string | null;
  assigned_prosecutor_id: number | null;
  assigned_prosecutor_name: string | null;
  active_motion_decision_approval_id: number | null;
};

export async function getMotionResolutionApprovalCandidates(caseId: number): Promise<SupabaseQueryResult<MotionResolutionApprovalCandidateRecord[]>> {
  return runSupabaseQuery("getMotionResolutionApprovalCandidates", "v_case_motion_resolutions_detail" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase
      .from("v_case_motion_resolutions_detail" as never)
      .select("id, case_id, case_motion_id, recommendation_id, recommendation_code, recommendation_label, date_resolved, time_resolved, motion_title, filed_by, filed_by_code, date_filed, assigned_prosecutor_id, assigned_prosecutor_name, active_motion_decision_approval_id")
      .eq("case_id" as never, caseId)
      .eq("is_voided" as never, false)
      .order("date_resolved" as never, { ascending: false, nullsFirst: false })
      .order("id" as never, { ascending: false })) as unknown as { data: MotionResolutionApprovalCandidateRecord[] | null; error: unknown };
  }, []);
}

export type CaseStatusOptionRecord = { id: number; code: string; display_label: string; sort_order: number | null; is_active: boolean | null };
export type CaseStageOptionRecord = { id: number; code: string; display_label: string; sort_order: number | null; is_active: boolean | null };

export async function getMotionDecisionCaseStatusOptions(): Promise<SupabaseQueryResult<CaseStatusOptionRecord[]>> {
  return runSupabaseQuery("getMotionDecisionCaseStatusOptions", "case_statuses" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("case_statuses" as never).select("id, code, display_label, sort_order, is_active").eq("is_active" as never, true).in("code" as never, ["PENDING", "FILED", "DISMISSED", "MIXED_RESULT"]).order("sort_order" as never, { ascending: true })) as unknown as { data: CaseStatusOptionRecord[] | null; error: unknown };
  }, []);
}

export async function getMotionDecisionCaseStageOptions(): Promise<SupabaseQueryResult<CaseStageOptionRecord[]>> {
  return runSupabaseQuery("getMotionDecisionCaseStageOptions", "case_stages" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("case_stages" as never).select("id, code, display_label, sort_order, is_active").eq("is_active" as never, true).order("sort_order" as never, { ascending: true })) as unknown as { data: CaseStageOptionRecord[] | null; error: unknown };
  }, []);
}

export interface RecordMotionDecisionApprovedEventInput {
  caseId: number;
  motionResolutionId: number;
  approvedDecisionRecommendationId: number;
  approvedByProsecutorId: number;
  dateApproved: string;
  timeApproved?: string | null;
  updateCaseStatus: boolean;
  selectedCaseStatusId?: number | null;
  selectedCaseStageId?: number | null;
  remarks?: string | null;
}

export async function recordMotionDecisionApprovedEvent(input: RecordMotionDecisionApprovedEventInput): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) return fail({ message: "Supabase is not configured.", table: "case_motion_resolution_approvals" as RelationName, operation: "recordMotionDecisionApprovedEvent" });
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) return fail(toQueryError(currentUserQuery.error ?? new Error("No active user available."), "recordMotionDecisionApprovedEvent", "users"));
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("record_motion_decision_approved_event" as never, {
      p_case_id: input.caseId,
      p_case_motion_resolution_id: input.motionResolutionId,
      p_approved_decision_recommendation_id: input.approvedDecisionRecommendationId,
      p_approved_by_prosecutor_id: input.approvedByProsecutorId,
      p_date_approved: input.dateApproved,
      p_time_approved: input.timeApproved?.trim() || null,
      p_update_case_status: input.updateCaseStatus,
      p_selected_case_status_id: input.updateCaseStatus ? input.selectedCaseStatusId ?? null : null,
      p_selected_case_stage_id: input.updateCaseStatus ? input.selectedCaseStageId ?? null : null,
      p_remarks: input.remarks?.trim() || null,
      p_user_id: currentUserQuery.data.id,
    } as never);
    if (error) return fail(toQueryError(error, "recordMotionDecisionApprovedEvent", "case_motion_resolution_approvals" as RelationName));
    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "recordMotionDecisionApprovedEvent", "case_motion_resolution_approvals" as RelationName));
  }
}

export interface CreateCaseEventInput {
  caseId: number;
  eventTypeCode: string;
  eventDate: string;
  title: string;
  description?: string;
  detailsJson?: Json | null;
}

export async function createCaseEvent(
  input: CreateCaseEventInput,
): Promise<SupabaseQueryResult<number>> {
  const environment = getSupabaseEnvironmentStatus();
  if (!environment.isConfigured) {
    return fail({
      message: "Supabase is not configured.",
      table: "cases",
      operation: "createCaseEvent",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user available."),
          "createCaseEvent",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("create_case_event" as never, {
      p_case_id: input.caseId,
      p_event_type_code: input.eventTypeCode,
      p_event_date: input.eventDate,
      p_title: input.title,
      p_description: input.description?.trim() || null,
      p_details_jsonb: input.detailsJson ?? {},
      p_user_id: currentUserQuery.data.id,
    } as never);

    if (error) {
      return fail(toQueryError(error, "createCaseEvent", "cases"));
    }

    return ok(Number(data ?? 0));
  } catch (error) {
    return fail(toQueryError(error, "createCaseEvent", "cases"));
  }
}

export interface EditCaseEventInput {
  caseEventId: number;
  eventDate: string;
  title: string;
  description?: string | null;
  detailsJsonb?: Json | null;
  editReason: string;
}

export async function editCaseEvent(
  input: EditCaseEventInput,
): Promise<SupabaseQueryResult<number>> {
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user."),
          "editCaseEvent",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("edit_case_event" as never, {
      p_case_event_id: input.caseEventId,
      p_event_date: input.eventDate,
      p_title: input.title,
      p_description: input.description ?? null,
      p_details_jsonb: input.detailsJsonb ?? null,
      p_edit_reason: input.editReason,
      p_user_id: currentUserQuery.data.id,
    } as never);

    if (error) {
      return fail(toQueryError(error, "editCaseEvent", "cases"));
    }

    return ok(Number(data));
  } catch (error) {
    return fail(toQueryError(error, "editCaseEvent", "cases"));
  }
}

export async function voidCaseEvent(
  caseEventId: number,
  reason: string,
): Promise<SupabaseQueryResult<boolean>> {
  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();
    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active user available."),
          "voidCaseEvent",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { error } = await supabase.rpc("void_case_event" as never, {
      p_case_event_id: caseEventId,
      p_void_reason: reason,
      p_voided_by_user_id: currentUserQuery.data.id,
    } as never);
    if (error) {
      return fail(toQueryError(error, "voidCaseEvent", "cases"));
    }
    return ok(true);
  } catch (error) {
    return fail(toQueryError(error, "voidCaseEvent", "cases"));
  }
}

export async function getViolations(limit?: number): Promise<SupabaseQueryResult<TableRow<"violations">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);
  return runSupabaseQuery("getViolations", "v_ref_violations" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_violations" as never).select("*").order("title" as never, { ascending: true }).limit(safeLimit)) as unknown as { data: TableRow<"violations">[] | null; error: unknown };
  }, []);
}

export async function getRecentAuditLogs(limit?: number): Promise<SupabaseQueryResult<TableRow<"audit_logs">[]>> {
  const safeLimit = normalizeLimit(limit, 20, 100);
  return runSupabaseQuery("getRecentAuditLogs", "v_recent_audit_logs" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_recent_audit_logs" as never).select("*").order("created_at" as never, { ascending: false }).limit(safeLimit)) as unknown as { data: TableRow<"audit_logs">[] | null; error: unknown };
  }, []);
}

export async function getDashboardStats(): Promise<
  SupabaseQueryResult<{
    totalCases: number;
    byStatusId: Record<string, number>;
  }>
> {
  return runSupabaseQuery(
    "getDashboardStats",
    "v_docket_quickdetails" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = (await supabase
        .from("v_docket_quickdetails" as never)
        .select("id,current_case_status_code,current_case_stage_code")) as unknown as {
        data: Pick<DocketQuickDetailsRecord, "id" | "current_case_status_code" | "current_case_stage_code">[] | null;
        error: unknown;
      };

      if (error || !data) {
        return { data: null, error };
      }

      const byStatusId = data.reduce<Record<string, number>>((totals, row) => {
        const statusKey = row.current_case_status_code ?? "UNKNOWN";
        totals[statusKey] = (totals[statusKey] ?? 0) + 1;
        return totals;
      }, {});
      const byStageId = data.reduce<Record<string, number>>((totals, row) => {
        const stageKey = row.current_case_stage_code ?? "UNKNOWN";
        totals[stageKey] = (totals[stageKey] ?? 0) + 1;
        return totals;
      }, {});

      return {
        data: {
          totalCases: data.length,
          byStatusId,
          byStageId,
        },
        error: null,
      };
    },
    {
      totalCases: 0,
      byStatusId: {},
      byStageId: {},
    },
  );
}

async function searchClearanceRpc(
  params: ClearanceSearchParams,
  operation:
    | "searchClearanceRecords"
    | "searchClearancePossibleMatches"
    | "searchClearancePhoneticMatches",
  rpcName:
    | "search_clearance_records"
    | "search_clearance_possible_matches"
    | "search_clearance_phonetic_matches",
): Promise<SupabaseQueryResult<ClearanceSearchResult[]>> {
  const safeQuery = params.query.trim();
  const searchType = params.searchType ?? "all";
  const safeLimit = normalizeLimit(params.limit, 50, 100);

  if (!safeQuery) {
    return ok([]);
  }

  return runSupabaseQuery(
    operation,
    "v_docket_shell" as RelationName,
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = await supabase.rpc(
        rpcName as never,
        {
          p_query: safeQuery,
          p_search_type: searchType,
          p_limit: safeLimit,
        } as never,
      );

      if (error || !Array.isArray(data)) {
        return { data: [], error };
      }

      const results = (data as ClearanceRpcRow[]).map(normalizeClearanceSearchRow);
      const caseIds = Array.from(new Set(results.map((result) => result.caseId)));

      if (caseIds.length === 0) {
        return { data: results, error: null };
      }

      const [caseSummaries, participantAttributes] = await Promise.all([
        supabase
          .from("v_docket_case_violation_classification" as never)
          .select("id,violations")
          .in("id" as never, caseIds) as unknown as Promise<{
            data: Pick<DocketCaseLabelsRecord, "id" | "violations">[] | null;
            error: unknown;
          }>,
        supabase
          .from("v_clearance_participant_attributes" as never)
          .select("case_id, person_id, age_text, age_years")
          .in("case_id" as never, caseIds) as unknown as Promise<{
            data: { case_id: number; person_id: number; age_text: string | null; age_years: number | null }[] | null;
            error: unknown;
          }>,
      ]);

      if (caseSummaries.error) {
        return { data: null, error: caseSummaries.error };
      }

      if (participantAttributes.error) {
        return { data: null, error: participantAttributes.error };
      }

      const violationsByCaseId = new Map(
        (caseSummaries.data ?? []).map((row) => [row.id, row.violations ?? "—"]),
      );
      const ageByCasePersonKey = new Map<string, string>();

      for (const row of participantAttributes.data ?? []) {
        const age = row.age_text ?? row.age_years?.toString();

        if (age) {
          ageByCasePersonKey.set(`${row.case_id}-${row.person_id}`, age);
        }
      }

      return {
        data: results.map((result) => ({
          ...result,
          age: result.personId ? ageByCasePersonKey.get(`${result.caseId}-${result.personId}`) ?? result.age : result.age,
          violations: violationsByCaseId.get(result.caseId) ?? result.violations,
        })),
        error: null,
      };
    },
    [],
  );
}

export async function searchClearanceRecords(
  params: ClearanceSearchParams,
): Promise<SupabaseQueryResult<ClearanceSearchResult[]>> {
  return searchClearanceRpc(
    params,
    "searchClearanceRecords",
    "search_clearance_records",
  );
}

export async function searchClearancePossibleMatches(
  params: ClearanceSearchParams,
): Promise<SupabaseQueryResult<ClearanceSearchResult[]>> {
  return searchClearanceRpc(
    params,
    "searchClearancePossibleMatches",
    "search_clearance_possible_matches",
  );
}

export async function searchClearancePhoneticMatches(
  params: ClearanceSearchParams,
): Promise<SupabaseQueryResult<ClearanceSearchResult[]>> {
  return searchClearanceRpc(
    params,
    "searchClearancePhoneticMatches",
    "search_clearance_phonetic_matches",
  );
}

export async function getCaseClassifications(): Promise<SupabaseQueryResult<TableRow<"case_classifications">[]>> {
  return runSupabaseQuery("getCaseClassifications", "v_ref_case_classifications" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_case_classifications" as never).select("*").order("display_label" as never, { ascending: true })) as unknown as { data: TableRow<"case_classifications">[] | null; error: unknown };
  }, []);
}

export async function getParticipantRoles(): Promise<SupabaseQueryResult<TableRow<"participant_roles">[]>> {
  return runSupabaseQuery("getParticipantRoles", "v_ref_participant_roles" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_participant_roles" as never).select("*").order("display_label" as never, { ascending: true })) as unknown as { data: TableRow<"participant_roles">[] | null; error: unknown };
  }, []);
}


export type CaseEventTypeReference = {
  id: number;
  code: string;
  display_label: string;
  category: string;
  description: string | null;
  sort_order: number;
  is_active: boolean;
};

export async function getCaseEventTypes(): Promise<SupabaseQueryResult<CaseEventTypeReference[]>> {
  return runSupabaseQuery("getCaseEventTypes", "v_ref_case_event_types" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase
      .from("v_ref_case_event_types" as never)
      .select("id,code,display_label,category,description,sort_order,is_active")
      .order("sort_order" as never, { ascending: true })
      .order("display_label" as never, { ascending: true })) as unknown as { data: CaseEventTypeReference[] | null; error: unknown };
  }, []);
}

export async function getAddressTypes(): Promise<SupabaseQueryResult<TableRow<"address_types">[]>> {
  return runSupabaseQuery("getAddressTypes", "v_ref_address_types" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_address_types" as never).select("*").order("display_label" as never, { ascending: true })) as unknown as { data: TableRow<"address_types">[] | null; error: unknown };
  }, []);
}

export type DatabaseUserSummary = Pick<TableRow<"users">, "email" | "id">;

async function getCurrentDatabaseUserRecord() {
  const supabase = await getSupabaseBrowserClient();
  const { data: authData } = await supabase.auth.getUser();
  const authEmail = authData.user?.email;

  if (authEmail) {
    const authenticatedUserQuery = (await supabase
      .from("v_ref_users" as never)
      .select("id,email")
      .eq("email" as never, authEmail)
      .maybeSingle()) as unknown as {
      data: DatabaseUserSummary | null;
      error: unknown;
    };

    if (authenticatedUserQuery.error || authenticatedUserQuery.data) {
      return authenticatedUserQuery;
    }
  }

  return (await supabase
    .from("v_ref_users" as never)
    .select("id,email")
    .order("id" as never, { ascending: true })
    .limit(1)
    .maybeSingle()) as unknown as {
    data: DatabaseUserSummary | null;
    error: unknown;
  };
}

export async function getCurrentDatabaseUser(): Promise<SupabaseQueryResult<DatabaseUserSummary | null>> {
  return runSupabaseQuery("getCurrentDatabaseUser", "v_ref_users" as RelationName, async () => getCurrentDatabaseUserRecord(), null);
}

export async function getActiveUsers(): Promise<SupabaseQueryResult<DatabaseUserSummary[]>> {
  return runSupabaseQuery("getActiveUsers", "v_ref_users" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_users" as never).select("id,email").order("email" as never, { ascending: true })) as unknown as { data: DatabaseUserSummary[] | null; error: unknown };
  }, []);
}

async function getNextDocketNumberValue(
  docketTypeId: number,
  docketYear: number,
) {
  const supabase = await getSupabaseBrowserClient();
  const counterQuery = (await supabase
    .from("v_docket_sequence_lookup" as never)
    .select("next_number")
    .eq("docket_type_id" as never, docketTypeId)
    .eq("docket_year" as never, docketYear)
    .maybeSingle()) as unknown as {
    data: { next_number: number } | null;
    error: unknown;
  };

  if (counterQuery.error || counterQuery.data) {
    return {
      data: counterQuery.data?.next_number ?? null,
      error: counterQuery.error,
    };
  }

  const latestCaseQuery = (await supabase
    .from("v_docket_shell" as never)
    .select("docket_number")
    .eq("docket_type_id" as never, docketTypeId)
    .eq("docket_year" as never, docketYear)
    .order("docket_number" as never, { ascending: false })
    .limit(1)
    .maybeSingle()) as unknown as {
    data: Pick<DocketShellRecord, "docket_number"> | null;
    error: unknown;
  };

  return {
    data: latestCaseQuery.data?.docket_number
      ? latestCaseQuery.data.docket_number + 1
      : 1,
    error: latestCaseQuery.error,
  };
}

export async function getNextDocketNumber(docketTypeId: number, docketYear: number): Promise<SupabaseQueryResult<number>> {
  if (!Number.isFinite(docketTypeId) || !Number.isFinite(docketYear)) return ok(1);
  return runSupabaseQuery("getNextDocketNumber", "v_docket_sequence_lookup" as RelationName, async () => getNextDocketNumberValue(docketTypeId, docketYear), 1);
}

export async function searchAddressSuggestions(query: string, limit?: number): Promise<SupabaseQueryResult<TableRow<"addresses">[]>> {
  const safeLimit = normalizeLimit(limit, 8, 25);
  const safeQuery = escapeIlikeTerm(query);
  if (!safeQuery) return ok([]);
  return runSupabaseQuery("searchAddressSuggestions", "v_address_suggestions" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_address_suggestions" as never).select("*").or(`line1.ilike.%${safeQuery}%,line2.ilike.%${safeQuery}%,barangay.ilike.%${safeQuery}%,city.ilike.%${safeQuery}%,province.ilike.%${safeQuery}%,region.ilike.%${safeQuery}%`).order("created_at" as never, { ascending: false }).limit(safeLimit)) as unknown as { data: TableRow<"addresses">[] | null; error: unknown };
  }, []);
}

export async function searchViolationSuggestions(query: string, limit?: number): Promise<SupabaseQueryResult<TableRow<"violations">[]>> {
  const safeLimit = normalizeLimit(limit, 8, 25);
  const safeQuery = escapeIlikeTerm(query);
  if (!safeQuery) return getViolations(safeLimit);
  return runSupabaseQuery("searchViolationSuggestions", "v_ref_violations" as RelationName, async () => {
    const supabase = await getSupabaseBrowserClient();
    return (await supabase.from("v_ref_violations" as never).select("*").or(`title.ilike.%${safeQuery}%,short_label.ilike.%${safeQuery}%,law_reference.ilike.%${safeQuery}%,reference_code.ilike.%${safeQuery}%,description.ilike.%${safeQuery}%`).order("title" as never, { ascending: true }).limit(safeLimit)) as unknown as { data: TableRow<"violations">[] | null; error: unknown };
  }, []);
}

export interface NewDocketParticipantInput {
  participantKind?: "PERSON" | "ORGANIZATION";
  existingPersonId?: number | null;
  existingOrganizationId?: number | null;
  newPerson?: {
    firstName?: string | null;
    middleName?: string | null;
    lastName?: string | null;
    suffix?: string | null;
    noMiddleName?: boolean;
    gender?: string | null;
    birthDate?: string | null;
    notes?: string | null;
    personDescriptor?: string | null;
  } | null;
  contactInformations?: { id: string; contactType?: "PHONE" | "EMAIL" | "OTHER" | string; contactValue?: string | null; label?: string | null; isPrimary?: boolean | null; remarks?: string | null }[];
  newOrganization?: {
    organizationName?: string | null;
    contactPerson?: string | null;
    contactNumber?: string | null;
    email?: string | null;
    detailsJsonb?: Json | null;
  } | null;
  aliases?: { id?: string; aliasName?: string | null }[];
  addresses?: (NewDocketAddressInput & { id: string; suggestionQuery: string; selectedExistingLabel?: string | null; existingRelation?: boolean })[];
  organizationName?: string | null;
  contactPerson?: string | null;
  contactNumber?: string | null;
  email?: string | null;
  firstName?: string | null;
  middleName?: string | null;
  lastName?: string | null;
  suffix?: string | null;
  noMiddleName?: boolean;
  gender?: string | null;
  age?: string | null;
  birthDate?: string | null;
  roleId: number;
  participantOrder?: number | null;
  remarks?: string | null;
  sourceDetail?: string | null;
  notes?: string | null;
  personDescriptor?: string | null;
  attributes?: {
    ageText?: string | null;
    ageYears?: number | null;
    genderText?: string | null;
    genderNormalized?: string | null;
    minorText?: string | null;
    isMinorAtCase?: boolean | null;
    seniorText?: string | null;
    isSeniorAtCase?: boolean | null;
    pwdText?: string | null;
    isPwdAtCase?: boolean | null;
    notes?: string | null;
  };
}

export interface NewDocketAddressInput {
  existingAddressId?: number | null;
  newAddress?: {
    line1?: string | null;
    line2?: string | null;
    barangay?: string | null;
    city?: string | null;
    province?: string | null;
    region?: string | null;
    zipCode?: string | null;
    country?: string | null;
  } | null;
  addressTypeId: number;
  isPrimary?: boolean | null;
  line1?: string | null;
  line2?: string | null;
  barangay?: string | null;
  city?: string | null;
  province?: string | null;
  region?: string | null;
  zipCode?: string | null;
  country?: string | null;
  remarks?: string | null;
}

export interface NewDocketViolationInput {
  existingViolationId?: number | null;
  violationId?: number | null;
  violationOrder?: number | null;
  rawViolationText?: string | null;
  newViolation?: {
    title: string;
    referenceCode?: string | null;
    shortLabel?: string | null;
    description?: string | null;
    lawReference?: string | null;
  } | null;
}

export interface NewDocketEntryInput {
  docketTypeId: number;
  docketYear: number;
  dateReceived: string;
  initialStatusId: number;
  caseClassificationId?: number | null;
  docketMonthCode?: string | null;
  regionCode?: string | null;
  summaryText?: string | null;
  remarks?: string | null;
  caseReceivedDescription?: string | null;
  isSummaryProcedure?: boolean | null;
  caseAlsoRaffled?: boolean | null;
  assignmentRemarks?: string | null;
  assignedProsecutorId?: number | null;
  participants: NewDocketParticipantInput[];
  placeOfCommission?: NewDocketAddressInput | null;
  placesOfCommission?: NewDocketAddressInput[];
  addresses: NewDocketAddressInput[];
  violations: NewDocketViolationInput[];
  notes?: string | null;
}

export interface NewDocketEntryResult {
  caseId: number;
  docketTypeId: number;
  docketYear: number;
  docketNumber: number;
  docketMonthCode: string | null;
  docketDisplayNumber: string;
  createdPersonCount: number;
  reusedPersonCount: number;
  createdAddressCount: number;
  reusedAddressCount: number;
  createdViolationCount: number;
  reusedViolationCount: number;
  participantCount: number;
  violationCount: number;
}

function cleanString(value: string | null | undefined) {
  const cleaned = value?.trim();
  return cleaned ? cleaned : null;
}

function getDocketMonthCode(dateReceived: string) {
  const date = new Date(`${dateReceived}T00:00:00`);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toLocaleString("en-US", { month: "short" }).toUpperCase();
}

function buildFullName(person: NewDocketParticipantInput) {
  return [
    cleanString(person.firstName),
    cleanString(person.middleName),
    cleanString(person.lastName),
    cleanString(person.suffix),
  ]
    .filter(Boolean)
    .join(" ");
}

function normalizeGenderForAttributes(value: string | null | undefined) {
  const cleaned = cleanString(value);

  if (!cleaned || cleaned.toLowerCase() === "unspecified") {
    return { genderText: null, genderNormalized: "UNKNOWN" };
  }

  const normalized = cleaned.toUpperCase();

  if (["MALE", "FEMALE", "OTHER", "UNKNOWN"].includes(normalized)) {
    return { genderText: cleaned, genderNormalized: normalized };
  }

  return { genderText: cleaned, genderNormalized: "OTHER" };
}

function parseAgeYears(value: string | null | undefined) {
  const cleaned = cleanString(value);

  if (!cleaned) {
    return null;
  }

  const match = cleaned.match(/\d+/);

  if (!match) {
    return null;
  }

  const age = Number.parseInt(match[0], 10);
  return age >= 0 && age <= 150 ? age : null;
}

function ageFlag(ageYears: number | null, minimumAge: number) {
  return ageYears === null ? null : ageYears >= minimumAge;
}

async function advanceDocketCounter(
  docketTypeId: number,
  docketYear: number,
  issuedNumber: number,
) {
  void docketTypeId;
  void docketYear;
  void issuedNumber;
  return new Error(
    "Direct browser mutations are disabled during the frontend read-view refactor.",
  );
}
export async function createNewDocketEntry(input: NewDocketEntryInput): Promise<SupabaseQueryResult<NewDocketEntryResult>> {
  const environment = getSupabaseEnvironmentStatus();

  if (!environment.isConfigured) {
    return fail({
      message: "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable live docket creation.",
      table: "cases",
      operation: "createNewDocketEntry",
    });
  }

  try {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.rpc("create_new_docket_entry" as never, {
      p_payload: input as unknown as Json,
    } as never);

    if (error) {
      return fail(toQueryError(error, "createNewDocketEntry", "cases"));
    }

    return ok(data as unknown as NewDocketEntryResult);
  } catch (error) {
    return fail(toQueryError(error, "createNewDocketEntry", "cases"));
  }
}
