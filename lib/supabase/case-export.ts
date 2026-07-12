import { getSupabaseBrowserClient, getSupabaseEnvironmentStatus } from '@/lib/supabase/client';
import type { RelationName, SupabaseQueryError, SupabaseQueryResult } from '@/lib/supabase/types';

export type CaseExcelExportRow = {
  case_id: number;
  docket_type_id: number | null;
  docket_type_prefix: string | null;
  docket_type_label: string | null;
  docket_type_sort_order: number | null;
  docket_year: number | null;
  docket_month_code: string | null;
  docket_number: number | null;
  docket_no: string;
  complainants: string | null;
  complainant_attributes: string | null;
  respondents: string | null;
  respondent_attributes: string | null;
  violations: string | null;
  case_classification: string | null;
  date_received: string | null;
  current_status: string | null;
  assigned_prosecutor: string | null;
  court_filings_court: string | null;
  court_dates_filed: string | null;
  criminal_case_numbers: string | null;
  charges_filed: string | null;
  court_statuses: string | null;
  motion_titles: string | null;
  motion_filed_by: string | null;
  motion_dates_received: string | null;
  motion_statuses: string | null;
  petition_dates_filed: string | null;
  petition_filed_by: string | null;
  petition_statuses: string | null;
  case_notes: string | null;
};

type SupabaseErrorLike = { message?: string; code?: string; details?: string; hint?: string };

function toQueryError(error: unknown, operation: string, table: RelationName): SupabaseQueryError {
  if (typeof error === 'object' && error !== null) {
    const candidate = error as SupabaseErrorLike;
    return {
      message: candidate.message ?? 'The Supabase request failed.',
      code: candidate.code,
      details: candidate.details,
      hint: candidate.hint,
      operation,
      table,
    };
  }

  return { message: error instanceof Error ? error.message : 'The Supabase request failed.', operation, table };
}

export async function getCasesExcelExport(params: {
  docketYear: number | null;
  docketTypeId: number | null;
}): Promise<SupabaseQueryResult<CaseExcelExportRow[]>> {
  const operation = 'getCasesExcelExport';
  const table = 'cases' as RelationName;
  const environment = getSupabaseEnvironmentStatus();

  if (!environment.isConfigured) {
    return { data: null, error: { message: 'Supabase is not configured. Configure Supabase before exporting cases.', operation, table } };
  }

  try {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = (await supabase.rpc('export_cases_excel_data' as never, {
      p_docket_year: params.docketYear,
      p_docket_type_id: params.docketTypeId,
    } as never)) as unknown as { data: CaseExcelExportRow[] | null; error: unknown };

    if (error) {
      return { data: null, error: toQueryError(error, operation, table) };
    }

    return { data: data ?? [], error: null };
  } catch (error) {
    return { data: null, error: toQueryError(error, operation, table) };
  }
}
