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


export type CasesCompactQueryParams = {
  docketType?: string;
  docketYear?: number;
  search?: string;
  limit?: number;
};

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

export async function getCasesCompact(
  params: CasesCompactQueryParams = {},
): Promise<SupabaseQueryResult<ViewRow<'v_cases_table_compact'>[]>> {
  const { docketType, docketYear, limit } = params;

  return runSupabaseQuery('getCasesCompact', 'v_cases_table_compact', async () => {
    const supabase = await getSupabaseBrowserClient();
    let query = supabase
      .from('v_cases_table_compact')
      .select('*')
      .order('created_at', { ascending: false });

    if (docketType && docketType !== 'All') {
      query = query.eq('docket_type', docketType);
    }

    if (docketYear !== undefined) {
      query = query.eq('docket_year', docketYear);
    }

    if (limit !== undefined) {
      query = query.limit(normalizeLimit(limit, 50, 250));
    }

    return query;
  }, []);
}

export async function getCompactCases(
  params?: number | CasesCompactQueryParams,
): Promise<SupabaseQueryResult<ViewRow<'v_cases_table_compact'>[]>> {
  if (typeof params === 'number') {
    return getCasesCompact({ limit: params });
  }

  return getCasesCompact(params);
}


export type CaseDetailsRecord = TableRow<'cases'> & {
  case_statuses: Pick<TableRow<'case_statuses'>, 'code' | 'display_label'> | null;
  courts: Pick<TableRow<'courts'>, 'code' | 'court_type' | 'name'> | null;
  docket_types: Pick<TableRow<'docket_types'>, 'name' | 'prefix'> | null;
  prosecutors: Pick<TableRow<'prosecutors'>, 'full_name' | 'short_name'> | null;
  violations: Pick<TableRow<'violations'>, 'description' | 'law_reference' | 'reference_code' | 'short_label' | 'title'> | null;
};

export type CaseParticipantRecord = TableRow<'case_participants'> & {
  participant_roles: Pick<TableRow<'participant_roles'>, 'code' | 'display_label'> | null;
  persons: Pick<TableRow<'persons'>, 'birth_date' | 'first_name' | 'full_name' | 'gender' | 'last_name' | 'middle_name' | 'suffix'> | null;
};

export type CaseAssignmentRecord = TableRow<'case_assignments'> & {
  prosecutors: Pick<TableRow<'prosecutors'>, 'full_name' | 'short_name'> | null;
  staff: Pick<TableRow<'staff'>, 'full_name' | 'short_name'> | null;
};

export type CaseStatusHistoryRecord = TableRow<'case_status_history'> & {
  from_status: Pick<TableRow<'case_statuses'>, 'code' | 'display_label'> | null;
  to_status: Pick<TableRow<'case_statuses'>, 'code' | 'display_label'> | null;
};

export async function getCaseCompactById(
  caseId: number,
): Promise<SupabaseQueryResult<ViewRow<'v_cases_table_compact'> | null>> {
  return runSupabaseQuery('getCaseCompactById', 'v_cases_table_compact', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase.from('v_cases_table_compact').select('*').eq('case_id', caseId).maybeSingle();
  }, null);
}

export async function getCaseDetailsById(
  caseId: number,
): Promise<SupabaseQueryResult<CaseDetailsRecord | null>> {
  return runSupabaseQuery('getCaseDetailsById', 'cases', async () => {
    const supabase = await getSupabaseBrowserClient();
    const query = supabase
      .from('cases')
      .select(`
        *,
        case_statuses:case_statuses!cases_current_status_id_fkey (code, display_label),
        courts:courts!cases_court_id_fkey (code, court_type, name),
        docket_types:docket_types!cases_docket_type_id_fkey (name, prefix),
        prosecutors:prosecutors!cases_current_prosecutor_id_fkey (full_name, short_name),
        violations:violations!cases_violation_id_fkey (description, law_reference, reference_code, short_label, title)
      `)
      .eq('id', caseId)
      .maybeSingle();

    return query as unknown as Promise<{ data: CaseDetailsRecord | null; error: unknown }>;
  }, null);
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
): Promise<SupabaseQueryResult<CaseParticipantRecord[]>> {
  return runSupabaseQuery('getCaseParticipants', 'case_participants', async () => {
    const supabase = await getSupabaseBrowserClient();
    const query = supabase
      .from('case_participants')
      .select('*, participant_roles:participant_roles!case_participants_role_id_fkey (code, display_label), persons:persons!case_participants_person_id_fkey (birth_date, first_name, full_name, gender, last_name, middle_name, suffix)')
      .eq('case_id', caseId)
      .order('participant_order', { ascending: true, nullsFirst: false })
      .order('id', { ascending: true });

    return query as unknown as Promise<{ data: CaseParticipantRecord[] | null; error: unknown }>;
  }, []);
}

export async function getCaseAssignments(
  caseId: number,
): Promise<SupabaseQueryResult<CaseAssignmentRecord[]>> {
  return runSupabaseQuery('getCaseAssignments', 'case_assignments', async () => {
    const supabase = await getSupabaseBrowserClient();
    const query = supabase
      .from('case_assignments')
      .select('*, prosecutors:prosecutors!case_assignments_prosecutor_id_fkey (full_name, short_name), staff:staff!case_assignments_staff_id_fkey (full_name, short_name)')
      .eq('case_id', caseId)
      .order('assigned_at', { ascending: false });

    return query as unknown as Promise<{ data: CaseAssignmentRecord[] | null; error: unknown }>;
  }, []);
}

export async function getCaseStatusHistory(
  caseId: number,
): Promise<SupabaseQueryResult<CaseStatusHistoryRecord[]>> {
  return runSupabaseQuery('getCaseStatusHistory', 'case_status_history', async () => {
    const supabase = await getSupabaseBrowserClient();
    const query = supabase
      .from('case_status_history')
      .select('*, from_status:case_statuses!case_status_history_from_status_id_fkey (code, display_label), to_status:case_statuses!case_status_history_to_status_id_fkey (code, display_label)')
      .eq('case_id', caseId)
      .order('changed_at', { ascending: false });

    return query as unknown as Promise<{ data: CaseStatusHistoryRecord[] | null; error: unknown }>;
  }, []);
}

export async function getCaseCourtDetails(
  caseId: number,
): Promise<SupabaseQueryResult<Pick<CaseDetailsRecord, 'court_branch' | 'court_id' | 'court_remarks' | 'court_status' | 'criminal_case_number' | 'date_filed_in_court' | 'information_count' | 'courts'> | null>> {
  const result = await getCaseDetailsById(caseId);

  if (result.error) {
    return fail(result.error);
  }

  if (!result.data) {
    return ok(null);
  }

  const { court_branch, court_id, court_remarks, court_status, criminal_case_number, date_filed_in_court, information_count, courts } = result.data;
  return ok({ court_branch, court_id, court_remarks, court_status, criminal_case_number, date_filed_in_court, information_count, courts });
}

export async function getCaseMotions(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<'case_motions'>[]>> {
  return runSupabaseQuery('getCaseMotions', 'case_motions', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('case_motions')
      .select('*')
      .eq('case_id', caseId)
      .order('date_received', { ascending: false, nullsFirst: false })
      .order('created_at', { ascending: false });
  }, []);
}

export async function getCaseAttachmentsIndex(
  caseId: number,
): Promise<SupabaseQueryResult<TableRow<'case_attachment_index'>[]>> {
  return runSupabaseQuery('getCaseAttachmentsIndex', 'case_attachment_index', async () => {
    const supabase = await getSupabaseBrowserClient();
    return supabase
      .from('case_attachment_index')
      .select('*')
      .eq('case_id', caseId)
      .order('last_seen_at', { ascending: false });
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
