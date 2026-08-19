'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import {
  ArrowRight,
  CheckCircle2,
  CircleAlert,
  DatabaseZap,
  ExternalLink,
  Loader2,
  Search,
} from 'lucide-react';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import {
  applyAutoUpdateCaseStates,
  getDeveloperCaseStageYears,
  getDocketTypes,
  previewAutoUpdateCaseStates,
  type AutoUpdateCaseStateCandidate,
} from '@/lib/supabase/queries';

const MONTH_OPTIONS = [
  { code: 'A', label: 'January' },
  { code: 'B', label: 'February' },
  { code: 'C', label: 'March' },
  { code: 'D', label: 'April' },
  { code: 'E', label: 'May' },
  { code: 'F', label: 'June' },
  { code: 'G', label: 'July' },
  { code: 'H', label: 'August' },
  { code: 'I', label: 'September' },
  { code: 'J', label: 'October' },
  { code: 'K', label: 'November' },
  { code: 'L', label: 'December' },
] as const;

type DocketTypeOption = {
  id: number;
  prefix: string;
  name: string;
  is_active: boolean;
};

const numberFormatter = new Intl.NumberFormat('en-PH');
const dateFormatter = new Intl.DateTimeFormat('en-PH', {
  timeZone: 'Asia/Manila',
  dateStyle: 'medium',
});

function formatDate(value: string) {
  const parsed = new Date(`${value}T00:00:00+08:00`);
  return Number.isNaN(parsed.getTime()) ? value : dateFormatter.format(parsed);
}

function CurrentState({ row }: { row: AutoUpdateCaseStateCandidate }) {
  return (
    <div className="flex min-w-[10rem] flex-col items-start gap-1.5">
      <Badge variant="outline">{row.current_case_status_label ?? 'Status not set'}</Badge>
      <span className="text-xs text-muted-foreground">{row.current_case_stage_label ?? 'Stage not set'}</span>
    </div>
  );
}

function ComputedState({ row }: { row: AutoUpdateCaseStateCandidate }) {
  return (
    <div className="flex min-w-[10rem] flex-col items-start gap-1.5">
      <Badge className="border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200">
        {row.computed_case_status_label}
      </Badge>
      <span className="text-xs font-medium text-foreground">{row.computed_case_stage_label}</span>
    </div>
  );
}

export default function AutoUpdateCasesStatusPage() {
  const [yearOptions, setYearOptions] = useState<number[]>([]);
  const [docketTypeOptions, setDocketTypeOptions] = useState<DocketTypeOption[]>([]);
  const [docketYear, setDocketYear] = useState('');
  const [docketMonth, setDocketMonth] = useState('');
  const [docketType, setDocketType] = useState('');
  const [rows, setRows] = useState<AutoUpdateCaseStateCandidate[]>([]);
  const [selectedCaseIds, setSelectedCaseIds] = useState<Set<number>>(new Set());
  const [search, setSearch] = useState('');
  const [hasPreviewed, setHasPreviewed] = useState(false);
  const [isLoadingOptions, setIsLoadingOptions] = useState(true);
  const [isPreviewing, setIsPreviewing] = useState(false);
  const [isApplying, setIsApplying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const filtersReady = Boolean(docketYear && docketMonth && docketType);
  const selectedCount = selectedCaseIds.size;
  const visibleRows = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();
    if (!normalizedSearch) return rows;

    return rows.filter((row) => [
      row.docket_display_number,
      row.complainant,
      row.respondent,
      row.violations,
      row.current_case_status_label,
      row.current_case_stage_label,
      row.computed_case_status_label,
      row.computed_case_stage_label,
    ].some((value) => value?.toLowerCase().includes(normalizedSearch)));
  }, [rows, search]);
  const allVisibleSelected = visibleRows.length > 0 && visibleRows.every((row) => selectedCaseIds.has(row.case_id));
  const someVisibleSelected = visibleRows.some((row) => selectedCaseIds.has(row.case_id));

  useEffect(() => {
    let isActive = true;

    async function loadOptions() {
      setIsLoadingOptions(true);
      const [yearsResult, docketTypesResult] = await Promise.all([
        getDeveloperCaseStageYears(),
        getDocketTypes(),
      ]);

      if (!isActive) return;
      if (yearsResult.error || docketTypesResult.error) {
        setError(yearsResult.error?.message ?? docketTypesResult.error?.message ?? 'Unable to load docket filters.');
      } else {
        setYearOptions(yearsResult.data
          .map((option) => option.docket_year)
          .filter((year): year is number => year !== null));
        setDocketTypeOptions((docketTypesResult.data as DocketTypeOption[]).filter((option) => option.is_active));
      }
      setIsLoadingOptions(false);
    }

    void loadOptions();
    return () => { isActive = false; };
  }, []);

  function invalidatePreview() {
    setRows([]);
    setSelectedCaseIds(new Set());
    setSearch('');
    setHasPreviewed(false);
    setSuccess(null);
  }

  async function previewChanges() {
    if (!filtersReady) return;
    setIsPreviewing(true);
    setError(null);
    setSuccess(null);
    setSelectedCaseIds(new Set());
    setSearch('');

    const result = await previewAutoUpdateCaseStates({
      docketYear: Number(docketYear),
      docketMonthCode: docketMonth,
      docketTypeId: Number(docketType),
    });

    if (result.error) {
      setRows([]);
      setError(result.error.message);
    } else {
      setRows(result.data);
    }
    setHasPreviewed(true);
    setIsPreviewing(false);
  }

  function toggleCase(caseId: number, checked: boolean) {
    setSelectedCaseIds((current) => {
      const next = new Set(current);
      if (checked) next.add(caseId);
      else next.delete(caseId);
      return next;
    });
  }

  function toggleVisibleCases(checked: boolean) {
    setSelectedCaseIds((current) => {
      const next = new Set(current);
      for (const row of visibleRows) {
        if (checked) next.add(row.case_id);
        else next.delete(row.case_id);
      }
      return next;
    });
  }

  async function applySelectedChanges() {
    if (selectedCaseIds.size === 0) return;
    const requestedCount = selectedCaseIds.size;
    setIsApplying(true);
    setError(null);
    setSuccess(null);

    const applyResult = await applyAutoUpdateCaseStates(Array.from(selectedCaseIds));
    if (applyResult.error) {
      setError(applyResult.error.message);
      setIsApplying(false);
      return;
    }

    const refreshResult = await previewAutoUpdateCaseStates({
      docketYear: Number(docketYear),
      docketMonthCode: docketMonth,
      docketTypeId: Number(docketType),
    });
    const updatedCount = applyResult.data.length;

    if (refreshResult.error) {
      const updatedIds = new Set(applyResult.data.map((row) => row.case_id));
      setRows((current) => current.filter((row) => !updatedIds.has(row.case_id)));
      setError(`Cases were updated, but the preview could not be refreshed: ${refreshResult.error.message}`);
    } else {
      setRows(refreshResult.data);
    }

    setSelectedCaseIds(new Set());
    setSuccess(updatedCount === requestedCount
      ? `${numberFormatter.format(updatedCount)} ${updatedCount === 1 ? 'case was' : 'cases were'} updated.`
      : `${numberFormatter.format(updatedCount)} of ${numberFormatter.format(requestedCount)} selected cases required an update when recomputed.`);
    setIsApplying(false);
  }

  return (
    <RoleRouteGuard route="/developer/auto-update-cases-status">
      <div className="flex min-h-screen bg-muted/20">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto px-3 pb-6 pt-16 sm:px-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-[1600px] space-y-5">
            <header className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div className="space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary"><DatabaseZap className="h-5 w-5" /></div>
                  <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Auto Update Cases Status</h1>
                  <Badge variant="secondary">Developer only</Badge>
                </div>
                <p className="text-sm text-muted-foreground">Review computed case status and stage differences for a single docket group.</p>
              </div>
              {hasPreviewed ? (
                <div className="flex items-center gap-3 rounded-md border bg-background px-4 py-2 text-sm shadow-xs">
                  <span><strong>{numberFormatter.format(rows.length)}</strong> changes</span>
                  <span className="h-5 w-px bg-border" />
                  <span><strong>{numberFormatter.format(selectedCount)}</strong> selected</span>
                </div>
              ) : null}
            </header>

            {error ? (
              <Alert variant="destructive">
                <CircleAlert className="h-4 w-4" />
                <AlertTitle>Unable to complete the request</AlertTitle>
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            ) : null}
            {success ? (
              <Alert className="border-emerald-200 bg-emerald-50 text-emerald-950 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-100">
                <CheckCircle2 className="h-4 w-4" />
                <AlertTitle>Update complete</AlertTitle>
                <AlertDescription>{success} No case event was created.</AlertDescription>
              </Alert>
            ) : null}

            <Card className="gap-4 py-5">
              <CardHeader className="px-5 sm:px-6">
                <CardTitle>Docket filters</CardTitle>
                <CardDescription>Year, month, and docket type are required before computing a preview.</CardDescription>
              </CardHeader>
              <CardContent className="grid gap-4 px-5 sm:grid-cols-2 sm:px-6 lg:grid-cols-[minmax(9rem,0.7fr)_minmax(10rem,1fr)_minmax(15rem,1.5fr)_auto] lg:items-end">
                <div className="space-y-2">
                  <Label htmlFor="docket-year">Docket year</Label>
                  <Select value={docketYear} onValueChange={(value) => { setDocketYear(value); invalidatePreview(); }} disabled={isLoadingOptions || isApplying}>
                    <SelectTrigger id="docket-year" className="w-full"><SelectValue placeholder="Select year" /></SelectTrigger>
                    <SelectContent>{yearOptions.map((year) => <SelectItem key={year} value={String(year)}>{year}</SelectItem>)}</SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="docket-month">Docket month</Label>
                  <Select value={docketMonth} onValueChange={(value) => { setDocketMonth(value); invalidatePreview(); }} disabled={isLoadingOptions || isApplying}>
                    <SelectTrigger id="docket-month" className="w-full"><SelectValue placeholder="Select month" /></SelectTrigger>
                    <SelectContent>{MONTH_OPTIONS.map((month) => <SelectItem key={month.code} value={month.code}>{month.label} ({month.code})</SelectItem>)}</SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="docket-type">Docket type</Label>
                  <Select value={docketType} onValueChange={(value) => { setDocketType(value); invalidatePreview(); }} disabled={isLoadingOptions || isApplying}>
                    <SelectTrigger id="docket-type" className="w-full"><SelectValue placeholder="Select docket type" /></SelectTrigger>
                    <SelectContent>{docketTypeOptions.map((option) => <SelectItem key={option.id} value={String(option.id)}>{option.prefix} - {option.name}</SelectItem>)}</SelectContent>
                  </Select>
                </div>
                <Button className="w-full lg:w-auto" onClick={() => void previewChanges()} disabled={!filtersReady || isPreviewing || isApplying}>
                  {isPreviewing ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <DatabaseZap className="mr-2 h-4 w-4" />}
                  {isPreviewing ? 'Computing...' : 'Compute preview'}
                </Button>
              </CardContent>
            </Card>

            <Card className="gap-0 overflow-hidden py-0">
              <CardHeader className="border-b px-5 py-5 sm:px-6">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                  <div className="space-y-1">
                    <CardTitle>Cases with computed changes</CardTitle>
                    <CardDescription>{hasPreviewed ? `${numberFormatter.format(rows.length)} cases differ from their computed current state.` : 'No preview has been computed.'}</CardDescription>
                  </div>
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                    {rows.length > 0 ? (
                      <div className="relative min-w-0 sm:w-72">
                        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                        <Input className="pl-9" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search preview" aria-label="Search preview" />
                      </div>
                    ) : null}
                    {rows.length > 0 ? (
                      <Button variant="outline" onClick={() => setSelectedCaseIds(selectedCount === rows.length ? new Set() : new Set(rows.map((row) => row.case_id)))} disabled={isApplying}>
                        {selectedCount === rows.length ? 'Clear selection' : 'Select all changes'}
                      </Button>
                    ) : null}
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <Button disabled={selectedCount === 0 || isApplying}>
                          {isApplying ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <CheckCircle2 className="mr-2 h-4 w-4" />}
                          Update selected ({numberFormatter.format(selectedCount)})
                        </Button>
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>Update {numberFormatter.format(selectedCount)} selected {selectedCount === 1 ? 'case' : 'cases'}?</AlertDialogTitle>
                          <AlertDialogDescription>
                            Each selected case will be recomputed, then its current status and stage will be synchronized. This action creates an audit log but no case event.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Cancel</AlertDialogCancel>
                          <AlertDialogAction onClick={() => void applySelectedChanges()}>Update selected</AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </div>
                </div>
              </CardHeader>

              {isPreviewing ? (
                <div className="flex min-h-64 items-center justify-center gap-2 text-sm text-muted-foreground">
                  <Loader2 className="h-5 w-5 animate-spin" /> Computing current case states...
                </div>
              ) : visibleRows.length > 0 ? (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="w-10 pl-5">
                        <Checkbox
                          checked={allVisibleSelected ? true : someVisibleSelected ? 'indeterminate' : false}
                          onCheckedChange={(checked) => toggleVisibleCases(checked === true)}
                          aria-label="Select visible cases"
                        />
                      </TableHead>
                      <TableHead>Case</TableHead>
                      <TableHead>Parties / violation</TableHead>
                      <TableHead>Current</TableHead>
                      <TableHead className="w-8"><span className="sr-only">Changes to</span></TableHead>
                      <TableHead>Computed</TableHead>
                      <TableHead>Fields</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {visibleRows.map((row) => {
                      const isSelected = selectedCaseIds.has(row.case_id);
                      return (
                        <TableRow key={row.case_id} data-state={isSelected ? 'selected' : undefined}>
                          <TableCell className="pl-5">
                            <Checkbox checked={isSelected} onCheckedChange={(checked) => toggleCase(row.case_id, checked === true)} aria-label={`Select ${row.docket_display_number}`} />
                          </TableCell>
                          <TableCell className="min-w-52 whitespace-normal">
                            <Link className="inline-flex items-center gap-1 font-semibold text-primary hover:underline" href={`/cases/${row.case_id}`}>
                              {row.docket_display_number}<ExternalLink className="h-3.5 w-3.5" />
                            </Link>
                            <p className="mt-1 text-xs text-muted-foreground">Received {formatDate(row.date_received)}</p>
                          </TableCell>
                          <TableCell className="max-w-sm whitespace-normal">
                            <p className="line-clamp-2 text-sm"><span className="font-medium">Complainant:</span> {row.complainant ?? 'Not recorded'}</p>
                            <p className="mt-1 line-clamp-2 text-sm"><span className="font-medium">Respondent:</span> {row.respondent ?? 'Not recorded'}</p>
                            <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">{row.violations ?? 'No violation recorded'}</p>
                          </TableCell>
                          <TableCell><CurrentState row={row} /></TableCell>
                          <TableCell><ArrowRight className="h-4 w-4 text-muted-foreground" /></TableCell>
                          <TableCell><ComputedState row={row} /></TableCell>
                          <TableCell>
                            <div className="flex min-w-24 flex-wrap gap-1">
                              {row.will_update_status ? <Badge variant="secondary">Status</Badge> : null}
                              {row.will_update_stage ? <Badge variant="outline">Stage</Badge> : null}
                            </div>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              ) : (
                <div className="flex min-h-64 flex-col items-center justify-center gap-2 px-6 text-center">
                  {hasPreviewed ? <CheckCircle2 className="h-8 w-8 text-emerald-600" /> : <DatabaseZap className="h-8 w-8 text-muted-foreground" />}
                  <p className="font-medium">{hasPreviewed ? (rows.length === 0 ? 'All matching cases are current' : 'No cases match this search') : 'Preview not computed'}</p>
                  <p className="max-w-md text-sm text-muted-foreground">
                    {hasPreviewed ? (rows.length === 0 ? 'The stored status and stage already match the computed state.' : 'Clear the search to see the previewed changes.') : 'Select a docket year, month, and type to compute case-state differences.'}
                  </p>
                </div>
              )}
            </Card>
          </div>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
