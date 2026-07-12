import type { Workbook, Worksheet } from 'exceljs';
import type { CaseExcelExportRow } from '@/lib/supabase/case-export';

type WorkbookColumn = { header: string; key: keyof CaseExcelExportRow; width: number };
type DocketTypeGroup = {
  id: number | null;
  prefix: string;
  label: string;
  sortOrder: number | null;
  rows: CaseExcelExportRow[];
};

const PREFERRED_DOCKET_TYPE_ORDER = ['INV', 'INQ', 'PE', 'DC'];
const INVALID_WORKSHEET_CHARACTERS = /[:\\/?*\[\]]/g;

export const CASE_EXCEL_COLUMNS: WorkbookColumn[] = [
  { header: 'Docket No.', key: 'docket_no', width: 22 },
  { header: 'Complainant', key: 'complainants', width: 30 },
  { header: 'Complainants Attributes', key: 'complainant_attributes', width: 42 },
  { header: 'Respondent', key: 'respondents', width: 30 },
  { header: 'Respondents Attributes', key: 'respondent_attributes', width: 42 },
  { header: 'Violations', key: 'violations', width: 36 },
  { header: 'Case Classification', key: 'case_classification', width: 22 },
  { header: 'Date Received', key: 'date_received', width: 16 },
  { header: 'Current Status', key: 'current_status', width: 22 },
  { header: 'Assigned Prosecutor', key: 'assigned_prosecutor', width: 26 },
  { header: 'Court Filings Court', key: 'court_filings_court', width: 32 },
  { header: 'Date Filed in Court', key: 'court_dates_filed', width: 20 },
  { header: 'Criminal Case Nos.', key: 'criminal_case_numbers', width: 24 },
  { header: 'Charge Filed', key: 'charges_filed', width: 32 },
  { header: 'Court Status', key: 'court_statuses', width: 24 },
  { header: 'Motion Received Title', key: 'motion_titles', width: 32 },
  { header: 'Filed By', key: 'motion_filed_by', width: 22 },
  { header: 'Motion Date Received', key: 'motion_dates_received', width: 20 },
  { header: 'Motion Status', key: 'motion_statuses', width: 24 },
  { header: 'Petition for Review Date Filed', key: 'petition_dates_filed', width: 24 },
  { header: 'Filed by Comp/Resp?', key: 'petition_filed_by', width: 22 },
  { header: 'Petition for Review Status', key: 'petition_statuses', width: 26 },
  { header: 'Case Notes', key: 'case_notes', width: 50 },
];

function parseDateOnly(value: string | null) {
  if (!value || value.includes('\n')) return value ?? '';
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return value;
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

function safeFilenamePart(value: string) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'ALL';
}

function localDateString() {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function docketSortValue(row: CaseExcelExportRow) {
  return {
    year: row.docket_year ?? Number.MAX_SAFE_INTEGER,
    monthCode: row.docket_month_code ?? '',
    number: row.docket_number ?? Number.MAX_SAFE_INTEGER,
    caseId: row.case_id,
  };
}

function sortRowsByDocket(left: CaseExcelExportRow, right: CaseExcelExportRow) {
  const leftSort = docketSortValue(left);
  const rightSort = docketSortValue(right);
  return (
    leftSort.year - rightSort.year ||
    leftSort.monthCode.localeCompare(rightSort.monthCode, undefined, { numeric: true, sensitivity: 'base' }) ||
    leftSort.number - rightSort.number ||
    leftSort.caseId - rightSort.caseId
  );
}

export function sanitizeWorksheetName(requestedName: string, existingNames: Set<string>): string {
  const baseName = requestedName.replace(INVALID_WORKSHEET_CHARACTERS, ' ').replace(/\s+/g, ' ').trim() || 'Other';
  const truncatedBaseName = baseName.slice(0, 31) || 'Other';
  let candidate = truncatedBaseName;
  let suffix = 2;

  while (existingNames.has(candidate.toLowerCase())) {
    const suffixText = ` (${suffix})`;
    candidate = `${truncatedBaseName.slice(0, 31 - suffixText.length)}${suffixText}`;
    suffix += 1;
  }

  existingNames.add(candidate.toLowerCase());
  return candidate;
}

function groupRowsByDocketType(rows: CaseExcelExportRow[]) {
  const groups = new Map<string, DocketTypeGroup>();

  for (const row of rows) {
    const groupKey = row.docket_type_id === null ? `unknown:${row.docket_type_prefix ?? row.docket_type_label ?? 'other'}` : `id:${row.docket_type_id}`;
    const existingGroup = groups.get(groupKey);

    if (existingGroup) {
      existingGroup.rows.push(row);
      continue;
    }

    groups.set(groupKey, {
      id: row.docket_type_id,
      prefix: row.docket_type_prefix?.trim() || '',
      label: row.docket_type_label?.trim() || '',
      sortOrder: row.docket_type_sort_order,
      rows: [row],
    });
  }

  return Array.from(groups.values()).sort(sortDocketTypeGroups);
}

function sortDocketTypeGroups(left: DocketTypeGroup, right: DocketTypeGroup) {
  if (left.sortOrder !== null && right.sortOrder !== null && left.sortOrder !== right.sortOrder) {
    return left.sortOrder - right.sortOrder;
  }

  if (left.sortOrder !== null && right.sortOrder === null) return -1;
  if (left.sortOrder === null && right.sortOrder !== null) return 1;

  const leftPreferred = PREFERRED_DOCKET_TYPE_ORDER.indexOf(left.prefix.toUpperCase());
  const rightPreferred = PREFERRED_DOCKET_TYPE_ORDER.indexOf(right.prefix.toUpperCase());
  if (leftPreferred !== -1 || rightPreferred !== -1) {
    if (leftPreferred === -1) return 1;
    if (rightPreferred === -1) return -1;
    return leftPreferred - rightPreferred;
  }

  return left.prefix.localeCompare(right.prefix, undefined, { numeric: true, sensitivity: 'base' }) || left.label.localeCompare(right.label, undefined, { numeric: true, sensitivity: 'base' });
}

function preferredWorksheetName(group: DocketTypeGroup) {
  return group.prefix || group.label || (group.id === null ? 'Other' : `Docket Type ${group.id}`);
}

function addCasesWorksheet(params: { workbook: Workbook; sheetName: string; rows: CaseExcelExportRow[] }): Worksheet {
  const worksheet = params.workbook.addWorksheet(params.sheetName);
  worksheet.views = [{ state: 'frozen', ySplit: 1 }];
  worksheet.columns = CASE_EXCEL_COLUMNS.map((column) => ({ header: column.header, key: column.key, width: column.width }));
  worksheet.autoFilter = `A1:W1`;
  worksheet.pageSetup = { orientation: 'landscape', printTitlesRow: '1:1' };

  worksheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true };
    cell.alignment = { wrapText: true, vertical: 'middle', horizontal: 'center' };
  });

  for (const row of [...params.rows].sort(sortRowsByDocket)) {
    const excelRow = worksheet.addRow(CASE_EXCEL_COLUMNS.map((column) => column.key === 'date_received' ? parseDateOnly(row.date_received) : row[column.key] ?? ''));
    excelRow.eachCell((cell) => {
      cell.alignment = { wrapText: true, vertical: 'top' };
      if (cell.value instanceof Date) cell.numFmt = 'dd-mmm-yyyy';
    });
  }

  return worksheet;
}

function addSummaryWorksheet(workbook: Workbook, groups: DocketTypeGroup[], existingNames: Set<string>) {
  const worksheet = workbook.addWorksheet(sanitizeWorksheetName('Summary', existingNames));
  worksheet.views = [{ state: 'frozen', ySplit: 1 }];
  worksheet.columns = [
    { header: 'Docket Type', key: 'prefix', width: 18 },
    { header: 'Description', key: 'label', width: 36 },
    { header: 'Number of Cases', key: 'count', width: 18 },
  ];
  worksheet.autoFilter = 'A1:C1';

  worksheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true };
    cell.alignment = { wrapText: true, vertical: 'middle', horizontal: 'center' };
  });

  let total = 0;
  for (const group of groups) {
    total += group.rows.length;
    const row = worksheet.addRow({ prefix: group.prefix || 'Other', label: group.label, count: group.rows.length });
    row.getCell(3).numFmt = '#,##0';
  }

  const totalRow = worksheet.addRow({ prefix: 'Total', label: '', count: total });
  totalRow.font = { bold: true };
  totalRow.getCell(3).numFmt = '#,##0';
}

export async function downloadCasesWorkbook(
  rows: CaseExcelExportRow[],
  filters: {
    yearLabel: string;
    docketTypeLabel: string;
    docketTypeId: number | null;
  },
): Promise<void> {
  const ExcelJS = await import('exceljs');
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'OCP Docket Management System';
  workbook.created = new Date();

  const existingWorksheetNames = new Set<string>();
  const docketTypeGroups = groupRowsByDocketType(rows);

  if (filters.docketTypeId === null) {
    addSummaryWorksheet(workbook, docketTypeGroups, existingWorksheetNames);
  }

  for (const group of docketTypeGroups) {
    addCasesWorksheet({
      workbook,
      sheetName: sanitizeWorksheetName(preferredWorksheetName(group), existingWorksheetNames),
      rows: group.rows,
    });
  }

  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `OCP_Cases_${safeFilenamePart(filters.yearLabel)}_${safeFilenamePart(filters.docketTypeLabel)}_${localDateString()}.xlsx`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1_000);
}
