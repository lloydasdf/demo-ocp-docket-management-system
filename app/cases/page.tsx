'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { getCaseParticipantsForCases, getCasesFromTable, getLatestCaseDocketYear, type CaseParticipantRecord, type CasesTableRecord } from '@/lib/supabase/queries';

type CompactCase = CasesTableRecord;
type DocketTypeFilter = string;
type DocketYearFilter = string;

const DEFAULT_DOCKET_TYPE = 'INV';

const docketNumberCollator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });

const CASE_TABLE_COLUMNS = [
  { key: 'docketNumber', label: 'Docket number', initialWidth: 220, minWidth: 160 },
  { key: 'docketType', label: 'Docket type', initialWidth: 150, minWidth: 120 },
  { key: 'docketYear', label: 'Year', initialWidth: 100, minWidth: 80 },
  { key: 'complainant', label: 'Complainant', initialWidth: 300, minWidth: 200 },
  { key: 'respondent', label: 'Respondent', initialWidth: 300, minWidth: 200 },
  { key: 'violation', label: 'Violation', initialWidth: 260, minWidth: 180 },
  { key: 'classification', label: 'Classification', initialWidth: 180, minWidth: 140 },
  { key: 'assignedProsecutor', label: 'Assigned Prosecutor', initialWidth: 240, minWidth: 180 },
  { key: 'currentStatus', label: 'Current Status', initialWidth: 180, minWidth: 150 },
  { key: 'dateReceived', label: 'Date Received', initialWidth: 150, minWidth: 120 },
] as const;

type CaseTableColumnKey = (typeof CASE_TABLE_COLUMNS)[number]['key'];
type ColumnWidths = Record<CaseTableColumnKey, number>;
type CasePartyNames = { complainants: string | null; respondents: string | null };

function getInitialColumnWidths(): ColumnWidths {
  return CASE_TABLE_COLUMNS.reduce((widths, column) => {
    widths[column.key] = column.initialWidth;
    return widths;
  }, {} as ColumnWidths);
}

function formatDisplayDocketNumber(caseDetail: CompactCase) {
  const prefix = caseDetail.docket_types?.prefix ?? 'Case';
  const month = caseDetail.docket_month_code ? `-${caseDetail.docket_month_code}` : '';
  return (
    caseDetail.docket_display_number ||
    `${prefix}-${caseDetail.docket_year}${month}-${String(caseDetail.docket_number).padStart(6, '0')}`
  );
}

function caseViolations(caseDetail: CompactCase) {
  const violations = (caseDetail.case_violations ?? [])
    .slice()
    .sort((left, right) => (left.violation_order ?? 0) - (right.violation_order ?? 0))
    .map((violation) =>
      violation.raw_violation_text?.trim() ||
      violation.violations?.short_label ||
      violation.violations?.canonical_title ||
      violation.violations?.title ||
      '',
    )
    .filter(Boolean);

  return violations.length > 0 ? violations.join(', ') : caseDetail.summary_text;
}

function currentAssignment(caseDetail: CompactCase) {
  return (caseDetail.case_assignments ?? [])
    .filter((assignment) => !assignment.unassigned_at)
    .sort((left, right) => (right.assigned_at ?? '').localeCompare(left.assigned_at ?? ''))[0];
}

function currentStatus(caseDetail: CompactCase) {
  return caseDetail.current_status;
}

function caseClassification(caseDetail: CompactCase) {
  return (
    caseDetail.case_classifications?.display_label ??
    caseDetail.case_classifications?.name ??
    caseDetail.case_classifications?.code ??
    '—'
  );
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return '—';
  }

  const parsedDate = new Date(value);
  return Number.isNaN(parsedDate.getTime()) ? value : parsedDate.toLocaleDateString();
}

function getCaseKey(caseDetail: CompactCase) {
  return `${caseDetail.id ?? 'case'}-${formatDisplayDocketNumber(caseDetail)}`;
}

function personName(participant: CaseParticipantRecord) {
  return participant.persons?.full_name?.trim() || 'Unnamed participant';
}

function participantMatchesRole(participant: CaseParticipantRecord, roleName: 'complainant' | 'respondent') {
  const roleText = `${participant.participant_roles?.code ?? ''} ${participant.participant_roles?.display_label ?? ''}`.toLowerCase();
  return roleText.includes(roleName);
}

function summarizePartyNames(participants: CaseParticipantRecord[], roleName: 'complainant' | 'respondent') {
  const names = participants.filter((participant) => participantMatchesRole(participant, roleName)).map(personName);

  if (names.length === 0) {
    return null;
  }

  return names.length > 2 ? `${names.slice(0, 2).join(', ')} et al.` : names.join(', ');
}

function buildPartyNamesByCase(participants: CaseParticipantRecord[]) {
  const grouped = new Map<number, CaseParticipantRecord[]>();

  for (const participant of participants) {
    grouped.set(participant.case_id, [...(grouped.get(participant.case_id) ?? []), participant]);
  }

  return Array.from(grouped.entries()).reduce((namesByCase, [caseId, caseParticipants]) => {
    namesByCase[caseId] = {
      complainants: summarizePartyNames(caseParticipants, 'complainant'),
      respondents: summarizePartyNames(caseParticipants, 'respondent'),
    };
    return namesByCase;
  }, {} as Record<number, CasePartyNames>);
}

export default function CasesPage() {
  const router = useRouter();
  const [cases, setCases] = useState<CompactCase[]>([]);
  const [selectedDocketType, setSelectedDocketType] = useState<DocketTypeFilter>(DEFAULT_DOCKET_TYPE);
  const [selectedDocketYear, setSelectedDocketYear] = useState<DocketYearFilter>('All');
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingAllCases, setIsLoadingAllCases] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedCaseKey, setSelectedCaseKey] = useState<string | null>(null);
  const [columnWidths, setColumnWidths] = useState<ColumnWidths>(() => getInitialColumnWidths());
  const [partyNamesByCase, setPartyNamesByCase] = useState<Record<number, CasePartyNames>>({});

  useEffect(() => {
    let isMounted = true;

    async function loadPartyNamesForCases(
      nextCases: CompactCase[],
      options: { clearOnError?: boolean } = {},
    ) {
      const participantResult = await getCaseParticipantsForCases(
        nextCases.map((caseDetail) => caseDetail.id).filter((caseId): caseId is number => Number.isFinite(caseId)),
      );

      if (!isMounted) {
        return;
      }

      if (!participantResult.error) {
        setPartyNamesByCase(buildPartyNamesByCase(participantResult.data));
      } else if (options.clearOnError) {
        setPartyNamesByCase({});
      }
    }

    async function loadAllCasesInBackground() {
      setIsLoadingAllCases(true);
      const allCasesResult = await getCasesFromTable();

      if (!isMounted) {
        return;
      }

      setIsLoadingAllCases(false);

      if (allCasesResult.error) {
        return;
      }

      setCases(allCasesResult.data);
      await loadPartyNamesForCases(allCasesResult.data);
    }

    async function loadCases() {
      setIsLoading(true);
      const latestYearResult = await getLatestCaseDocketYear(DEFAULT_DOCKET_TYPE);

      if (!isMounted) {
        return;
      }

      if (latestYearResult.error) {
        setErrorMessage(latestYearResult.error.message);
        setCases([]);
        setPartyNamesByCase({});
        setIsLoading(false);
        return;
      }

      const defaultDocketYear = latestYearResult.data ?? undefined;
      setSelectedDocketYear(defaultDocketYear ? String(defaultDocketYear) : 'All');

      const initialCasesResult = await getCasesFromTable({
        docketType: DEFAULT_DOCKET_TYPE,
        docketYear: defaultDocketYear,
      });

      if (!isMounted) {
        return;
      }

      if (initialCasesResult.error) {
        setErrorMessage(initialCasesResult.error.message);
        setCases([]);
        setPartyNamesByCase({});
      } else {
        setErrorMessage(null);
        setCases(initialCasesResult.data);
        await loadPartyNamesForCases(initialCasesResult.data, { clearOnError: true });
      }

      if (isMounted) {
        setIsLoading(false);

        if (!initialCasesResult.error) {
          void loadAllCasesInBackground();
        }
      }
    }

    loadCases();

    return () => {
      isMounted = false;
      setIsLoadingAllCases(false);
    };
  }, []);

  const filteredCases = useMemo(() => {
    const normalizedSearch = searchTerm.trim().toLowerCase();

    return cases.filter((caseDetail) => {
      if (selectedDocketType !== 'All' && caseDetail.docket_types?.prefix !== selectedDocketType) {
        return false;
      }

      if (selectedDocketYear !== 'All' && String(caseDetail.docket_year) !== selectedDocketYear) {
        return false;
      }

      if (!normalizedSearch) {
        return true;
      }

      const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
      const searchableText = [
        formatDisplayDocketNumber(caseDetail),
        caseDetail.docket_types?.prefix ?? '',
        String(caseDetail.docket_year ?? ''),
        casePartyNames?.complainants ?? '',
        casePartyNames?.respondents ?? '',
        caseViolations(caseDetail) ?? '',
        currentAssignment(caseDetail)?.prosecutors?.full_name ?? currentAssignment(caseDetail)?.prosecutors?.short_name ?? '',
        caseClassification(caseDetail),
        currentStatus(caseDetail)?.display_label ?? currentStatus(caseDetail)?.code ?? caseDetail.current_status_raw ?? '',
      ]
        .join(' ')
        .toLowerCase();

      return searchableText.includes(normalizedSearch);
    });
  }, [cases, partyNamesByCase, searchTerm, selectedDocketType, selectedDocketYear]);

  const sortedCases = useMemo(
    () =>
      [...filteredCases].sort((left, right) =>
        docketNumberCollator.compare(
          formatDisplayDocketNumber(left),
          formatDisplayDocketNumber(right),
        ),
      ),
    [filteredCases],
  );

  const docketTypeFilters = useMemo(() => {
    const values = Array.from(
      new Set(cases.map((caseDetail) => caseDetail.docket_types?.prefix).filter((value): value is string => Boolean(value))),
    ).sort();
    return ['All', ...values];
  }, [cases]);

  const docketYearFilters = useMemo(() => {
    const values = Array.from(
      new Set(cases.map((caseDetail) => caseDetail.docket_year).filter((value): value is number => Number.isFinite(value))),
    ).sort((left, right) => right - left);
    return ['All', ...values.map(String)];
  }, [cases]);

  const tableWidth = useMemo(
    () => CASE_TABLE_COLUMNS.reduce((total, column) => total + columnWidths[column.key], 0),
    [columnWidths],
  );

  function handleColumnResize(columnKey: CaseTableColumnKey, startX: number) {
    const column = CASE_TABLE_COLUMNS.find((candidate) => candidate.key === columnKey);
    const startWidth = columnWidths[columnKey];

    function handlePointerMove(event: PointerEvent) {
      const nextWidth = Math.max(column?.minWidth ?? 120, startWidth + event.clientX - startX);
      setColumnWidths((currentWidths) => ({ ...currentWidths, [columnKey]: nextWidth }));
    }

    function handlePointerUp() {
      document.removeEventListener('pointermove', handlePointerMove);
      document.removeEventListener('pointerup', handlePointerUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    }

    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    document.addEventListener('pointermove', handlePointerMove);
    document.addEventListener('pointerup', handlePointerUp);
  }

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="flex min-w-0 flex-1 flex-col overflow-hidden p-4 pt-16 md:p-8">
        <div className="flex min-h-0 flex-1 flex-col gap-6">
          <div className="shrink-0">
            <h1 className="text-3xl font-bold text-foreground">All Cases</h1>
            <p className="text-muted-foreground mt-1">Browse all cases in the system</p>
          </div>

          {errorMessage ? (
            <Alert variant="destructive" className="shrink-0">
              <AlertTitle>Unable to load live Supabase cases</AlertTitle>
              <AlertDescription>{errorMessage}</AlertDescription>
            </Alert>
          ) : null}

          <Card aria-busy={isLoading || isLoadingAllCases} className="min-h-0 flex-1 gap-4 overflow-hidden py-4">
            <CardHeader className="shrink-0 px-4 md:px-6">
              <div className="grid gap-4 sm:max-w-xl sm:grid-cols-2">
                <div className="flex flex-col gap-2 sm:col-span-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="case-search">
                    Search Cases
                  </label>
                  <Input
                    id="case-search"
                    placeholder="Search docket no., parties, violation, prosecutor, or status"
                    value={searchTerm}
                    onChange={(event) => setSearchTerm(event.target.value)}
                  />
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="docket-type-filter">
                    Docket Type
                  </label>
                  <Select
                    value={selectedDocketType}
                    onValueChange={(value) => setSelectedDocketType(value as DocketTypeFilter)}
                  >
                    <SelectTrigger id="docket-type-filter" className="w-full">
                      <SelectValue placeholder="Filter by docket type" />
                    </SelectTrigger>
                    <SelectContent>
                      {docketTypeFilters.map((docketType) => (
                        <SelectItem key={docketType} value={docketType}>
                          {docketType}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="docket-year-filter">
                    Docket Year
                  </label>
                  <Select
                    value={selectedDocketYear}
                    onValueChange={(value) => setSelectedDocketYear(value as DocketYearFilter)}
                  >
                    <SelectTrigger id="docket-year-filter" className="w-full">
                      <SelectValue placeholder="Filter by docket year" />
                    </SelectTrigger>
                    <SelectContent>
                      {docketYearFilters.map((docketYear) => (
                        <SelectItem key={docketYear} value={docketYear}>
                          {docketYear === 'All' ? 'All years' : docketYear}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </CardHeader>

            <CardContent className="min-h-0 flex-1 overflow-hidden px-4 md:px-6">
              {isLoading ? (
                <div className="py-8 text-center text-sm text-muted-foreground">Loading cases...</div>
              ) : sortedCases.length === 0 ? (
                <div className="py-8 text-center text-sm text-muted-foreground">No cases found.</div>
              ) : (
                <div
                  className="h-full min-h-0 overflow-auto rounded-lg border border-border"
                  aria-label="Cases table with native horizontal and vertical scrollbars"
                >
                  <table className="w-full caption-bottom table-fixed text-sm" style={{ width: tableWidth, minWidth: '100%' }}>
                    <colgroup>
                      {CASE_TABLE_COLUMNS.map((column) => (
                        <col key={column.key} style={{ width: columnWidths[column.key] }} />
                      ))}
                    </colgroup>
                    <TableHeader className="sticky top-0 z-20 bg-muted shadow-sm">
                      <TableRow className="bg-muted hover:bg-muted">
                        {CASE_TABLE_COLUMNS.map((column) => (
                          <TableHead key={column.key} className="relative select-none whitespace-nowrap pr-4 uppercase">
                            {column.label}
                            <button
                              type="button"
                              className="absolute right-0 top-0 h-full w-2 cursor-col-resize touch-none border-r border-transparent hover:border-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                              aria-label={`Resize ${column.label} column`}
                              onPointerDown={(event) => {
                                event.preventDefault();
                                handleColumnResize(column.key, event.clientX);
                              }}
                            />
                          </TableHead>
                        ))}
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {sortedCases.map((caseDetail) => {
                        const caseKey = getCaseKey(caseDetail);
                        const isSelected = selectedCaseKey === caseKey;

                        return (
                          <TableRow
                            key={caseKey}
                            aria-selected={isSelected}
                            className={`cursor-pointer ${isSelected ? 'bg-primary/10 hover:bg-primary/15' : 'hover:bg-muted/50'}`}
                            tabIndex={caseDetail.id ? 0 : -1}
                            onClick={() => setSelectedCaseKey(caseKey)}
                            onDoubleClick={() => {
                              if (caseDetail.id) {
                                router.push(`/cases/${caseDetail.id}`);
                              }
                            }}
                            onKeyDown={(event) => {
                              if (!caseDetail.id) {
                                return;
                              }

                              if (event.key === 'Enter') {
                                event.preventDefault();
                                router.push(`/cases/${caseDetail.id}`);
                              }

                              if (event.key === ' ') {
                                event.preventDefault();
                                setSelectedCaseKey(caseKey);
                              }
                            }}
                          >
                            <TableCell className="truncate font-medium text-primary">
                              {formatDisplayDocketNumber(caseDetail)}
                            </TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.docket_types?.name ?? caseDetail.docket_types?.prefix ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.docket_year ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">
                              {caseDetail.id ? partyNamesByCase[caseDetail.id]?.complainants ?? '—' : '—'}
                            </TableCell>
                            <TableCell className="truncate text-sm">
                              {caseDetail.id ? partyNamesByCase[caseDetail.id]?.respondents ?? '—' : '—'}
                            </TableCell>
                            <TableCell className="truncate text-sm">{caseViolations(caseDetail) ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseClassification(caseDetail)}</TableCell>
                            <TableCell className="truncate text-sm">{currentAssignment(caseDetail)?.prosecutors?.full_name ?? currentAssignment(caseDetail)?.prosecutors?.short_name ?? '—'}</TableCell>
                            <TableCell>
                              <Badge variant="outline">{currentStatus(caseDetail)?.display_label ?? currentStatus(caseDetail)?.code ?? caseDetail.current_status_raw ?? '—'}</Badge>
                            </TableCell>
                            <TableCell className="truncate text-sm">{formatDate(caseDetail.date_received)}</TableCell>
                          </TableRow>
                        );
                      })}
                    </TableBody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}
