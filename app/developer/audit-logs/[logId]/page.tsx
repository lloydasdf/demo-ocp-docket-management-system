'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { ArrowLeft, FileClock, RefreshCw } from 'lucide-react';

import {
  AuditJsonPanel,
  formatAuditDateTime,
  formatAuditIdentifier,
  getAuditActionBadgeVariant,
  getAuditActionHref,
  getAuditActorHref,
  getAuditEntityHref,
} from '@/components/audit-logs/audit-log-ui';
import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { getDeveloperAuditLog, type DeveloperAuditLogRecord } from '@/lib/supabase/queries';

function DetailValue({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0 rounded-lg border bg-muted/20 p-3">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
      <div className="mt-1 break-words text-sm font-medium [&_a]:break-all">{children}</div>
    </div>
  );
}

export default function AuditLogDetailPage() {
  const params = useParams<{ logId: string }>();
  const auditLogId = Number(params.logId);
  const [record, setRecord] = useState<DeveloperAuditLogRecord | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadRecord = useCallback(async () => {
    if (!Number.isSafeInteger(auditLogId) || auditLogId <= 0) {
      setRecord(null);
      setError('The audit log identifier in this URL is invalid.');
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);
    const result = await getDeveloperAuditLog(auditLogId);
    if (result.error) {
      setRecord(null);
      setError(result.error.message);
    } else {
      setRecord(result.data);
    }
    setIsLoading(false);
  }, [auditLogId]);

  useEffect(() => {
    void loadRecord();
  }, [loadRecord]);

  return (
    <RoleRouteGuard route="/developer/audit-logs">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-6xl space-y-4 sm:space-y-6">
            <Button className="-ml-2 max-w-full justify-start whitespace-normal" variant="ghost" size="sm" asChild>
              <Link href="/developer/audit-logs"><ArrowLeft className="h-4 w-4" />Back to all audit logs</Link>
            </Button>

            <header className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-2">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary"><FileClock className="h-5 w-5" /></div>
                  <h1 className="min-w-0 break-words text-2xl font-bold tracking-tight sm:text-3xl">Audit log #{Number.isFinite(auditLogId) ? auditLogId : '—'}</h1>
                  <Badge variant="secondary">Full record</Badge>
                </div>
                <p className="text-sm text-muted-foreground">Inspect the event context, linked records, and complete JSON snapshots.</p>
              </div>
              <Button className="w-full sm:w-auto" variant="outline" onClick={() => void loadRecord()} disabled={isLoading}>
                <RefreshCw className={`mr-2 h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />Refresh
              </Button>
            </header>

            {error ? (
              <Alert variant="destructive"><AlertTitle>Unable to load audit record</AlertTitle><AlertDescription>{error}</AlertDescription></Alert>
            ) : null}

            {isLoading ? (
              <Card className="py-0"><CardContent className="flex h-40 items-center justify-center p-4 text-sm text-muted-foreground">Loading audit record…</CardContent></Card>
            ) : !record ? (
              <Card>
                <CardHeader><CardTitle>Audit record not found</CardTitle><CardDescription>The record does not exist or is unavailable to the current developer account.</CardDescription></CardHeader>
                <CardContent><Button asChild><Link href="/developer/audit-logs">Return to audit logs</Link></Button></CardContent>
              </Card>
            ) : (
              <>
                <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
                  <CardHeader className="px-4 sm:px-6">
                    <div className="flex flex-wrap items-center gap-2">
                      <CardTitle>{formatAuditIdentifier(record.action)}</CardTitle>
                      <Badge className="max-w-full whitespace-normal break-all text-left leading-5" variant={getAuditActionBadgeVariant(record.action)}>{record.action}</Badge>
                    </div>
                    <CardDescription>{formatAuditDateTime(record.created_at)}</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4 px-4 sm:space-y-5 sm:px-6">
                    <p className="break-words rounded-lg border bg-background p-3 text-sm leading-6 sm:p-4">{record.summary ?? 'No summary recorded.'}</p>
                    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                      <DetailValue label="Actor">
                        {record.actor_user_id ? <Link className="text-primary hover:underline" href={getAuditActorHref(record.actor_user_id)}>{record.actor_display}</Link> : record.actor_display}
                      </DetailValue>
                      <DetailValue label="Action">
                        <Link className="text-primary hover:underline" href={getAuditActionHref(record.action)}>{record.action}</Link>
                      </DetailValue>
                      <DetailValue label="Target">
                        <Link className="text-primary hover:underline" href={getAuditEntityHref(record.entity_name, record.entity_id)}>{formatAuditIdentifier(record.entity_name)}{record.entity_id ? ` #${record.entity_id}` : ''}</Link>
                      </DetailValue>
                      <DetailValue label="Case">
                        {record.case_id ? <Link className="text-primary hover:underline" href={`/cases/${record.case_id}`}>{record.docket_display_number ?? `Case #${record.case_id}`}</Link> : 'Not linked'}
                      </DetailValue>
                      <DetailValue label="Actor user ID">{record.actor_user_id ?? 'System'}</DetailValue>
                      <DetailValue label="Entity ID">{record.entity_id ?? 'Not recorded'}</DetailValue>
                      <DetailValue label="IP address">{record.ip_address ?? 'Not recorded'}</DetailValue>
                      <DetailValue label="Created at">{formatAuditDateTime(record.created_at)}</DetailValue>
                    </div>
                  </CardContent>
                </Card>

                <div className="grid min-w-0 gap-4 sm:gap-6 lg:grid-cols-2">
                  <AuditJsonPanel title="Before" value={record.old_data} />
                  <AuditJsonPanel title="After" value={record.new_data} />
                </div>
                <AuditJsonPanel title="Metadata" value={record.metadata} />

                <Card className="gap-4 py-4 sm:gap-6 sm:py-6">
                  <CardHeader className="px-4 sm:px-6"><CardTitle>Continue exploring</CardTitle><CardDescription>Follow this event through its related audit histories.</CardDescription></CardHeader>
                  <CardContent className="grid gap-2 px-4 sm:flex sm:flex-wrap sm:px-6">
                    {record.actor_user_id ? <Button className="w-full sm:w-auto" variant="outline" asChild><Link href={getAuditActorHref(record.actor_user_id)}>Actor history</Link></Button> : null}
                    <Button className="w-full sm:w-auto" variant="outline" asChild><Link href={getAuditActionHref(record.action)}>Action history</Link></Button>
                    <Button className="h-auto min-h-9 w-full whitespace-normal py-2 sm:w-auto" variant="outline" asChild><Link href={getAuditEntityHref(record.entity_name, record.entity_id)}>Entity record history</Link></Button>
                    <Button className="h-auto min-h-9 w-full whitespace-normal py-2 sm:w-auto" variant="outline" asChild><Link href={getAuditEntityHref(record.entity_name)}>Entity type history</Link></Button>
                    {record.case_id ? <Button className="w-full sm:w-auto" variant="outline" asChild><Link href={`/cases/${record.case_id}`}>Case details</Link></Button> : null}
                  </CardContent>
                </Card>
              </>
            )}
          </div>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
