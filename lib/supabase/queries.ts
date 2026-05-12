import {
  getSupabaseBrowserClient,
  getSupabaseEnvironmentStatus,
} from "@/lib/supabase/client";
import type {
  RelationName,
  SupabaseQueryError,
  SupabaseQueryResult,
  TableName,
  TableRow,
  ViewRow,
} from "@/lib/supabase/types";

type SupabaseErrorLike = {
  message?: string;
  code?: string;
  details?: string;
  hint?: string;
};

function isSupabaseErrorLike(error: unknown): error is SupabaseErrorLike {
  return typeof error === "object" && error !== null && "message" in error;
}

function isMissingClearanceSearchFunction(
  error: SupabaseErrorLike,
  operation: string,
) {
  const message = error.message ?? "";
  const details = error.details ?? "";

  return (
    operation === "searchClearanceRecords" &&
    (error.code === "PGRST202" ||
      message.includes("search_clearance_records") ||
      details.includes("search_clearance_records"))
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
        message:
          "Database setup required: the live clearance search SQL function is not installed in Supabase yet. Run the clearance search migration, then refresh this page.",
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
  personId: number;
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
  matchType: "exact" | "alias" | "fuzzy" | "phonetic";
  roleLabel: string;
}

type ClearanceRpcRow = {
  person_id: number;
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
};

function normalizeClearanceSearchRow(
  row: ClearanceRpcRow,
): ClearanceSearchResult {
  const confidence = Math.round(Number(row.confidence_score ?? 0));
  const docketNumber = row.docket_number ?? `Case #${row.case_id}`;
  const caseNumber = row.case_number ?? docketNumber;

  return {
    id: `${row.case_id}-${row.person_id}`,
    personId: row.person_id,
    caseId: row.case_id,
    docketNumber,
    caseNumber,
    violations: row.violations ?? "—",
    respondentName: row.full_name ?? "Unknown person",
    respondentAliases: row.aliases ?? [],
    age: row.age,
    status: row.status ?? "Pending",
    lastUpdated: row.last_updated ?? new Date(0).toISOString(),
    confidenceScore: Math.min(Math.max(confidence, 0), 100),
    matchDetails: row.match_details ?? "Database fuzzy match",
    matchType: row.match_type ?? "fuzzy",
    roleLabel: row.role_label ?? "Participant",
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
    checkedTable: "docket_types";
    rowCount: number;
    checkedAt: string;
  }>
> {
  const checkedAt = new Date().toISOString();

  return runSupabaseQuery(
    "verifySupabaseConnection",
    "docket_types",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = await supabase
        .from("docket_types")
        .select("id")
        .limit(1);

      return {
        data: data
          ? {
              checkedTable: "docket_types" as const,
              rowCount: data.length,
              checkedAt,
            }
          : null,
        error,
      };
    },
    {
      checkedTable: "docket_types",
      rowCount: 0,
      checkedAt,
    },
  );
}

export async function getDocketTypes(): Promise<
  SupabaseQueryResult<TableRow<"docket_types">[]>
> {
  return runSupabaseQuery(
    "getDocketTypes",
    "docket_types",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("docket_types")
        .select("*")
        .order("sort_order", { ascending: true });
    },
    [],
  );
}

export async function getCaseStatuses(): Promise<
  SupabaseQueryResult<TableRow<"case_statuses">[]>
> {
  return runSupabaseQuery(
    "getCaseStatuses",
    "case_statuses",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("case_statuses")
        .select("*")
        .order("sort_order", { ascending: true });
    },
    [],
  );
}

export async function getCases(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"cases">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery(
    "getCases",
    "cases",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("cases")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(safeLimit);
    },
    [],
  );
}

export async function getCasesCompact(
  params: CasesCompactQueryParams = {},
): Promise<SupabaseQueryResult<ViewRow<"v_cases_display">[]>> {
  const { docketType, docketYear, limit } = params;

  return runSupabaseQuery(
    "getCasesCompact",
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      let query = supabase
        .from("v_cases_display")
        .select("*")
        .order("created_at", { ascending: false });

      if (docketType && docketType !== "All") {
        query = query.eq("docket_type_prefix", docketType);
      }

      if (docketYear !== undefined) {
        query = query.eq("docket_year", docketYear);
      }

      if (limit !== undefined) {
        query = query.limit(normalizeLimit(limit, 50, 250));
      }

      return query;
    },
    [],
  );
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
  docket_types: Pick<TableRow<"docket_types">, "name" | "prefix"> | null;
};

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

export type CaseParticipantRecord = TableRow<"case_participants"> & {
  participant_roles: Pick<
    TableRow<"participant_roles">,
    "code" | "display_label"
  > | null;
  persons: CaseParticipantPersonRecord | null;
};

export type CaseAssignmentRecord = TableRow<"case_assignments"> & {
  prosecutors: Pick<TableRow<"prosecutors">, "full_name" | "short_name"> | null;
  staff: Pick<TableRow<"staff">, "full_name" | "short_name"> | null;
};

export type CaseStatusHistoryRecord = TableRow<"case_status_history"> & {
  from_status: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
  to_status: Pick<TableRow<"case_statuses">, "code" | "display_label"> | null;
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
    "persons",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("persons")
        .select(
          `*,
        person_aliases:person_aliases!person_aliases_person_id_fkey (alias_name, alias_type, is_active),
        person_addresses:person_addresses!person_addresses_person_id_fkey (
          id, is_primary, remarks,
          addresses:addresses!person_addresses_address_id_fkey (barangay, city, country, line1, line2, province, region, zip_code)
        )`,
        )
        .eq("id", personId)
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
    "case_participants",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("case_participants")
        .select(
          `*,
        participant_roles:participant_roles!case_participants_role_id_fkey (code, display_label),
        persons:persons!case_participants_person_id_fkey (
          age, birth_date, first_name, full_name, gender, id, is_minor, is_pwd, is_senior, last_name, middle_name, notes, person_descriptor, suffix,
          person_addresses:person_addresses!person_addresses_person_id_fkey (
            id, is_primary, remarks,
            addresses:addresses!person_addresses_address_id_fkey (barangay, city, country, line1, line2, province, region, zip_code)
          )
        )`,
        )
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
): Promise<SupabaseQueryResult<ViewRow<"v_cases_display">[]>> {
  const safeCaseIds = Array.from(
    new Set(caseIds.filter((caseId) => Number.isFinite(caseId))),
  );

  if (safeCaseIds.length === 0) {
    return ok([]);
  }

  return runSupabaseQuery(
    "getCaseCompactsByIds",
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("v_cases_display")
        .select("*")
        .in("id", safeCaseIds)
        .order("date_received", { ascending: false, nullsFirst: false })
        .order("created_at", { ascending: false });
    },
    [],
  );
}

export async function getCaseCompactById(
  caseId: number,
): Promise<SupabaseQueryResult<ViewRow<"v_cases_display"> | null>> {
  return runSupabaseQuery(
    "getCaseCompactById",
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("v_cases_display")
        .select("*")
        .eq("id", caseId)
        .maybeSingle();
    },
    null,
  );
}

export async function getCaseDetailsById(
  caseId: number,
): Promise<SupabaseQueryResult<CaseDetailsRecord | null>> {
  return runSupabaseQuery(
    "getCaseDetailsById",
    "cases",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("cases")
        .select(
          "*, docket_types:docket_types!cases_docket_type_id_fkey (name, prefix)",
        )
        .eq("id", caseId)
        .maybeSingle();

      return query as unknown as Promise<{
        data: CaseDetailsRecord | null;
        error: unknown;
      }>;
    },
    null,
  );
}

export async function getCaseById(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<"cases"> | null>> {
  return runSupabaseQuery(
    "getCaseById",
    "cases",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase.from("cases").select("*").eq("id", caseId).single();
    },
    null,
  );
}

export async function searchCases(
  query: string,
  limit?: number,
): Promise<SupabaseQueryResult<ViewRow<"v_cases_display">[]>> {
  const safeLimit = normalizeLimit(limit, 25, 100);
  const safeQuery = escapeIlikeTerm(query);

  if (!safeQuery) {
    return getCompactCases(safeLimit);
  }

  return runSupabaseQuery(
    "searchCases",
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("v_cases_display")
        .select("*")
        .or(
          `docket_display_number.ilike.%${safeQuery}%,summary_text.ilike.%${safeQuery}%,violations.ilike.%${safeQuery}%,prosecutor_full_name.ilike.%${safeQuery}%,staff_full_name.ilike.%${safeQuery}%`,
        )
        .order("created_at", { ascending: false })
        .limit(safeLimit);
    },
    [],
  );
}

export async function getPersons(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"persons">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery(
    "getPersons",
    "persons",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("persons")
        .select("*")
        .order("full_name", { ascending: true })
        .limit(safeLimit);
    },
    [],
  );
}

export async function searchPersons(
  query: string,
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"persons">[]>> {
  const safeLimit = normalizeLimit(limit, 25, 100);
  const safeQuery = escapeIlikeTerm(query);

  if (!safeQuery) {
    return getPersons(safeLimit);
  }

  return runSupabaseQuery(
    "searchPersons",
    "persons",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("persons")
        .select("*")
        .or(
          `full_name.ilike.%${safeQuery}%,first_name.ilike.%${safeQuery}%,last_name.ilike.%${safeQuery}%`,
        )
        .order("full_name", { ascending: true })
        .limit(safeLimit);
    },
    [],
  );
}

export async function getProsecutors(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"prosecutors">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery(
    "getProsecutors",
    "prosecutors",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("prosecutors")
        .select("*")
        .eq("is_active", true)
        .order("full_name", { ascending: true })
        .limit(safeLimit);
    },
    [],
  );
}

export async function getCaseParticipants(
  caseId: number,
): Promise<SupabaseQueryResult<CaseParticipantRecord[]>> {
  return runSupabaseQuery(
    "getCaseParticipants",
    "case_participants",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("case_participants")
        .select(
          `*,
        participant_roles:participant_roles!case_participants_role_id_fkey (code, display_label),
        persons:persons!case_participants_person_id_fkey (
          age, birth_date, first_name, full_name, gender, id, is_minor, is_pwd, is_senior, last_name, middle_name, notes, person_descriptor, suffix,
          person_addresses:person_addresses!person_addresses_person_id_fkey (
            id, is_primary, remarks,
            addresses:addresses!person_addresses_address_id_fkey (barangay, city, country, line1, line2, province, region, zip_code)
          )
        )`,
        )
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
    "case_participants",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const allParticipants: CaseParticipantRecord[] = [];

      for (let start = 0; start < safeCaseIds.length; start += caseIdChunkSize) {
        const caseIdChunk = safeCaseIds.slice(start, start + caseIdChunkSize);
        const query = supabase
          .from("case_participants")
          .select(
            `*,
        participant_roles:participant_roles!case_participants_role_id_fkey (code, display_label),
        persons:persons!case_participants_person_id_fkey (
          age, birth_date, first_name, full_name, gender, id, is_minor, is_pwd, is_senior, last_name, middle_name, notes, person_descriptor, suffix,
          person_addresses:person_addresses!person_addresses_person_id_fkey (
            id, is_primary, remarks,
            addresses:addresses!person_addresses_address_id_fkey (barangay, city, country, line1, line2, province, region, zip_code)
          )
        )`,
          )
          .in("case_id", caseIdChunk)
          .order("case_id", { ascending: true })
          .order("participant_order", { ascending: true, nullsFirst: false })
          .order("id", { ascending: true });

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

export async function getCaseAssignments(
  caseId: number,
): Promise<SupabaseQueryResult<CaseAssignmentRecord[]>> {
  return runSupabaseQuery(
    "getCaseAssignments",
    "case_assignments",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("case_assignments")
        .select(
          "*, prosecutors:prosecutors!case_assignments_prosecutor_id_fkey (full_name, short_name), staff:staff!case_assignments_staff_id_fkey (full_name, short_name)",
        )
        .eq("case_id", caseId)
        .order("assigned_at", { ascending: false });

      return query as unknown as Promise<{
        data: CaseAssignmentRecord[] | null;
        error: unknown;
      }>;
    },
    [],
  );
}

export async function getCaseStatusHistory(
  caseId: number,
): Promise<SupabaseQueryResult<CaseStatusHistoryRecord[]>> {
  return runSupabaseQuery(
    "getCaseStatusHistory",
    "case_status_history",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("case_status_history")
        .select(
          "*, from_status:case_statuses!case_status_history_from_status_id_fkey (code, display_label), to_status:case_statuses!case_status_history_to_status_id_fkey (code, display_label)",
        )
        .eq("case_id", caseId)
        .order("changed_at", { ascending: false });

      return query as unknown as Promise<{
        data: CaseStatusHistoryRecord[] | null;
        error: unknown;
      }>;
    },
    [],
  );
}

export type CaseCourtRecord = TableRow<"case_courts"> & {
  courts: Pick<TableRow<"courts">, "code" | "court_type" | "name"> | null;
};

export async function getCaseCourtDetails(
  caseId: number,
): Promise<SupabaseQueryResult<CaseCourtRecord[]>> {
  return runSupabaseQuery(
    "getCaseCourtDetails",
    "case_courts",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const query = supabase
        .from("case_courts")
        .select(
          "*, courts:courts!case_courts_court_id_fkey (code, court_type, name)",
        )
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

export async function getCaseMotions(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<"case_motions">[]>> {
  return runSupabaseQuery(
    "getCaseMotions",
    "case_motions",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("case_motions")
        .select("*")
        .eq("case_id", caseId)
        .order("date_received", { ascending: false, nullsFirst: false })
        .order("created_at", { ascending: false });
    },
    [],
  );
}

export async function getCaseAttachmentsIndex(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<"case_attachment_index">[]>> {
  return runSupabaseQuery(
    "getCaseAttachmentsIndex",
    "case_attachment_index",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("case_attachment_index")
        .select("*")
        .eq("case_id", caseId)
        .order("last_seen_at", { ascending: false });
    },
    [],
  );
}

export async function getViolations(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"violations">[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery(
    "getViolations",
    "violations",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("violations")
        .select("*")
        .eq("is_active", true)
        .order("title", { ascending: true })
        .limit(safeLimit);
    },
    [],
  );
}

export async function getRecentAuditLogs(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"audit_logs">[]>> {
  const safeLimit = normalizeLimit(limit, 20, 100);

  return runSupabaseQuery(
    "getRecentAuditLogs",
    "audit_logs",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("audit_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(safeLimit);
    },
    [],
  );
}

export async function getDashboardStats(): Promise<
  SupabaseQueryResult<{
    totalCases: number;
    byStatusId: Record<string, number>;
  }>
> {
  return runSupabaseQuery(
    "getDashboardStats",
    "v_cases_display",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = await supabase
        .from("v_cases_display")
        .select("id,current_status_code");

      if (error || !data) {
        return { data: null, error };
      }

      const byStatusId = data.reduce<Record<string, number>>((totals, row) => {
        const statusKey = row.current_status_code ?? "UNKNOWN";
        totals[statusKey] = (totals[statusKey] ?? 0) + 1;
        return totals;
      }, {});

      return {
        data: {
          totalCases: data.length,
          byStatusId,
        },
        error: null,
      };
    },
    {
      totalCases: 0,
      byStatusId: {},
    },
  );
}

export async function searchClearanceRecords(
  params: ClearanceSearchParams,
): Promise<SupabaseQueryResult<ClearanceSearchResult[]>> {
  const safeQuery = params.query.trim();
  const searchType = params.searchType ?? "all";
  const safeLimit = normalizeLimit(params.limit, 50, 100);

  if (!safeQuery) {
    return ok([]);
  }

  return runSupabaseQuery(
    "searchClearanceRecords",
    "case_participants",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = await supabase.rpc(
        "search_clearance_records" as never,
        {
          p_query: safeQuery,
          p_search_type: searchType,
          p_limit: safeLimit,
        } as never,
      );

      return {
        data: Array.isArray(data)
          ? (data as ClearanceRpcRow[]).map(normalizeClearanceSearchRow)
          : [],
        error,
      };
    },
    [],
  );
}
