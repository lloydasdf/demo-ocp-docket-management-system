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
  date_approved: string | null;
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

export type CaseExportManifestRow = {
  docket_type_id: number | null;
  docket_type_prefix: string | null;
  docket_type_label: string | null;
  docket_type_sort_order: number | null;
  docket_year: number | null;
  expected_case_count: number;
};

type SupabaseErrorLike = { message?: string; code?: string; details?: string; hint?: string };

const EXPORT_PAGE_SIZE = 500;

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

function environmentError(operation: string, table: RelationName): SupabaseQueryResult<never> | null {
  const environment = getSupabaseEnvironmentStatus();
  if (environment.isConfigured) return null;
  return { data: null, error: { message: 'Supabase is not configured. Configure Supabase before exporting cases.', operation, table } };
}

export async function getCasesExportManifest(params: {
  docketYear: number | null;
  docketTypeId: number | null;
}): Promise<SupabaseQueryResult<CaseExportManifestRow[]>> {
  const operation = 'getCasesExportManifest';
  const table = 'cases' as RelationName;
  const configurationError = environmentError(operation, table);
  if (configurationError) return configurationError;

  try {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = (await supabase.rpc('get_cases_export_manifest' as never, {
      p_docket_year: params.docketYear,
      p_docket_type_id: params.docketTypeId,
    } as never)) as unknown as { data: CaseExportManifestRow[] | null; error: unknown };

    if (error) {
      return { data: null, error: toQueryError(error, operation, table) };
    }

    return { data: data ?? [], error: null };
  } catch (error) {
    return { data: null, error: toQueryError(error, operation, table) };
  }
}

export async function getCasesExcelExportPage(params: {
  docketYear: number | null;
  docketTypeId: number | null;
  from: number;
  to: number;
}): Promise<SupabaseQueryResult<CaseExcelExportRow[]>> {
  const operation = 'getCasesExcelExportPage';
  const table = 'cases' as RelationName;
  const configurationError = environmentError(operation, table);
  if (configurationError) return configurationError;

  try {
    const supabase = await getSupabaseBrowserClient();
    const { data, error } = (await supabase
      .rpc('export_cases_excel_data' as never, {
        p_docket_year: params.docketYear,
        p_docket_type_id: params.docketTypeId,
      } as never)
      .range(params.from, params.to)) as unknown as { data: CaseExcelExportRow[] | null; error: unknown };

    if (error) {
      return { data: null, error: toQueryError(error, operation, table) };
    }

    return { data: data ?? [], error: null };
  } catch (error) {
    return { data: null, error: toQueryError(error, operation, table) };
  }
}

export async function getCasesExcelExport(params: {
  docketYear: number | null;
  docketTypeId: number | null;
  expectedCaseCount?: number;
  onPageLoaded?: (pageNumber: number, loadedCount: number) => void;
}): Promise<SupabaseQueryResult<CaseExcelExportRow[]>> {
  const rows: CaseExcelExportRow[] = [];
  let pageNumber = 1;

  while (true) {
    const from = rows.length;
    const pageResult = await getCasesExcelExportPage({
      docketYear: params.docketYear,
      docketTypeId: params.docketTypeId,
      from,
      to: from + EXPORT_PAGE_SIZE - 1,
    });

    if (pageResult.error) return pageResult;

    const pageRows = pageResult.data ?? [];
    rows.push(...pageRows);
    params.onPageLoaded?.(pageNumber, rows.length);

    if (params.expectedCaseCount !== undefined && rows.length >= params.expectedCaseCount) break;
    if (pageRows.length < EXPORT_PAGE_SIZE) break;
    pageNumber += 1;
  }

  return { data: rows, error: null };
}

export async function getCasesExcelExportForCaseIds(params: {
  caseIds: number[];
  onPageLoaded?: (pageNumber: number, loadedCount: number) => void;
}): Promise<SupabaseQueryResult<CaseExcelExportRow[]>> {
  const operation = 'getCasesExcelExportForCaseIds';
  const table = 'cases' as RelationName;
  const configurationError = environmentError(operation, table);
  if (configurationError) return configurationError;

  const rows: CaseExcelExportRow[] = [];
  let pageNumber = 1;

  try {
    const supabase = await getSupabaseBrowserClient();

    while (true) {
      const from = rows.length;
      const { data, error } = (await supabase
        .rpc('export_cases_excel_data_for_cases' as never, { p_case_ids: params.caseIds } as never)
        .range(from, from + EXPORT_PAGE_SIZE - 1)) as unknown as { data: CaseExcelExportRow[] | null; error: unknown };

      if (error) return { data: null, error: toQueryError(error, operation, table) };

      const pageRows = data ?? [];
      rows.push(...pageRows);
      params.onPageLoaded?.(pageNumber, rows.length);

      if (rows.length >= params.caseIds.length || pageRows.length < EXPORT_PAGE_SIZE) break;
      pageNumber += 1;
    }

    return { data: rows, error: null };
  } catch (error) {
    return { data: null, error: toQueryError(error, operation, table) };
  }
}

export { EXPORT_PAGE_SIZE };
