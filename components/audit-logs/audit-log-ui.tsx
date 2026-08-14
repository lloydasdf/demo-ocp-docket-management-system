import {
  ArrowRight,
  ChevronDown,
  CircleMinus,
  CirclePlus,
  FileJson2,
  GitCompareArrows,
  Info,
  PencilLine,
} from 'lucide-react';

import type { Json } from '@/lib/supabase/types';
import { cn } from '@/lib/utils';

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

type FlatAuditValue = {
  path: string[];
  value: Json;
};

type AuditChange = {
  key: string;
  path: string[];
  before?: Json;
  after?: Json;
  kind: 'added' | 'removed' | 'updated';
};

function pathKey(path: string[]) {
  return JSON.stringify(path);
}

function flattenAuditValue(value: Json, path: string[], output: Map<string, FlatAuditValue>) {
  if (Array.isArray(value)) {
    if (value.length === 0) {
      output.set(pathKey(path), { path, value });
      return;
    }

    value.forEach((item, index) => flattenAuditValue(item, [...path, `Item ${index + 1}`], output));
    return;
  }

  if (typeof value === 'object' && value !== null) {
    const entries = Object.entries(value).filter((entry): entry is [string, Json] => entry[1] !== undefined);
    if (entries.length === 0) {
      output.set(pathKey(path), { path, value });
      return;
    }

    entries.forEach(([key, item]) => flattenAuditValue(item, [...path, key], output));
    return;
  }

  output.set(pathKey(path), { path, value });
}

function flattenSnapshot(value: Json | null) {
  const output = new Map<string, FlatAuditValue>();
  if (value !== null) flattenAuditValue(value, [], output);
  return output;
}

function valuesMatch(left: Json, right: Json) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function getAuditChanges(oldValue: Json | null, newValue: Json | null): AuditChange[] {
  const before = flattenSnapshot(oldValue);
  const after = flattenSnapshot(newValue);
  const keys = [...after.keys(), ...[...before.keys()].filter((key) => !after.has(key))];

  return keys.flatMap((key) => {
    const previous = before.get(key);
    const next = after.get(key);

    if (previous && next && valuesMatch(previous.value, next.value)) return [];
    return [{
      key,
      path: next?.path ?? previous?.path ?? [],
      before: previous?.value,
      after: next?.value,
      kind: !previous ? 'added' : !next ? 'removed' : 'updated',
    }];
  });
}

function formatPathSegment(segment: string) {
  if (/^Item \d+$/.test(segment)) return segment;

  return segment
    .split('_')
    .filter(Boolean)
    .map((part) => {
      const normalized = part.toLowerCase();
      if (normalized === 'id') return 'ID';
      if (normalized === 'ip') return 'IP';
      if (normalized === 'url') return 'URL';
      return normalized.charAt(0).toUpperCase() + normalized.slice(1);
    })
    .join(' ');
}

function formatAuditValue(value: Json | undefined) {
  if (value === undefined || value === null) return 'Not recorded';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'number') return value.toLocaleString('en-PH');
  if (Array.isArray(value)) return value.length === 0 ? 'Empty list' : JSON.stringify(value);
  if (typeof value === 'object') return Object.keys(value).length === 0 ? 'Empty object' : JSON.stringify(value);
  if (value.trim() === '') return 'Empty text';
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)) return formatAuditDateTime(value);
  if (/^[A-Z0-9]+(?:_[A-Z0-9]+)+$/.test(value)) return formatAuditIdentifier(value);
  return value;
}

function AuditFieldPath({ path }: { path: string[] }) {
  const segments = path.length > 0 ? path : ['Value'];

  return (
    <div className="flex flex-wrap items-center gap-x-1 gap-y-0.5 text-sm font-medium">
      {segments.map((segment, index) => (
        <span className="contents" key={`${segment}-${index}`}>
          {index > 0 ? <span className="text-muted-foreground/60">›</span> : null}
          <span>{formatPathSegment(segment)}</span>
        </span>
      ))}
    </div>
  );
}

function AuditValue({ value, empty, tone }: { value: Json | undefined; empty?: boolean; tone: 'before' | 'after' }) {
  return (
    <div
      className={cn(
        'min-w-0 rounded-md border px-3 py-2 text-sm leading-5',
        empty
          ? 'border-dashed bg-muted/20 text-muted-foreground'
          : tone === 'before'
            ? 'border-rose-200 bg-rose-50/70 text-rose-950 dark:border-rose-900 dark:bg-rose-950/25 dark:text-rose-100'
            : 'border-emerald-200 bg-emerald-50/70 text-emerald-950 dark:border-emerald-900 dark:bg-emerald-950/25 dark:text-emerald-100',
      )}
    >
      <span className="break-words [overflow-wrap:anywhere]">{empty ? 'Not present' : formatAuditValue(value)}</span>
    </div>
  );
}

function ChangeKind({ kind }: { kind: AuditChange['kind'] }) {
  const config = {
    added: { icon: CirclePlus, label: 'Added', className: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200' },
    removed: { icon: CircleMinus, label: 'Removed', className: 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-200' },
    updated: { icon: PencilLine, label: 'Updated', className: 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-200' },
  }[kind];
  const Icon = config.icon;

  return (
    <span className={cn('inline-flex w-fit items-center gap-1 rounded-full px-2 py-1 text-[11px] font-medium', config.className)}>
      <Icon className="h-3 w-3" />
      {config.label}
    </span>
  );
}

function AuditChangesPanel({ oldValue, newValue }: { oldValue: Json | null; newValue: Json | null }) {
  const changes = getAuditChanges(oldValue, newValue);

  return (
    <section className="min-w-0 overflow-hidden rounded-xl border bg-card">
      <div className="flex flex-col gap-3 border-b bg-muted/20 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex min-w-0 items-start gap-3">
          <div className="mt-0.5 rounded-lg bg-primary/10 p-2 text-primary">
            <GitCompareArrows className="h-4 w-4" />
          </div>
          <div className="min-w-0">
            <h3 className="text-sm font-semibold">What changed</h3>
            <p className="mt-0.5 text-xs leading-5 text-muted-foreground">Only fields with a different value are shown.</p>
          </div>
        </div>
        <span className="w-fit rounded-full border bg-background px-2.5 py-1 text-xs font-medium">
          {changes.length} {changes.length === 1 ? 'change' : 'changes'}
        </span>
      </div>

      {changes.length === 0 ? (
        <div className="flex min-h-28 flex-col items-center justify-center px-4 py-6 text-center">
          <GitCompareArrows className="h-5 w-5 text-muted-foreground" />
          <p className="mt-2 text-sm font-medium">No field-level changes</p>
          <p className="mt-1 text-xs text-muted-foreground">The before and after snapshots are identical or were not recorded.</p>
        </div>
      ) : (
        <div className="max-h-[32rem] overflow-y-auto">
          <div className="hidden grid-cols-[minmax(9rem,0.7fr)_minmax(0,1fr)_1.5rem_minmax(0,1fr)] gap-3 border-b bg-muted/10 px-4 py-2 text-[11px] font-medium uppercase tracking-wide text-muted-foreground sm:grid">
            <span>Field</span>
            <span>Previous value</span>
            <span aria-hidden="true" />
            <span>New value</span>
          </div>
          <div className="divide-y">
            {changes.map((change) => (
              <article className="grid gap-3 px-4 py-4 sm:grid-cols-[minmax(9rem,0.7fr)_minmax(0,1fr)_1.5rem_minmax(0,1fr)] sm:items-center" key={change.key}>
                <div className="flex min-w-0 items-start justify-between gap-2 sm:block">
                  <AuditFieldPath path={change.path} />
                  <div className="shrink-0 sm:mt-2"><ChangeKind kind={change.kind} /></div>
                </div>
                <div className="min-w-0">
                  <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-muted-foreground sm:hidden">Previous value</p>
                  <AuditValue value={change.before} empty={change.kind === 'added'} tone="before" />
                </div>
                <ArrowRight className="mx-auto hidden h-4 w-4 text-muted-foreground sm:block" />
                <div className="min-w-0">
                  <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-muted-foreground sm:hidden">New value</p>
                  <AuditValue value={change.after} empty={change.kind === 'removed'} tone="after" />
                </div>
              </article>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}

function AuditMetadataPanel({ value }: { value: Json | null }) {
  const items = [...flattenSnapshot(value).values()];

  return (
    <section className="min-w-0 rounded-xl border bg-card p-4">
      <div className="flex items-start gap-3">
        <div className="mt-0.5 rounded-lg bg-sky-100 p-2 text-sky-700 dark:bg-sky-950 dark:text-sky-200">
          <Info className="h-4 w-4" />
        </div>
        <div>
          <h3 className="text-sm font-semibold">Additional details</h3>
          <p className="mt-0.5 text-xs leading-5 text-muted-foreground">Context recorded alongside this activity.</p>
        </div>
      </div>

      {items.length === 0 ? (
        <p className="mt-4 rounded-lg border border-dashed bg-muted/20 px-3 py-4 text-center text-sm text-muted-foreground">No additional details were recorded.</p>
      ) : (
        <dl className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((item) => (
            <div className="min-w-0 rounded-lg border bg-muted/15 px-3 py-2.5" key={pathKey(item.path)}>
              <dt className="text-xs text-muted-foreground"><AuditFieldPath path={item.path} /></dt>
              <dd className="mt-1 break-words text-sm font-medium [overflow-wrap:anywhere]">{formatAuditValue(item.value)}</dd>
            </div>
          ))}
        </dl>
      )}
    </section>
  );
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

export function AuditLogDataDetails({
  oldValue,
  newValue,
  metadata,
}: {
  oldValue: Json | null;
  newValue: Json | null;
  metadata: Json | null;
}) {
  return (
    <div className="min-w-0 space-y-4">
      <AuditChangesPanel oldValue={oldValue} newValue={newValue} />
      <AuditMetadataPanel value={metadata} />

      <details className="group min-w-0 rounded-xl border bg-card">
        <summary className="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-medium transition-colors hover:bg-muted/30 [&::-webkit-details-marker]:hidden">
          <span className="flex items-center gap-2"><FileJson2 className="h-4 w-4 text-muted-foreground" />Raw audit data</span>
          <ChevronDown className="h-4 w-4 text-muted-foreground transition-transform group-open:rotate-180" />
        </summary>
        <div className="space-y-4 border-t p-4">
          <p className="text-xs leading-5 text-muted-foreground">Exact values stored by the system. Use this view for technical investigation.</p>
          <div className="grid min-w-0 gap-4 lg:grid-cols-2">
            <AuditJsonPanel title="Before" value={oldValue} />
            <AuditJsonPanel title="After" value={newValue} />
          </div>
          <AuditJsonPanel title="Metadata" value={metadata} />
        </div>
      </details>
    </div>
  );
}
