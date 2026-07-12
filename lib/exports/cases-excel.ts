import type { CaseExcelExportRow } from '@/lib/supabase/case-export';

type WorkbookColumn = { header: string; key: keyof CaseExcelExportRow; width: number };

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

export async function downloadCasesWorkbook(rows: CaseExcelExportRow[], filters: { yearLabel: string; docketTypeLabel: string }): Promise<void> {
  const ExcelJS = await import('exceljs');
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'OCP Docket Management System';
  workbook.created = new Date();

  const worksheet = workbook.addWorksheet('Cases');
  worksheet.views = [{ state: 'frozen', ySplit: 1 }];
  worksheet.columns = CASE_EXCEL_COLUMNS.map((column) => ({ header: column.header, key: column.key, width: column.width }));
  worksheet.autoFilter = `A1:W1`;
  worksheet.pageSetup = { orientation: 'landscape', printTitlesRow: '1:1' };

  worksheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true };
    cell.alignment = { wrapText: true, vertical: 'middle', horizontal: 'center' };
  });

  for (const row of rows) {
    const excelRow = worksheet.addRow(CASE_EXCEL_COLUMNS.map((column) => column.key === 'date_received' ? parseDateOnly(row.date_received) : row[column.key] ?? ''));
    excelRow.eachCell((cell) => {
      cell.alignment = { wrapText: true, vertical: 'top' };
      if (cell.value instanceof Date) cell.numFmt = 'dd-mmm-yyyy';
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
