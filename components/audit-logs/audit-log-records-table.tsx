import Link from 'next/link';
import { ArrowUpRight, Eye } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import type { DeveloperAuditLogRecord } from '@/lib/supabase/queries';
import {
  formatAuditDateTime,
  formatAuditIdentifier,
  getAuditActionBadgeVariant,
  getAuditActionHref,
  getAuditActorHref,
  getAuditEntityHref,
  getAuditLogHref,
} from '@/components/audit-logs/audit-log-ui';

export function AuditLogRecordsTable({
  rows,
  isLoading,
  emptyMessage = 'No audit logs match this view.',
  onPreview,
}: {
  rows: DeveloperAuditLogRecord[];
  isLoading: boolean;
  emptyMessage?: string;
  onPreview?: (row: DeveloperAuditLogRecord) => void;
}) {
  return (
    <>
      <div className="space-y-3 md:hidden">
        {isLoading ? (
          <div className="flex min-h-32 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">
            Loading audit logs…
          </div>
        ) : rows.length === 0 ? (
          <div className="flex min-h-32 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">
            {emptyMessage}
          </div>
        ) : rows.map((row) => (
          <article key={row.id} className="min-w-0 rounded-xl border bg-card p-4 shadow-sm">
            <div className="flex min-w-0 items-start justify-between gap-3">
              <Badge className="max-w-full whitespace-normal text-left leading-5" variant={getAuditActionBadgeVariant(row.action)} asChild>
                <Link href={getAuditActionHref(row.action)}>{formatAuditIdentifier(row.action)}</Link>
              </Badge>
              <span className="shrink-0 text-xs font-medium text-muted-foreground">#{row.id}</span>
            </div>
            <p className="mt-2 text-xs text-muted-foreground">{formatAuditDateTime(row.created_at)}</p>

            <Link className="mt-3 block break-words text-sm font-medium leading-6 hover:text-primary hover:underline" href={getAuditLogHref(row.id)}>
              {row.summary ?? 'No summary recorded.'}
            </Link>

            <dl className="mt-4 grid min-w-0 grid-cols-2 gap-x-4 gap-y-3 border-t pt-4 text-sm">
              <div className="col-span-2 min-w-0">
                <dt className="text-xs text-muted-foreground">Actor</dt>
                <dd className="mt-1 break-all font-medium">
                  {row.actor_user_id ? (
                    <Link className="text-primary hover:underline" href={getAuditActorHref(row.actor_user_id)}>{row.actor_display}</Link>
                  ) : row.actor_display}
                </dd>
                {row.actor_user_id ? <p className="text-xs text-muted-foreground">User #{row.actor_user_id}</p> : null}
              </div>
              <div className="min-w-0">
                <dt className="text-xs text-muted-foreground">Target</dt>
                <dd className="mt-1 break-words font-medium">
                  <Link className="text-primary hover:underline" href={getAuditEntityHref(row.entity_name, row.entity_id)}>
                    {formatAuditIdentifier(row.entity_name)}{row.entity_id ? ` #${row.entity_id}` : ''}
                  </Link>
                </dd>
              </div>
              <div className="min-w-0">
                <dt className="text-xs text-muted-foreground">Case</dt>
                <dd className="mt-1 break-words font-medium">
                  {row.case_id ? (
                    <Link className="text-primary hover:underline" href={`/cases/${row.case_id}`}>
                      {row.docket_display_number ?? `Case #${row.case_id}`}
                    </Link>
                  ) : <span className="text-muted-foreground">Not linked</span>}
                </dd>
              </div>
            </dl>

            <div className={`mt-4 grid gap-2 ${onPreview ? 'grid-cols-2' : 'grid-cols-1'}`}>
              {onPreview ? (
                <Button type="button" variant="outline" className="w-full" onClick={() => onPreview(row)}>
                  <Eye className="h-4 w-4" />Preview
                </Button>
              ) : null}
              <Button className="w-full" asChild>
                <Link href={getAuditLogHref(row.id)}>Full record<ArrowUpRight className="h-4 w-4" /></Link>
              </Button>
            </div>
          </article>
        ))}
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
              <TableHead className="w-16"><span className="sr-only">Open</span></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableRow><TableCell colSpan={7} className="h-32 text-center text-muted-foreground">Loading audit logs…</TableCell></TableRow>
            ) : rows.length === 0 ? (
              <TableRow><TableCell colSpan={7} className="h-32 text-center text-muted-foreground">{emptyMessage}</TableCell></TableRow>
            ) : rows.map((row) => (
              <TableRow key={row.id}>
                <TableCell className="whitespace-normal text-xs text-muted-foreground">{formatAuditDateTime(row.created_at)}</TableCell>
                <TableCell>
                  {row.actor_user_id ? (
                    <Link className="block max-w-52 truncate font-medium text-primary hover:underline" href={getAuditActorHref(row.actor_user_id)} title={row.actor_display}>
                      {row.actor_display}
                    </Link>
                  ) : <span className="font-medium">{row.actor_display}</span>}
                  {row.actor_user_id ? <div className="text-xs text-muted-foreground">User #{row.actor_user_id}</div> : null}
                </TableCell>
                <TableCell>
                  <Badge variant={getAuditActionBadgeVariant(row.action)} asChild>
                    <Link href={getAuditActionHref(row.action)}>{formatAuditIdentifier(row.action)}</Link>
                  </Badge>
                </TableCell>
                <TableCell className="hidden xl:table-cell">
                  <Link className="font-medium text-primary hover:underline" href={getAuditEntityHref(row.entity_name, row.entity_id)}>
                    {formatAuditIdentifier(row.entity_name)}
                  </Link>
                  <div className="text-xs text-muted-foreground">{row.entity_id ? `#${row.entity_id}` : 'All records'}</div>
                </TableCell>
                <TableCell className="hidden lg:table-cell">
                  {row.case_id ? (
                    <Link className="font-medium text-primary hover:underline" href={`/cases/${row.case_id}`}>
                      {row.docket_display_number ?? `Case #${row.case_id}`}
                    </Link>
                  ) : <span className="text-muted-foreground">—</span>}
                </TableCell>
                <TableCell className="whitespace-normal">
                  <Link className="line-clamp-2 max-w-xl text-sm hover:text-primary hover:underline" href={getAuditLogHref(row.id)}>
                    {row.summary ?? 'No summary recorded.'}
                  </Link>
                </TableCell>
                <TableCell>
                  {onPreview ? (
                    <Button type="button" variant="ghost" size="icon" onClick={() => onPreview(row)} aria-label={`Preview audit log ${row.id}`}>
                      <Eye className="h-4 w-4" />
                    </Button>
                  ) : (
                    <Button variant="ghost" size="icon" asChild>
                      <Link href={getAuditLogHref(row.id)} aria-label={`Open audit log ${row.id}`}>
                        <ArrowUpRight className="h-4 w-4" />
                      </Link>
                    </Button>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </>
  );
}
