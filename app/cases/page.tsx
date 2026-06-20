'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ChevronDown, X } from 'lucide-react';
import {
  getDocketParticipantsForCases,
  getDocketQuickDetailsForCases,
  getDocketShellDisplay,
  type CasesDisplayRecord,
  type DocketParticipantsRecord,
  type DocketQuickDetailsRecord,
  type DocketShellRecord,
} from '@/lib/supabase/queries';

type CompactCase = CasesDisplayRecord;
type DocketTypeFilter = string;
type DocketYearFilter = string;

const DEFAULT_DOCKET_TYPE = 'All';
const CASE_ROW_HEIGHT = 49;
const EXPANDED_CASE_ROW_HEIGHT = 96;
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
type CaseSearchColumnKey = Exclude<CaseTableColumnKey, 'docketType' | 'docketYear'>;
type ColumnWidths = Record<CaseTableColumnKey, number>;
type ColumnFilters = Record<CaseTableColumnKey, string[]>;
type ColumnFilterTouched = Record<CaseTableColumnKey, boolean>;
type CasePartyNames = {
  complainants: string[];
  respondents: string[];
};
type CaseClassificationByCase = Record<number, string>;

type CasesPageCache = {
  cases: CompactCase[];
  partyNamesByCase: Record<number, CasePartyNames>;
  classificationsByCase: CaseClassificationByCase;
  hasAllCases: boolean;
  searchTerm?: string;
  selectedSearchColumns?: CaseSearchColumnKey[];
  selectedDocketTypes?: DocketTypeFilter[];
  selectedDocketYears?: DocketYearFilter[];
  selectedColumnFilters?: Partial<ColumnFilters>;
  showColumnFilters?: boolean;
};

const SEARCH_COLUMN_OPTIONS = CASE_TABLE_COLUMNS.filter(
  (column): column is Extract<(typeof CASE_TABLE_COLUMNS)[number], { key: CaseSearchColumnKey }> =>
    column.key !== 'docketType' && column.key !== 'docketYear',
);
const DEFAULT_SEARCH_COLUMNS = SEARCH_COLUMN_OPTIONS.map((column) => column.key);
const CASES_PAGE_CACHE_KEY = 'ocp-cases-page-cache-v14';
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

function getInitialColumnFilters(cachedFilters: Partial<ColumnFilters> | undefined): ColumnFilters {
  return CASE_TABLE_COLUMNS.reduce((filters, column) => {
    filters[column.key] = cachedFilters?.[column.key] ?? [];
    return filters;
  }, {} as ColumnFilters);
}

function getInitialColumnFilterTouched(cachedFilters: Partial<ColumnFilters> | undefined): ColumnFilterTouched {
  return CASE_TABLE_COLUMNS.reduce((touched, column) => {
    touched[column.key] = Array.isArray(cachedFilters?.[column.key]);
    return touched;
  }, {} as ColumnFilterTouched);
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

function searchColumnValue(
  caseDetail: CompactCase,
  columnKey: CaseSearchColumnKey,
  partyNames: CasePartyNames | undefined,
  classification: string | undefined,
) {
  switch (columnKey) {
    case 'docketNumber':
      return formatDisplayDocketNumber(caseDetail);
    case 'complainant':
      return partyNames?.complainants.join(' ') ?? '';
    case 'respondent':
      return partyNames?.respondents.join(' ') ?? '';
    case 'violation':
      return caseViolations(caseDetail) ?? '';
    case 'classification':
      return classification ?? '';
    case 'assignedProsecutor':
      return assignedProsecutor(caseDetail) ?? '';
    case 'currentStatus':
      return currentStatusLabel(caseDetail) ?? '';
    case 'dateReceived':
      return `${caseDetail.date_received ?? ''} ${formatDate(caseDetail.date_received)}`;
    default:
      return '';
  }
}

function searchColumnLabel(columnKey: CaseSearchColumnKey) {
  return SEARCH_COLUMN_OPTIONS.find((column) => column.key === columnKey)?.label ?? columnKey;
}

function columnFilterLabel(columnKey: CaseTableColumnKey) {
  return CASE_TABLE_COLUMNS.find((column) => column.key === columnKey)?.label ?? columnKey;
}

function uniqueSortedOptions(values: string[]) {
  return Array.from(new Set(values)).sort((left, right) => left.localeCompare(right, undefined, { numeric: true, sensitivity: 'base' }));
}

function sameOptions(left: string[], right: string[]) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function allOptionsSelected<T extends string>(selectedOptions: T[], availableOptions: T[]) {
  return (
    availableOptions.length > 0 &&
    selectedOptions.length === availableOptions.length &&
    availableOptions.every((option) => selectedOptions.includes(option))
  );
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return '—';
  }

  const parsedDate = new Date(value);
  return Number.isNaN(parsedDate.getTime()) ? value : parsedDate.toLocaleDateString();
}

function getCaseColumnFilterValue(
  caseDetail: CompactCase,
  columnKey: CaseTableColumnKey,
  partyNames: CasePartyNames | undefined,
  classification: string | undefined,
) {
  switch (columnKey) {
    case 'docketNumber':
      return formatDisplayDocketNumber(caseDetail);
    case 'docketType':
      return caseDetail.docket_type_name ?? caseDetail.docket_type_prefix ?? '—';
    case 'docketYear':
      return Number.isFinite(caseDetail.docket_year) ? String(caseDetail.docket_year) : '—';
    case 'complainant':
      return compactPartyNames(partyNames?.complainants ?? []);
    case 'respondent':
      return compactPartyNames(partyNames?.respondents ?? []);
    case 'violation':
      return caseViolations(caseDetail) ?? '—';
    case 'classification':
      return classification ?? '—';
    case 'assignedProsecutor':
      return assignedProsecutor(caseDetail) ?? '—';
    case 'currentStatus':
      return currentStatusLabel(caseDetail) ?? '—';
    case 'dateReceived':
      return formatDate(caseDetail.date_received);
    default:
      return '—';
  }
}

function getCaseKey(caseDetail: CompactCase) {
  return `${caseDetail.id ?? 'case'}-${formatDisplayDocketNumber(caseDetail)}`;
}

function compactPartyNames(names: string[]) {
  if (names.length === 0) {
    return '—';
  }

  return names.length > 1 ? `${names[0]} +${names.length - 1}` : names[0];
}

function expandedPartyNames(names: string[]) {
  if (names.length === 0) {
    return '—';
  }

  return names.join('\n');
}

const EMPTY_CASE_PARTICIPANTS: Omit<DocketParticipantsRecord, 'id'> = {
  complainant: null,
  respondent: null,
};

const EMPTY_CASE_QUICK_DETAILS: Omit<DocketQuickDetailsRecord, 'id'> = {
  date_received: null,
  current_status_code: null,
  current_status_label: null,
  prosecutor_full_name: null,
  prosecutor_short_name: null,
};

function withEmptyHydratedColumns(shellRows: DocketShellRecord[]): CompactCase[] {
  return shellRows.map((shellRow) => ({
    ...shellRow,
    ...EMPTY_CASE_PARTICIPANTS,
    ...EMPTY_CASE_QUICK_DETAILS,
  }));
}

function mergeParticipantsIntoCases(
  caseRows: CompactCase[],
  participants: DocketParticipantsRecord[],
): CompactCase[] {
  const participantsByCaseId = new Map(participants.map((participant) => [participant.id, participant]));

  return caseRows.map((caseDetail) => ({
    ...caseDetail,
    ...(participantsByCaseId.get(caseDetail.id) ?? EMPTY_CASE_PARTICIPANTS),
  }));
}

function mergeQuickDetailsIntoCases(
  caseRows: CompactCase[],
  quickDetails: DocketQuickDetailsRecord[],
): CompactCase[] {
  const quickDetailsByCaseId = new Map(quickDetails.map((detail) => [detail.id, detail]));

  return caseRows.map((caseDetail) => ({
    ...caseDetail,
    ...(quickDetailsByCaseId.get(caseDetail.id) ?? EMPTY_CASE_QUICK_DETAILS),
  }));
}

function splitViewNames(value: string | null | undefined) {
  return value?.split(' | ').map((name) => name.trim()).filter(Boolean) ?? [];
}

function buildPartyNamesByCase(casesToMap: CompactCase[]) {
  return casesToMap.reduce((namesByCase, caseDetail) => {
    if (Number.isFinite(caseDetail.id)) {
      namesByCase[caseDetail.id] = {
        complainants: splitViewNames(caseDetail.complainant),
        respondents: splitViewNames(caseDetail.respondent),
      };
    }

    return namesByCase;
  }, {} as Record<number, CasePartyNames>);
}

function buildClassificationsByCase(casesToMap: CompactCase[]) {
  return casesToMap.reduce((classificationByCase, caseDetail) => {
    if (Number.isFinite(caseDetail.id)) {
      classificationByCase[caseDetail.id] = caseDetail.case_classification_label ?? '—';
    }

    return classificationByCase;
  }, {} as CaseClassificationByCase);
}

export default function CasesPage() {
  const router = useRouter();
  const tableContainerRef = useRef<HTMLDivElement | null>(null);
  const [cachedInitialState] = useState(() => readCasesPageCache());
  const [cases, setCases] = useState<CompactCase[]>(cachedInitialState?.cases ?? []);
  const docketFiltersTouchedRef = useRef(
    Array.isArray(cachedInitialState?.selectedDocketTypes) || Array.isArray(cachedInitialState?.selectedDocketYears),
  );
  const [selectedDocketTypes, setSelectedDocketTypes] = useState<DocketTypeFilter[]>(cachedInitialState?.selectedDocketTypes ?? []);
  const [selectedDocketYears, setSelectedDocketYears] = useState<DocketYearFilter[]>(cachedInitialState?.selectedDocketYears ?? []);
  const columnFilterTouchedRef = useRef<ColumnFilterTouched>(
    getInitialColumnFilterTouched(cachedInitialState?.selectedColumnFilters),
  );
  const [selectedColumnFilters, setSelectedColumnFilters] = useState<ColumnFilters>(() =>
    getInitialColumnFilters(cachedInitialState?.selectedColumnFilters),
  );
  const [showColumnFilters, setShowColumnFilters] = useState(cachedInitialState?.showColumnFilters ?? false);
  const [searchTerm, setSearchTerm] = useState(cachedInitialState?.searchTerm ?? '');
  const [selectedSearchColumns, setSelectedSearchColumns] = useState<CaseSearchColumnKey[]>(() =>
    cachedInitialState?.selectedSearchColumns ?? [...DEFAULT_SEARCH_COLUMNS],
  );
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
      options: { hasAllCases?: boolean } = {},
    ) {
      const nextPartyNamesByCase = buildPartyNamesByCase(nextCases);
      const nextClassificationsByCase = buildClassificationsByCase(nextCases);

      setPartyNamesByCase(nextPartyNamesByCase);
      setClassificationsByCase(nextClassificationsByCase);

      writeCasesPageCache({
        cases: nextCases,
        partyNamesByCase: nextPartyNamesByCase,
        classificationsByCase: nextClassificationsByCase,
        hasAllCases: options.hasAllCases ?? readCasesPageCache()?.hasAllCases ?? false,
        searchTerm: readCasesPageCache()?.searchTerm ?? searchTerm,
        selectedSearchColumns: readCasesPageCache()?.selectedSearchColumns ?? selectedSearchColumns,
        selectedDocketTypes: readCasesPageCache()?.selectedDocketTypes ?? selectedDocketTypes,
        selectedDocketYears: readCasesPageCache()?.selectedDocketYears ?? selectedDocketYears,
        selectedColumnFilters: readCasesPageCache()?.selectedColumnFilters ?? selectedColumnFilters,
        showColumnFilters: readCasesPageCache()?.showColumnFilters ?? showColumnFilters,
      });
    }

    async function hydrateParticipantsAndQuickDetails(shellCases: CompactCase[]) {
      setIsLoadingAllCases(true);
      const caseIds = shellCases.map((caseDetail) => caseDetail.id);
      const participantsResult = await getDocketParticipantsForCases(caseIds);

      if (!isMounted) {
        return;
      }

      if (participantsResult.error) {
        setIsLoadingAllCases(false);
        return;
      }

      const participantCases = mergeParticipantsIntoCases(shellCases, participantsResult.data);
      setCases(participantCases);
      cacheCasesPageState(participantCases);

      const quickDetailsResult = await getDocketQuickDetailsForCases(caseIds);

      if (!isMounted) {
        return;
      }

      setIsLoadingAllCases(false);

      if (quickDetailsResult.error) {
        return;
      }

      const hydratedCases = mergeQuickDetailsIntoCases(participantCases, quickDetailsResult.data);
      setCases(hydratedCases);
      cacheCasesPageState(hydratedCases, { hasAllCases: true });
    }

    async function loadCases() {
      if (cachedInitialState) {
        setIsLoading(false);

        if (!cachedInitialState.hasAllCases) {
          void hydrateParticipantsAndQuickDetails(cachedInitialState.cases);
        }

        return;
      }

      setIsLoading(true);
      const shellResult = await getDocketShellDisplay();

      if (!isMounted) {
        return;
      }

      if (shellResult.error) {
        setErrorMessage(shellResult.error.message);
        setCases([]);
        setPartyNamesByCase({});
        setIsLoading(false);
        return;
      }

      const shellCases = withEmptyHydratedColumns(shellResult.data);
      setErrorMessage(null);
      setCases(shellCases);
      cacheCasesPageState(shellCases);
      setIsLoading(false);

      void hydrateParticipantsAndQuickDetails(shellCases);
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    const currentCache = readCasesPageCache();

    if (!currentCache) {
      return;
    }

    writeCasesPageCache({
      ...currentCache,
      searchTerm,
      selectedSearchColumns,
      selectedDocketTypes,
      selectedDocketYears,
      selectedColumnFilters,
      showColumnFilters,
    });
  }, [
    searchTerm,
    selectedColumnFilters,
    selectedDocketTypes,
    selectedDocketYears,
    selectedSearchColumns,
    showColumnFilters,
  ]);

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
      if (selectedDocketTypes.length === 0 || selectedDocketYears.length === 0 || selectedSearchColumns.length === 0) {
        return false;
      }

      if (!caseDetail.docket_type_prefix || !selectedDocketTypes.includes(caseDetail.docket_type_prefix)) {
        return false;
      }

      if (!Number.isFinite(caseDetail.docket_year) || !selectedDocketYears.includes(String(caseDetail.docket_year))) {
        return false;
      }

      const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
      const classification = caseDetail.id ? classificationsByCase[caseDetail.id] : undefined;

      if (showColumnFilters) {
        const matchesColumnFilters = CASE_TABLE_COLUMNS.every((column) => {
          const selectedValues = selectedColumnFilters[column.key];
          return selectedValues.length > 0 && selectedValues.includes(
            getCaseColumnFilterValue(caseDetail, column.key, casePartyNames, classification),
          );
        });

        if (!matchesColumnFilters) {
          return false;
        }
      }

      if (!normalizedSearch) {
        return true;
      }

      return selectedSearchColumns.some((columnKey) =>
        searchColumnValue(caseDetail, columnKey, casePartyNames, classification)
          .toLowerCase()
          .includes(normalizedSearch),
      );
    });
  }, [
    cases,
    classificationsByCase,
    partyNamesByCase,
    searchTerm,
    selectedColumnFilters,
    selectedDocketTypes,
    selectedDocketYears,
    selectedSearchColumns,
    showColumnFilters,
  ]);

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

  const docketTypeFilters = useMemo(() => (
    Array.from(
      new Set(cases.map((caseDetail) => caseDetail.docket_type_prefix).filter((value): value is string => Boolean(value))),
    ).sort()
  ), [cases]);

  const docketYearFilters = useMemo(() => {
    const values = Array.from(
      new Set(cases.map((caseDetail) => caseDetail.docket_year).filter((value): value is number => Number.isFinite(value))),
    ).sort((left, right) => right - left);
    return values.map(String);
  }, [cases]);

  const columnFilterOptions = useMemo(() => (
    CASE_TABLE_COLUMNS.reduce((options, column) => {
      options[column.key] = uniqueSortedOptions(
        cases.map((caseDetail) => {
          const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
          const classification = caseDetail.id ? classificationsByCase[caseDetail.id] : undefined;
          return getCaseColumnFilterValue(caseDetail, column.key, casePartyNames, classification);
        }),
      );
      return options;
    }, {} as ColumnFilters)
  ), [cases, classificationsByCase, partyNamesByCase]);

  const activeColumnFilterCount = useMemo(() => (
    CASE_TABLE_COLUMNS.filter((column) => {
      const selectedValues = selectedColumnFilters[column.key];
      const availableValues = columnFilterOptions[column.key];
      return selectedValues.length !== availableValues.length || selectedValues.some((value) => !availableValues.includes(value));
    }).length
  ), [columnFilterOptions, selectedColumnFilters]);

  useEffect(() => {
    if (!docketFiltersTouchedRef.current) {
      setSelectedDocketTypes(docketTypeFilters);
    }
  }, [docketTypeFilters]);

  useEffect(() => {
    if (!docketFiltersTouchedRef.current) {
      setSelectedDocketYears(docketYearFilters);
    }
  }, [docketYearFilters]);

  useEffect(() => {
    setSelectedColumnFilters((currentFilters) => {
      let nextFilters = currentFilters;

      for (const column of CASE_TABLE_COLUMNS) {
        if (columnFilterTouchedRef.current[column.key]) {
          continue;
        }

        const nextColumnOptions = columnFilterOptions[column.key];
        if (sameOptions(currentFilters[column.key], nextColumnOptions)) {
          continue;
        }

        if (nextFilters === currentFilters) {
          nextFilters = { ...currentFilters };
        }

        nextFilters[column.key] = nextColumnOptions;
      }

      return nextFilters;
    });
  }, [columnFilterOptions]);

  const searchColumnSummary = useMemo(() => {
    if (selectedSearchColumns.length === 0) {
      return 'No columns';
    }

    if (selectedSearchColumns.length === DEFAULT_SEARCH_COLUMNS.length) {
      return 'All columns';
    }

    if (selectedSearchColumns.length === 1) {
      return searchColumnLabel(selectedSearchColumns[0]);
    }

    return `${selectedSearchColumns.length} columns`;
  }, [selectedSearchColumns]);

  const docketTypeSummary = useMemo(() => {
    if (selectedDocketTypes.length === 0) {
      return 'No docket types';
    }

    if (allOptionsSelected(selectedDocketTypes, docketTypeFilters)) {
      return DEFAULT_DOCKET_TYPE;
    }

    if (selectedDocketTypes.length === 1) {
      return selectedDocketTypes[0];
    }

    return `${selectedDocketTypes.length} types`;
  }, [docketTypeFilters, selectedDocketTypes]);

  const docketYearSummary = useMemo(() => {
    if (selectedDocketYears.length === 0) {
      return 'No years';
    }

    if (allOptionsSelected(selectedDocketYears, docketYearFilters)) {
      return 'All years';
    }

    if (selectedDocketYears.length === 1) {
      return selectedDocketYears[0];
    }

    return `${selectedDocketYears.length} years`;
  }, [docketYearFilters, selectedDocketYears]);

  const tableWidth = useMemo(
    () => CASE_TABLE_COLUMNS.reduce((total, column) => total + columnWidths[column.key], 0),
    [columnWidths],
  );

  const rowHeights = useMemo(
    () =>
      sortedCases.map((caseDetail) => {
        if (selectedCaseKey !== getCaseKey(caseDetail)) {
          return CASE_ROW_HEIGHT;
        }

        const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
        const partyLineCount = Math.max(
          casePartyNames?.complainants.length ?? 1,
          casePartyNames?.respondents.length ?? 1,
          1,
        );

        return Math.max(
          EXPANDED_CASE_ROW_HEIGHT,
          CASE_ROW_HEIGHT + (partyLineCount - 1) * 24,
        );
      }),
    [partyNamesByCase, selectedCaseKey, sortedCases],
  );

  const virtualRows = useMemo(() => {
    const overscanPixels = VIRTUAL_ROW_OVERSCAN * CASE_ROW_HEIGHT;
    const startBoundary = Math.max(0, scrollTop - overscanPixels);
    const endBoundary = scrollTop + viewportHeight + overscanPixels;
    let topPadding = 0;
    let startIndex = 0;

    while (startIndex < rowHeights.length && topPadding + rowHeights[startIndex] < startBoundary) {
      topPadding += rowHeights[startIndex];
      startIndex += 1;
    }

    let visibleHeight = topPadding;
    let endIndex = startIndex;

    while (endIndex < rowHeights.length && visibleHeight < endBoundary) {
      visibleHeight += rowHeights[endIndex];
      endIndex += 1;
    }

    const bottomPadding = rowHeights.slice(endIndex).reduce((total, height) => total + height, 0);

    return {
      rows: sortedCases.slice(startIndex, endIndex),
      topPadding,
      bottomPadding,
    };
  }, [rowHeights, scrollTop, sortedCases, viewportHeight]);

  function toggleSearchAllColumns() {
    setSelectedSearchColumns((currentColumns) =>
      allOptionsSelected(currentColumns, DEFAULT_SEARCH_COLUMNS) ? [] : [...DEFAULT_SEARCH_COLUMNS],
    );
  }

  function toggleSearchColumn(columnKey: CaseSearchColumnKey) {
    setSelectedSearchColumns((currentColumns) => {
      if (currentColumns.includes(columnKey)) {
        return currentColumns.filter((currentColumn) => currentColumn !== columnKey);
      }

      return [...currentColumns, columnKey];
    });
  }

  function toggleDocketType(docketType: DocketTypeFilter) {
    docketFiltersTouchedRef.current = true;
    setSelectedDocketTypes((currentTypes) => {
      if (currentTypes.includes(docketType)) {
        return currentTypes.filter((currentType) => currentType !== docketType);
      }

      return [...currentTypes, docketType];
    });
  }

  function toggleAllDocketTypes() {
    docketFiltersTouchedRef.current = true;
    setSelectedDocketTypes((currentTypes) =>
      allOptionsSelected(currentTypes, docketTypeFilters) ? [] : [...docketTypeFilters],
    );
  }

  function toggleDocketYear(docketYear: DocketYearFilter) {
    docketFiltersTouchedRef.current = true;
    setSelectedDocketYears((currentYears) => {
      if (currentYears.includes(docketYear)) {
        return currentYears.filter((currentYear) => currentYear !== docketYear);
      }

      return [...currentYears, docketYear];
    });
  }

  function toggleAllDocketYears() {
    docketFiltersTouchedRef.current = true;
    setSelectedDocketYears((currentYears) =>
      allOptionsSelected(currentYears, docketYearFilters) ? [] : [...docketYearFilters],
    );
  }

  function clearSearch() {
    setSearchTerm('');
  }

  function clearColumnFilters() {
    columnFilterTouchedRef.current = CASE_TABLE_COLUMNS.reduce((touched, column) => {
      touched[column.key] = false;
      return touched;
    }, {} as ColumnFilterTouched);
    setSelectedColumnFilters({ ...columnFilterOptions });
  }

  function columnFilterSummary(columnKey: CaseTableColumnKey) {
    const selectedValues = selectedColumnFilters[columnKey];
    const availableValues = columnFilterOptions[columnKey];

    if (selectedValues.length === 0) {
      return 'None';
    }

    if (allOptionsSelected(selectedValues, availableValues)) {
      return 'All';
    }

    if (selectedValues.length === 1) {
      return selectedValues[0];
    }

    return `${selectedValues.length} selected`;
  }

  function toggleColumnFilterValue(columnKey: CaseTableColumnKey, value: string) {
    columnFilterTouchedRef.current[columnKey] = true;
    setSelectedColumnFilters((currentFilters) => ({
      ...currentFilters,
      [columnKey]: currentFilters[columnKey].includes(value)
        ? currentFilters[columnKey].filter((currentValue) => currentValue !== value)
        : [...currentFilters[columnKey], value],
    }));
  }

  function toggleAllColumnFilterValues(columnKey: CaseTableColumnKey) {
    columnFilterTouchedRef.current[columnKey] = true;
    setSelectedColumnFilters((currentFilters) => ({
      ...currentFilters,
      [columnKey]: allOptionsSelected(currentFilters[columnKey], columnFilterOptions[columnKey])
        ? []
        : [...columnFilterOptions[columnKey]],
    }));
  }

  function renderColumnFilter(columnKey: CaseTableColumnKey) {
    if (!showColumnFilters) {
      return null;
    }

    const availableValues = columnFilterOptions[columnKey];
    const selectedValues = selectedColumnFilters[columnKey];

    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button type="button" variant="ghost" size="sm" className="h-7 max-w-full justify-start gap-1 px-0 text-xs font-normal normal-case">
            <span className="truncate">{columnFilterSummary(columnKey)}</span>
            <ChevronDown className="size-3 opacity-70" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="start" className="max-h-80 w-64 overflow-y-auto">
          <DropdownMenuLabel>{columnFilterLabel(columnKey)}</DropdownMenuLabel>
          <DropdownMenuCheckboxItem
            checked={allOptionsSelected(selectedValues, availableValues)}
            onCheckedChange={() => toggleAllColumnFilterValues(columnKey)}
            onSelect={(event) => event.preventDefault()}
          >
            All
          </DropdownMenuCheckboxItem>
          {availableValues.map((value) => (
            <DropdownMenuCheckboxItem
              key={value}
              checked={selectedValues.includes(value)}
              onCheckedChange={() => toggleColumnFilterValue(columnKey, value)}
              onSelect={(event) => event.preventDefault()}
            >
              {value}
            </DropdownMenuCheckboxItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>
    );
  }

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
              <AlertTitle>Unable to load live PostgreSQL cases</AlertTitle>
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
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <div className="relative sm:flex-1">
                      <Input
                        id="case-search"
                        className="pr-10"
                        placeholder={`Search ${searchColumnSummary.toLowerCase()}`}
                        value={searchTerm}
                        onChange={(event) => setSearchTerm(event.target.value)}
                      />
                      {searchTerm ? (
                        <button
                          type="button"
                          className="absolute right-2 top-1/2 flex size-6 -translate-y-1/2 items-center justify-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                          aria-label="Clear case search"
                          onClick={clearSearch}
                        >
                          <X className="size-4" />
                        </button>
                      ) : null}
                    </div>
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button type="button" variant="outline" className="justify-between sm:w-56">
                          {searchColumnSummary}
                          <ChevronDown className="size-4 opacity-70" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" className="w-56">
                        <DropdownMenuLabel>Search columns</DropdownMenuLabel>
                        <DropdownMenuCheckboxItem
                          checked={allOptionsSelected(selectedSearchColumns, DEFAULT_SEARCH_COLUMNS)}
                          onCheckedChange={toggleSearchAllColumns}
                          onSelect={(event) => event.preventDefault()}
                        >
                          Search all columns
                        </DropdownMenuCheckboxItem>
                        {SEARCH_COLUMN_OPTIONS.map((column) => (
                          <DropdownMenuCheckboxItem
                            key={column.key}
                            checked={selectedSearchColumns.includes(column.key)}
                            onCheckedChange={() => toggleSearchColumn(column.key)}
                            onSelect={(event) => event.preventDefault()}
                          >
                            {column.label}
                          </DropdownMenuCheckboxItem>
                        ))}
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="docket-type-filter">
                    Docket Type
                  </label>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button id="docket-type-filter" type="button" variant="outline" className="justify-between">
                        {docketTypeSummary}
                        <ChevronDown className="size-4 opacity-70" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start" className="w-56">
                      <DropdownMenuLabel>Docket types</DropdownMenuLabel>
                      <DropdownMenuCheckboxItem
                        checked={allOptionsSelected(selectedDocketTypes, docketTypeFilters)}
                        onCheckedChange={toggleAllDocketTypes}
                        onSelect={(event) => event.preventDefault()}
                      >
                        All
                      </DropdownMenuCheckboxItem>
                      {docketTypeFilters.map((docketType) => (
                        <DropdownMenuCheckboxItem
                          key={docketType}
                          checked={selectedDocketTypes.includes(docketType)}
                          onCheckedChange={() => toggleDocketType(docketType)}
                          onSelect={(event) => event.preventDefault()}
                        >
                          {docketType}
                        </DropdownMenuCheckboxItem>
                      ))}
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>

                <div className="flex flex-col gap-2">
                  <label className="text-sm font-medium text-foreground" htmlFor="docket-year-filter">
                    Docket Year
                  </label>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button id="docket-year-filter" type="button" variant="outline" className="justify-between">
                        {docketYearSummary}
                        <ChevronDown className="size-4 opacity-70" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start" className="w-56">
                      <DropdownMenuLabel>Docket years</DropdownMenuLabel>
                      <DropdownMenuCheckboxItem
                        checked={allOptionsSelected(selectedDocketYears, docketYearFilters)}
                        onCheckedChange={toggleAllDocketYears}
                        onSelect={(event) => event.preventDefault()}
                      >
                        All years
                      </DropdownMenuCheckboxItem>
                      {docketYearFilters.map((docketYear) => (
                        <DropdownMenuCheckboxItem
                          key={docketYear}
                          checked={selectedDocketYears.includes(docketYear)}
                          onCheckedChange={() => toggleDocketYear(docketYear)}
                          onSelect={(event) => event.preventDefault()}
                        >
                          {docketYear}
                        </DropdownMenuCheckboxItem>
                      ))}
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
            </CardHeader>

            <CardContent className="flex min-h-0 flex-1 flex-col gap-2 overflow-hidden px-4 md:px-6">
              {isLoading ? (
                <div className="py-8 text-center text-sm text-muted-foreground">Loading cases...</div>
              ) : (
                <div
                  ref={tableContainerRef}
                  className="min-h-0 flex-1 overflow-auto rounded-lg border border-border"
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
                            <div className="flex min-w-0 flex-col gap-1">
                              <span>{column.label}</span>
                              {renderColumnFilter(column.key)}
                            </div>
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

                      {sortedCases.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={CASE_TABLE_COLUMNS.length} className="py-8 text-center text-sm text-muted-foreground">
                            No cases, please check filters.
                          </TableCell>
                        </TableRow>
                      ) : null}

                      {virtualRows.rows.map((caseDetail) => {
                        const caseKey = getCaseKey(caseDetail);
                        const isSelected = selectedCaseKey === caseKey;
                        const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
                        const complainantNames = casePartyNames?.complainants ?? [];
                        const respondentNames = casePartyNames?.respondents ?? [];

                        return (
                          <TableRow
                            key={caseKey}
                            aria-selected={isSelected}
                            className={`cursor-pointer ${isSelected ? 'bg-primary/10 hover:bg-primary/15' : 'h-12 hover:bg-muted/50'}`}
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
                            <TableCell className={isSelected ? 'whitespace-pre-line text-sm leading-6' : 'truncate text-sm'}>
                              {isSelected ? expandedPartyNames(complainantNames) : compactPartyNames(complainantNames)}
                            </TableCell>
                            <TableCell className={isSelected ? 'whitespace-pre-line text-sm leading-6' : 'truncate text-sm'}>
                              {isSelected ? expandedPartyNames(respondentNames) : compactPartyNames(respondentNames)}
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
              <div className="flex shrink-0 items-center justify-between gap-4 text-sm text-muted-foreground">
                <span>
                  {sortedCases.length.toLocaleString()} {sortedCases.length === 1 ? 'case' : 'cases'} shown
                </span>
                <div className="flex items-center gap-2">
                  {showColumnFilters && activeColumnFilterCount > 0 ? (
                    <Button type="button" variant="ghost" size="sm" onClick={clearColumnFilters}>
                      Clear filters
                    </Button>
                  ) : null}
                  <Button type="button" variant="outline" size="sm" onClick={() => setShowColumnFilters((currentValue) => !currentValue)}>
                    {showColumnFilters ? 'Turn off filters' : 'Turn on filters'}
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}
