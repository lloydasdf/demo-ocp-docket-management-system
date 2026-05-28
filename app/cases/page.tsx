'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { dockets } from '@/lib/dummy-data';
import { getCaseParticipantsForCases, getCasesFromTable, type CaseParticipantRecord, type CasesTableRecord } from '@/lib/supabase/queries';

type CompactCase = CasesTableRecord;
type DocketTypeFilter = 'All' | 'INV' | 'INQ' | 'PE' | 'DC20';
type DocketYearFilter = 'All' | '2022';

const DOCKET_TYPE_FILTERS: DocketTypeFilter[] = ['All', 'INV', 'INQ', 'PE', 'DC20'];
const DOCKET_YEAR_FILTERS: DocketYearFilter[] = ['2022', 'All'];

const docketNumberCollator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });

const CASE_TABLE_COLUMNS = [
  { key: 'docketNumber', label: 'Docket number', initialWidth: 220, minWidth: 160 },
  { key: 'complainant', label: 'Complainant', initialWidth: 300, minWidth: 200 },
  { key: 'respondent', label: 'Respondent', initialWidth: 300, minWidth: 200 },
  { key: 'violation', label: 'Violation', initialWidth: 260, minWidth: 180 },
  { key: 'assignedProsecutor', label: 'Assigned Prosecutor', initialWidth: 240, minWidth: 180 },
  { key: 'currentStatus', label: 'Current Status', initialWidth: 180, minWidth: 150 },
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
  return `${prefix}-${caseDetail.docket_year}${month}-${String(caseDetail.docket_number).padStart(6, '0')}`;
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
  return (caseDetail.case_status_history ?? [])
    .slice()
    .sort((left, right) =>
      (right.status_date ?? right.changed_at ?? '').localeCompare(left.status_date ?? left.changed_at ?? ''),
    )[0]?.to_status;
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

function getFallbackCases(): CompactCase[] {
  return dockets.flatMap((docket) =>
    docket.cases.map((caseDetail) => ({
      id: Number.parseInt(caseDetail.id.replace(/\D/g, ''), 10) || null,
      summary_text:
        caseDetail.complainants.length > 0
          ? `Complainant: ${caseDetail.complainants[0].firstName} ${caseDetail.complainants[0].lastName}${
              caseDetail.complainants.length > 1 ? ' et al.' : ''
            }`
          : null,
      created_at: docket.createdDate,
      created_by_user_id: 0,
      date_received: caseDetail.dateOfIncident,
      docket_month_code: null,
      docket_number: Number.parseInt(docket.docketNumber.match(/\d+$/)?.[0] ?? '', 10) || 0,
      docket_type_id: 0,
      docket_types: { name: docket.docketNumber.split('-')[0] ?? '', prefix: docket.docketNumber.split('-')[0] ?? '' },
      docket_year: Number.parseInt(docket.docketNumber.match(/\d{4}/)?.[0] ?? '', 10) || 0,
      gdrive_folder_id: null,
      gdrive_folder_last_scanned_at: null,
      gdrive_folder_link: null,
      gdrive_folder_name: null,
      gdrive_folder_status: '',
      is_archived: false,
      is_summary_procedure: null,
      legacy_raw_json: null,
      legacy_row_number: null,
      legacy_source_file: null,
      legacy_source_sheet: null,
      region_code: null,
      source: null,
      updated_at: docket.createdDate,
      updated_by_user_id: null,
      case_violations: caseDetail.violations.map((violation, index) => ({
        raw_violation_text: violation.statute,
        violation_order: index + 1,
        violations: null,
      })),
      case_assignments: caseDetail.prosecutor
        ? [{ assigned_at: null, unassigned_at: null, prosecutors: { full_name: caseDetail.prosecutor, short_name: caseDetail.prosecutor } }]
        : [],
      case_status_history: caseDetail.status
        ? [{ changed_at: docket.createdDate, status_date: null, to_status: { code: caseDetail.status, display_label: caseDetail.status } }]
        : [],
    })) as CompactCase[],
  );
}

export default function CasesPage() {
  const router = useRouter();
  const fallbackCases = useMemo(getFallbackCases, []);
  const [cases, setCases] = useState<CompactCase[]>([]);
  const [selectedDocketType, setSelectedDocketType] = useState<DocketTypeFilter>('All');
  const [selectedDocketYear, setSelectedDocketYear] = useState<DocketYearFilter>('2022');
  const [searchTerm, setSearchTerm] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);
  const [selectedCaseKey, setSelectedCaseKey] = useState<string | null>(null);
  const [columnWidths, setColumnWidths] = useState<ColumnWidths>(() => getInitialColumnWidths());
  const [partyNamesByCase, setPartyNamesByCase] = useState<Record<number, CasePartyNames>>({});

  useEffect(() => {
    let isMounted = true;

    async function loadCases() {
      setIsLoading(true);
      const result = await getCasesFromTable({
        docketType: selectedDocketType === 'All' ? undefined : selectedDocketType,
        docketYear: selectedDocketYear === 'All' ? undefined : Number(selectedDocketYear),
      });

      if (!isMounted) {
        return;
      }

      if (result.error) {
        setErrorMessage(result.error.message);
        setCases(
          fallbackCases.filter((caseDetail) => {
            const matchesType = selectedDocketType === 'All' || caseDetail.docket_types?.prefix === selectedDocketType;
            const matchesYear = selectedDocketYear === 'All' || caseDetail.docket_year === Number(selectedDocketYear);
            return matchesType && matchesYear;
          }),
        );
        setPartyNamesByCase({});
        setIsUsingFallback(true);
      } else {
        setErrorMessage(null);
        setCases(result.data);
        setIsUsingFallback(false);

        const participantResult = await getCaseParticipantsForCases(
          result.data.map((caseDetail) => caseDetail.id).filter((caseId): caseId is number => Number.isFinite(caseId)),
        );

        if (isMounted && !participantResult.error) {
          setPartyNamesByCase(buildPartyNamesByCase(participantResult.data));
        } else if (isMounted) {
          setPartyNamesByCase({});
        }
      }

      if (isMounted) {
        setIsLoading(false);
      }
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, [fallbackCases, selectedDocketType, selectedDocketYear]);

  const filteredCases = useMemo(() => {
    const normalizedSearch = searchTerm.trim().toLowerCase();
    if (!normalizedSearch) {
      return cases;
    }

    return cases.filter((caseDetail) => {
      const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
      const searchableText = [
        formatDisplayDocketNumber(caseDetail),
        casePartyNames?.complainants ?? '',
        casePartyNames?.respondents ?? '',
        caseViolations(caseDetail) ?? '',
        currentAssignment(caseDetail)?.prosecutors?.full_name ?? currentAssignment(caseDetail)?.prosecutors?.short_name ?? '',
        currentStatus(caseDetail)?.display_label ?? currentStatus(caseDetail)?.code ?? '',
      ]
        .join(' ')
        .toLowerCase();

      return searchableText.includes(normalizedSearch);
    });
  }, [cases, partyNamesByCase, searchTerm]);

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
              <AlertDescription>{errorMessage} Showing fallback dummy data.</AlertDescription>
            </Alert>
          ) : null}

          <Card className="min-h-0 flex-1 gap-4 overflow-hidden py-4">
            <CardHeader className="shrink-0 gap-4 px-4 md:px-6">
              <div>
                <CardTitle>Cases List</CardTitle>
                <CardDescription>
                  {isLoading
                    ? 'Loading live cases from Supabase...'
                    : isUsingFallback
                      ? `${cases.length} fallback cases`
                      : `${cases.length} total cases`}
                </CardDescription>
              </div>

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
                      {DOCKET_TYPE_FILTERS.map((docketType) => (
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
                      {DOCKET_YEAR_FILTERS.map((docketYear) => (
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
                            <TableCell className="truncate text-sm">
                              {caseDetail.id ? partyNamesByCase[caseDetail.id]?.complainants ?? '—' : '—'}
                            </TableCell>
                            <TableCell className="truncate text-sm">
                              {caseDetail.id ? partyNamesByCase[caseDetail.id]?.respondents ?? '—' : '—'}
                            </TableCell>
                            <TableCell className="truncate text-sm">{caseViolations(caseDetail) ?? '—'}</TableCell>
                            <TableCell className="truncate text-sm">{currentAssignment(caseDetail)?.prosecutors?.full_name ?? currentAssignment(caseDetail)?.prosecutors?.short_name ?? '—'}</TableCell>
                            <TableCell>
                              <Badge variant="outline">{currentStatus(caseDetail)?.display_label ?? currentStatus(caseDetail)?.code ?? '—'}</Badge>
                            </TableCell>
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
