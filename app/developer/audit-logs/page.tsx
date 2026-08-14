'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Activity,
  CalendarClock,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Eye,
  RefreshCw,
  RotateCcw,
  Search,
  ShieldCheck,
  Users,
} from 'lucide-react';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { AuditLogRecordsTable } from '@/components/audit-logs/audit-log-records-table';
import {
  AuditLogDataDetails,
  getAuditActionHref,
  getAuditActivityHref,
  getAuditActorHref,
  getAuditEntityHref,
  getAuditLogHref,
} from '@/components/audit-logs/audit-log-ui';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import {
  getDeveloperAuditActivitySummary,
  getDeveloperAuditLogOverview,
  getDeveloperAuditLogs,
  type DeveloperAuditActivitySummaryRecord,
  type DeveloperAuditLogOverview,
  type DeveloperAuditLogRecord,
} from '@/lib/supabase/queries';

const PAGE_SIZE = 25;
const EMPTY_OVERVIEW: DeveloperAuditLogOverview = {
  actor_count: 0,
  last_24_hours_count: 0,
  last_7_days_count: 0,
  latest_log_at: null,
  total_log_count: 0,
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

function formatIdentifier(value: string) {
  return value
    .toLowerCase()
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function getActionBadgeVariant(action: string): 'default' | 'secondary' | 'destructive' | 'outline' {
  const normalized = action.toUpperCase();
  if (/(VOID|DELETE|REMOVE|BLOCK|FAIL)/.test(normalized)) return 'destructive';
  if (/(CREATE|ADD|RECORD|APPROVE|ASSIGN)/.test(normalized)) return 'secondary';
  if (/(EDIT|UPDATE|CHANGE|RENAME)/.test(normalized)) return 'outline';
  return 'default';
}

function getSince(period: string) {
  const hours = period === '24h' ? 24 : period === '7d' ? 24 * 7 : period === '30d' ? 24 * 30 : 0;
  return hours > 0 ? new Date(Date.now() - hours * 60 * 60 * 1000).toISOString() : null;
}

function StatCard({
  title,
  value,
  description,
  icon: Icon,
  href,
}: {
  title: string;
  value: number;
  description: string;
  icon: typeof Activity;
  href: string;
}) {
  return (
    <Link className="group block" href={href}>
      <Card className="relative h-full py-0 transition-colors group-hover:border-primary/50 group-hover:bg-muted/30">
        <CardContent className="min-w-0 p-4 sm:p-5">
          <div className="min-w-0 pr-10">
            <p className="text-sm font-medium text-muted-foreground">{title}</p>
            <p className="mt-2 text-2xl font-semibold tracking-tight sm:text-3xl">{numberFormatter.format(value)}</p>
            <p className="mt-1 break-words text-xs leading-5 text-muted-foreground">{description}</p>
          </div>
          <div className="absolute right-3 top-3 rounded-lg bg-primary/10 p-2 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground sm:right-5 sm:top-5 sm:p-2.5">
            <Icon className="h-5 w-5" />
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

export default function DeveloperAuditLogsPage() {
  const [rows, setRows] = useState<DeveloperAuditLogRecord[]>([]);
  const [activitySummary, setActivitySummary] = useState<DeveloperAuditActivitySummaryRecord[]>([]);
  const [overview, setOverview] = useState<DeveloperAuditLogOverview>(EMPTY_OVERVIEW);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [period, setPeriod] = useState('7d');
  const [entityName, setEntityName] = useState('all');
  const [action, setAction] = useState('all');
  const [selectedLog, setSelectedLog] = useState<DeveloperAuditLogRecord | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshingSummary, setIsRefreshingSummary] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const requestSequence = useRef(0);

  const totalPages = Math.max(Math.ceil(total / PAGE_SIZE), 1);
  const firstVisibleRecord = total === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const lastVisibleRecord = Math.min(page * PAGE_SIZE, total);

  const entityOptions = useMemo(
    () => Array.from(new Set(activitySummary.map((item) => item.entity_name))).sort(),
    [activitySummary],
  );
  const actionOptions = useMemo(
    () => Array.from(new Set(activitySummary.map((item) => item.action))).sort(),
    [activitySummary],
  );

  const loadSummary = useCallback(async () => {
    setIsRefreshingSummary(true);
    const [overviewResult, summaryResult] = await Promise.all([
      getDeveloperAuditLogOverview(),
      getDeveloperAuditActivitySummary(),
    ]);

    if (overviewResult.error || summaryResult.error) {
      setError(overviewResult.error?.message ?? summaryResult.error?.message ?? 'Unable to load audit summary.');
    } else {
      setOverview(overviewResult.data);
      setActivitySummary(summaryResult.data);
    }
    setIsRefreshingSummary(false);
  }, []);

  const loadLogs = useCallback(async () => {
    const sequence = requestSequence.current + 1;
    requestSequence.current = sequence;
    setIsLoading(true);
    setError(null);

    const result = await getDeveloperAuditLogs({
      page,
      pageSize: PAGE_SIZE,
      search,
      action: action === 'all' ? null : action,
      entityName: entityName === 'all' ? null : entityName,
      since: getSince(period),
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
  }, [action, entityName, page, period, search]);

  useEffect(() => {
    void loadSummary();
  }, [loadSummary]);

  useEffect(() => {
    void loadLogs();
  }, [loadLogs]);

  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  }

  function resetFilters() {
    setSearchInput('');
    setSearch('');
    setPeriod('7d');
    setEntityName('all');
    setAction('all');
    setPage(1);
  }

  async function refreshAll() {
    await Promise.all([loadSummary(), loadLogs()]);
  }

  return (
    <RoleRouteGuard route="/developer/audit-logs">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-[1600px] space-y-4 sm:space-y-6">
            <header className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary">
                    <ShieldCheck className="h-5 w-5" />
                  </div>
                  <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Audit Logs</h1>
                  <Badge variant="secondary">Developer only</Badge>
                </div>
                <p className="text-sm text-muted-foreground">
                  Review system activity, responsible users, and before-and-after data snapshots.
                </p>
              </div>
              <Button className="w-full sm:w-auto" variant="outline" onClick={() => void refreshAll()} disabled={isLoading || isRefreshingSummary}>
                <RefreshCw className={`mr-2 h-4 w-4 ${isLoading || isRefreshingSummary ? 'animate-spin' : ''}`} />
                Refresh
              </Button>
            </header>

            {error ? (
              <Alert variant="destructive">
                <AlertTitle>Unable to load audit logs</AlertTitle>
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            ) : null}

            <section className="grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4">
              <StatCard title="Total records" value={overview.total_log_count} description={overview.latest_log_at ? `Latest ${formatDateTime(overview.latest_log_at)}` : 'All audit entries'} icon={Activity} href="/developer/audit-logs/periods/all" />
              <StatCard title="Last 24 hours" value={overview.last_24_hours_count} description="Recent system activity" icon={Clock3} href="/developer/audit-logs/periods/24h" />
              <StatCard title="Last 7 days" value={overview.last_7_days_count} description="Weekly activity volume" icon={CalendarClock} href="/developer/audit-logs/periods/7d" />
              <StatCard title="Active actors" value={overview.actor_count} description="Users represented in the log" icon={Users} href="/developer/audit-logs/actors" />
            </section>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6">
                <CardTitle>Activity stream</CardTitle>
                <CardDescription>Filters are applied on the server and results are shown in Philippine time.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-5 px-4 sm:px-6">
                <form className="grid gap-3 lg:grid-cols-[minmax(16rem,1fr)_11rem_13rem_16rem_auto]" onSubmit={submitSearch}>
                  <div className="relative">
                    <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                    <Input
                      value={searchInput}
                      onChange={(event) => setSearchInput(event.target.value)}
                      className="pl-9"
                      placeholder="Search action, actor, docket, or summary"
                      aria-label="Search audit logs"
                    />
                  </div>
                  <Select value={period} onValueChange={(value) => { setPeriod(value); setPage(1); }}>
                    <SelectTrigger className="w-full" aria-label="Audit log period"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="24h">Last 24 hours</SelectItem>
                      <SelectItem value="7d">Last 7 days</SelectItem>
                      <SelectItem value="30d">Last 30 days</SelectItem>
                      <SelectItem value="all">All time</SelectItem>
                    </SelectContent>
                  </Select>
                  <Select value={entityName} onValueChange={(value) => { setEntityName(value); setPage(1); }}>
                    <SelectTrigger className="w-full" aria-label="Audit log entity"><SelectValue placeholder="All entities" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All entities</SelectItem>
                      {entityOptions.map((value) => <SelectItem key={value} value={value}>{formatIdentifier(value)}</SelectItem>)}
                    </SelectContent>
                  </Select>
                  <Select value={action} onValueChange={(value) => { setAction(value); setPage(1); }}>
                    <SelectTrigger className="w-full" aria-label="Audit log action"><SelectValue placeholder="All actions" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All actions</SelectItem>
                      {actionOptions.map((value) => <SelectItem key={value} value={value}>{formatIdentifier(value)}</SelectItem>)}
                    </SelectContent>
                  </Select>
                  <div className="flex gap-2">
                    <Button type="submit" className="flex-1 lg:flex-none">Search</Button>
                    <Button className="size-10 shrink-0" type="button" variant="ghost" size="icon" onClick={resetFilters} title="Reset filters" aria-label="Reset filters">
                      <RotateCcw className="h-4 w-4" />
                    </Button>
                  </div>
                </form>

                <div className="md:hidden">
                  <AuditLogRecordsTable rows={rows} isLoading={isLoading} onPreview={setSelectedLog} />
                </div>

                <div className="hidden rounded-lg border md:block">
                  <Table>
                    <TableHeader className="bg-muted/40">
                      <TableRow>
                        <TableHead className="w-44">Time</TableHead>
                        <TableHead>Actor</TableHead>
                        <TableHead>Action</TableHead>
                        <TableHead className="hidden xl:table-cell">Target</TableHead>
                        <TableHead className="hidden lg:table-cell">Case</TableHead>
                        <TableHead className="min-w-72">Summary</TableHead>
                        <TableHead className="w-16 text-right"><span className="sr-only">Details</span></TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {isLoading ? (
                        <TableRow><TableCell colSpan={7} className="h-32 text-center text-muted-foreground">Loading audit logs…</TableCell></TableRow>
                      ) : rows.length === 0 ? (
                        <TableRow><TableCell colSpan={7} className="h-32 text-center text-muted-foreground">No audit logs match the selected filters.</TableCell></TableRow>
                      ) : rows.map((row) => (
                        <TableRow key={row.id}>
                          <TableCell className="whitespace-normal text-xs text-muted-foreground">{formatDateTime(row.created_at)}</TableCell>
                          <TableCell>
                            {row.actor_user_id ? (
                              <Link className="block max-w-52 truncate font-medium text-primary hover:underline" href={getAuditActorHref(row.actor_user_id)} title={row.actor_display}>
                                {row.actor_display}
                              </Link>
                            ) : <div className="max-w-52 truncate font-medium" title={row.actor_display}>{row.actor_display}</div>}
                            {row.actor_user_id ? <div className="text-xs text-muted-foreground">User #{row.actor_user_id}</div> : null}
                          </TableCell>
                          <TableCell><Badge variant={getActionBadgeVariant(row.action)} asChild><Link href={getAuditActionHref(row.action)}>{formatIdentifier(row.action)}</Link></Badge></TableCell>
                          <TableCell className="hidden xl:table-cell">
                            <Link className="font-medium text-primary hover:underline" href={getAuditEntityHref(row.entity_name, row.entity_id)}>{formatIdentifier(row.entity_name)}</Link>
                            <div className="text-xs text-muted-foreground">{row.entity_id ? `#${row.entity_id}` : 'No entity ID'}</div>
                          </TableCell>
                          <TableCell className="hidden lg:table-cell">
                            {row.case_id ? (
                              <Link className="font-medium text-primary hover:underline" href={`/cases/${row.case_id}`}>
                                {row.docket_display_number ?? `Case #${row.case_id}`}
                              </Link>
                            ) : <span className="text-muted-foreground">—</span>}
                          </TableCell>
                          <TableCell className="whitespace-normal">
                            <Link className="line-clamp-2 max-w-xl text-sm hover:text-primary hover:underline" href={getAuditLogHref(row.id)}>{row.summary ?? 'No summary recorded.'}</Link>
                          </TableCell>
                          <TableCell className="text-right">
                            <Button type="button" variant="ghost" size="icon" onClick={() => setSelectedLog(row)} aria-label={`View audit log ${row.id}`}>
                              <Eye className="h-4 w-4" />
                            </Button>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>

                <div className="flex flex-col gap-3 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
                  <p>Showing {numberFormatter.format(firstVisibleRecord)}–{numberFormatter.format(lastVisibleRecord)} of {numberFormatter.format(total)}</p>
                  <div className="flex items-center justify-between gap-2 sm:justify-start">
                    <span>Page {page} of {totalPages}</span>
                    <Button className="size-10" variant="outline" size="icon" onClick={() => setPage((value) => Math.max(1, value - 1))} disabled={page <= 1 || isLoading} aria-label="Previous page">
                      <ChevronLeft className="h-4 w-4" />
                    </Button>
                    <Button className="size-10" variant="outline" size="icon" onClick={() => setPage((value) => Math.min(totalPages, value + 1))} disabled={page >= totalPages || isLoading} aria-label="Next page">
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6">
                <CardTitle>Activity breakdown</CardTitle>
                <CardDescription>Recorded volume and date range for every entity/action pair.</CardDescription>
              </CardHeader>
              <CardContent className="px-4 sm:px-6">
                <div className="max-h-[32rem] space-y-3 overflow-y-auto pr-1 md:hidden">
                  {isRefreshingSummary ? (
                    <div className="flex min-h-24 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">Loading activity breakdown…</div>
                  ) : activitySummary.length === 0 ? (
                    <div className="flex min-h-24 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">No activity has been recorded.</div>
                  ) : activitySummary.map((item) => (
                    <article key={`${item.entity_name}:${item.action}`} className="min-w-0 rounded-xl border bg-card p-4">
                      <div className="flex min-w-0 flex-wrap items-center justify-between gap-2">
                        <Badge className="max-w-full whitespace-normal text-left leading-5" variant={getActionBadgeVariant(item.action)} asChild>
                          <Link href={getAuditActionHref(item.action)}>{formatIdentifier(item.action)}</Link>
                        </Badge>
                        <Link className="text-lg font-semibold text-primary hover:underline" href={getAuditActivityHref(item.entity_name, item.action)}>
                          {numberFormatter.format(item.log_count)}
                        </Link>
                      </div>
                      <Link className="mt-3 block break-words font-medium text-primary hover:underline" href={getAuditEntityHref(item.entity_name)}>
                        {formatIdentifier(item.entity_name)}
                      </Link>
                      <dl className="mt-4 grid grid-cols-2 gap-3 border-t pt-4 text-xs">
                        <div><dt className="text-muted-foreground">First recorded</dt><dd className="mt-1 leading-5"><Link className="hover:text-primary hover:underline" href={getAuditActivityHref(item.entity_name, item.action)}>{formatDateTime(item.first_recorded_at)}</Link></dd></div>
                        <div><dt className="text-muted-foreground">Latest</dt><dd className="mt-1 leading-5"><Link className="hover:text-primary hover:underline" href={getAuditActivityHref(item.entity_name, item.action)}>{formatDateTime(item.latest_recorded_at)}</Link></dd></div>
                      </dl>
                    </article>
                  ))}
                </div>

                <div className="hidden max-h-96 overflow-auto rounded-lg border md:block">
                  <Table>
                    <TableHeader className="sticky top-0 z-10 bg-background">
                      <TableRow>
                        <TableHead>Action</TableHead>
                        <TableHead>Entity</TableHead>
                        <TableHead className="text-right">Records</TableHead>
                        <TableHead className="hidden md:table-cell">First recorded</TableHead>
                        <TableHead>Latest</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {isRefreshingSummary ? (
                        <TableRow><TableCell colSpan={5} className="h-24 text-center text-muted-foreground">Loading activity breakdown…</TableCell></TableRow>
                      ) : activitySummary.length === 0 ? (
                        <TableRow><TableCell colSpan={5} className="h-24 text-center text-muted-foreground">No activity has been recorded.</TableCell></TableRow>
                      ) : activitySummary.map((item) => (
                        <TableRow key={`${item.entity_name}:${item.action}`}>
                          <TableCell><Badge variant={getActionBadgeVariant(item.action)} asChild><Link href={getAuditActionHref(item.action)}>{formatIdentifier(item.action)}</Link></Badge></TableCell>
                          <TableCell><Link className="font-medium text-primary hover:underline" href={getAuditEntityHref(item.entity_name)}>{formatIdentifier(item.entity_name)}</Link></TableCell>
                          <TableCell className="text-right font-semibold"><Link className="text-primary hover:underline" href={getAuditActivityHref(item.entity_name, item.action)}>{numberFormatter.format(item.log_count)}</Link></TableCell>
                          <TableCell className="hidden text-muted-foreground md:table-cell"><Link className="hover:text-primary hover:underline" href={getAuditActivityHref(item.entity_name, item.action)}>{formatDateTime(item.first_recorded_at)}</Link></TableCell>
                          <TableCell className="text-muted-foreground"><Link className="hover:text-primary hover:underline" href={getAuditActivityHref(item.entity_name, item.action)}>{formatDateTime(item.latest_recorded_at)}</Link></TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </CardContent>
            </Card>
          </div>
        </main>
      </div>

      <Dialog open={selectedLog !== null} onOpenChange={(open) => { if (!open) setSelectedLog(null); }}>
        <DialogContent className="max-h-[calc(100dvh-1rem)] max-w-[calc(100%-1rem)] gap-3 overflow-y-auto p-4 sm:max-w-5xl sm:gap-4 sm:p-6">
          {selectedLog ? (
            <>
              <DialogHeader>
                <div className="flex flex-wrap items-center gap-2 pr-8">
                  <DialogTitle>Audit log #{selectedLog.id}</DialogTitle>
                  <Badge variant={getActionBadgeVariant(selectedLog.action)} asChild><Link href={getAuditActionHref(selectedLog.action)}>{formatIdentifier(selectedLog.action)}</Link></Badge>
                </div>
                <DialogDescription>{formatDateTime(selectedLog.created_at)} · {selectedLog.actor_display}</DialogDescription>
              </DialogHeader>

              <div className="grid gap-3 rounded-lg border bg-muted/20 p-3 text-sm sm:grid-cols-2 sm:p-4 lg:grid-cols-4">
                <div><p className="text-xs text-muted-foreground">Actor</p><p className="mt-1 font-medium">{selectedLog.actor_user_id ? <Link className="text-primary hover:underline" href={getAuditActorHref(selectedLog.actor_user_id)}>{selectedLog.actor_display}</Link> : selectedLog.actor_display}</p></div>
                <div><p className="text-xs text-muted-foreground">Entity</p><p className="mt-1 font-medium"><Link className="text-primary hover:underline" href={getAuditEntityHref(selectedLog.entity_name, selectedLog.entity_id)}>{formatIdentifier(selectedLog.entity_name)}{selectedLog.entity_id ? ` #${selectedLog.entity_id}` : ''}</Link></p></div>
                <div><p className="text-xs text-muted-foreground">Case</p><p className="mt-1 font-medium">{selectedLog.case_id ? <Link className="text-primary hover:underline" href={`/cases/${selectedLog.case_id}`}>{selectedLog.docket_display_number ?? `Case #${selectedLog.case_id}`}</Link> : '—'}</p></div>
                <div><p className="text-xs text-muted-foreground">IP address</p><p className="mt-1 font-medium">{selectedLog.ip_address ?? 'Not recorded'}</p></div>
              </div>

              <section className="rounded-lg border p-4">
                <h3 className="text-sm font-semibold">Summary</h3>
                <p className="mt-2 text-sm text-muted-foreground">{selectedLog.summary ?? 'No summary recorded.'}</p>
              </section>

              <AuditLogDataDetails oldValue={selectedLog.old_data} newValue={selectedLog.new_data} metadata={selectedLog.metadata} />
              <div className="flex justify-end">
                <Button className="w-full sm:w-auto" asChild><Link href={getAuditLogHref(selectedLog.id)}>Open full audit record</Link></Button>
              </div>
            </>
          ) : null}
        </DialogContent>
      </Dialog>
    </RoleRouteGuard>
  );
}
