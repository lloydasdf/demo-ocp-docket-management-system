'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { dockets } from '@/lib/dummy-data';
import { getCasesCompact } from '@/lib/supabase/queries';
import type { ViewRow } from '@/lib/supabase/types';

type CompactCase = ViewRow<'v_cases_table_compact'>;
type DocketTypeFilter = 'All' | 'INV' | 'INQ' | 'PE' | 'DC20';
type DocketYearFilter = 'All' | '2022';

const DOCKET_TYPE_FILTERS: DocketTypeFilter[] = ['All', 'INV', 'INQ', 'PE', 'DC20'];
const DOCKET_YEAR_FILTERS: DocketYearFilter[] = ['2022', 'All'];

const docketNumberCollator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });

const CASE_TABLE_COLUMNS = [
  { key: 'docketNumber', label: 'Docket number', initialWidth: 220, minWidth: 160 },
  { key: 'complainant', label: 'Complainant', initialWidth: 300, minWidth: 200 },
  { key: 'respondent', label: 'Respondent', initialWidth: 300, minWidth: 200 },
  { key: 'violation', label: 'Violation', initialWidth: 260, minWidth: 180 },
  { key: 'assignedProsecutor', label: 'Assigned Prosecutor', initialWidth: 240, minWidth: 180 },
  { key: 'currentStatus', label: 'Current Status', initialWidth: 180, minWidth: 150 },
] as const;

type CaseTableColumnKey = (typeof CASE_TABLE_COLUMNS)[number]['key'];
type ColumnWidths = Record<CaseTableColumnKey, number>;

function getInitialColumnWidths(): ColumnWidths {
  return CASE_TABLE_COLUMNS.reduce((widths, column) => {
    widths[column.key] = column.initialWidth;
    return widths;
  }, {} as ColumnWidths);
}

function formatDisplayDocketNumber(docketNumber: string | null) {
  return docketNumber?.replace(/^IV-31-/i, '') ?? '—';
}

function getCaseKey(caseDetail: CompactCase) {
  return `${caseDetail.case_id ?? 'case'}-${caseDetail.docket_number ?? 'docket'}`;
}

function getFallbackCases(): CompactCase[] {
  return dockets.flatMap((docket) =>
    docket.cases.map((caseDetail) => ({
      assigned_prosecutor: caseDetail.prosecutor ?? null,
      case_id: Number.parseInt(caseDetail.id.replace(/\D/g, ''), 10) || null,
      complainant:
        caseDetail.complainants.length > 0
          ? `${caseDetail.complainants[0].firstName} ${caseDetail.complainants[0].lastName}${
              caseDetail.complainants.length > 1 ? ' et al.' : ''
            }`
          : null,
      created_at: docket.createdDate,
      current_status: caseDetail.status,
      date_received: caseDetail.dateOfIncident,
      docket_month_code: null,
      docket_number: docket.docketNumber,
      docket_sequence_number: null,
      docket_type: docket.docketNumber.split('-')[0] ?? null,
      docket_year: Number.parseInt(docket.docketNumber.match(/\d{4}/)?.[0] ?? '', 10) || null,
      respondent:
        caseDetail.respondents.length > 0
          ? `${caseDetail.respondents[0].firstName} ${caseDetail.respondents[0].lastName}${
              caseDetail.respondents.length > 1 ? ' et al.' : ''
            }`
          : null,
      status_background_hex: null,
      status_border_hex: null,
      status_code: caseDetail.status,
      status_color_key: null,
      status_text_hex: null,
      updated_at: null,
      violations:
        caseDetail.violations.length > 0
          ? caseDetail.violations.map((violation) => violation.statute).join(', ')
          : null,
    })),
  );
}

export default function CasesPage() {
  const router = useRouter();
  const fallbackCases = useMemo(getFallbackCases, []);
  const [cases, setCases] = useState<CompactCase[]>([]);
  const [selectedDocketType, setSelectedDocketType] = useState<DocketTypeFilter>('All');
  const [selectedDocketYear, setSelectedDocketYear] = useState<DocketYearFilter>('2022');
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);
  const [selectedCaseKey, setSelectedCaseKey] = useState<string | null>(null);
  const [columnWidths, setColumnWidths] = useState<ColumnWidths>(() => getInitialColumnWidths());

  useEffect(() => {
    let isMounted = true;

    async function loadCases() {
      setIsLoading(true);
      const result = await getCasesCompact({
        docketType: selectedDocketType === 'All' ? undefined : selectedDocketType,
        docketYear: selectedDocketYear === 'All' ? undefined : Number(selectedDocketYear),
      });

      if (!isMounted) {
        return;
      }

      if (result.error) {
        setErrorMessage(result.error.message);
        setCases(
          fallbackCases.filter((caseDetail) => {
            const matchesType = selectedDocketType === 'All' || caseDetail.docket_type === selectedDocketType;
            const matchesYear = selectedDocketYear === 'All' || caseDetail.docket_year === Number(selectedDocketYear);
            return matchesType && matchesYear;
          }),
        );
        setIsUsingFallback(true);
      } else {
        setErrorMessage(null);
        setCases(result.data);
        setIsUsingFallback(false);
      }

      setIsLoading(false);
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, [fallbackCases, selectedDocketType, selectedDocketYear]);

  const sortedCases = useMemo(
    () =>
      [...cases].sort((left, right) =>
        docketNumberCollator.compare(
          formatDisplayDocketNumber(left.docket_number),
          formatDisplayDocketNumber(right.docket_number),
        ),
      ),
    [cases],
  );

  const tableWidth = useMemo(
    () => CASE_TABLE_COLUMNS.reduce((total, column) => total + columnWidths[column.key], 0),
    [columnWidths],
  );

  function handleColumnResize(columnKey: CaseTableColumnKey, startX: number) {
    const column = CASE_TABLE_COLUMNS.find((candidate) => candidate.key === columnKey);
    const startWidth = columnWidths[columnKey];

    function handlePointerMove(event: PointerEvent) {
      const nextWidth = Math.max(column?.minWidth ?? 120, startWidth + event.clientX - startX);
      setColumnWidths((currentWidths) => ({ ...currentWidths, [columnKey]: nextWidth }));
    }

    function handlePointerUp() {
      document.removeEventListener('pointermove', handlePointerMove);
      document.removeEventListener('pointerup', handlePointerUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    }

    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  }

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="flex min-w-0 flex-1 flex-col overflow-hidden p-4 pt-16 md:p-8">
        <div className="flex min-h-0 flex-1 flex-col gap-6">
          <div className="shrink-0">
            <h1 className="text-3xl font-bold text-foreground">All Cases</h1>
            <p className="text-muted-foreground mt-1">Browse all cases in the system</p>
          </div>

          {errorMessage ? (
            <Alert variant="destructive" className="shrink-0">
              <AlertTitle>Unable to load live Supabase cases</AlertTitle>
              <AlertDescription>{errorMessage} Showing fallback dummy data.</AlertDescription>
            </Alert>
          ) : null}

          <Card className="min-h-0 flex-1 gap-4 overflow-hidden py-4">
            <CardHeader className="shrink-0 gap-4 px-4 md:px-6">
              <div>
                <CardTitle>Cases List</CardTitle>
                <CardDescription>
                  {isLoading
                    ? 'Loading live cases from Supabase...'
                    : isUsingFallback
                      ? `${cases.length} fallback cases`
                      : `${cases.length} total cases`}
                </CardDescription>
              </div>

              <div className="grid gap-4 sm:max-w-xl sm:grid-cols-2">
                <div className="flex flex-col gap-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="docket-type-filter">
                    Docket Type
                  </label>
                  <Select
                    value={selectedDocketType}
                    onValueChange={(value) => setSelectedDocketType(value as DocketTypeFilter)}
                  >
                    <SelectTrigger id="docket-type-filter" className="w-full">
                      <SelectValue placeholder="Filter by docket type" />
                    </SelectTrigger>
                    <SelectContent>
                      {DOCKET_TYPE_FILTERS.map((docketType) => (
                        <SelectItem key={docketType} value={docketType}>
                          {docketType}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="docket-year-filter">
                    Docket Year
                  </label>
                  <Select
                    value={selectedDocketYear}
                    onValueChange={(value) => setSelectedDocketYear(value as DocketYearFilter)}
                  >
                    <SelectTrigger id="docket-year-filter" className="w-full">
                      <SelectValue placeholder="Filter by docket year" />
                    </SelectTrigger>
                    <SelectContent>
                      {DOCKET_YEAR_FILTERS.map((docketYear) => (
                        <SelectItem key={docketYear} value={docketYear}>
                          {docketYear === 'All' ? 'All years' : docketYear}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </CardHeader>

            <CardContent className="min-h-0 flex-1 overflow-hidden px-4 md:px-6">
              {isLoading ? (
                <div className="py-8 text-center text-sm text-muted-foreground">Loading cases...</div>
              ) : cases.length === 0 ? (
                <div className="py-8 text-center text-sm text-muted-foreground">No cases found.</div>
              ) : (
                <div
                  className="h-full min-h-0 overflow-auto rounded-lg border border-border"
                  aria-label="Cases table with horizontal scrollbar"
                >
                  <Table className="table-fixed" style={{ width: tableWidth, minWidth: '100%' }}>
                    <colgroup>
                      {CASE_TABLE_COLUMNS.map((column) => (
                        <col key={column.key} style={{ width: columnWidths[column.key] }} />
                      ))}
                    </colgroup>
                    <TableHeader className="sticky top-0 z-20 bg-muted shadow-sm">
                      <TableRow className="bg-muted hover:bg-muted">
                        {CASE_TABLE_COLUMNS.map((column) => (
                          <TableHead key={column.key} className="relative select-none whitespace-nowrap pr-4 uppercase">
                            {column.label}
                            <button
                              type="button"
                              className="absolute right-0 top-0 h-full w-2 cursor-col-resize touch-none border-r border-transparent hover:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                              aria-label={`Resize ${column.label} column`}
                              onPointerDown={(event) => {
                                event.preventDefault();
                                handleColumnResize(column.key, event.clientX);
                              }}
                            />
                          </TableHead>
                        ))}
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {sortedCases.map((caseDetail) => {
                        const caseKey = getCaseKey(caseDetail);
                        const isSelected = selectedCaseKey === caseKey;

                        return (
                          <TableRow
                            key={caseKey}
                            aria-selected={isSelected}
                            className={`cursor-pointer ${isSelected ? 'bg-primary/10 hover:bg-primary/15' : 'hover:bg-muted/50'}`}
                            tabIndex={caseDetail.case_id ? 0 : -1}
                            onClick={() => setSelectedCaseKey(caseKey)}
                            onDoubleClick={() => {
                              if (caseDetail.case_id) {
                                router.push(`/cases/${caseDetail.case_id}`);
                              }
                            }}
                            onKeyDown={(event) => {
                              if (!caseDetail.case_id) {
                                return;
                              }

                              if (event.key === 'Enter') {
                                event.preventDefault();
                                router.push(`/cases/${caseDetail.case_id}`);
                              }

                              if (event.key === ' ') {
                                event.preventDefault();
                                setSelectedCaseKey(caseKey);
                              }
                            }}
                          >
                            <TableCell className="truncate font-medium text-primary">
                              {formatDisplayDocketNumber(caseDetail.docket_number)}
                            </TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.complainant ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.respondent ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.violations ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.assigned_prosecutor ?? '—'}</TableCell>
                            <TableCell>
                              <Badge variant="outline">{caseDetail.current_status ?? '—'}</Badge>
                            </TableCell>
                          </TableRow>
                        );
                      })}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}
