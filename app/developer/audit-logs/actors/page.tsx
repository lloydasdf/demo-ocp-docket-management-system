'use client';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, ArrowUpRight, RefreshCw, Users } from 'lucide-react';

import { formatAuditDateTime, getAuditActorHref } from '@/components/audit-logs/audit-log-ui';
import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { getDeveloperAuditActorSummary, type DeveloperAuditActorSummaryRecord } from '@/lib/supabase/queries';

export default function AuditActorsPage() {
  const [actors, setActors] = useState<DeveloperAuditActorSummaryRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadActors = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    const result = await getDeveloperAuditActorSummary();
    if (result.error) {
      setActors([]);
      setError(result.error.message);
    } else {
      setActors(result.data);
    }
    setIsLoading(false);
  }, []);

  useEffect(() => {
    void loadActors();
  }, [loadActors]);

  const totalActivity = actors.reduce((sum, actor) => sum + actor.log_count, 0);

  return (
    <RoleRouteGuard route="/developer/audit-logs">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-6xl space-y-4 sm:space-y-6">
            <Button className="-ml-2 max-w-full justify-start whitespace-normal" variant="ghost" size="sm" asChild><Link href="/developer/audit-logs"><ArrowLeft className="h-4 w-4" />Back to all audit logs</Link></Button>

            <header className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-2">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary"><Users className="h-5 w-5" /></div>
                  <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Audit actors</h1>
                  <Badge variant="secondary">Developer only</Badge>
                </div>
                <p className="text-sm text-muted-foreground">Application users represented in the audit trail and their activity volume.</p>
              </div>
              <Button className="w-full sm:w-auto" variant="outline" onClick={() => void loadActors()} disabled={isLoading}><RefreshCw className={`mr-2 h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />Refresh</Button>
            </header>

            {error ? <Alert variant="destructive"><AlertTitle>Unable to load audit actors</AlertTitle><AlertDescription>{error}</AlertDescription></Alert> : null}

            <section className="grid grid-cols-2 gap-3 sm:gap-4">
              <Card className="py-0"><CardContent className="p-4 sm:p-5"><p className="text-sm text-muted-foreground">Actors</p><p className="mt-2 text-2xl font-semibold sm:text-3xl">{actors.length.toLocaleString('en-PH')}</p></CardContent></Card>
              <Card className="py-0"><CardContent className="p-4 sm:p-5"><p className="text-sm text-muted-foreground">Recorded actions</p><p className="mt-2 text-2xl font-semibold sm:text-3xl">{totalActivity.toLocaleString('en-PH')}</p></CardContent></Card>
            </section>

            <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
              <CardHeader className="px-4 sm:px-6"><CardTitle>Actor directory</CardTitle><CardDescription>Open a user to inspect their complete audit history.</CardDescription></CardHeader>
              <CardContent className="px-4 sm:px-6">
                <div className="space-y-3 md:hidden">
                  {isLoading ? (
                    <div className="flex min-h-32 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">Loading actors…</div>
                  ) : actors.length === 0 ? (
                    <div className="flex min-h-32 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">No actors were found.</div>
                  ) : actors.map((actor) => (
                    <article key={actor.actor_user_id} className="min-w-0 rounded-xl border bg-card p-4">
                      <div className="flex min-w-0 items-start justify-between gap-3">
                        <div className="min-w-0">
                          <Link className="block break-all font-medium text-primary hover:underline" href={getAuditActorHref(actor.actor_user_id)}>{actor.actor_display}</Link>
                          <p className="mt-1 text-xs text-muted-foreground">User #{actor.actor_user_id}</p>
                        </div>
                        <div className="shrink-0 text-right"><p className="text-xl font-semibold">{actor.log_count.toLocaleString('en-PH')}</p><p className="text-xs text-muted-foreground">actions</p></div>
                      </div>
                      <dl className="mt-4 grid grid-cols-2 gap-3 border-t pt-4 text-xs">
                        <div><dt className="text-muted-foreground">First recorded</dt><dd className="mt-1 leading-5">{formatAuditDateTime(actor.first_recorded_at)}</dd></div>
                        <div><dt className="text-muted-foreground">Latest</dt><dd className="mt-1 leading-5">{formatAuditDateTime(actor.latest_recorded_at)}</dd></div>
                      </dl>
                      <Button className="mt-4 w-full" asChild><Link href={getAuditActorHref(actor.actor_user_id)}>Open audit history<ArrowUpRight className="h-4 w-4" /></Link></Button>
                    </article>
                  ))}
                </div>

                <div className="hidden rounded-lg border md:block">
                  <Table>
                    <TableHeader className="bg-muted/40"><TableRow><TableHead>Actor</TableHead><TableHead className="text-right">Actions</TableHead><TableHead className="hidden md:table-cell">First recorded</TableHead><TableHead>Latest</TableHead><TableHead className="w-16"><span className="sr-only">Open</span></TableHead></TableRow></TableHeader>
                    <TableBody>
                      {isLoading ? (
                        <TableRow><TableCell colSpan={5} className="h-32 text-center text-muted-foreground">Loading actors…</TableCell></TableRow>
                      ) : actors.length === 0 ? (
                        <TableRow><TableCell colSpan={5} className="h-32 text-center text-muted-foreground">No actors were found.</TableCell></TableRow>
                      ) : actors.map((actor) => (
                        <TableRow key={actor.actor_user_id}>
                          <TableCell><Link className="font-medium text-primary hover:underline" href={getAuditActorHref(actor.actor_user_id)}>{actor.actor_display}</Link><p className="text-xs text-muted-foreground">User #{actor.actor_user_id}</p></TableCell>
                          <TableCell className="text-right font-semibold">{actor.log_count.toLocaleString('en-PH')}</TableCell>
                          <TableCell className="hidden text-muted-foreground md:table-cell">{formatAuditDateTime(actor.first_recorded_at)}</TableCell>
                          <TableCell className="text-muted-foreground">{formatAuditDateTime(actor.latest_recorded_at)}</TableCell>
                          <TableCell><Button variant="ghost" size="icon" asChild><Link href={getAuditActorHref(actor.actor_user_id)} aria-label={`Open ${actor.actor_display} audit history`}><ArrowUpRight className="h-4 w-4" /></Link></Button></TableCell>
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
    </RoleRouteGuard>
  );
}
