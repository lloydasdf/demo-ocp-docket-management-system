'use client';

import Link from 'next/link';
import { useCallback, useDeferredValue, useEffect, useMemo, useRef, useState } from 'react';
import type { LucideIcon } from 'lucide-react';
import {
  Activity,
  ArrowUpRight,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  ClipboardCheck,
  Files,
  FileClock,
  FolderClock,
  Gavel,
  RefreshCw,
  Search,
  UserRoundX,
  Workflow,
} from 'lucide-react';

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
import { cn } from '@/lib/utils';
import {
  getDeveloperCaseStageDistribution,
  getDeveloperCaseStageDocketTypes,
  getDeveloperCaseStageMonitor,
  getDeveloperCaseStageMonitorOverview,
  getDeveloperCaseStageYears,
  type DeveloperCaseStageDistributionRecord,
  type DeveloperCaseStageDocketTypeSummary,
  type DeveloperCaseStageMonitorOverview,
  type DeveloperCaseStageMonitorRecord,
  type DeveloperCaseStageQueue,
  type DeveloperCaseStageYearSummary,
} from '@/lib/supabase/queries';

const PAGE_SIZE = 25;
const EMPTY_OVERVIEW: DeveloperCaseStageMonitorOverview = {
  docket_year: null,
  docket_type_id: null,
  docket_type_prefix: null,
  docket_type_name: null,
  total_active_case_count: 0,
  attention_case_count: 0,
  unassigned_prosecutor_count: 0,
  unapproved_case_resolution_count: 0,
  unfiled_for_filing_count: 0,
  unresolved_motion_count: 0,
  unapproved_motion_resolution_count: 0,
  pending_petition_for_review_count: 0,
  oldest_attention_date: null,
  latest_event_at: null,
};

const dateTimeFormatter = new Intl.DateTimeFormat('en-PH', {
  timeZone: 'Asia/Manila',
  dateStyle: 'medium',
  timeStyle: 'short',
});

const numberFormatter = new Intl.NumberFormat('en-PH');

function formatDateTime(value: string | null) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : dateTimeFormatter.format(date);
}

function MetricCard({
  title,
  value,
  description,
  icon: Icon,
  active,
  href,
}: {
  title: string;
  value: number;
  description: string;
  icon: LucideIcon;
  active: boolean;
  href: string;
}) {
  return (
    <Link className="group min-w-0 text-left" href={href} aria-current={active ? 'page' : undefined}>
      <Card className={cn('relative h-full gap-0 py-0 transition-colors group-hover:border-primary/50 group-hover:bg-muted/30', active && 'border-primary ring-2 ring-primary/20')}>
        <CardContent className="min-w-0 p-4 sm:p-5">
          <div className="min-w-0 pr-10">
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <p className="mt-2 text-2xl font-semibold tracking-tight sm:text-3xl">{numberFormatter.format(value)}</p>
            <p className="mt-1 break-words text-xs leading-5 text-muted-foreground">{description}</p>
          </div>
          <div className="absolute right-3 top-3 rounded-lg bg-primary/10 p-2 text-primary sm:right-5 sm:top-5">
            <Icon className="h-5 w-5" />
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

export default function DeveloperCaseStageMonitorPage() {
  const [rows, setRows] = useState<DeveloperCaseStageMonitorRecord[]>([]);
  const [overview, setOverview] = useState<DeveloperCaseStageMonitorOverview>(EMPTY_OVERVIEW);
  const [distribution, setDistribution] = useState<DeveloperCaseStageDistributionRecord[]>([]);
  const [yearOptions, setYearOptions] = useState<DeveloperCaseStageYearSummary[]>([]);
  const [docketTypeOptions, setDocketTypeOptions] = useState<DeveloperCaseStageDocketTypeSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [columnFilters, setColumnFilters] = useState<CaseStageColumnFilters>({
    ...EMPTY_CASE_STAGE_COLUMN_FILTERS,
    queue: 'attention',
  });
  const deferredColumnFilters = useDeferredValue(columnFilters);
  const [docketYear, setDocketYear] = useState('all');
  const [docketType, setDocketType] = useState('all');
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshingSummary, setIsRefreshingSummary] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const requestSequence = useRef(0);

  const totalPages = Math.max(Math.ceil(total / PAGE_SIZE), 1);
  const firstVisibleRecord = total === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const lastVisibleRecord = Math.min(page * PAGE_SIZE, total);
  const maxStageCount = useMemo(() => Math.max(...distribution.map((stage) => stage.case_count), 1), [distribution]);
  const selectedDocketYear = docketYear === 'all' ? null : Number(docketYear);
  const selectedDocketTypeId = docketType === 'all' ? null : Number(docketType);
  const supportParams = new URLSearchParams();
  if (selectedDocketYear !== null) supportParams.set('year', String(selectedDocketYear));
  if (selectedDocketTypeId !== null) supportParams.set('docketType', String(selectedDocketTypeId));
  const supportParamString = supportParams.toString();
  const supportQuery = supportParamString ? `?${supportParamString}` : '';
  const docketTypeQuery = selectedDocketTypeId === null ? '' : `?docketType=${selectedDocketTypeId}`;

  const loadSummary = useCallback(async () => {
    setIsRefreshingSummary(true);
    const [overviewResult, distributionResult, yearsResult, docketTypesResult] = await Promise.all([
      getDeveloperCaseStageMonitorOverview(selectedDocketYear, selectedDocketTypeId),
      getDeveloperCaseStageDistribution(selectedDocketYear, selectedDocketTypeId),
      getDeveloperCaseStageYears(),
      getDeveloperCaseStageDocketTypes(),
    ]);

    if (overviewResult.error || distributionResult.error || yearsResult.error || docketTypesResult.error) {
      setError(overviewResult.error?.message ?? distributionResult.error?.message ?? yearsResult.error?.message ?? docketTypesResult.error?.message ?? 'Unable to load case-stage summary.');
    } else {
      setOverview(overviewResult.data);
      setDistribution(distributionResult.data);
      setYearOptions(yearsResult.data);
      setDocketTypeOptions(docketTypesResult.data);
    }
    setIsRefreshingSummary(false);
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

  useEffect(() => {
    void loadSummary();
  }, [loadSummary]);

  useEffect(() => {
    void loadCases();
  }, [loadCases]);

  function updateColumnFilters(filters: CaseStageColumnFilters) {
    setColumnFilters(filters);
    setPage(1);
  }

  function resetColumnFilters() {
    setColumnFilters({ ...EMPTY_CASE_STAGE_COLUMN_FILTERS, queue: 'attention' });
    setPage(1);
  }

  async function refreshAll() {
    await Promise.all([loadSummary(), loadCases()]);
  }

  const metricCards: Array<{
    queue: DeveloperCaseStageQueue;
    title: string;
    value: number;
    description: string;
    icon: LucideIcon;
    href: string;
  }> = [
    { queue: 'all', title: 'Active cases', value: overview.total_active_case_count, description: 'All non-archived cases', icon: Activity, href: `/developer/case-stage-monitor/queues/all${supportQuery}` },
    { queue: 'attention', title: 'Needs attention', value: overview.attention_case_count, description: 'Cases in any monitored queue', icon: Workflow, href: `/developer/case-stage-monitor/queues/attention${supportQuery}` },
    { queue: 'unassigned', title: 'No prosecutor', value: overview.unassigned_prosecutor_count, description: 'No active assignment', icon: UserRoundX, href: `/developer/case-stage-monitor/queues/unassigned${supportQuery}` },
    { queue: 'unapproved_resolution', title: 'Resolution approval', value: overview.unapproved_case_resolution_count, description: 'Case resolutions not approved', icon: ClipboardCheck, href: `/developer/case-stage-monitor/queues/unapproved_resolution${supportQuery}` },
    { queue: 'unfiled_for_filing', title: 'Awaiting filing', value: overview.unfiled_for_filing_count, description: 'Approved filing actions not filed', icon: Gavel, href: `/developer/case-stage-monitor/queues/unfiled_for_filing${supportQuery}` },
    { queue: 'unresolved_motion', title: 'Unresolved motions', value: overview.unresolved_motion_count, description: 'Received motions without resolution', icon: FolderClock, href: `/developer/case-stage-monitor/queues/unresolved_motion${supportQuery}` },
    { queue: 'motion_resolution_for_approval', title: 'Motion approval', value: overview.unapproved_motion_resolution_count, description: 'Motion resolutions not approved', icon: FileClock, href: `/developer/case-stage-monitor/queues/motion_resolution_for_approval${supportQuery}` },
    { queue: 'pending_petition', title: 'Petition review', value: overview.pending_petition_for_review_count, description: 'Cases pending petition review', icon: Search, href: `/developer/case-stage-monitor/queues/pending_petition${supportQuery}` },
  ];

  return (
    <RoleRouteGuard route="/developer/case-stage-monitor">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-[1600px] space-y-4 sm:space-y-6">
            <header className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary"><Workflow className="h-5 w-5" /></div>
                  <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Case Stage Monitor</h1>
                  <Badge variant="secondary">Developer only</Badge>
                </div>
                <p className="max-w-4xl text-sm leading-6 text-muted-foreground">
                  Monitor current workflow stages, outstanding resolutions and motions, filing readiness, prosecutor assignment, and the latest case event.
                </p>
              </div>
              <Button className="w-full sm:w-auto" variant="outline" onClick={() => void refreshAll()} disabled={isLoading || isRefreshingSummary}>
                <RefreshCw className={cn('mr-2 h-4 w-4', (isLoading || isRefreshingSummary) && 'animate-spin')} />Refresh
              </Button>
            </header>

            {error ? <Alert variant="destructive"><AlertTitle>Unable to load case-stage monitoring</AlertTitle><AlertDescription>{error}</AlertDescription></Alert> : null}

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardContent className="px-4 sm:px-6">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 font-semibold"><CalendarDays className="h-4 w-4 text-primary" />General filters</div>
                    <p className="text-sm text-muted-foreground">Docket year and docket type update every total, stage, and case shown below.</p>
                  </div>
                  <div className="grid w-full gap-2 sm:grid-cols-2 xl:w-auto xl:grid-cols-[14rem_18rem_auto]">
                    <Select value={docketYear} onValueChange={(value) => { setDocketYear(value); setPage(1); }}>
                      <SelectTrigger className="w-full" aria-label="Filter case stage monitor by docket year"><CalendarDays className="h-4 w-4" /><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All docket years</SelectItem>
                        {yearOptions.map((year) => year.docket_year === null ? null : (
                          <SelectItem key={year.docket_year} value={String(year.docket_year)}>
                            {year.docket_year}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <Select value={docketType} onValueChange={(value) => { setDocketType(value); setPage(1); }}>
                      <SelectTrigger className="w-full" aria-label="Filter case stage monitor by docket type"><Files className="h-4 w-4" /><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All docket types</SelectItem>
                        {docketTypeOptions.map((type) => type.docket_type_id === null ? null : (
                          <SelectItem key={type.docket_type_id} value={String(type.docket_type_id)}>
                            {type.docket_type_prefix ?? type.docket_type_name ?? `Type ${type.docket_type_id}`}{type.docket_type_name && type.docket_type_prefix ? ` — ${type.docket_type_name}` : ''}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <Button className="sm:col-span-2 xl:col-span-1" variant="outline" asChild>
                      <Link href={selectedDocketYear === null ? `/developer/case-stage-monitor/queues/all${supportQuery}` : `/developer/case-stage-monitor/years/${selectedDocketYear}${docketTypeQuery}`}>
                        Open filtered view<ArrowUpRight className="h-4 w-4" />
                      </Link>
                    </Button>
                  </div>
                </div>
                {yearOptions.length > 0 ? (
                  <div className="mt-4 flex gap-2 overflow-x-auto pb-1" aria-label="Docket year supporting screens">
                    {yearOptions.map((year) => year.docket_year === null ? null : (
                      <Button key={year.docket_year} className="shrink-0" size="sm" variant={docketYear === String(year.docket_year) ? 'default' : 'secondary'} asChild>
                        <Link href={`/developer/case-stage-monitor/years/${year.docket_year}${docketTypeQuery}`}>{year.docket_year}</Link>
                      </Button>
                    ))}
                  </div>
                ) : null}
              </CardContent>
            </Card>

            <section className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
              {metricCards.map((card) => (
                <MetricCard key={card.queue} {...card} active={columnFilters.queue === card.queue} />
              ))}
            </section>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6">
                <CardTitle>Current stage distribution</CardTitle>
                <CardDescription>Open a stage drill-down. Attention counts can overlap across monitoring categories.</CardDescription>
              </CardHeader>
              <CardContent className="px-4 sm:px-6">
                {isRefreshingSummary ? (
                  <div className="flex min-h-28 items-center justify-center text-sm text-muted-foreground">Loading stage distribution…</div>
                ) : distribution.length === 0 ? (
                  <div className="flex min-h-28 items-center justify-center text-sm text-muted-foreground">No current stages were found.</div>
                ) : (
                  <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
                    {distribution.map((stage) => {
                      const selected = columnFilters.stageCode === stage.stage_code;
                      const width = Math.max((stage.case_count / maxStageCount) * 100, 3);
                      return (
                        <Link
                          key={stage.stage_code}
                          href={`/developer/case-stage-monitor/stages/${encodeURIComponent(stage.stage_code)}${supportQuery}`}
                          className={cn('min-w-0 rounded-lg border p-3 text-left transition-colors hover:border-primary/50 hover:bg-muted/40', selected && 'border-primary bg-primary/5 ring-2 ring-primary/20')}
                          aria-current={selected ? 'page' : undefined}
                        >
                          <div className="flex min-w-0 items-start justify-between gap-3">
                            <div className="min-w-0"><p className="break-words text-sm font-medium">{stage.stage_label}</p><p className="mt-1 text-xs text-muted-foreground">{numberFormatter.format(stage.attention_case_count)} need attention</p></div>
                            <span className="shrink-0 text-lg font-semibold">{numberFormatter.format(stage.case_count)}</span>
                          </div>
                          <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-muted"><div className="h-full rounded-full bg-primary" style={{ width: `${width}%` }} /></div>
                        </Link>
                      );
                    })}
                  </div>
                )}
              </CardContent>
            </Card>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6">
                <CardTitle>Case work queue</CardTitle>
                <CardDescription>
                  Filter every data column in the table header or mobile filter panel, then open a case to review its complete event timeline.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-5 px-4 sm:px-6">
                <CaseStageRecords rows={rows} isLoading={isLoading} filters={columnFilters} stageOptions={distribution} onFiltersChange={updateColumnFilters} onResetFilters={resetColumnFilters} />

                <div className="flex flex-col gap-3 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
                  <p>Showing {numberFormatter.format(firstVisibleRecord)}–{numberFormatter.format(lastVisibleRecord)} of {numberFormatter.format(total)}</p>
                  <div className="flex items-center justify-between gap-2 sm:justify-start">
                    <span>Page {page} of {totalPages}</span>
                    <Button className="size-10" variant="outline" size="icon" onClick={() => setPage((value) => Math.max(1, value - 1))} disabled={page <= 1 || isLoading} aria-label="Previous page"><ChevronLeft className="h-4 w-4" /></Button>
                    <Button className="size-10" variant="outline" size="icon" onClick={() => setPage((value) => Math.min(totalPages, value + 1))} disabled={page >= totalPages || isLoading} aria-label="Next page"><ChevronRight className="h-4 w-4" /></Button>
                  </div>
                </div>

                <div className="rounded-lg border bg-muted/20 p-3 text-xs leading-5 text-muted-foreground sm:p-4">
                  Queue rules mirror the active, non-voided event precedence in <code>compute_current_case_state</code>. A case may appear in multiple attention categories; the case details timeline remains the source for reviewing and resolving each item.
                  {overview.latest_event_at ? ` Latest monitored activity: ${formatDateTime(overview.latest_event_at)}.` : ''}
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
