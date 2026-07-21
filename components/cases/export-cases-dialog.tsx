'use client';

import { useState } from 'react';
import { FileSpreadsheet } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { downloadCasesWorkbook } from '@/lib/exports/cases-excel';
import { getCasesExcelExportForCaseIds } from '@/lib/supabase/case-export';

type ExportCasesButtonProps = {
  caseIds: number[];
  yearLabel: string;
  docketTypeLabel: string;
  docketTypeId: number | null;
  disabled?: boolean;
};

/** Exports the same case set that is currently rendered by the docket list. */
export function ExportCasesDialog({
  caseIds,
  yearLabel,
  docketTypeLabel,
  docketTypeId,
  disabled,
}: ExportCasesButtonProps) {
  const [isExporting, setIsExporting] = useState(false);

  async function handleExport() {
    if (isExporting || caseIds.length === 0) return;

    setIsExporting(true);

    try {
      const result = await getCasesExcelExportForCaseIds({ caseIds });
      if (result.error) {
        throw new Error(result.error.message || 'Unable to load export data. Confirm the export migration has been applied.');
      }

      const exportedCaseIds = new Set(result.data.map((row) => row.case_id));
      const hasCompleteCurrentView =
        exportedCaseIds.size === caseIds.length &&
        caseIds.every((caseId) => exportedCaseIds.has(caseId));

      if (!hasCompleteCurrentView) {
        throw new Error('The export could not be completed because not all currently displayed cases were retrieved. Please try again.');
      }

      await downloadCasesWorkbook(result.data, { yearLabel, docketTypeLabel, docketTypeId });
      toast.success('Excel export downloaded.');
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Unable to prepare the Excel export.');
    } finally {
      setIsExporting(false);
    }
  }

  return (
    <Button type="button" variant="outline" onClick={handleExport} disabled={disabled || isExporting || caseIds.length === 0}>
      <FileSpreadsheet className="mr-2 size-4" />
      {isExporting ? 'Preparing Excel…' : 'Export to Excel'}
    </Button>
  );
}
