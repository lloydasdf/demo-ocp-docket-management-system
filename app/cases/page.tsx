'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import {
  getCaseClassificationsForCases,
  getCasePartyParticipantsForCases,
  getCasesDisplay,
  getLatestCaseDocketYear,
  type CaseClassificationSummaryRecord,
  type CasePartyParticipantRecord,
  type CasesDisplayRecord,
} from '@/lib/supabase/queries';

type CompactCase = CasesDisplayRecord;
type DocketTypeFilter = string;
type DocketYearFilter = string;

const DEFAULT_DOCKET_TYPE = 'INV';
const INITIAL_CASE_LIMIT = 500;
const CASE_ROW_HEIGHT = 49;
const VIRTUAL_ROW_OVERSCAN = 12;

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
type CaseClassificationByCase = Record<number, string>;

type CasesPageCache = {
  cases: CompactCase[];
  partyNamesByCase: Record<number, CasePartyNames>;
  classificationsByCase: CaseClassificationByCase;
  selectedDocketYear: DocketYearFilter;
  hasAllCases: boolean;
};

const CASES_PAGE_CACHE_KEY = 'ocp-cases-page-cache-v4';
let casesPageMemoryCache: CasesPageCache | null = null;

function readCasesPageCache() {
  if (casesPageMemoryCache) {
    return casesPageMemoryCache;
  }

  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const cachedValue = window.sessionStorage.getItem(CASES_PAGE_CACHE_KEY);
    if (!cachedValue) {
      return null;
    }

    casesPageMemoryCache = JSON.parse(cachedValue) as CasesPageCache;
    return casesPageMemoryCache;
  } catch {
    return null;
  }
}

function writeCasesPageCache(cache: CasesPageCache) {
  casesPageMemoryCache = cache;

  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.sessionStorage.setItem(CASES_PAGE_CACHE_KEY, JSON.stringify(cache));
  } catch {
    window.sessionStorage.removeItem(CASES_PAGE_CACHE_KEY);
  }
}

function getInitialColumnWidths(): ColumnWidths {
  return CASE_TABLE_COLUMNS.reduce((widths, column) => {
    widths[column.key] = column.initialWidth;
    return widths;
  }, {} as ColumnWidths);
}

function formatDisplayDocketNumber(caseDetail: CompactCase) {
  const prefix = caseDetail.docket_type_prefix ?? 'Case';
  const month = caseDetail.docket_month_code ? `-${caseDetail.docket_month_code}` : '';
  return (
    caseDetail.docket_display_number ||
    `${prefix}-${caseDetail.docket_year}${month}-${String(caseDetail.docket_number).padStart(6, '0')}`
  );
}

function caseViolations(caseDetail: CompactCase) {
  return caseDetail.violations || caseDetail.summary_text;
}

function assignedProsecutor(caseDetail: CompactCase) {
  return caseDetail.prosecutor_full_name || caseDetail.prosecutor_short_name;
}

function currentStatusLabel(caseDetail: CompactCase) {
  return caseDetail.current_status_label || caseDetail.current_status_code;
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

function personName(participant: CasePartyParticipantRecord) {
  return (
    participant.persons?.full_name?.trim() ||
    participant.organizations?.organization_name?.trim() ||
    participant.display_name_snapshot?.trim() ||
    'Unnamed participant'
  );
}

function participantMatchesRole(participant: CasePartyParticipantRecord, roleName: 'complainant' | 'respondent') {
  const roleText = `${participant.participant_roles?.code ?? ''} ${participant.participant_roles?.display_label ?? ''}`.toLowerCase();
  return roleText.includes(roleName);
}

function summarizePartyNames(participants: CasePartyParticipantRecord[], roleName: 'complainant' | 'respondent') {
  const names = participants.filter((participant) => participantMatchesRole(participant, roleName)).map(personName);

  if (names.length === 0) {
    return null;
  }

  return names.length > 2 ? `${names.slice(0, 2).join(', ')} et al.` : names.join(', ');
}

function caseIdsForCases(casesToCheck: CompactCase[]) {
  return casesToCheck
    .map((caseDetail) => caseDetail.id)
    .filter((caseId): caseId is number => Number.isFinite(caseId));
}

function shouldRefreshCachedPartyNames(
  cachedCases: CompactCase[],
  cachedPartyNamesByCase: Record<number, CasePartyNames>,
) {
  const cachedCaseIds = caseIdsForCases(cachedCases);

  return (
    cachedCaseIds.length > 0 &&
    cachedCaseIds.some((caseId) => !(caseId in cachedPartyNamesByCase))
  );
}

function classificationLabel(classification: CaseClassificationSummaryRecord["case_classifications"]) {
  return classification?.display_label || null;
}

function buildClassificationsByCase(classifications: CaseClassificationSummaryRecord[]) {
  return classifications.reduce((classificationByCase, classification) => {
    const caseId = classification.id;
    if (Number.isFinite(caseId)) {
      classificationByCase[caseId] = classificationLabel(classification.case_classifications) ?? '—';
    }

    return classificationByCase;
  }, {} as CaseClassificationByCase);
}

function buildPartyNamesByCase(participants: CasePartyParticipantRecord[]) {
  const grouped = new Map<number, CasePartyParticipantRecord[]>();

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
  const tableContainerRef = useRef<HTMLDivElement | null>(null);
  const [cachedInitialState] = useState(() => readCasesPageCache());
  const [cases, setCases] = useState<CompactCase[]>(cachedInitialState?.cases ?? []);
  const [selectedDocketType, setSelectedDocketType] = useState<DocketTypeFilter>(DEFAULT_DOCKET_TYPE);
  const [selectedDocketYear, setSelectedDocketYear] = useState<DocketYearFilter>(cachedInitialState?.selectedDocketYear ?? 'All');
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(!cachedInitialState);
  const [isLoadingAllCases, setIsLoadingAllCases] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedCaseKey, setSelectedCaseKey] = useState<string | null>(null);
  const [columnWidths, setColumnWidths] = useState<ColumnWidths>(() => getInitialColumnWidths());
  const [partyNamesByCase, setPartyNamesByCase] = useState<Record<number, CasePartyNames>>(cachedInitialState?.partyNamesByCase ?? {});
  const [classificationsByCase, setClassificationsByCase] = useState<CaseClassificationByCase>(cachedInitialState?.classificationsByCase ?? {});
  const [scrollTop, setScrollTop] = useState(0);
  const [viewportHeight, setViewportHeight] = useState(640);

  useEffect(() => {
    let isMounted = true;

    function cacheCasesPageState(
      nextCases: CompactCase[],
      nextPartyNamesByCase: Record<number, CasePartyNames>,
      options: { selectedYear?: DocketYearFilter; hasAllCases?: boolean } = {},
    ) {
      writeCasesPageCache({
        cases: nextCases,
        partyNamesByCase: nextPartyNamesByCase,
        classificationsByCase: readCasesPageCache()?.classificationsByCase ?? classificationsByCase,
        selectedDocketYear: options.selectedYear ?? readCasesPageCache()?.selectedDocketYear ?? selectedDocketYear,
        hasAllCases: options.hasAllCases ?? readCasesPageCache()?.hasAllCases ?? false,
      });
    }

    async function loadPartyNamesForCases(
      nextCases: CompactCase[],
      options: { clearOnError?: boolean } = {},
    ) {
      const participantResult = await getCasePartyParticipantsForCases(caseIdsForCases(nextCases));

      if (!isMounted) {
        return;
      }

      if (!participantResult.error) {
        const nextPartyNamesByCase = buildPartyNamesByCase(participantResult.data);
        setPartyNamesByCase(nextPartyNamesByCase);
        cacheCasesPageState(nextCases, nextPartyNamesByCase);
      } else if (options.clearOnError) {
        setPartyNamesByCase({});
        cacheCasesPageState(nextCases, {});
      }
    }

    async function loadClassificationsForCases(nextCases: CompactCase[]) {
      const classificationResult = await getCaseClassificationsForCases(caseIdsForCases(nextCases));

      if (!isMounted || classificationResult.error) {
        return;
      }

      const nextClassificationsByCase = buildClassificationsByCase(classificationResult.data);
      setClassificationsByCase(nextClassificationsByCase);
      writeCasesPageCache({
        cases: nextCases,
        partyNamesByCase: readCasesPageCache()?.partyNamesByCase ?? partyNamesByCase,
        classificationsByCase: nextClassificationsByCase,
        selectedDocketYear: readCasesPageCache()?.selectedDocketYear ?? selectedDocketYear,
        hasAllCases: readCasesPageCache()?.hasAllCases ?? false,
      });
    }

    async function loadAllCasesInBackground() {
      setIsLoadingAllCases(true);
      const allCasesResult = await getCasesDisplay();

      if (!isMounted) {
        return;
      }

      setIsLoadingAllCases(false);

      if (allCasesResult.error) {
        return;
      }

      setCases(allCasesResult.data);
      cacheCasesPageState(
        allCasesResult.data,
        readCasesPageCache()?.partyNamesByCase ?? partyNamesByCase,
        { hasAllCases: true },
      );
      void loadPartyNamesForCases(allCasesResult.data);
      void loadClassificationsForCases(allCasesResult.data);
    }

    async function loadCases() {
      if (cachedInitialState) {
        setIsLoading(false);

        if (shouldRefreshCachedPartyNames(cachedInitialState.cases, cachedInitialState.partyNamesByCase)) {
          void loadPartyNamesForCases(cachedInitialState.cases);
        }

        if (Object.keys(cachedInitialState.classificationsByCase ?? {}).length === 0) {
          void loadClassificationsForCases(cachedInitialState.cases);
        }

        if (!cachedInitialState.hasAllCases) {
          void loadAllCasesInBackground();
        }

        return;
      }

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
      const selectedYear = defaultDocketYear ? String(defaultDocketYear) : 'All';
      setSelectedDocketYear(selectedYear);

      const initialCasesResult = await getCasesDisplay({
        docketType: DEFAULT_DOCKET_TYPE,
        docketYear: defaultDocketYear,
        limit: INITIAL_CASE_LIMIT,
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
        cacheCasesPageState(initialCasesResult.data, {}, { selectedYear });
        void loadPartyNamesForCases(initialCasesResult.data, { clearOnError: true });
        void loadClassificationsForCases(initialCasesResult.data);
      }

      setIsLoading(false);

      if (!initialCasesResult.error) {
        void loadAllCasesInBackground();
      }
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    const container = tableContainerRef.current;
    if (!container) {
      return;
    }

    function syncViewport() {
      setViewportHeight(container?.clientHeight || 640);
      setScrollTop(container?.scrollTop || 0);
    }

    syncViewport();

    if (typeof ResizeObserver === 'undefined') {
      window.addEventListener('resize', syncViewport);
      return () => window.removeEventListener('resize', syncViewport);
    }

    const resizeObserver = new ResizeObserver(syncViewport);
    resizeObserver.observe(container);

    return () => resizeObserver.disconnect();
  }, [isLoading, cases.length]);

  const filteredCases = useMemo(() => {
    const normalizedSearch = searchTerm.trim().toLowerCase();

    return cases.filter((caseDetail) => {
      if (selectedDocketType !== 'All' && caseDetail.docket_type_prefix !== selectedDocketType) {
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
        caseDetail.docket_type_prefix ?? '',
        String(caseDetail.docket_year ?? ''),
        casePartyNames?.complainants ?? '',
        casePartyNames?.respondents ?? '',
        caseViolations(caseDetail) ?? '',
        assignedProsecutor(caseDetail) ?? '',
        currentStatusLabel(caseDetail) ?? '',
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
      new Set(cases.map((caseDetail) => caseDetail.docket_type_prefix).filter((value): value is string => Boolean(value))),
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

  const virtualRows = useMemo(() => {
    const visibleCount = Math.ceil(viewportHeight / CASE_ROW_HEIGHT);
    const startIndex = Math.max(0, Math.floor(scrollTop / CASE_ROW_HEIGHT) - VIRTUAL_ROW_OVERSCAN);
    const endIndex = Math.min(sortedCases.length, startIndex + visibleCount + VIRTUAL_ROW_OVERSCAN * 2);

    return {
      rows: sortedCases.slice(startIndex, endIndex),
      topPadding: startIndex * CASE_ROW_HEIGHT,
      bottomPadding: Math.max(0, (sortedCases.length - endIndex) * CASE_ROW_HEIGHT),
    };
  }, [scrollTop, sortedCases, viewportHeight]);

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
                  ref={tableContainerRef}
                  className="h-full min-h-0 overflow-auto rounded-lg border border-border"
                  aria-label="Cases table with native horizontal and vertical scrollbars"
                  onScroll={(event) => setScrollTop(event.currentTarget.scrollTop)}
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
                      {virtualRows.topPadding > 0 ? (
                        <TableRow aria-hidden="true">
                          <TableCell colSpan={CASE_TABLE_COLUMNS.length} style={{ height: virtualRows.topPadding, padding: 0 }} />
                        </TableRow>
                      ) : null}

                      {virtualRows.rows.map((caseDetail) => {
                        const caseKey = getCaseKey(caseDetail);
                        const isSelected = selectedCaseKey === caseKey;

                        return (
                          <TableRow
                            key={caseKey}
                            aria-selected={isSelected}
                            className={`h-12 cursor-pointer ${isSelected ? 'bg-primary/10 hover:bg-primary/15' : 'hover:bg-muted/50'}`}
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
                            <TableCell className="truncate text-sm">{caseDetail.docket_type_name ?? caseDetail.docket_type_prefix ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.docket_year ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">
                              {caseDetail.id ? partyNamesByCase[caseDetail.id]?.complainants ?? '—' : '—'}
                            </TableCell>
                            <TableCell className="truncate text-sm">
                              {caseDetail.id ? partyNamesByCase[caseDetail.id]?.respondents ?? '—' : '—'}
                            </TableCell>
                            <TableCell className="truncate text-sm">{caseViolations(caseDetail) ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{caseDetail.id ? classificationsByCase[caseDetail.id] ?? '—' : '—'}</TableCell>
                            <TableCell className="truncate text-sm">{assignedProsecutor(caseDetail) ?? '—'}</TableCell>
                            <TableCell>
                              <Badge variant="outline">{currentStatusLabel(caseDetail) ?? '—'}</Badge>
                            </TableCell>
                            <TableCell className="truncate text-sm">{formatDate(caseDetail.date_received)}</TableCell>
                          </TableRow>
                        );
                      })}

                      {virtualRows.bottomPadding > 0 ? (
                        <TableRow aria-hidden="true">
                          <TableCell colSpan={CASE_TABLE_COLUMNS.length} style={{ height: virtualRows.bottomPadding, padding: 0 }} />
                        </TableRow>
                      ) : null}
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
