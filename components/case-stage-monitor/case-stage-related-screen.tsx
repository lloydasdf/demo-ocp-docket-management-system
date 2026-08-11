'use client';

import Link from 'next/link';
import { useCallback, useDeferredValue, useEffect, useRef, useState } from 'react';
import { ArrowLeft, CalendarDays, ChevronLeft, ChevronRight, Files, RefreshCw, Workflow } from 'lucide-react';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import {
  CaseStageRecords,
  EMPTY_CASE_STAGE_COLUMN_FILTERS,
  type CaseStageColumnFilters,
} from '@/components/case-stage-monitor/case-stage-records';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  getDeveloperCaseStageDistribution,
  getDeveloperCaseStageDocketTypes,
  getDeveloperCaseStageMonitor,
  getDeveloperCaseStageYears,
  type DeveloperCaseStageDistributionRecord,
  type DeveloperCaseStageDocketTypeSummary,
  type DeveloperCaseStageMonitorRecord,
  type DeveloperCaseStageQueue,
  type DeveloperCaseStageYearSummary,
} from '@/lib/supabase/queries';

const PAGE_SIZE = 25;

export const CASE_STAGE_QUEUE_DEFINITIONS: Record<DeveloperCaseStageQueue, { title: string; description: string }> = {
  all: { title: 'All active cases', description: 'Every active, non-archived case in the stage monitor.' },
  attention: { title: 'Cases needing attention', description: 'Cases matching at least one monitored workflow exception.' },
  unassigned: { title: 'Cases without an assigned prosecutor', description: 'Active cases with no current, non-voided prosecutor assignment.' },
  unapproved_resolution: { title: 'Case resolutions awaiting approval', description: 'Active case resolutions that do not yet have an active approval.' },
  unfiled_for_filing: { title: 'Approved filing actions not yet filed', description: 'FOR_FILING approval actions without a matching active court filing.' },
  unresolved_motion: { title: 'Cases with unresolved motions', description: 'Active motions recorded in the case timeline without an active motion resolution.' },
  motion_resolution_for_approval: { title: 'Motion resolutions awaiting approval', description: 'Active motion resolutions that do not yet have an active approval event.' },
  pending_petition: { title: 'Cases pending petition review', description: 'Cases whose current canonical stage is pending petition for review.' },
};

export function isDeveloperCaseStageQueue(value: string): value is DeveloperCaseStageQueue {
  return value in CASE_STAGE_QUEUE_DEFINITIONS;
}

export function formatCaseStageIdentifier(value: string) {
  return value
    .replace(/[_-]+/g, ' ')
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function CaseStageRelatedScreen({
  title,
  description,
  badge,
  queue = 'all',
  stageCode = null,
  initialDocketYear = null,
}: {
  title: string;
  description: string;
  badge: string;
  queue?: DeveloperCaseStageQueue;
  stageCode?: string | null;
  initialDocketYear?: number | null;
}) {
  const [rows, setRows] = useState<DeveloperCaseStageMonitorRecord[]>([]);
  const [yearOptions, setYearOptions] = useState<DeveloperCaseStageYearSummary[]>([]);
  const [docketTypeOptions, setDocketTypeOptions] = useState<DeveloperCaseStageDocketTypeSummary[]>([]);
  const [stageOptions, setStageOptions] = useState<DeveloperCaseStageDistributionRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [columnFilters, setColumnFilters] = useState<CaseStageColumnFilters>({
    ...EMPTY_CASE_STAGE_COLUMN_FILTERS,
    queue,
    stageCode: stageCode ?? 'all',
  });
  const deferredColumnFilters = useDeferredValue(columnFilters);
  const [docketYear, setDocketYear] = useState(initialDocketYear === null ? 'all' : String(initialDocketYear));
  const [docketType, setDocketType] = useState('all');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const requestSequence = useRef(0);
  const selectedDocketYear = docketYear === 'all' ? null : Number(docketYear);
  const selectedDocketTypeId = docketType === 'all' ? null : Number(docketType);
  const selectedDocketType = docketTypeOptions.find((option) => option.docket_type_id === selectedDocketTypeId) ?? null;
  const totalPages = Math.max(Math.ceil(total / PAGE_SIZE), 1);
  const firstVisibleRecord = total === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const lastVisibleRecord = Math.min(page * PAGE_SIZE, total);

  useEffect(() => {
    if (initialDocketYear !== null) return;
    const requestedYear = new URLSearchParams(window.location.search).get('year');
    const parsedYear = requestedYear === null ? Number.NaN : Number(requestedYear);
    if (Number.isInteger(parsedYear) && parsedYear > 0) setDocketYear(String(parsedYear));
    const requestedDocketType = new URLSearchParams(window.location.search).get('docketType');
    const parsedDocketType = requestedDocketType === null ? Number.NaN : Number(requestedDocketType);
    if (Number.isInteger(parsedDocketType) && parsedDocketType > 0) setDocketType(String(parsedDocketType));
  }, [initialDocketYear]);

  const loadFilterOptions = useCallback(async () => {
    const [yearsResult, docketTypesResult, stagesResult] = await Promise.all([
      getDeveloperCaseStageYears(),
      getDeveloperCaseStageDocketTypes(),
      getDeveloperCaseStageDistribution(selectedDocketYear, selectedDocketTypeId),
    ]);
    if (yearsResult.error || docketTypesResult.error || stagesResult.error) {
      setError(yearsResult.error?.message ?? docketTypesResult.error?.message ?? stagesResult.error?.message ?? 'Unable to load filter options.');
    } else {
      setYearOptions(yearsResult.data);
      setDocketTypeOptions(docketTypesResult.data);
      setStageOptions(stagesResult.data);
    }
  }, [selectedDocketTypeId, selectedDocketYear]);

  const loadCases = useCallback(async () => {
    const sequence = requestSequence.current + 1;
    requestSequence.current = sequence;
    setIsLoading(true);
    setError(null);

    const result = await getDeveloperCaseStageMonitor({
      page,
      pageSize: PAGE_SIZE,
      caseSearch: deferredColumnFilters.caseSearch,
      queue: deferredColumnFilters.queue,
      stageCode: deferredColumnFilters.stageCode === 'all' ? null : deferredColumnFilters.stageCode,
      prosecutorSearch: deferredColumnFilters.prosecutorSearch,
      minStageDays: deferredColumnFilters.minStageDays === '' ? null : Number(deferredColumnFilters.minStageDays),
      maxStageDays: deferredColumnFilters.maxStageDays === '' ? null : Number(deferredColumnFilters.maxStageDays),
      latestEventSearch: deferredColumnFilters.latestEventSearch,
      docketYear: selectedDocketYear,
      docketTypeId: selectedDocketTypeId,
    });

    if (requestSequence.current !== sequence) return;
    if (result.error) {
      setRows([]);
      setTotal(0);
      setError(result.error.message);
    } else {
      setRows(result.data.rows);
      setTotal(result.data.total);
    }
    setIsLoading(false);
  }, [deferredColumnFilters, page, selectedDocketTypeId, selectedDocketYear]);

  useEffect(() => { void loadFilterOptions(); }, [loadFilterOptions]);
  useEffect(() => { void loadCases(); }, [loadCases]);

  function updateColumnFilters(filters: CaseStageColumnFilters) {
    setColumnFilters(filters);
    setPage(1);
  }

  function resetColumnFilters() {
    setColumnFilters({ ...EMPTY_CASE_STAGE_COLUMN_FILTERS, queue, stageCode: stageCode ?? 'all' });
    setPage(1);
  }

  return (
    <RoleRouteGuard route="/developer/case-stage-monitor">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-[1500px] space-y-4 sm:space-y-6">
            <Button className="-ml-2 max-w-full justify-start whitespace-normal" variant="ghost" size="sm" asChild>
              <Link href="/developer/case-stage-monitor"><ArrowLeft className="h-4 w-4" />Back to case stage monitor</Link>
            </Button>

            <header className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-2">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary"><Workflow className="h-5 w-5" /></div>
                  <h1 className="min-w-0 break-words text-2xl font-bold tracking-tight sm:text-3xl">{title}</h1>
                  <Badge variant="secondary">{badge}</Badge>
                </div>
                <p className="max-w-3xl text-sm leading-6 text-muted-foreground">{description}</p>
              </div>
              <Button className="w-full sm:w-auto" variant="outline" onClick={() => void Promise.all([loadFilterOptions(), loadCases()])} disabled={isLoading}>
                <RefreshCw className={`mr-2 h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />Refresh
              </Button>
            </header>

            {error ? <Alert variant="destructive"><AlertTitle>Unable to load monitored cases</AlertTitle><AlertDescription>{error}</AlertDescription></Alert> : null}

            <section className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3">
              <Card className="py-0"><CardContent className="p-4 sm:p-5"><p className="text-sm text-muted-foreground">Matching cases</p><p className="mt-2 text-2xl font-semibold sm:text-3xl">{total.toLocaleString('en-PH')}</p></CardContent></Card>
              <Card className="py-0"><CardContent className="p-4 sm:p-5"><p className="text-sm text-muted-foreground">Docket year</p><p className="mt-2 text-xl font-semibold sm:text-3xl">{selectedDocketYear ?? 'All years'}</p></CardContent></Card>
              <Card className="col-span-2 py-0 lg:col-span-1"><CardContent className="p-4 sm:p-5"><p className="text-sm text-muted-foreground">Docket type</p><p className="mt-2 break-words text-xl font-semibold sm:text-3xl">{selectedDocketType?.docket_type_prefix ?? selectedDocketType?.docket_type_name ?? 'All types'}</p></CardContent></Card>
            </section>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6">
                <CardTitle>Cases in this view</CardTitle>
                <CardDescription>Use the general filters first, then narrow every data column directly in the table header or mobile filter panel.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-5 px-4 sm:px-6">
                <div className="grid gap-3 sm:grid-cols-2" aria-label="General case stage filters">
                  <Select value={docketYear} onValueChange={(value) => { setDocketYear(value); setPage(1); }}>
                    <SelectTrigger className="w-full" aria-label="Filter this view by docket year"><CalendarDays className="h-4 w-4" /><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All docket years</SelectItem>
                      {yearOptions.map((year) => year.docket_year === null ? null : <SelectItem key={year.docket_year} value={String(year.docket_year)}>{year.docket_year}</SelectItem>)}
                    </SelectContent>
                  </Select>
                  <Select value={docketType} onValueChange={(value) => { setDocketType(value); setPage(1); }}>
                    <SelectTrigger className="w-full" aria-label="Filter this view by docket type"><Files className="h-4 w-4" /><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All docket types</SelectItem>
                      {docketTypeOptions.map((type) => type.docket_type_id === null ? null : <SelectItem key={type.docket_type_id} value={String(type.docket_type_id)}>{type.docket_type_prefix ?? type.docket_type_name ?? `Type ${type.docket_type_id}`}{type.docket_type_name && type.docket_type_prefix ? ` — ${type.docket_type_name}` : ''}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>

                <CaseStageRecords rows={rows} isLoading={isLoading} filters={columnFilters} stageOptions={stageOptions} onFiltersChange={updateColumnFilters} onResetFilters={resetColumnFilters} />

                <div className="flex flex-col gap-3 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
                  <p>Showing {firstVisibleRecord.toLocaleString('en-PH')}–{lastVisibleRecord.toLocaleString('en-PH')} of {total.toLocaleString('en-PH')}</p>
                  <div className="flex items-center justify-between gap-2 sm:justify-start">
                    <span>Page {page} of {totalPages}</span>
                    <Button className="size-10" variant="outline" size="icon" onClick={() => setPage((value) => Math.max(1, value - 1))} disabled={page <= 1 || isLoading} aria-label="Previous page"><ChevronLeft className="h-4 w-4" /></Button>
                    <Button className="size-10" variant="outline" size="icon" onClick={() => setPage((value) => Math.min(totalPages, value + 1))} disabled={page >= totalPages || isLoading} aria-label="Next page"><ChevronRight className="h-4 w-4" /></Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
