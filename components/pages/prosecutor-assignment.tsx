'use client';

import { useEffect, useMemo, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import {
  assignProsecutorToCase,
  getCompactCases,
  getProsecutors,
  unassignActiveProsecutorFromCase,
} from '@/lib/supabase/queries';
import type { TableRow as SupabaseTableRow, ViewRow } from '@/lib/supabase/types';
import { AlertCircle, CheckCircle, Loader2, Search as SearchIcon } from 'lucide-react';

type CompactCase = ViewRow<'v_cases_display'>;
type Prosecutor = SupabaseTableRow<'prosecutors'>;

type Message = {
  type: 'success' | 'error';
  text: string;
};

function formatDocketNumber(caseDetail: CompactCase) {
  return caseDetail.docket_display_number?.replace(/^IV-31-/i, '') ?? `Case #${caseDetail.id ?? '—'}`;
}

function formatDate(value: string | null) {
  if (!value) {
    return '—';
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
  }).format(new Date(value));
}

function prosecutorDisplayName(prosecutor: Pick<Prosecutor, 'full_name' | 'short_name'>) {
  return prosecutor.full_name || prosecutor.short_name || 'Unnamed prosecutor';
}

function caseMatchesSearch(caseDetail: CompactCase, query: string) {
  const safeQuery = query.trim().toLowerCase();

  if (!safeQuery) {
    return true;
  }

  return [
    caseDetail.docket_display_number,
    caseDetail.summary_text,
    caseDetail.violations,
    caseDetail.current_status_label,
  ]
    .filter(Boolean)
    .some((value) => value?.toLowerCase().includes(safeQuery));
}

export default function ProsecutorAssignment() {
  const [selectedCaseId, setSelectedCaseId] = useState('');
  const [selectedProsecutorId, setSelectedProsecutorId] = useState('');
  const [cases, setCases] = useState<CompactCase[]>([]);
  const [prosecutors, setProsecutors] = useState<Prosecutor[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [message, setMessage] = useState<Message | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  async function loadAssignmentData() {
    setIsLoading(true);
    const [casesResult, prosecutorsResult] = await Promise.all([
      getCompactCases({ limit: 250 }),
      getProsecutors(250),
    ]);

    const firstError = casesResult.error ?? prosecutorsResult.error;

    if (firstError) {
      setMessage({ type: 'error', text: firstError.message });
    }

    setCases(casesResult.data ?? []);
    setProsecutors(prosecutorsResult.data ?? []);
    setIsLoading(false);
  }

  useEffect(() => {
    let isMounted = true;

    async function load() {
      setIsLoading(true);
      const [casesResult, prosecutorsResult] = await Promise.all([
        getCompactCases({ limit: 250 }),
        getProsecutors(250),
      ]);

      if (!isMounted) {
        return;
      }

      const firstError = casesResult.error ?? prosecutorsResult.error;

      if (firstError) {
        setMessage({ type: 'error', text: firstError.message });
      }

      setCases(casesResult.data ?? []);
      setProsecutors(prosecutorsResult.data ?? []);
      setIsLoading(false);
    }

    load();

    return () => {
      isMounted = false;
    };
  }, []);

  const activeAssignments = useMemo(() => {
    return cases
      .filter((caseDetail) => caseDetail.id && caseDetail.current_prosecutor_id)
      .sort((a, b) => {
        const aDate = a.current_assigned_at ? new Date(a.current_assigned_at).getTime() : 0;
        const bDate = b.current_assigned_at ? new Date(b.current_assigned_at).getTime() : 0;
        return bDate - aDate;
      });
  }, [cases]);

  const availableCases = useMemo(() => {
    return cases
      .filter((caseDetail) => caseDetail.id && !caseDetail.current_prosecutor_id)
      .filter((caseDetail) => caseMatchesSearch(caseDetail, searchQuery));
  }, [cases, searchQuery]);

  const selectedCase = useMemo(() => {
    const caseId = Number(selectedCaseId);
    return cases.find((caseDetail) => caseDetail.id === caseId) ?? null;
  }, [cases, selectedCaseId]);

  const assignmentCountsByProsecutor = useMemo(() => {
    return activeAssignments.reduce<Record<number, number>>((counts, caseDetail) => {
      if (caseDetail.current_prosecutor_id) {
        counts[caseDetail.current_prosecutor_id] = (counts[caseDetail.current_prosecutor_id] ?? 0) + 1;
      }

      return counts;
    }, {});
  }, [activeAssignments]);

  const handleAssign = async () => {
    const caseId = Number(selectedCaseId);
    const prosecutorId = Number(selectedProsecutorId);

    if (!caseId || !prosecutorId) {
      return;
    }

    setIsSaving(true);
    setMessage(null);

    const result = await assignProsecutorToCase({
      caseId,
      prosecutorId,
      remarks: 'Assigned from Prosecutor Assignment page.',
    });

    if (result.error) {
      setMessage({ type: 'error', text: result.error.message });
      setIsSaving(false);
      return;
    }

    setSelectedCaseId('');
    setSelectedProsecutorId('');
    setSearchQuery('');
    await loadAssignmentData();
    setMessage({ type: 'success', text: 'Prosecutor assigned successfully.' });
    setIsSaving(false);
  };

  const handleRemoveAssignment = async (caseId: number | null) => {
    if (!caseId) {
      return;
    }

    setIsSaving(true);
    setMessage(null);

    const result = await unassignActiveProsecutorFromCase(caseId);

    if (result.error) {
      setMessage({ type: 'error', text: result.error.message });
      setIsSaving(false);
      return;
    }

    await loadAssignmentData();
    setMessage({ type: 'success', text: 'Active prosecutor assignment removed.' });
    setIsSaving(false);
  };

  return (
    <div className="p-8 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Prosecutor Assignment</h1>
        <p className="text-muted-foreground mt-1">
          Assign prosecutors to live case records from the PostgreSQL database.
        </p>
      </div>

      {message && (
        <div
          className={`flex items-center gap-2 rounded border px-4 py-3 ${
            message.type === 'success'
              ? 'border-green-400 bg-green-100 text-green-700'
              : 'border-destructive/40 bg-destructive/10 text-destructive'
          }`}
        >
          {message.type === 'success' ? <CheckCircle className="h-5 w-5" /> : <AlertCircle className="h-5 w-5" />}
          {message.text}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>New Assignment</CardTitle>
          <CardDescription>
            Select an unassigned case from <code>v_cases_display</code> and an active prosecutor from{' '}
            <code>prosecutors</code>.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div className="relative">
              <Label htmlFor="case-search">Select Case</Label>
              <div className="relative mt-1">
                <SearchIcon className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  id="case-search"
                  placeholder="Search docket, summary, violation..."
                  value={searchQuery}
                  onChange={(event) => setSearchQuery(event.target.value)}
                  className="pl-10"
                  disabled={isLoading || isSaving}
                />
              </div>
              {searchQuery && availableCases.length > 0 && (
                <div className="absolute z-10 mt-1 max-h-56 w-full overflow-y-auto rounded-md border border-border bg-background shadow-lg">
                  {availableCases.slice(0, 8).map((caseDetail) => (
                    <button
                      key={caseDetail.id}
                      onClick={() => {
                        setSelectedCaseId(String(caseDetail.id));
                        setSearchQuery('');
                      }}
                      className="w-full px-3 py-2 text-left hover:bg-muted"
                      type="button"
                    >
                      <p className="font-medium">{formatDocketNumber(caseDetail)}</p>
                      <p className="line-clamp-1 text-xs text-muted-foreground">
                        {caseDetail.violations ?? caseDetail.summary_text ?? 'No summary recorded'}
                      </p>
                    </button>
                  ))}
                </div>
              )}
              {searchQuery && !isLoading && availableCases.length === 0 && (
                <p className="mt-2 text-sm text-muted-foreground">No unassigned cases match that search.</p>
              )}
            </div>

            <div>
              <Label htmlFor="prosecutor">Prosecutor</Label>
              <Select
                value={selectedProsecutorId}
                onValueChange={setSelectedProsecutorId}
                disabled={isLoading || isSaving}
              >
                <SelectTrigger id="prosecutor" className="mt-1">
                  <SelectValue placeholder="Select prosecutor..." />
                </SelectTrigger>
                <SelectContent>
                  {prosecutors.map((prosecutor) => (
                    <SelectItem key={prosecutor.id} value={String(prosecutor.id)}>
                      <div>
                        <p className="font-medium">{prosecutorDisplayName(prosecutor)}</p>
                        <p className="text-xs text-muted-foreground">{prosecutor.short_name ?? 'Active prosecutor'}</p>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-end">
              <Button
                onClick={handleAssign}
                disabled={!selectedCaseId || !selectedProsecutorId || isLoading || isSaving}
                className="w-full"
              >
                {isSaving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                Assign
              </Button>
            </div>
          </div>

          {selectedCase && (
            <div className="rounded bg-muted p-3">
              <p className="text-sm">
                <span className="text-muted-foreground">Selected Case:</span>{' '}
                <span className="font-medium">{formatDocketNumber(selectedCase)}</span>
              </p>
              <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">
                {selectedCase.violations ?? selectedCase.summary_text ?? 'No summary recorded'}
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Active Assignments</CardTitle>
          <CardDescription>
            {isLoading
              ? 'Loading assignments from the database...'
              : `${activeAssignments.length} active assignment${activeAssignments.length === 1 ? '' : 's'}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center gap-2 py-8 text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" />
              Loading prosecutor assignments...
            </div>
          ) : activeAssignments.length === 0 ? (
            <div className="py-8 text-center">
              <p className="text-muted-foreground">No active prosecutor assignments found.</p>
            </div>
          ) : (
            <div className="overflow-hidden rounded-lg border border-border">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>Case Number</TableHead>
                    <TableHead>Prosecutor</TableHead>
                    <TableHead>Assignment Date</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {activeAssignments.map((assignment) => (
                    <TableRow key={assignment.id} className="hover:bg-muted/50">
                      <TableCell className="font-medium text-primary">{formatDocketNumber(assignment)}</TableCell>
                      <TableCell>{assignment.prosecutor_full_name ?? assignment.prosecutor_short_name ?? '—'}</TableCell>
                      <TableCell className="text-sm">{formatDate(assignment.current_assigned_at)}</TableCell>
                      <TableCell>
                        <Badge className="bg-green-100 text-green-800">Active</Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleRemoveAssignment(assignment.id)}
                          className="text-destructive"
                          disabled={isSaving}
                        >
                          Remove
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Available Prosecutors</CardTitle>
          <CardDescription>Active prosecutors currently stored in the database.</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex items-center justify-center gap-2 py-8 text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" />
              Loading prosecutors...
            </div>
          ) : prosecutors.length === 0 ? (
            <p className="py-8 text-center text-muted-foreground">No active prosecutors found.</p>
          ) : (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
              {prosecutors.map((prosecutor) => (
                <div key={prosecutor.id} className="rounded-lg border border-border p-4">
                  <h4 className="font-semibold">{prosecutorDisplayName(prosecutor)}</h4>
                  <p className="mt-1 text-sm text-muted-foreground">{prosecutor.short_name ?? 'No short name recorded'}</p>
                  <p className="mt-2 text-xs text-muted-foreground">
                    {assignmentCountsByProsecutor[prosecutor.id] ?? 0} active case
                    {(assignmentCountsByProsecutor[prosecutor.id] ?? 0) === 1 ? '' : 's'}
                  </p>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
