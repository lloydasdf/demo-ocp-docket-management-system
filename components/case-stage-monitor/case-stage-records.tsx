'use client';

import Link from 'next/link';
import { ArrowUpRight, RotateCcw } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import type {
  DeveloperCaseStageDistributionRecord,
  DeveloperCaseStageMonitorRecord,
  DeveloperCaseStageQueue,
} from '@/lib/supabase/queries';
import { cn } from '@/lib/utils';

const dateFormatter = new Intl.DateTimeFormat('en-PH', {
  timeZone: 'Asia/Manila',
  dateStyle: 'medium',
});
const numberFormatter = new Intl.NumberFormat('en-PH');

const QUEUE_OPTIONS: Array<{ value: DeveloperCaseStageQueue; label: string }> = [
  { value: 'all', label: 'All attention states' },
  { value: 'attention', label: 'Needs attention' },
  { value: 'unassigned', label: 'No prosecutor' },
  { value: 'unapproved_resolution', label: 'Resolution approval' },
  { value: 'unfiled_for_filing', label: 'Awaiting filing' },
  { value: 'unresolved_motion', label: 'Unresolved motion' },
  { value: 'motion_resolution_for_approval', label: 'Motion approval' },
  { value: 'pending_petition', label: 'Petition review' },
];

export type CaseStageColumnFilters = {
  caseSearch: string;
  stageCode: string;
  queue: DeveloperCaseStageQueue;
  prosecutorSearch: string;
  minStageDays: string;
  maxStageDays: string;
  latestEventSearch: string;
};

export const EMPTY_CASE_STAGE_COLUMN_FILTERS: CaseStageColumnFilters = {
  caseSearch: '',
  stageCode: 'all',
  queue: 'all',
  prosecutorSearch: '',
  minStageDays: '',
  maxStageDays: '',
  latestEventSearch: '',
};

function formatDate(value: string | null) {
  if (!value) return '—';
  const date = new Date(`${value.slice(0, 10)}T00:00:00+08:00`);
  return Number.isNaN(date.getTime()) ? value : dateFormatter.format(date);
}

function formatIdentifier(value: string) {
  return value.replace(/[_-]+/g, ' ').trim().replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function StageBadge({ row }: { row: DeveloperCaseStageMonitorRecord }) {
  return <Badge className="max-w-full whitespace-normal text-left leading-5" variant={row.is_final_stage ? 'default' : 'outline'}>{row.current_case_stage_label ?? 'Unspecified stage'}</Badge>;
}

function AttentionBadges({ row }: { row: DeveloperCaseStageMonitorRecord }) {
  const items = [
    row.has_no_active_prosecutor ? { key: 'prosecutor', label: 'No prosecutor', count: 1, variant: 'destructive' as const } : null,
    row.has_unapproved_case_resolution ? { key: 'resolution', label: 'Resolution approval', count: row.unapproved_case_resolution_count, variant: 'outline' as const } : null,
    row.has_unfiled_for_filing ? { key: 'filing', label: 'Not yet filed', count: row.unfiled_for_filing_count, variant: 'default' as const } : null,
    row.has_unresolved_motion ? { key: 'motion', label: 'Unresolved motion', count: row.unresolved_motion_count, variant: 'secondary' as const } : null,
    row.has_unapproved_motion_resolution ? { key: 'motion-approval', label: 'Motion approval', count: row.unapproved_motion_resolution_count, variant: 'outline' as const } : null,
    row.is_pending_petition_for_review ? { key: 'petition', label: 'Petition review', count: 1, variant: 'secondary' as const } : null,
  ].filter((item): item is NonNullable<typeof item> => item !== null);

  if (items.length === 0) return <span className="text-xs text-muted-foreground">No monitored exception</span>;
  return <div className="flex flex-wrap gap-1.5">{items.map((item) => <Badge key={item.key} className="max-w-full whitespace-normal text-left leading-5" variant={item.variant}>{item.label}{item.count > 1 ? ` · ${item.count}` : ''}</Badge>)}</div>;
}

function StageFilter({ filters, stageOptions, onChange }: FilterControlsProps) {
  return (
    <Select value={filters.stageCode} onValueChange={(stageCode) => onChange({ ...filters, stageCode })}>
      <SelectTrigger className="w-full bg-background" aria-label="Filter current stage column"><SelectValue placeholder="All stages" /></SelectTrigger>
      <SelectContent>
        <SelectItem value="all">All stages</SelectItem>
        {filters.stageCode !== 'all' && !stageOptions.some((stage) => stage.stage_code === filters.stageCode) ? <SelectItem value={filters.stageCode}>{formatIdentifier(filters.stageCode)}</SelectItem> : null}
        {stageOptions.map((stage) => <SelectItem key={stage.stage_code} value={stage.stage_code}>{stage.stage_label}</SelectItem>)}
      </SelectContent>
    </Select>
  );
}

function QueueFilter({ filters, onChange }: Pick<FilterControlsProps, 'filters' | 'onChange'>) {
  return (
    <Select value={filters.queue} onValueChange={(queue) => onChange({ ...filters, queue: queue as DeveloperCaseStageQueue })}>
      <SelectTrigger className="w-full bg-background" aria-label="Filter attention column"><SelectValue /></SelectTrigger>
      <SelectContent>{QUEUE_OPTIONS.map((option) => <SelectItem key={option.value} value={option.value}>{option.label}</SelectItem>)}</SelectContent>
    </Select>
  );
}

type FilterControlsProps = {
  filters: CaseStageColumnFilters;
  stageOptions: DeveloperCaseStageDistributionRecord[];
  onChange: (filters: CaseStageColumnFilters) => void;
};

function MobileColumnFilters({ filters, stageOptions, onChange, onReset }: FilterControlsProps & { onReset: () => void }) {
  return (
    <section className="rounded-xl border bg-muted/20 p-3 md:hidden" aria-label="Case stage column filters">
      <div className="mb-3 flex items-center justify-between gap-3"><p className="text-sm font-semibold">Column filters</p><Button type="button" variant="ghost" size="sm" onClick={onReset}><RotateCcw className="h-4 w-4" />Reset</Button></div>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="space-y-1 text-xs font-medium text-muted-foreground">Case<Input className="bg-background" value={filters.caseSearch} onChange={(event) => onChange({ ...filters, caseSearch: event.target.value })} placeholder="Docket, type, class, violation" /></label>
        <label className="space-y-1 text-xs font-medium text-muted-foreground">Stage and status<StageFilter filters={filters} stageOptions={stageOptions} onChange={onChange} /></label>
        <label className="space-y-1 text-xs font-medium text-muted-foreground">Attention<QueueFilter filters={filters} onChange={onChange} /></label>
        <label className="space-y-1 text-xs font-medium text-muted-foreground">Prosecutor<Input className="bg-background" value={filters.prosecutorSearch} onChange={(event) => onChange({ ...filters, prosecutorSearch: event.target.value })} placeholder="Name, assigned, unassigned" /></label>
        <fieldset className="space-y-1"><legend className="text-xs font-medium text-muted-foreground">Stage age in days</legend><div className="grid grid-cols-2 gap-2"><Input className="bg-background" type="number" min="0" value={filters.minStageDays} onChange={(event) => onChange({ ...filters, minStageDays: event.target.value })} placeholder="Min" aria-label="Minimum stage age" /><Input className="bg-background" type="number" min="0" value={filters.maxStageDays} onChange={(event) => onChange({ ...filters, maxStageDays: event.target.value })} placeholder="Max" aria-label="Maximum stage age" /></div></fieldset>
        <label className="space-y-1 text-xs font-medium text-muted-foreground">Latest event<Input className="bg-background" value={filters.latestEventSearch} onChange={(event) => onChange({ ...filters, latestEventSearch: event.target.value })} placeholder="Title, type, or no event" /></label>
      </div>
    </section>
  );
}

export function CaseStageRecords({ rows, isLoading, filters, stageOptions, onFiltersChange, onResetFilters }: {
  rows: DeveloperCaseStageMonitorRecord[];
  isLoading: boolean;
  filters: CaseStageColumnFilters;
  stageOptions: DeveloperCaseStageDistributionRecord[];
  onFiltersChange: (filters: CaseStageColumnFilters) => void;
  onResetFilters: () => void;
}) {
  return (
    <>
      <MobileColumnFilters filters={filters} stageOptions={stageOptions} onChange={onFiltersChange} onReset={onResetFilters} />

      <div className="space-y-3 md:hidden">
        {isLoading ? <div className="flex min-h-32 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">Loading monitored cases…</div> : rows.length === 0 ? <div className="flex min-h-32 items-center justify-center rounded-xl border bg-card p-4 text-center text-sm text-muted-foreground">No cases match these column filters.</div> : rows.map((row) => (
          <article key={row.case_id} className="min-w-0 rounded-xl border bg-card p-4 shadow-sm">
            <div className="flex min-w-0 items-start justify-between gap-3"><div className="min-w-0"><Link className="break-words text-base font-semibold text-primary hover:underline" href={`/cases/${row.case_id}`}>{row.docket_display_number}</Link><p className="mt-1 text-xs text-muted-foreground">{row.docket_type_prefix} · Docket year {row.docket_year} · Received {formatDate(row.date_received)}</p></div><Button className="size-10 shrink-0" variant="ghost" size="icon" asChild><Link href={`/cases/${row.case_id}`} aria-label={`Open case ${row.docket_display_number}`}><ArrowUpRight className="h-4 w-4" /></Link></Button></div>
            <div className="mt-3"><StageBadge row={row} /><p className="mt-1 text-xs text-muted-foreground">{numberFormatter.format(row.days_in_current_stage)} days in stage · {numberFormatter.format(row.case_age_days)} days old</p></div>
            <div className="mt-4"><AttentionBadges row={row} /></div>
            <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 border-t pt-4 text-sm"><div className="col-span-2 min-w-0"><dt className="text-xs text-muted-foreground">Status</dt><dd className="mt-1 break-words font-medium">{row.current_case_status_label ?? 'No status recorded'}</dd></div><div className="col-span-2 min-w-0"><dt className="text-xs text-muted-foreground">Assigned prosecutor</dt><dd className={cn('mt-1 break-all font-medium', !row.prosecutor_display && 'text-destructive')}>{row.prosecutor_display ?? 'Unassigned'}</dd></div><div><dt className="text-xs text-muted-foreground">Oldest attention</dt><dd className="mt-1 font-medium">{formatDate(row.oldest_attention_date)}</dd></div><div><dt className="text-xs text-muted-foreground">Latest event</dt><dd className="mt-1 break-words font-medium">{row.latest_event_id ? <Link className="text-primary hover:underline" href={`/cases/${row.case_id}#case-timeline`}>{row.latest_event_title ?? row.latest_event_type_label ?? 'Open event'}</Link> : 'No event recorded'}</dd><p className="text-xs text-muted-foreground">{formatDate(row.latest_event_date)}</p></div></dl>
            {row.case_classification_label ? <p className="mt-4 break-words border-t pt-4 text-sm font-medium">{row.case_classification_label}</p> : null}{row.violations ? <p className="mt-2 line-clamp-3 break-words text-xs leading-5 text-muted-foreground">{row.violations}</p> : null}<Button className="mt-4 w-full" asChild><Link href={`/cases/${row.case_id}#case-timeline`}>Open case timeline<ArrowUpRight className="h-4 w-4" /></Link></Button>
          </article>
        ))}
      </div>

      <div className="hidden overflow-x-auto rounded-lg border md:block">
        <Table>
          <TableHeader className="bg-muted/40">
            <TableRow><TableHead>Case</TableHead><TableHead>Stage and status</TableHead><TableHead className="min-w-64">Attention</TableHead><TableHead>Prosecutor</TableHead><TableHead className="text-right">Stage age</TableHead><TableHead className="min-w-56">Latest event</TableHead></TableRow>
            <TableRow className="bg-muted/20 align-top hover:bg-muted/20">
              <TableHead className="p-2"><Input className="min-w-44 bg-background" value={filters.caseSearch} onChange={(event) => onFiltersChange({ ...filters, caseSearch: event.target.value })} placeholder="Docket, type, class…" aria-label="Filter case column" /></TableHead>
              <TableHead className="p-2"><StageFilter filters={filters} stageOptions={stageOptions} onChange={onFiltersChange} /></TableHead>
              <TableHead className="p-2"><QueueFilter filters={filters} onChange={onFiltersChange} /></TableHead>
              <TableHead className="p-2"><Input className="min-w-40 bg-background" value={filters.prosecutorSearch} onChange={(event) => onFiltersChange({ ...filters, prosecutorSearch: event.target.value })} placeholder="Name or unassigned" aria-label="Filter prosecutor column" /></TableHead>
              <TableHead className="p-2"><div className="grid min-w-36 grid-cols-2 gap-1"><Input className="bg-background" type="number" min="0" value={filters.minStageDays} onChange={(event) => onFiltersChange({ ...filters, minStageDays: event.target.value })} placeholder="Min" aria-label="Minimum stage age" /><Input className="bg-background" type="number" min="0" value={filters.maxStageDays} onChange={(event) => onFiltersChange({ ...filters, maxStageDays: event.target.value })} placeholder="Max" aria-label="Maximum stage age" /></div></TableHead>
              <TableHead className="p-2"><div className="flex min-w-48 gap-1"><Input className="bg-background" value={filters.latestEventSearch} onChange={(event) => onFiltersChange({ ...filters, latestEventSearch: event.target.value })} placeholder="Title, type, no event" aria-label="Filter latest event column" /><Button className="size-9 shrink-0" type="button" variant="ghost" size="icon" onClick={onResetFilters} aria-label="Reset all column filters" title="Reset column filters"><RotateCcw className="h-4 w-4" /></Button></div></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? <TableRow><TableCell colSpan={6} className="h-32 text-center text-muted-foreground">Loading monitored cases…</TableCell></TableRow> : rows.length === 0 ? <TableRow><TableCell colSpan={6} className="h-32 text-center text-muted-foreground">No cases match these column filters.</TableCell></TableRow> : rows.map((row) => (
              <TableRow key={row.case_id}>
                <TableCell className="whitespace-normal"><Link className="font-semibold text-primary hover:underline" href={`/cases/${row.case_id}`}>{row.docket_display_number}</Link><p className="mt-1 text-xs text-muted-foreground">{row.docket_type_prefix} · {row.docket_year} · Received {formatDate(row.date_received)}</p><p className="mt-1 max-w-64 line-clamp-1 text-xs text-muted-foreground">{row.case_classification_label ?? row.violations ?? `Case #${row.case_id}`}</p></TableCell>
                <TableCell className="whitespace-normal"><StageBadge row={row} /><p className="mt-1 text-xs text-muted-foreground">{row.current_case_status_label ?? 'No status'} · since {formatDate(row.current_case_stage_date)}</p></TableCell>
                <TableCell className="whitespace-normal"><AttentionBadges row={row} />{row.oldest_attention_date ? <p className="mt-1 text-xs text-muted-foreground">Oldest: {formatDate(row.oldest_attention_date)}</p> : null}</TableCell>
                <TableCell className={cn('max-w-56 whitespace-normal break-all text-sm', !row.prosecutor_display && 'font-medium text-destructive')}>{row.prosecutor_display ?? 'Unassigned'}</TableCell>
                <TableCell className="text-right"><p className="font-semibold">{numberFormatter.format(row.days_in_current_stage)}d</p><p className="text-xs text-muted-foreground">Case {numberFormatter.format(row.case_age_days)}d</p></TableCell>
                <TableCell className="whitespace-normal"><p className="line-clamp-2 text-sm font-medium">{row.latest_event_id ? <Link className="text-primary hover:underline" href={`/cases/${row.case_id}#case-timeline`}>{row.latest_event_title ?? row.latest_event_type_label ?? 'Open event'}</Link> : 'No event recorded'}</p><p className="mt-1 text-xs text-muted-foreground">{row.latest_event_type_label ?? '—'} · {formatDate(row.latest_event_date)}</p></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </>
  );
}
