'use client';

import { useMemo, useState } from 'react';
import { AlertCircle, CheckCircle2, FileSpreadsheet, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Progress } from '@/components/ui/progress';
import { downloadCasesWorkbook } from '@/lib/exports/cases-excel';
import { getCasesExcelExportForCaseIds } from '@/lib/supabase/case-export';
import type { SupabaseQueryError } from '@/lib/supabase/types';

type ExportCasesButtonProps = {
  caseIds: number[];
  yearLabel: string;
  docketTypeLabel: string;
  docketTypeId: number | null;
  disabled?: boolean;
};

type ExportStep = 'idle' | 'loading' | 'validating' | 'building' | 'downloading' | 'complete' | 'error';

type ExportStatus = {
  step: ExportStep;
  title: string;
  detail: string;
  progress: number;
  error?: string;
};

const INITIAL_STATUS: ExportStatus = {
  step: 'idle',
  title: 'Ready to export',
  detail: 'Excel export has not started yet.',
  progress: 0,
};

function formatSupabaseError(error: SupabaseQueryError) {
  return [
    error.message,
    error.code ? `Code: ${error.code}` : null,
    error.details ? `Details: ${error.details}` : null,
    error.hint ? `Hint: ${error.hint}` : null,
    error.operation ? `Operation: ${error.operation}` : null,
    error.table ? `Table/RPC: ${error.table}` : null,
  ].filter(Boolean).join('\n');
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;

  try {
    return JSON.stringify(error, null, 2);
  } catch {
    return 'Unable to prepare the Excel export.';
  }
}

/** Exports the same case set that is currently rendered by the docket list. */
export function ExportCasesDialog({
  caseIds,
  yearLabel,
  docketTypeLabel,
  docketTypeId,
  disabled,
}: ExportCasesButtonProps) {
  const [isExporting, setIsExporting] = useState(false);
  const [isStatusOpen, setIsStatusOpen] = useState(false);
  const [status, setStatus] = useState<ExportStatus>(INITIAL_STATUS);

  const canCloseStatus = !isExporting;
  const progressLabel = useMemo(() => `${Math.max(0, Math.min(100, Math.round(status.progress)))}%`, [status.progress]);

  async function handleExport() {
    if (isExporting || caseIds.length === 0) return;

    setIsExporting(true);
    setIsStatusOpen(true);
    setStatus({
      step: 'loading',
      title: 'Loading case records',
      detail: `Requesting 0 of ${caseIds.length.toLocaleString()} cases from Supabase…`,
      progress: 10,
    });

    try {
      const result = await getCasesExcelExportForCaseIds({
        caseIds,
        onPageLoaded: (pageNumber, loadedCount) => {
          const boundedProgress = Math.min(65, 10 + (loadedCount / Math.max(caseIds.length, 1)) * 55);
          setStatus({
            step: 'loading',
            title: 'Loading case records',
            detail: `Loaded page ${pageNumber} with ${loadedCount.toLocaleString()} of ${caseIds.length.toLocaleString()} cases.`,
            progress: boundedProgress,
          });
        },
      });

      if (result.error) {
        throw new Error(formatSupabaseError(result.error));
      }

      setStatus({
        step: 'validating',
        title: 'Validating export data',
        detail: 'Checking that every case currently shown in the list was returned for export.',
        progress: 70,
      });

      const exportedCaseIds = new Set(result.data.map((row) => row.case_id));
      const hasCompleteCurrentView =
        exportedCaseIds.size === caseIds.length &&
        caseIds.every((caseId) => exportedCaseIds.has(caseId));

      if (!hasCompleteCurrentView) {
        const missingCaseIds = caseIds.filter((caseId) => !exportedCaseIds.has(caseId));
        throw new Error(`The export could not be completed because ${missingCaseIds.length.toLocaleString()} currently displayed case(s) were not retrieved. Missing case IDs: ${missingCaseIds.slice(0, 25).join(', ')}${missingCaseIds.length > 25 ? ', …' : ''}`);
      }

      setStatus({
        step: 'building',
        title: 'Building Excel workbook',
        detail: 'Creating sheets, formatting columns, and writing rows into the workbook.',
        progress: 78,
      });

      await downloadCasesWorkbook(result.data, { yearLabel, docketTypeLabel, docketTypeId }, (workbookStatus) => {
        setStatus({
          step: workbookStatus.step,
          title: workbookStatus.title,
          detail: workbookStatus.detail,
          progress: workbookStatus.progress,
        });
      });

      setStatus({
        step: 'complete',
        title: 'Excel export downloaded',
        detail: `Successfully exported ${result.data.length.toLocaleString()} case(s).`,
        progress: 100,
      });
      toast.success('Excel export downloaded.');
    } catch (error) {
      const message = getErrorMessage(error);
      setStatus({
        step: 'error',
        title: 'Excel export failed',
        detail: 'Review the real error below, then retry or send it to support.',
        progress: 100,
        error: message,
      });
      toast.error(message);
    } finally {
      setIsExporting(false);
    }
  }

  return (
    <>
      <Button
        type="button"
        variant="outline"
        className="size-9 px-0 sm:h-9 sm:w-auto sm:px-3"
        onClick={handleExport}
        disabled={disabled || isExporting || caseIds.length === 0}
        aria-label={isExporting ? 'Preparing Excel' : 'Export to Excel'}
      >
        <FileSpreadsheet className="size-4" />
        <span className="hidden sm:inline">{isExporting ? 'Preparing Excel…' : 'Export to Excel'}</span>
      </Button>

      <Dialog open={isStatusOpen} onOpenChange={(open) => canCloseStatus && setIsStatusOpen(open)}>
        <DialogContent showCloseButton={canCloseStatus} onInteractOutside={(event) => { if (!canCloseStatus) event.preventDefault(); }}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {status.step === 'error' ? <AlertCircle className="size-5 text-destructive" /> : status.step === 'complete' ? <CheckCircle2 className="size-5 text-green-600" /> : <Loader2 className="size-5 animate-spin text-primary" />}
              {status.title}
            </DialogTitle>
            <DialogDescription>{status.detail}</DialogDescription>
          </DialogHeader>

          <div className="space-y-3">
            <div className="flex items-center justify-between text-sm text-muted-foreground">
              <span>Status</span>
              <span>{progressLabel}</span>
            </div>
            <Progress value={status.progress} aria-label={`Excel export progress ${progressLabel}`} />
            {status.error ? (
              <pre className="max-h-56 overflow-auto whitespace-pre-wrap rounded-md border border-destructive/30 bg-destructive/10 p-3 text-xs text-destructive">
                {status.error}
              </pre>
            ) : null}
          </div>

          <DialogFooter>
            <Button type="button" onClick={() => setIsStatusOpen(false)} disabled={!canCloseStatus}>
              {status.step === 'complete' ? 'Done' : status.step === 'error' ? 'Close' : 'Please wait…'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
