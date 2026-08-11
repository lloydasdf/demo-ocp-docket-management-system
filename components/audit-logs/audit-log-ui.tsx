import { FileJson2 } from 'lucide-react';

import type { Json } from '@/lib/supabase/types';

const dateTimeFormatter = new Intl.DateTimeFormat('en-PH', {
  timeZone: 'Asia/Manila',
  dateStyle: 'medium',
  timeStyle: 'short',
});

export function formatAuditDateTime(value: string | null) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : dateTimeFormatter.format(date);
}

export function formatAuditIdentifier(value: string) {
  return value
    .toLowerCase()
    .split('_')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

export function formatAuditJson(value: Json | null) {
  if (value === null) return 'No data recorded.';
  return JSON.stringify(value, null, 2);
}

export function getAuditActionBadgeVariant(action: string): 'default' | 'secondary' | 'destructive' | 'outline' {
  const normalized = action.toUpperCase();
  if (/(VOID|DELETE|REMOVE|BLOCK|FAIL)/.test(normalized)) return 'destructive';
  if (/(CREATE|ADD|RECORD|APPROVE|ASSIGN)/.test(normalized)) return 'secondary';
  if (/(EDIT|UPDATE|CHANGE|RENAME)/.test(normalized)) return 'outline';
  return 'default';
}

export function getAuditLogHref(auditLogId: number) {
  return `/developer/audit-logs/${auditLogId}`;
}

export function getAuditActorHref(actorUserId: number) {
  return `/developer/audit-logs/actors/${actorUserId}`;
}

export function getAuditActionHref(action: string) {
  return `/developer/audit-logs/actions/${encodeURIComponent(action)}`;
}

export function getAuditEntityHref(entityName: string, entityId?: number | null) {
  const base = `/developer/audit-logs/entities/${encodeURIComponent(entityName)}`;
  return entityId === null || entityId === undefined ? base : `${base}/${entityId}`;
}

export function getAuditActivityHref(entityName: string, action: string) {
  return `/developer/audit-logs/activity/${encodeURIComponent(entityName)}/${encodeURIComponent(action)}`;
}

export function AuditJsonPanel({ title, value }: { title: string; value: Json | null }) {
  return (
    <section className="min-w-0 space-y-2">
      <div className="flex items-center gap-2">
        <FileJson2 className="h-4 w-4 shrink-0 text-muted-foreground" />
        <h3 className="text-sm font-semibold">{title}</h3>
      </div>
      <pre className="max-h-96 max-w-full overflow-auto whitespace-pre-wrap break-words [overflow-wrap:anywhere] rounded-lg border bg-muted/50 p-3 text-[11px] leading-5 sm:text-xs">
        {formatAuditJson(value)}
      </pre>
    </section>
  );
}
