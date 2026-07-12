'use client';

import { useEffect, useMemo, useState } from 'react';
import { FileSpreadsheet } from 'lucide-react';
import { toast } from 'sonner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { getCasesExcelExport, getCasesExportManifest } from '@/lib/supabase/case-export';
import { getDocketTypes } from '@/lib/supabase/queries';
import { downloadCasesWorkbook } from '@/lib/exports/cases-excel';
import { validateExportCompleteness } from '@/lib/exports/export-validation';

type DocketTypeOption = { id: number; prefix: string; displayLabel: string };

const ALL_YEARS = 'ALL_YEARS';
const ALL_TYPES = 'ALL_TYPES';

export function ExportCasesDialog({ availableYears, disabled }: { availableYears: number[]; disabled?: boolean }) {
  const [open, setOpen] = useState(false);
  const [docketTypes, setDocketTypes] = useState<DocketTypeOption[]>([]);
  const [docketTypesError, setDocketTypesError] = useState<string | null>(null);
  const [selectedYear, setSelectedYear] = useState(ALL_YEARS);
  const [selectedDocketType, setSelectedDocketType] = useState(ALL_TYPES);
  const [isExporting, setIsExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const [exportProgress, setExportProgress] = useState<string | null>(null);

  const yearOptions = useMemo(() => [...availableYears].sort((left, right) => right - left), [availableYears]);
  const selectedDocketTypeOption = docketTypes.find((option) => String(option.id) === selectedDocketType);
  const yearLabel = selectedYear === ALL_YEARS ? 'ALL_YEARS' : selectedYear;
  const docketTypeLabel = selectedDocketTypeOption?.prefix ?? 'ALL_TYPES';

  useEffect(() => {
    if (!open || docketTypes.length > 0 || docketTypesError) return;

    let isMounted = true;
    void getDocketTypes().then((result) => {
      if (!isMounted) return;
      if (result.error) {
        setDocketTypesError(result.error.message);
        return;
      }
      setDocketTypes(result.data.map((type) => ({ id: type.id, prefix: type.prefix, displayLabel: type.name ?? type.prefix })));
    });

    return () => { isMounted = false; };
  }, [docketTypes.length, docketTypesError, open]);

  async function handleExport() {
    if (isExporting) return;

    setIsExporting(true);
    setExportError(null);
    setExportProgress('Preparing export…');

    const docketYear = selectedYear === ALL_YEARS ? null : Number(selectedYear);
    const docketTypeId = selectedDocketType === ALL_TYPES ? null : Number(selectedDocketType);

    try {
      setExportProgress('Loading manifest…');
      const manifestResult = await getCasesExportManifest({ docketYear, docketTypeId });

      if (manifestResult.error) {
        throw new Error(manifestResult.error.message || 'Unable to load export manifest. Confirm the export migration has been applied.');
      }

      const expectedCaseCount = manifestResult.data.reduce((total, row) => total + Number(row.expected_case_count ?? 0), 0);
      if (expectedCaseCount === 0) {
        setExportError('No cases matched the selected year and docket type.');
        return;
      }

      setExportProgress('Loading export page 1…');
      const result = await getCasesExcelExport({
        docketYear,
        docketTypeId,
        onPageLoaded: (pageNumber, loadedCount) => {
          setExportProgress(`Loading export page ${pageNumber}… ${loadedCount.toLocaleString()} of ${expectedCaseCount.toLocaleString()} cases loaded`);
        },
      });

      if (result.error) {
        throw new Error(result.error.message || 'Unable to load export data. Confirm the export migration has been applied.');
      }

      setExportProgress('Validating export…');
      const validation = validateExportCompleteness(manifestResult.data, result.data);
      if (!validation.valid) {
        setExportError(validation.message);
        return;
      }

      setExportProgress('Generating workbook…');
      await downloadCasesWorkbook(result.data, {
        yearLabel,
        docketTypeLabel,
        docketTypeId,
      });
      toast.success('Excel export downloaded.');
      setOpen(false);
    } catch (error) {
      setExportError(error instanceof Error ? error.message : 'Unable to prepare the Excel export.');
    } finally {
      setIsExporting(false);
      setExportProgress(null);
    }
  }

  return (
    <Dialog open={open} onOpenChange={(nextOpen) => !isExporting && setOpen(nextOpen)}>
      <DialogTrigger asChild>
        <Button type="button" variant="outline" disabled={disabled}>
          <FileSpreadsheet className="mr-2 size-4" />
          Export to Excel
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Export current docket data to Excel</DialogTitle>
          <DialogDescription>Choose a docket year and docket type. Search, pagination, and visible rows do not limit this export.</DialogDescription>
        </DialogHeader>
        <div className="grid gap-4 py-2">
          <div className="grid gap-2">
            <Label htmlFor="export-year">Year</Label>
            <Select value={selectedYear} onValueChange={setSelectedYear} disabled={isExporting}>
              <SelectTrigger id="export-year"><SelectValue placeholder="All years" /></SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL_YEARS}>All years</SelectItem>
                {yearOptions.map((year) => <SelectItem key={year} value={String(year)}>{year}</SelectItem>)}
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="export-docket-type">Docket type</Label>
            <Select value={selectedDocketType} onValueChange={setSelectedDocketType} disabled={isExporting || Boolean(docketTypesError)}>
              <SelectTrigger id="export-docket-type"><SelectValue placeholder="All docket types" /></SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL_TYPES}>All docket types</SelectItem>
                {docketTypes.map((type) => <SelectItem key={type.id} value={String(type.id)}>{type.prefix} — {type.displayLabel}</SelectItem>)}
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">The workbook creates one worksheet for each docket type and year combination.</p>
          </div>
          {docketTypesError ? <Alert variant="destructive"><AlertDescription>{docketTypesError}</AlertDescription></Alert> : null}
          {exportProgress ? <p className="text-sm text-muted-foreground">{exportProgress}</p> : null}
          {exportError ? <Alert variant="destructive"><AlertDescription className="whitespace-pre-line">{exportError}</AlertDescription></Alert> : null}
        </div>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => setOpen(false)} disabled={isExporting}>Cancel</Button>
          <Button type="button" onClick={handleExport} disabled={isExporting || Boolean(docketTypesError)}>
            {isExporting ? 'Preparing Excel…' : 'Download Excel'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
