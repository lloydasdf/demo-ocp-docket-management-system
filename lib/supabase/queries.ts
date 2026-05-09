import { getSupabaseBrowserClient, getSupabaseEnvironmentStatus } from '@/lib/supabase/client';
import type { RelationName, SupabaseQueryError, SupabaseQueryResult, TableName, TableRow, ViewRow } from '@/lib/supabase/types';

type SupabaseErrorLike = {
  message?: string;
  code?: string;
  details?: string;
  hint?: string;
};

function isSupabaseErrorLike(error: unknown): error is SupabaseErrorLike {
  return typeof error === 'object' && error !== null && 'message' in error;
}

function toQueryError(
  error: unknown,
  operation: string,
  table?: RelationName,
): SupabaseQueryError {
  if (isSupabaseErrorLike(error)) {
    return {
      message: error.message ?? 'Supabase query failed.',
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
    message: 'Supabase query failed with an unknown error.',
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
        'Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY to enable live database reads.',
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

function normalizeLimit(limit: number | undefined, defaultLimit: number, maxLimit: number) {
  if (!Number.isFinite(limit)) {
    return defaultLimit;
  }

  return Math.min(Math.max(Math.trunc(limit ?? defaultLimit), 1), maxLimit);
}

function escapeIlikeTerm(term: string) {
  return term.replace(/[%,]/g, '').trim();
}


type CasesListNestedPerson = Pick<TableRow<'persons'>, 'full_name'> | null;
type CasesListNestedRole = Pick<TableRow<'participant_roles'>, 'code' | 'display_label'> | null;
type CasesListNestedParticipant = Pick<
  TableRow<'case_participants'>,
  'id' | 'is_primary' | 'participant_order' | 'raw_name_text'
> & {
  persons: CasesListNestedPerson;
  participant_roles: CasesListNestedRole;
};
type CasesListNestedViolation = Pick<
  TableRow<'violations'>,
  'title' | 'short_label' | 'reference_code' | 'law_reference'
> | null;
type CasesListNestedProsecutor = Pick<TableRow<'prosecutors'>, 'full_name' | 'short_name'> | null;
type CasesListNestedAssignment = Pick<
  TableRow<'case_assignments'>,
  'assigned_at' | 'unassigned_at'
> & {
  prosecutors: CasesListNestedProsecutor;
};
type CasesListNestedStatus = Pick<TableRow<'case_statuses'>, 'code' | 'display_label'> | null;
type CasesListNestedDocketType = Pick<TableRow<'docket_types'>, 'name' | 'prefix'> | null;

type CasesListNestedRow = Pick<
  TableRow<'cases'>,
  'id' | 'created_at' | 'date_received' | 'docket_display_number'
> & {
  docket_types: CasesListNestedDocketType;
  case_statuses: CasesListNestedStatus;
  violations: CasesListNestedViolation;
  prosecutors: CasesListNestedProsecutor;
  case_assignments: CasesListNestedAssignment[];
  case_participants: CasesListNestedParticipant[];
};

export type CasesListItem = {
  id: number;
  docketNumber: string;
  complainant: string;
  respondent: string;
  violations: string;
  assignedProsecutor: string;
  currentStatus: string;
  dateReceived: string | null;
  createdAt: string | null;
};

function sortParticipants(
  firstParticipant: CasesListNestedParticipant,
  secondParticipant: CasesListNestedParticipant,
) {
  if (firstParticipant.is_primary !== secondParticipant.is_primary) {
    return firstParticipant.is_primary ? -1 : 1;
  }

  return (
    (firstParticipant.participant_order ?? Number.MAX_SAFE_INTEGER) -
      (secondParticipant.participant_order ?? Number.MAX_SAFE_INTEGER) ||
    firstParticipant.id - secondParticipant.id
  );
}

function getParticipantName(participant: CasesListNestedParticipant) {
  return participant.persons?.full_name ?? participant.raw_name_text ?? 'Name unavailable';
}

function formatParticipantDisplay(participants: CasesListNestedParticipant[]) {
  if (participants.length === 0) {
    return '—';
  }

  const [firstParticipant] = [...participants].sort(sortParticipants);
  const suffix = participants.length > 1 ? ' et al.' : '';

  return `${getParticipantName(firstParticipant)}${suffix}`;
}

function roleMatches(role: CasesListNestedRole, roleName: 'complainant' | 'respondent') {
  return (
    role?.code.toLowerCase() === roleName ||
    role?.display_label.toLowerCase() === roleName
  );
}

// TODO: Expand this formatter if the schema adds a typed case-to-many-violations relation;
// the current cases row exposes one violation_id relationship.
function getViolationDisplay(violation: CasesListNestedViolation) {
  if (!violation) {
    return '—';
  }

  return violation.short_label ?? violation.reference_code ?? violation.title ?? '—';
}

function getProsecutorDisplay(prosecutor: CasesListNestedProsecutor) {
  return prosecutor?.short_name ?? prosecutor?.full_name ?? null;
}

function getAssignedProsecutorDisplay(row: CasesListNestedRow) {
  const activeAssignment = [...row.case_assignments]
    .filter((assignment) => assignment.unassigned_at === null)
    .sort((firstAssignment, secondAssignment) => (
      new Date(secondAssignment.assigned_at).getTime() - new Date(firstAssignment.assigned_at).getTime()
    ))[0];

  return getProsecutorDisplay(activeAssignment?.prosecutors ?? null) ?? getProsecutorDisplay(row.prosecutors) ?? '—';
}

function toCasesListItem(row: CasesListNestedRow): CasesListItem {
  const complainants = row.case_participants.filter((participant) =>
    roleMatches(participant.participant_roles, 'complainant'),
  );
  const respondents = row.case_participants.filter((participant) =>
    roleMatches(participant.participant_roles, 'respondent'),
  );

  return {
    id: row.id,
    docketNumber: row.docket_display_number,
    complainant: formatParticipantDisplay(complainants),
    respondent: formatParticipantDisplay(respondents),
    violations: getViolationDisplay(row.violations),
    assignedProsecutor: getAssignedProsecutorDisplay(row),
    currentStatus: row.case_statuses?.display_label ?? row.case_statuses?.code ?? '—',
    dateReceived: row.date_received,
    createdAt: row.created_at,
  };
}

export async function verifySupabaseConnection(): Promise<
  SupabaseQueryResult<{
    checkedTable: 'docket_types';
    rowCount: number;
    checkedAt: string;
  }>
> {
  const checkedAt = new Date().toISOString();

  return runSupabaseQuery(
    'verifySupabaseConnection',
    'docket_types',
    async () => {
      const supabase = await getSupabaseBrowserClient();
      const { data, error } = await supabase.from('docket_types').select('id').limit(1);

      return {
        data: data
          ? {
              checkedTable: 'docket_types' as const,
              rowCount: data.length,
              checkedAt,
            }
          : null,
        error,
      };
    },
    {
      checkedTable: 'docket_types',
      rowCount: 0,
      checkedAt,
    },
  );
}

export async function getDocketTypes(): Promise<SupabaseQueryResult<TableRow<'docket_types'>[]>> {
  return runSupabaseQuery('getDocketTypes', 'docket_types', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase.from('docket_types').select('*').order('sort_order', { ascending: true });
  }, []);
}

export async function getCaseStatuses(): Promise<SupabaseQueryResult<TableRow<'case_statuses'>[]>> {
  return runSupabaseQuery('getCaseStatuses', 'case_statuses', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase.from('case_statuses').select('*').order('sort_order', { ascending: true });
  }, []);
}


export async function getCasesList(limit?: number): Promise<SupabaseQueryResult<CasesListItem[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery('getCasesList', 'cases', async () => {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase
      .from('cases')
      .select(`
        id,
        created_at,
        date_received,
        docket_display_number,
        docket_types!cases_docket_type_id_fkey(name, prefix),
        case_statuses!cases_current_status_id_fkey(code, display_label),
        violations!cases_violation_id_fkey(title, short_label, reference_code, law_reference),
        prosecutors!cases_current_prosecutor_id_fkey(full_name, short_name),
        case_assignments(
          assigned_at,
          unassigned_at,
          prosecutors!case_assignments_prosecutor_id_fkey(full_name, short_name)
        ),
        case_participants(
          id,
          is_primary,
          participant_order,
          raw_name_text,
          persons!case_participants_person_id_fkey(full_name),
          participant_roles!case_participants_role_id_fkey(code, display_label)
        )
      `)
      .eq('is_archived', false)
      .order('created_at', { ascending: false })
      .limit(safeLimit);

    return {
      data: data ? (data as unknown as CasesListNestedRow[]).map(toCasesListItem) : null,
      error,
    };
  }, []);
}

export async function getCases(limit?: number): Promise<SupabaseQueryResult<TableRow<'cases'>[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery('getCases', 'cases', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('cases')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(safeLimit);
  }, []);
}

export async function getCompactCases(
  limit?: number,
): Promise<SupabaseQueryResult<ViewRow<'v_cases_table_compact'>[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery('getCompactCases', 'v_cases_table_compact', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('v_cases_table_compact')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(safeLimit);
  }, []);
}

export async function getCaseById(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<'cases'> | null>> {
  return runSupabaseQuery('getCaseById', 'cases', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase.from('cases').select('*').eq('id', caseId).single();
  }, null);
}

export async function searchCases(
  query: string,
  limit?: number,
): Promise<SupabaseQueryResult<ViewRow<'v_cases_table_compact'>[]>> {
  const safeLimit = normalizeLimit(limit, 25, 100);
  const safeQuery = escapeIlikeTerm(query);

  if (!safeQuery) {
    return getCompactCases(safeLimit);
  }

  return runSupabaseQuery('searchCases', 'v_cases_table_compact', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('v_cases_table_compact')
      .select('*')
      .or(
        `docket_number.ilike.%${safeQuery}%,complainant.ilike.%${safeQuery}%,respondent.ilike.%${safeQuery}%`,
      )
      .order('created_at', { ascending: false })
      .limit(safeLimit);
  }, []);
}

export async function getPersons(limit?: number): Promise<SupabaseQueryResult<TableRow<'persons'>[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery('getPersons', 'persons', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase.from('persons').select('*').order('full_name', { ascending: true }).limit(safeLimit);
  }, []);
}

export async function searchPersons(
  query: string,
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<'persons'>[]>> {
  const safeLimit = normalizeLimit(limit, 25, 100);
  const safeQuery = escapeIlikeTerm(query);

  if (!safeQuery) {
    return getPersons(safeLimit);
  }

  return runSupabaseQuery('searchPersons', 'persons', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('persons')
      .select('*')
      .or(`full_name.ilike.%${safeQuery}%,first_name.ilike.%${safeQuery}%,last_name.ilike.%${safeQuery}%`)
      .order('full_name', { ascending: true })
      .limit(safeLimit);
  }, []);
}

export async function getProsecutors(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<'prosecutors'>[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery('getProsecutors', 'prosecutors', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('prosecutors')
      .select('*')
      .eq('is_active', true)
      .order('full_name', { ascending: true })
      .limit(safeLimit);
  }, []);
}

export async function getCaseParticipants(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<'case_participants'>[]>> {
  return runSupabaseQuery('getCaseParticipants', 'case_participants', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase.from('case_participants').select('*').eq('case_id', caseId).order('id');
  }, []);
}

export async function getCaseAssignments(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<'case_assignments'>[]>> {
  return runSupabaseQuery('getCaseAssignments', 'case_assignments', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('case_assignments')
      .select('*')
      .eq('case_id', caseId)
      .order('assigned_at', { ascending: false });
  }, []);
}

export async function getCaseStatusHistory(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<'case_status_history'>[]>> {
  return runSupabaseQuery('getCaseStatusHistory', 'case_status_history', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('case_status_history')
      .select('*')
      .eq('case_id', caseId)
      .order('created_at', { ascending: false });
  }, []);
}

export async function getViolations(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<'violations'>[]>> {
  const safeLimit = normalizeLimit(limit, 50, 250);

  return runSupabaseQuery('getViolations', 'violations', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('violations')
      .select('*')
      .eq('is_active', true)
      .order('title', { ascending: true })
      .limit(safeLimit);
  }, []);
}

export async function getRecentAuditLogs(
  limit?: number,
): Promise<SupabaseQueryResult<TableRow<'audit_logs'>[]>> {
  const safeLimit = normalizeLimit(limit, 20, 100);

  return runSupabaseQuery('getRecentAuditLogs', 'audit_logs', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('audit_logs')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(safeLimit);
  }, []);
}

export async function getDashboardStats(): Promise<
  SupabaseQueryResult<{
    totalCases: number;
    byStatusId: Record<number, number>;
  }>
> {
  return runSupabaseQuery('getDashboardStats', 'cases', async () => {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = await supabase.from('cases').select('id,current_status_id');

    if (error || !data) {
      return { data: null, error };
    }

    const byStatusId = data.reduce<Record<number, number>>((totals, row) => {
      totals[row.current_status_id] = (totals[row.current_status_id] ?? 0) + 1;
      return totals;
    }, {});

    return {
      data: {
        totalCases: data.length,
        byStatusId,
      },
      error: null,
    };
  }, {
    totalCases: 0,
    byStatusId: {},
  });
}
