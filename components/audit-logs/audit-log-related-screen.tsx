'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight, History, RefreshCw, Search } from 'lucide-react';

import { AuditLogRecordsTable } from '@/components/audit-logs/audit-log-records-table';
import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  getDeveloperAuditLogs,
  type DeveloperAuditLogFilters,
  type DeveloperAuditLogRecord,
} from '@/lib/supabase/queries';

const PAGE_SIZE = 25;

function getSince(period: string) {
  const hours = period === '24h' ? 24 : period === '7d' ? 24 * 7 : period === '30d' ? 24 * 30 : 0;
  return hours > 0 ? new Date(Date.now() - hours * 60 * 60 * 1000).toISOString() : null;
}

export type AuditLogRelatedFilters = Pick<DeveloperAuditLogFilters, 'actorUserId' | 'action' | 'entityName' | 'entityId'>;

export function AuditLogRelatedScreen({
  title,
  description,
  badge,
  filters,
  initialPeriod = 'all',
}: {
  title: string;
  description: string;
  badge: string;
  filters: AuditLogRelatedFilters;
  initialPeriod?: 'all' | '24h' | '7d' | '30d';
}) {
  const [rows, setRows] = useState<DeveloperAuditLogRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [period, setPeriod] = useState<string>(initialPeriod);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const requestSequence = useRef(0);
  const actorUserId = filters.actorUserId;
  const fixedAction = filters.action;
  const entityName = filters.entityName;
  const entityId = filters.entityId;
  const totalPages = Math.max(Math.ceil(total / PAGE_SIZE), 1);
  const firstVisibleRecord = total === 0 ? 0 : (page - 1) * PAGE_SIZE + 1;
  const lastVisibleRecord = Math.min(page * PAGE_SIZE, total);

  const loadLogs = useCallback(async () => {
    const sequence = requestSequence.current + 1;
    requestSequence.current = sequence;
    setIsLoading(true);
    setError(null);

    const result = await getDeveloperAuditLogs({
      actorUserId,
      action: fixedAction,
      entityName,
      entityId,
      page,
      pageSize: PAGE_SIZE,
      search,
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
  }, [actorUserId, entityId, entityName, fixedAction, page, period, search]);

  useEffect(() => {
    void loadLogs();
  }, [loadLogs]);

  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPage(1);
    setSearch(searchInput.trim());
  }

  return (
    <RoleRouteGuard route="/developer/audit-logs">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-[1500px] space-y-4 sm:space-y-6">
            <Button className="-ml-2 max-w-full justify-start whitespace-normal" variant="ghost" size="sm" asChild>
              <Link href="/developer/audit-logs"><ArrowLeft className="h-4 w-4" />Back to all audit logs</Link>
            </Button>

            <header className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-2">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary"><History className="h-5 w-5" /></div>
                  <h1 className="min-w-0 break-words text-2xl font-bold tracking-tight sm:text-3xl">{title}</h1>
                  <Badge variant="secondary">{badge}</Badge>
                </div>
                <p className="max-w-3xl text-sm text-muted-foreground">{description}</p>
              </div>
              <Button className="w-full sm:w-auto" variant="outline" onClick={() => void loadLogs()} disabled={isLoading}>
                <RefreshCw className={`mr-2 h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />Refresh
              </Button>
            </header>

            {error ? (
              <Alert variant="destructive"><AlertTitle>Unable to load related activity</AlertTitle><AlertDescription>{error}</AlertDescription></Alert>
            ) : null}

            <section className="grid grid-cols-2 gap-3 sm:gap-4">
              <Card className="py-0">
                <CardContent className="p-4 sm:p-5">
                  <p className="text-sm text-muted-foreground">Matching records</p>
                  <p className="mt-2 text-2xl font-semibold sm:text-3xl">{total.toLocaleString('en-PH')}</p>
                </CardContent>
              </Card>
              <Card className="py-0">
                <CardContent className="p-4 sm:p-5">
                  <p className="text-sm text-muted-foreground">Current window</p>
                  <p className="mt-2 text-xl font-semibold sm:text-3xl">{period === 'all' ? 'All time' : period === '24h' ? '24 hours' : period === '7d' ? '7 days' : '30 days'}</p>
                </CardContent>
              </Card>
            </section>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6">
                <CardTitle>Related activity</CardTitle>
                <CardDescription>Open any value to continue following the audit trail.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-5 px-4 sm:px-6">
                <form className="grid gap-3 md:grid-cols-[minmax(16rem,1fr)_12rem_auto]" onSubmit={submitSearch}>
                  <div className="relative">
                    <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                    <Input value={searchInput} onChange={(event) => setSearchInput(event.target.value)} className="pl-9" placeholder="Search within these records" aria-label="Search related audit logs" />
                  </div>
                  <Select value={period} onValueChange={(value) => { setPeriod(value); setPage(1); }}>
                    <SelectTrigger className="w-full" aria-label="Related activity period"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All time</SelectItem>
                      <SelectItem value="24h">Last 24 hours</SelectItem>
                      <SelectItem value="7d">Last 7 days</SelectItem>
                      <SelectItem value="30d">Last 30 days</SelectItem>
                    </SelectContent>
                  </Select>
                  <Button className="w-full md:w-auto" type="submit">Search</Button>
                </form>

                <AuditLogRecordsTable rows={rows} isLoading={isLoading} />

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
