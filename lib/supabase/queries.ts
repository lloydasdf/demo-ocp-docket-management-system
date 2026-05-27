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

export type CaseParticipantRecord = TableRow<"case_participants"> & {
  case_participant_attributes: CaseParticipantAttributeRecord | null;
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
        case_participant_attributes:case_participant_attributes!case_participant_attributes_case_participant_id_fkey (age_text, age_years, gender_text, gender_normalized, is_minor_at_case, is_senior_at_case, is_pwd_at_case),
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
        case_participant_attributes:case_participant_attributes!case_participant_attributes_case_participant_id_fkey (age_text, age_years, gender_text, gender_normalized, is_minor_at_case, is_senior_at_case, is_pwd_at_case),
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
        case_participant_attributes:case_participant_attributes!case_participant_attributes_case_participant_id_fkey (age_text, age_years, gender_text, gender_normalized, is_minor_at_case, is_senior_at_case, is_pwd_at_case),
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

export interface AssignProsecutorInput {
  caseId: number;
  prosecutorId: number;
  remarks?: string;
}

export async function assignProsecutorToCase(
  input: AssignProsecutorInput,
): Promise<SupabaseQueryResult<TableRow<"case_assignments">>> {
  const environment = getSupabaseEnvironmentStatus();

  if (!environment.isConfigured) {
    return fail({
      message:
        "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable live prosecutor assignments.",
      table: "case_assignments",
      operation: "assignProsecutorToCase",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();

    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ??
            new Error("No active database user is available for prosecutor assignment."),
          "assignProsecutorToCase",
          "users",
        ),
      );
    }

    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase
      .from("case_assignments")
      .insert({
        assigned_at: new Date().toISOString(),
        assigned_by_user_id: currentUserQuery.data.id,
        case_id: input.caseId,
        prosecutor_id: input.prosecutorId,
        remarks: input.remarks?.trim() || null,
      })
      .select("*")
      .single();

    if (error || !data) {
      return fail(toQueryError(error, "assignProsecutorToCase", "case_assignments"));
    }

    return ok(data);
  } catch (error) {
    return fail(toQueryError(error, "assignProsecutorToCase", "case_assignments"));
  }
}

export async function unassignActiveProsecutorFromCase(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<"case_assignments">[]>> {
  const environment = getSupabaseEnvironmentStatus();

  if (!environment.isConfigured) {
    return fail({
      message:
        "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable live prosecutor assignments.",
      table: "case_assignments",
      operation: "unassignActiveProsecutorFromCase",
    });
  }

  try {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase
      .from("case_assignments")
      .update({ unassigned_at: new Date().toISOString() })
      .eq("case_id", caseId)
      .is("unassigned_at", null)
      .select("*");

    if (error) {
      return fail(
        toQueryError(error, "unassignActiveProsecutorFromCase", "case_assignments"),
      );
    }

    return ok(data ?? []);
  } catch (error) {
    return fail(
      toQueryError(error, "unassignActiveProsecutorFromCase", "case_assignments"),
    );
  }
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

export async function getCaseTimelineEvents(
  caseId: number,
): Promise<SupabaseQueryResult<CaseTimelineEventRecord[]>> {
  return runSupabaseQuery(
    "getCaseTimelineEvents",
    "cases",
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
      p_reason: reason,
      p_user_id: currentUserQuery.data.id,
    } as never);
    if (error) {
      return fail(toQueryError(error, "voidCaseEvent", "cases"));
    }
    return ok(true);
  } catch (error) {
    return fail(toQueryError(error, "voidCaseEvent", "cases"));
  }
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
          .from("v_cases_display")
          .select("id,violations")
          .in("id", caseIds),
        supabase
          .from("case_participants")
          .select(
            "case_id, person_id, case_participant_attributes:case_participant_attributes!case_participant_attributes_case_participant_id_fkey (age_text, age_years)",
          )
          .in("case_id", caseIds),
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
        const rawAttributes = row.case_participant_attributes;
        const attributes = Array.isArray(rawAttributes)
          ? rawAttributes[0]
          : rawAttributes;
        const age = attributes?.age_text ?? attributes?.age_years?.toString();

        if (age) {
          ageByCasePersonKey.set(`${row.case_id}-${row.person_id}`, age);
        }
      }

      return {
        data: results.map((result) => ({
          ...result,
          age: ageByCasePersonKey.get(`${result.caseId}-${result.personId}`) ?? result.age,
          violations: violationsByCaseId.get(result.caseId) ?? result.violations,
        })),
        error: null,
      };
    },
    [],
  );
}


export async function getParticipantRoles(): Promise<
  SupabaseQueryResult<TableRow<"participant_roles">[]>
> {
  return runSupabaseQuery(
    "getParticipantRoles",
    "participant_roles",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("participant_roles")
        .select("*")
        .eq("is_active", true)
        .order("display_label", { ascending: true });
    },
    [],
  );
}

export async function getAddressTypes(): Promise<
  SupabaseQueryResult<TableRow<"address_types">[]>
> {
  return runSupabaseQuery(
    "getAddressTypes",
    "address_types",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("address_types")
        .select("*")
        .eq("is_active", true)
        .order("display_label", { ascending: true });
    },
    [],
  );
}

export type DatabaseUserSummary = Pick<TableRow<"users">, "email" | "id">;

async function getCurrentDatabaseUserRecord() {
  const supabase = await getSupabaseBrowserClient();
  const { data: authData } = await supabase.auth.getUser();
  const authEmail = authData.user?.email;

  if (authEmail) {
    const authenticatedUserQuery = await supabase
      .from("users")
      .select("id,email")
      .eq("email", authEmail)
      .eq("is_active", true)
      .maybeSingle();

    if (authenticatedUserQuery.error || authenticatedUserQuery.data) {
      return authenticatedUserQuery;
    }
  }

  return supabase
    .from("users")
    .select("id,email")
    .eq("is_active", true)
    .order("id", { ascending: true })
    .limit(1)
    .maybeSingle();
}

export async function getCurrentDatabaseUser(): Promise<
  SupabaseQueryResult<DatabaseUserSummary | null>
> {
  return runSupabaseQuery(
    "getCurrentDatabaseUser",
    "users",
    async () => getCurrentDatabaseUserRecord(),
    null,
  );
}

export async function getActiveUsers(): Promise<
  SupabaseQueryResult<DatabaseUserSummary[]>
> {
  return runSupabaseQuery(
    "getActiveUsers",
    "users",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("users")
        .select("id,email")
        .eq("is_active", true)
        .order("email", { ascending: true });
    },
    [],
  );
}

async function getNextDocketNumberValue(
  docketTypeId: number,
  docketYear: number,
) {
  const supabase = await getSupabaseBrowserClient();
  const counterQuery = await supabase
    .from("docket_sequence_counters")
    .select("next_number")
    .eq("docket_type_id", docketTypeId)
    .eq("docket_year", docketYear)
    .maybeSingle();

  if (counterQuery.error || counterQuery.data) {
    return {
      data: counterQuery.data?.next_number ?? null,
      error: counterQuery.error,
    };
  }

  const latestCaseQuery = await supabase
    .from("cases")
    .select("docket_number")
    .eq("docket_type_id", docketTypeId)
    .eq("docket_year", docketYear)
    .order("docket_number", { ascending: false })
    .limit(1)
    .maybeSingle();

  return {
    data: latestCaseQuery.data?.docket_number
      ? latestCaseQuery.data.docket_number + 1
      : 1,
    error: latestCaseQuery.error,
  };
}

export async function getNextDocketNumber(
  docketTypeId: number,
  docketYear: number,
): Promise<SupabaseQueryResult<number>> {
  if (!Number.isFinite(docketTypeId) || !Number.isFinite(docketYear)) {
    return ok(1);
  }

  return runSupabaseQuery(
    "getNextDocketNumber",
    "docket_sequence_counters",
    async () => getNextDocketNumberValue(docketTypeId, docketYear),
    1,
  );
}

export async function searchAddressSuggestions(
  query: string,
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"addresses">[]>> {
  const safeLimit = normalizeLimit(limit, 8, 25);
  const safeQuery = escapeIlikeTerm(query);

  if (!safeQuery) {
    return ok([]);
  }

  return runSupabaseQuery(
    "searchAddressSuggestions",
    "addresses",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("addresses")
        .select("*")
        .or(
          `line1.ilike.%${safeQuery}%,line2.ilike.%${safeQuery}%,barangay.ilike.%${safeQuery}%,city.ilike.%${safeQuery}%,province.ilike.%${safeQuery}%,region.ilike.%${safeQuery}%`,
        )
        .order("created_at", { ascending: false })
        .limit(safeLimit);
    },
    [],
  );
}

export async function searchViolationSuggestions(
  query: string,
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<"violations">[]>> {
  const safeLimit = normalizeLimit(limit, 8, 25);
  const safeQuery = escapeIlikeTerm(query);

  if (!safeQuery) {
    return getViolations(safeLimit);
  }

  return runSupabaseQuery(
    "searchViolationSuggestions",
    "violations",
    async () => {
      const supabase = await getSupabaseBrowserClient();
      return supabase
        .from("violations")
        .select("*")
        .eq("is_active", true)
        .or(
          `title.ilike.%${safeQuery}%,short_label.ilike.%${safeQuery}%,law_reference.ilike.%${safeQuery}%,reference_code.ilike.%${safeQuery}%,description.ilike.%${safeQuery}%`,
        )
        .order("title", { ascending: true })
        .limit(safeLimit);
    },
    [],
  );
}

export interface NewDocketPersonInput {
  firstName: string;
  middleName?: string | null;
  lastName: string;
  suffix?: string | null;
  gender?: string | null;
  age?: string | null;
  birthDate?: string | null;
  roleId: number;
  remarks?: string | null;
}

export interface NewDocketAddressInput {
  addressTypeId: number;
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
  violationId: number;
  rawViolationText?: string | null;
}

export interface NewDocketEntryInput {
  docketTypeId: number;
  docketYear: number;
  dateReceived: string;
  initialStatusId?: number | null;
  regionCode?: string | null;
  source?: string | null;
  summaryText?: string | null;
  remarks?: string | null;
  isSummaryProcedure?: boolean | null;
  persons: NewDocketPersonInput[];
  addresses: NewDocketAddressInput[];
  violations: NewDocketViolationInput[];
}

export interface NewDocketEntryResult {
  caseId: number;
  docketNumber: number;
  docketYear: number;
  docketTypeId: number;
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

function buildFullName(person: NewDocketPersonInput) {
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
  const supabase = await getSupabaseBrowserClient();
  const { data: existingCounter, error: counterError } = await supabase
    .from("docket_sequence_counters")
    .select("id,next_number")
    .eq("docket_type_id", docketTypeId)
    .eq("docket_year", docketYear)
    .maybeSingle();

  if (counterError) {
    return counterError;
  }

  if (existingCounter) {
    if (existingCounter.next_number > issuedNumber) {
      return null;
    }

    const { error } = await supabase
      .from("docket_sequence_counters")
      .update({
        last_issued_number: issuedNumber,
        next_number: issuedNumber + 1,
      })
      .eq("id", existingCounter.id);

    return error;
  }

  const { error } = await supabase.from("docket_sequence_counters").insert({
    docket_type_id: docketTypeId,
    docket_year: docketYear,
    last_issued_number: issuedNumber,
    next_number: issuedNumber + 1,
  });

  return error;
}

export async function createNewDocketEntry(
  input: NewDocketEntryInput,
): Promise<SupabaseQueryResult<NewDocketEntryResult>> {
  const environment = getSupabaseEnvironmentStatus();

  if (!environment.isConfigured) {
    return fail({
      message:
        "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable live docket creation.",
      table: "cases",
      operation: "createNewDocketEntry",
    });
  }

  try {
    const currentUserQuery = await getCurrentDatabaseUserRecord();

    if (currentUserQuery.error || !currentUserQuery.data) {
      return fail(
        toQueryError(
          currentUserQuery.error ?? new Error("No active database user is available for docket creation."),
          "createNewDocketEntry",
          "users",
        ),
      );
    }

    const nextDocketNumber = await getNextDocketNumberValue(
      input.docketTypeId,
      input.docketYear,
    );

    if (nextDocketNumber.error || !nextDocketNumber.data) {
      return fail(
        toQueryError(
          nextDocketNumber.error ?? new Error("Unable to determine the next docket number."),
          "createNewDocketEntry",
          "docket_sequence_counters",
        ),
      );
    }

    const createdByUserId = currentUserQuery.data.id;
    const docketNumber = nextDocketNumber.data;
    const supabase = await getSupabaseBrowserClient();
    const { data: createdCase, error: caseError } = await supabase
      .from("cases")
      .insert({
        created_by_user_id: createdByUserId,
        date_received: input.dateReceived,
        docket_month_code: getDocketMonthCode(input.dateReceived),
        docket_number: docketNumber,
        docket_type_id: input.docketTypeId,
        docket_year: input.docketYear,
        is_summary_procedure: input.isSummaryProcedure ?? null,
        region_code: cleanString(input.regionCode) ?? "IV-A",
        remarks: cleanString(input.remarks),
        source: cleanString(input.source) ?? "manual",
        summary_text: cleanString(input.summaryText),
        updated_by_user_id: createdByUserId,
      })
      .select("id,docket_number,docket_year,docket_type_id")
      .single();

    if (caseError || !createdCase) {
      return fail(toQueryError(caseError, "createNewDocketEntry", "cases"));
    }

    const caseId = createdCase.id;
    const counterError = await advanceDocketCounter(
      input.docketTypeId,
      input.docketYear,
      docketNumber,
    );

    if (counterError) {
      return fail(
        toQueryError(counterError, "createNewDocketEntry", "docket_sequence_counters"),
      );
    }

    for (const [index, person] of input.persons.entries()) {
      const firstName = cleanString(person.firstName);
      const lastName = cleanString(person.lastName);

      if (!firstName || !lastName) {
        continue;
      }

      const { data: createdPerson, error: personError } = await supabase
        .from("persons")
        .insert({
          age: cleanString(person.age),
          birth_date: cleanString(person.birthDate),
          first_name: firstName,
          full_name: buildFullName(person),
          gender: cleanString(person.gender),
          last_name: lastName,
          middle_name: cleanString(person.middleName),
          suffix: cleanString(person.suffix),
        })
        .select("id")
        .single();

      if (personError || !createdPerson) {
        return fail(toQueryError(personError, "createNewDocketEntry", "persons"));
      }

      const { data: createdParticipant, error: participantError } = await supabase
        .from("case_participants")
        .insert({
          case_id: caseId,
          participant_order: index + 1,
          person_id: createdPerson.id,
          remarks: cleanString(person.remarks),
          role_id: person.roleId,
        })
        .select("id")
        .single();

      if (participantError || !createdParticipant) {
        return fail(
          toQueryError(participantError, "createNewDocketEntry", "case_participants"),
        );
      }

      const ageText = cleanString(person.age);
      const ageYears = parseAgeYears(person.age);
      const gender = normalizeGenderForAttributes(person.gender);

      if (ageText || gender.genderText || gender.genderNormalized !== "UNKNOWN") {
        const { error: attributesError } = await supabase
          .from("case_participant_attributes")
          .insert({
            age_basis_date: input.dateReceived,
            age_source: ageText ? "MANUAL_ENTRY" : "UNKNOWN",
            age_text: ageText,
            age_years: ageYears,
            case_participant_id: createdParticipant.id,
            created_by_user_id: createdByUserId,
            gender_normalized: gender.genderNormalized,
            gender_text: gender.genderText,
            is_minor_at_case: ageYears === null ? null : ageYears < 18,
            is_senior_at_case: ageFlag(ageYears, 60),
            source: "MANUAL_ENTRY",
            updated_by_user_id: createdByUserId,
          });

        if (attributesError) {
          return fail(
            toQueryError(attributesError, "createNewDocketEntry", "case_participant_attributes"),
          );
        }
      }
    }

    for (const address of input.addresses) {
      const { data: createdAddress, error: addressError } = await supabase
        .from("addresses")
        .insert({
          barangay: cleanString(address.barangay),
          city: cleanString(address.city),
          country: cleanString(address.country) ?? "Philippines",
          line1: cleanString(address.line1),
          line2: cleanString(address.line2),
          province: cleanString(address.province),
          region: cleanString(address.region),
          zip_code: cleanString(address.zipCode),
        })
        .select("id")
        .single();

      if (addressError || !createdAddress) {
        return fail(toQueryError(addressError, "createNewDocketEntry", "addresses"));
      }

      const { error: caseAddressError } = await supabase
        .from("case_addresses")
        .insert({
          address_id: createdAddress.id,
          address_type_id: address.addressTypeId,
          case_id: caseId,
          is_primary: true,
          remarks: cleanString(address.remarks),
        });

      if (caseAddressError) {
        return fail(
          toQueryError(caseAddressError, "createNewDocketEntry", "case_addresses"),
        );
      }
    }

    if (input.violations.length > 0) {
      const { error: violationsError } = await supabase.from("case_violations").insert(
        input.violations.map((violation, index) => ({
          case_id: caseId,
          raw_violation_text: cleanString(violation.rawViolationText),
          violation_id: violation.violationId,
          violation_order: index + 1,
        })),
      );

      if (violationsError) {
        return fail(
          toQueryError(violationsError, "createNewDocketEntry", "case_violations"),
        );
      }
    }

    if (input.initialStatusId) {
      const { error: statusError } = await supabase
        .from("case_status_history")
        .insert({
          case_id: caseId,
          changed_by_user_id: createdByUserId,
          remarks: "Initial status set to Received during docket creation.",
          status_date: input.dateReceived,
          to_status_id: input.initialStatusId,
        });

      if (statusError) {
        return fail(
          toQueryError(statusError, "createNewDocketEntry", "case_status_history"),
        );
      }
    }

    return ok({
      caseId,
      docketNumber: createdCase.docket_number,
      docketTypeId: createdCase.docket_type_id,
      docketYear: createdCase.docket_year,
    });
  } catch (error) {
    return fail(toQueryError(error, "createNewDocketEntry", "cases"));
  }
}
