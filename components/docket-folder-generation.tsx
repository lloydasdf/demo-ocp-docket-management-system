'use client';

import { useEffect, useMemo, useState } from 'react';
import { CheckCircle2, ChevronDown, FolderPlus, Loader2, XCircle } from 'lucide-react';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { DropdownMenu, DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuLabel, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Progress } from '@/components/ui/progress';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import { getDocketCaseLabelsForCases, getDocketParticipantsForCases, getDocketQuickDetailsForCases, getDocketShellDisplay, type DocketCaseLabelsRecord, type DocketParticipantsRecord, type DocketQuickDetailsRecord, type DocketShellRecord } from '@/lib/supabase/queries';

type FilterCase = DocketShellRecord & Partial<DocketParticipantsRecord & DocketCaseLabelsRecord & DocketQuickDetailsRecord>;
type Result = { totalCasesChecked: number; existingFolders: number; newFoldersCreated: number; databaseMappingsUpdated: number; failedCases: Array<{ caseId: number; docketNumber: string; error: string }> };
type ProgressUpdate = { completed: number; total: number; percent: number; message: string };
const toggle = (values: string[], value: string) => values.includes(value) ? values.filter((item) => item !== value) : [...values, value];
const summary = (values: string[], all: string[], noun: string) => values.length === all.length ? `All ${noun}` : values.length ? `${values.length} ${noun}` : `No ${noun}`;

export function DocketFolderGeneration() {
  const [cases, setCases] = useState<FilterCase[]>([]);
  const [search, setSearch] = useState('');
  const [types, setTypes] = useState<string[]>([]); const [years, setYears] = useState<string[]>([]); const [months, setMonths] = useState<string[]>([]);
  const [loading, setLoading] = useState(true); const [processing, setProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null); const [result, setResult] = useState<Result | null>(null);
  const [progress, setProgress] = useState<ProgressUpdate | null>(null); const [logs, setLogs] = useState<string[]>([]);

  useEffect(() => { let active = true; void (async () => {
    setLoading(true); setError(null);
    const shell = await getDocketShellDisplay(); if (shell.error || !shell.data) throw new Error('Unable to load cases.');
    const ids = shell.data.map((item) => item.id).filter((id): id is number => id !== null);
    const [participants, labels, details] = await Promise.all([getDocketParticipantsForCases(ids), getDocketCaseLabelsForCases(ids), getDocketQuickDetailsForCases(ids)]);
    if (participants.error || labels.error || details.error) throw new Error('Unable to load case search fields.');
    const participantMap = new Map(participants.data?.map((item) => [item.id, item])); const labelMap = new Map(labels.data?.map((item) => [item.id, item])); const detailMap = new Map(details.data?.map((item) => [item.id, item]));
    const hydrated = shell.data.map((item) => ({ ...item, ...participantMap.get(item.id), ...labelMap.get(item.id), ...detailMap.get(item.id) })); if (!active) return;
    setCases(hydrated); setTypes(Array.from(new Set(hydrated.map((item) => item.docket_type_prefix).filter((item): item is string => Boolean(item))))); setYears(Array.from(new Set(hydrated.map((item) => String(item.docket_year)).filter((item) => item !== 'null')))); setMonths(Array.from(new Set(hydrated.map((item) => item.docket_month_code?.trim().toUpperCase()).filter((item): item is string => Boolean(item)))));
  })().catch((cause) => { if (active) setError(cause instanceof Error ? cause.message : 'Unable to load cases.'); }).finally(() => { if (active) setLoading(false); }); return () => { active = false; }; }, []);

  const allTypes = useMemo(() => Array.from(new Set(cases.map((item) => item.docket_type_prefix).filter((item): item is string => Boolean(item)))).sort(), [cases]);
  const allYears = useMemo(() => Array.from(new Set(cases.map((item) => String(item.docket_year)).filter((item) => item !== 'null'))).sort().reverse(), [cases]);
  const allMonths = useMemo(() => Array.from(new Set(cases.map((item) => item.docket_month_code?.trim().toUpperCase()).filter((item): item is string => Boolean(item)))).sort(), [cases]);
  const filtered = useMemo(() => { const needle = search.trim().toLowerCase(); return cases.filter((item) => {
    if (!item.docket_type_prefix || !types.includes(item.docket_type_prefix) || !years.includes(String(item.docket_year)) || !item.docket_month_code || !months.includes(item.docket_month_code.trim().toUpperCase())) return false;
    return !needle || [item.docket_display_number, item.complainant, item.respondent, item.violations, item.summary_text, item.case_classification_label, item.prosecutor_full_name, item.prosecutor_short_name, item.current_case_status_label, item.current_status_label, item.current_case_stage_label, item.date_received].some((value) => String(value ?? '').toLowerCase().includes(needle));
  }); }, [cases, months, search, types, years]);

  async function generate() { setProcessing(true); setError(null); setResult(null); setProgress({ completed: 0, total: filtered.length, percent: 0, message: 'Preparing folder check…' }); setLogs(['Preparing folder check…']); try {
    const supabase = await getSupabaseBrowserClient(); const session = await supabase.auth.getSession(); if (!session.data.session?.access_token) throw new Error('Your session has expired.');
    const response = await fetch('/api/developer/gdrive/docket-folders', { method: 'POST', headers: { 'content-type': 'application/json', Authorization: `Bearer ${session.data.session.access_token}` }, body: JSON.stringify({ caseIds: filtered.map((item) => item.id) }) });
    if (!response.ok || !response.body) { const body = await response.json().catch(() => null) as { error?: { message?: string } } | null; throw new Error(body?.error?.message ?? 'Folder generation failed.'); }
    const reader = response.body.getReader(); const decoder = new TextDecoder(); let buffer = ''; let completedResult: Result | null = null;
    while (true) { const { done, value } = await reader.read(); buffer += decoder.decode(value, { stream: !done }); const lines = buffer.split('\n'); buffer = lines.pop() ?? '';
      for (const line of lines) { if (!line.trim()) continue; const event = JSON.parse(line) as ({ type: 'progress' } & ProgressUpdate) | { type: 'complete'; data: Result } | { type: 'error'; message: string };
        if (event.type === 'progress') { setProgress(event); setLogs((current) => [...current, event.message]); }
        else if (event.type === 'complete') completedResult = event.data; else throw new Error(event.message);
      }
      if (done) break;
    }
    if (!completedResult) throw new Error('Folder generation ended before completion.'); setResult(completedResult); setProgress((current) => current ? { ...current, percent: 100, completed: current.total, message: 'Folder check complete.' } : null);
  } catch (cause) { setError(cause instanceof Error ? cause.message : 'Folder generation failed.'); } finally { setProcessing(false); } }

  return <Card><CardHeader><CardTitle className="flex items-center gap-2"><FolderPlus className="h-5 w-5" />Docket Folder Generation</CardTitle><CardDescription>Use the Cases page search and docket filters. Only the {filtered.length.toLocaleString()} currently matched cases will be checked.</CardDescription></CardHeader><CardContent className="space-y-4">
    <Input aria-label="Search cases" placeholder="Search cases" value={search} onChange={(event) => setSearch(event.target.value)} disabled={loading || processing} />
    <div className="grid gap-2 sm:grid-cols-3">{([[types, setTypes, allTypes, 'docket types'], [years, setYears, allYears, 'years'], [months, setMonths, allMonths, 'months']] as const).map(([selected, setter, options, noun]) => <DropdownMenu key={noun}><DropdownMenuTrigger asChild><Button variant="outline" className="justify-between" disabled={loading || processing}>{summary(selected, options, noun)}<ChevronDown className="h-4 w-4" /></Button></DropdownMenuTrigger><DropdownMenuContent className="max-h-72 overflow-y-auto"><DropdownMenuLabel>{noun}</DropdownMenuLabel><DropdownMenuCheckboxItem checked={selected.length === options.length} onCheckedChange={() => setter(selected.length === options.length ? [] : [...options])} onSelect={(event) => event.preventDefault()}>All</DropdownMenuCheckboxItem>{options.map((option) => <DropdownMenuCheckboxItem key={option} checked={selected.includes(option)} onCheckedChange={() => setter(toggle(selected, option))} onSelect={(event) => event.preventDefault()}>{option}</DropdownMenuCheckboxItem>)}</DropdownMenuContent></DropdownMenu>)}</div>
    <Button onClick={() => void generate()} disabled={loading || processing || filtered.length === 0}>{processing ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <FolderPlus className="mr-2 h-4 w-4" />}{processing ? 'Checking folders…' : 'Check & Create Google Drive Folders'}</Button>
    {progress ? <div className="space-y-2 rounded-md border bg-muted/30 p-4" aria-live="polite"><div className="flex items-center justify-between gap-4 text-sm font-medium"><span>{progress.message}</span><span className="shrink-0 tabular-nums">{progress.percent}%</span></div><Progress value={progress.percent} aria-label={`Folder generation ${progress.percent}% complete`} /><p className="text-xs text-muted-foreground">{progress.completed.toLocaleString()} of {progress.total.toLocaleString()} cases completed</p><div className="max-h-48 overflow-y-auto rounded border bg-background p-3 font-mono text-xs" role="log" aria-label="Folder generation activity log">{logs.map((message, index) => <div key={`${index}-${message}`} className="py-0.5"><span className="mr-2 text-muted-foreground">[{String(index + 1).padStart(3, '0')}]</span>{message}</div>)}</div></div> : null}
    {error ? <Alert variant="destructive"><XCircle className="h-4 w-4" /><AlertTitle>Unable to process folders</AlertTitle><AlertDescription>{error}</AlertDescription></Alert> : null}
    {result ? <Alert variant={result.failedCases.length ? 'destructive' : 'default'}><CheckCircle2 className="h-4 w-4" /><AlertTitle>Folder check complete</AlertTitle><AlertDescription><dl className="mt-2 grid grid-cols-[1fr_auto] gap-x-6 gap-y-1"><dt>Total cases checked</dt><dd>{result.totalCasesChecked}</dd><dt>Existing folders</dt><dd>{result.existingFolders}</dd><dt>New folders created</dt><dd>{result.newFoldersCreated}</dd><dt>Database mappings updated</dt><dd>{result.databaseMappingsUpdated}</dd><dt>Failed cases</dt><dd>{result.failedCases.length}</dd></dl>{result.failedCases.length ? <ul className="mt-3 list-disc pl-5">{result.failedCases.map((failure) => <li key={failure.caseId}>{failure.docketNumber}: {failure.error}</li>)}</ul> : null}</AlertDescription></Alert> : null}
  </CardContent></Card>;
}
