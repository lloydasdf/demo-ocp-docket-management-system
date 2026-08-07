'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { StageBadge, StatusBadge } from '@/components/status-badge';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
} from '@/components/ui/context-menu';
import { ChevronDown, ChevronRight, ExternalLink, Eye, Filter, GripVertical, Printer, RefreshCw, X } from 'lucide-react';
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels';
import { ExportCasesDialog } from '@/components/cases/export-cases-dialog';
import { useCurrentUserRole } from '@/hooks/use-current-user-role';
import { canExportCasesToExcel, canViewCaseAging, canViewCriminalCaseNumbers, canViewLinkedDocket } from '@/lib/auth/ui-permissions';
import {
  getDocketCaseLabelsForCases,
  getCriminalCaseNumbersForCases,
  getDocketParticipantsForCases,
  getDocketApprovalsForCases,
  canCurrentUserViewDocketQuickDetails,
  getDocketQuickDetailsForCases,
  getDocketShellDisplay,
  getLinkedDocketsForCases,
  type CasesDisplayRecord,
  type DocketCaseLabelsRecord,
  type DocketParticipantsRecord,
  type DocketApprovalRecord,
  type DocketQuickDetailsRecord,
  type DocketShellRecord,
  type CaseCriminalCaseNumbersRecord,
} from '@/lib/supabase/queries';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import type { CasesReportFilters, CasesReportRow } from '@/lib/pdf/cases-report';

type CompactCase = CasesDisplayRecord;
type DocketTypeFilter = string;
type DocketYearFilter = string;
type DocketMonthsByYear = Record<DocketYearFilter, string[]>;

const DEFAULT_DOCKET_TYPE = 'All';
const DOCKET_MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
] as const;
const DOCKET_MONTH_SHORT_NAMES = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
] as const;
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
  { key: 'currentStage', label: 'Current Stage', initialWidth: 200, minWidth: 160 },
  { key: 'criminalCaseNumber', label: 'CC. No.', initialWidth: 180, minWidth: 140 },
  { key: 'dateApproved', label: 'Date Approved', initialWidth: 150, minWidth: 120 },
  { key: 'dateReceived', label: 'Date Received', initialWidth: 150, minWidth: 120 },
  { key: 'aging', label: 'Aging', initialWidth: 120, minWidth: 100 },
] as const;

type CaseTableColumnKey = (typeof CASE_TABLE_COLUMNS)[number]['key'];
type CaseSearchColumnKey = Exclude<CaseTableColumnKey, 'docketType' | 'docketYear' | 'aging'>;
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
  hasLoadedCases: boolean;
  searchTerm?: string;
  selectedSearchColumns?: CaseSearchColumnKey[];
  selectedDocketTypes?: DocketTypeFilter[];
  selectedDocketYears?: DocketYearFilter[];
  selectedDocketMonthsByYear?: DocketMonthsByYear;
  selectedColumnFilters?: Partial<ColumnFilters>;
  showColumnFilters?: boolean;
};

const SEARCH_COLUMN_OPTIONS = CASE_TABLE_COLUMNS.filter(
  (column): column is Extract<(typeof CASE_TABLE_COLUMNS)[number], { key: CaseSearchColumnKey }> =>
    column.key !== 'docketType' && column.key !== 'docketYear' && column.key !== 'aging',
);
const DEFAULT_SEARCH_COLUMNS = SEARCH_COLUMN_OPTIONS.map((column) => column.key);
const CASES_PAGE_CACHE_KEY_PREFIX = 'ocp-cases-page-cache-v25';
const casesPageMemoryCache = new Map<string, CasesPageCache>();

function getCasesPageCacheKey(userId: string) {
  return `${CASES_PAGE_CACHE_KEY_PREFIX}:${userId}`;
}

function clearLegacyCasesPageCaches() {
  if (typeof window === 'undefined') {
    return;
  }

  window.sessionStorage.removeItem('ocp-cases-page-cache-v16');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v17');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v18');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v19');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v20');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v21');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v22');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v23');
  window.sessionStorage.removeItem('ocp-cases-page-cache-v24');
}

function docketMonthName(monthCode: string) {
  const monthIndex = monthCode.trim().toUpperCase().charCodeAt(0) - 65;
  return DOCKET_MONTH_NAMES[monthIndex] ?? monthCode;
}

function docketMonthShortName(monthCode: string) {
  const monthIndex = monthCode.trim().toUpperCase().charCodeAt(0) - 65;
  return DOCKET_MONTH_SHORT_NAMES[monthIndex] ?? monthCode;
}

function readCasesPageCache(userId: string) {
  const cacheKey = getCasesPageCacheKey(userId);
  const memoryCache = casesPageMemoryCache.get(cacheKey);
  if (memoryCache) {
    return memoryCache;
  }

  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const cachedValue = window.sessionStorage.getItem(getCasesPageCacheKey(userId));
    if (!cachedValue) {
      return null;
    }

    const cache = JSON.parse(cachedValue) as CasesPageCache;
    casesPageMemoryCache.set(cacheKey, cache);
    return cache;
  } catch {
    return null;
  }
}

function hasUsableCasesCache(cache: CasesPageCache | null) {
  return Boolean(
    cache?.hasLoadedCases &&
    cache.hasAllCases &&
    Array.isArray(cache.cases),
  );
}

function writeCasesPageCache(userId: string, cache: CasesPageCache) {
  const cacheKey = getCasesPageCacheKey(userId);
  casesPageMemoryCache.set(cacheKey, cache);

  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.sessionStorage.setItem(cacheKey, JSON.stringify(cache));
  } catch {
    window.sessionStorage.removeItem(cacheKey);
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
  return caseDetail.current_case_status_label || caseDetail.current_case_status_code || caseDetail.current_status_label || caseDetail.current_status_code;
}

function currentStageLabel(caseDetail: CompactCase) {
  return caseDetail.current_case_stage_label || caseDetail.current_case_stage_code;
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
    case 'criminalCaseNumber':
      return caseDetail.criminal_case_numbers ?? '';
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
    case 'currentStage':
      return currentStageLabel(caseDetail) ?? '';
    case 'dateApproved':
      return `${caseDetail.date_approved ?? ''} ${formatDate(caseDetail.date_approved)}`;
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

const AGING_EXCLUDED_STATUS_CODES = new Set(['FILED', 'MIXED_RESULT', 'DISMISSED']);

function formatCaseAging(caseDetail: CompactCase, today = new Date()) {
  const statusCode = (
    caseDetail.current_case_status_code ||
    caseDetail.current_case_status_label ||
    caseDetail.current_status_code ||
    caseDetail.current_status_label
  )?.trim().toUpperCase().replace(/[\s-]+/g, '_');
  if (!caseDetail.date_received || (statusCode && AGING_EXCLUDED_STATUS_CODES.has(statusCode))) {
    return '—';
  }

  const receivedParts = /^(\d{4})-(\d{2})-(\d{2})/.exec(caseDetail.date_received);
  if (!receivedParts) {
    return '—';
  }

  const receivedUtc = Date.UTC(Number(receivedParts[1]), Number(receivedParts[2]) - 1, Number(receivedParts[3]));
  const todayUtc = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate());
  const days = Math.max(0, Math.floor((todayUtc - receivedUtc) / 86_400_000));
  return `${days} ${days === 1 ? 'day' : 'days'}`;
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
    case 'criminalCaseNumber':
      return caseDetail.criminal_case_numbers ?? '—';
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
    case 'dateApproved':
      return formatDate(caseDetail.date_approved);
    case 'dateReceived':
      return formatDate(caseDetail.date_received);
    case 'aging':
      return formatCaseAging(caseDetail);
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

const EMPTY_CASE_LABELS: Omit<DocketCaseLabelsRecord, 'id'> = {
  violations: null,
  summary_text: null,
  case_classification_label: null,
};

const EMPTY_CASE_QUICK_DETAILS: Omit<DocketQuickDetailsRecord, 'id'> = {
  date_received: null,
  current_status_code: null,
  current_status_label: null,
  current_status_id: null,
  current_status_date: null,
  current_case_status_id: null,
  current_case_status_code: null,
  current_case_status_label: null,
  current_case_status_date: null,
  current_case_status_remarks: null,
  current_case_stage_id: null,
  current_case_stage_code: null,
  current_case_stage_label: null,
  current_case_stage_date: null,
  current_case_stage_remarks: null,
  prosecutor_full_name: null,
  prosecutor_short_name: null,
};

const EMPTY_CASE_APPROVAL = {
  date_approved: null,
  approval_case_event_id: null,
  approval_event_type_code: null,
};

const EMPTY_CRIMINAL_CASE_NUMBERS = { criminal_case_numbers: null };

function withEmptyHydratedColumns(shellRows: DocketShellRecord[]): CompactCase[] {
  return shellRows.map((shellRow) => ({
    ...shellRow,
    ...EMPTY_CASE_PARTICIPANTS,
    ...EMPTY_CASE_LABELS,
    ...EMPTY_CASE_QUICK_DETAILS,
    ...EMPTY_CASE_APPROVAL,
    ...EMPTY_CRIMINAL_CASE_NUMBERS,
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

function mergeCriminalCaseNumbersIntoCases(
  caseRows: CompactCase[],
  criminalCaseNumbers: CaseCriminalCaseNumbersRecord[],
): CompactCase[] {
  const numbersByCaseId = new Map(criminalCaseNumbers.map((row) => [row.case_id, row.criminal_case_numbers]));

  return caseRows.map((caseDetail) => ({
    ...caseDetail,
    criminal_case_numbers: numbersByCaseId.get(caseDetail.id) ?? null,
  }));
}


function mergeLabelsIntoCases(
  caseRows: CompactCase[],
  labels: DocketCaseLabelsRecord[],
): CompactCase[] {
  const labelsByCaseId = new Map(labels.map((label) => [label.id, label]));

  return caseRows.map((caseDetail) => ({
    ...caseDetail,
    ...(labelsByCaseId.get(caseDetail.id) ?? EMPTY_CASE_LABELS),
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

function mergeApprovalsIntoCases(
  caseRows: CompactCase[],
  approvals: DocketApprovalRecord[],
): CompactCase[] {
  const approvalsByCaseId = new Map(approvals.map((approval) => [approval.case_id, approval]));

  return caseRows.map((caseDetail) => {
    const approval = approvalsByCaseId.get(caseDetail.id);

    return {
      ...caseDetail,
      date_approved: approval?.date_approved ?? null,
      approval_case_event_id: approval?.case_event_id ?? null,
      approval_event_type_code: approval?.approval_event_type_code ?? null,
    };
  });
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
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [hasResolvedCurrentUser, setHasResolvedCurrentUser] = useState(false);
  const [cachedInitialState, setCachedInitialState] = useState<CasesPageCache | null>(null);
  const [cases, setCases] = useState<CompactCase[]>([]);
  const docketFiltersTouchedRef = useRef(false);
  const [selectedDocketTypes, setSelectedDocketTypes] = useState<DocketTypeFilter[]>([]);
  const [selectedDocketYears, setSelectedDocketYears] = useState<DocketYearFilter[]>([]);
  const [selectedDocketMonthsByYear, setSelectedDocketMonthsByYear] = useState<DocketMonthsByYear>({});
  const [expandedDocketYears, setExpandedDocketYears] = useState<DocketYearFilter[]>([]);
  const columnFilterTouchedRef = useRef<ColumnFilterTouched>(
    getInitialColumnFilterTouched(undefined),
  );
  const [selectedColumnFilters, setSelectedColumnFilters] = useState<ColumnFilters>(() =>
    getInitialColumnFilters(undefined),
  );
  const [showColumnFilters, setShowColumnFilters] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedSearchColumns, setSelectedSearchColumns] = useState<CaseSearchColumnKey[]>(() =>
    [...DEFAULT_SEARCH_COLUMNS],
  );
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingAllCases, setIsLoadingAllCases] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedCaseKey, setSelectedCaseKey] = useState<string | null>(null);
  const [quickViewCaseId, setQuickViewCaseId] = useState<number | null>(null);

  const [columnWidths, setColumnWidths] = useState<ColumnWidths>(() => getInitialColumnWidths());
  const [partyNamesByCase, setPartyNamesByCase] = useState<Record<number, CasePartyNames>>({});
  const [classificationsByCase, setClassificationsByCase] = useState<CaseClassificationByCase>({});
  const [linkedDocketsByCase, setLinkedDocketsByCase] = useState<Record<number, string>>({});
  const [scrollTop, setScrollTop] = useState(0);
  const [viewportHeight, setViewportHeight] = useState(640);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isGeneratingPdf, setIsGeneratingPdf] = useState(false);
  const [pdfError, setPdfError] = useState<string | null>(null);
  const { roles: currentRoles, isLoading: isRoleLoading, error: roleError } = useCurrentUserRole();
  const canShowExcelExport = !isRoleLoading && !roleError && canExportCasesToExcel(currentRoles);
  const canViewLinkedDockets = !isRoleLoading && !roleError && canViewLinkedDocket(currentRoles);
  const canViewCriminalCaseNo = !isRoleLoading && !roleError && canViewCriminalCaseNumbers(currentRoles);
  const canViewAging = !isRoleLoading && !roleError && canViewCaseAging(currentRoles);
  const visibleCaseTableColumns = useMemo(
    () => CASE_TABLE_COLUMNS.filter((column) =>
      (column.key !== 'aging' || canViewAging) &&
      (column.key !== 'criminalCaseNumber' || canViewCriminalCaseNo),
    ),
    [canViewAging, canViewCriminalCaseNo],
  );
  const availableSearchColumnOptions = useMemo(
    () => SEARCH_COLUMN_OPTIONS.filter((column) => column.key !== 'criminalCaseNumber' || canViewCriminalCaseNo),
    [canViewCriminalCaseNo],
  );
  const availableSearchColumns = useMemo(
    () => availableSearchColumnOptions.map((column) => column.key),
    [availableSearchColumnOptions],
  );

  useEffect(() => {
    if (isRoleLoading) return;
    setSelectedSearchColumns((columns) => columns.filter((column) => availableSearchColumns.includes(column)));
  }, [availableSearchColumns, isRoleLoading]);
  const renderedColumnCount = visibleCaseTableColumns.length + (canViewLinkedDockets ? 1 : 0);

  useEffect(() => {
    if (!canViewLinkedDockets || cases.length === 0) return;
    let mounted = true;
    void getLinkedDocketsForCases(cases.map((caseDetail) => caseDetail.id).filter((id): id is number => id !== null)).then((result) => {
      if (!mounted || result.error) return;
      setLinkedDocketsByCase(result.data.reduce<Record<number, string>>((links, link) => {
        links[link.id] = (link.pe_case_id === link.id ? link.linked_docket_number : link.pe_docket_number) ?? '—';
        return links;
      }, {}));
    });
    return () => { mounted = false; };
  }, [canViewLinkedDockets, cases]);
  const latestCacheableStateRef = useRef({
    searchTerm,
    selectedSearchColumns,
    selectedDocketTypes,
    selectedDocketYears,
    selectedDocketMonthsByYear,
    selectedColumnFilters,
    showColumnFilters,
  });

  latestCacheableStateRef.current = {
    searchTerm,
    selectedSearchColumns,
    selectedDocketTypes,
    selectedDocketYears,
    selectedDocketMonthsByYear,
    selectedColumnFilters,
    showColumnFilters,
  };

  const isMountedRef = useRef(false);

  const applyCachedCasesPageState = useCallback((cache: CasesPageCache) => {
    setCases(cache.cases);
    setPartyNamesByCase(cache.partyNamesByCase);
    setClassificationsByCase(cache.classificationsByCase);
    setSearchTerm(cache.searchTerm ?? '');
    setSelectedSearchColumns(cache.selectedSearchColumns ?? [...DEFAULT_SEARCH_COLUMNS]);
    setSelectedDocketTypes(cache.selectedDocketTypes ?? []);
    setSelectedDocketYears(cache.selectedDocketYears ?? []);
    setSelectedDocketMonthsByYear(cache.selectedDocketMonthsByYear ?? {});
    setSelectedColumnFilters(getInitialColumnFilters(cache.selectedColumnFilters));
    setShowColumnFilters(cache.showColumnFilters ?? false);
    docketFiltersTouchedRef.current = Array.isArray(cache.selectedDocketTypes) || Array.isArray(cache.selectedDocketYears);
    columnFilterTouchedRef.current = getInitialColumnFilterTouched(cache.selectedColumnFilters);
  }, []);

  const cacheCasesPageState = useCallback((
    nextCases: CompactCase[],
    options: { hasAllCases?: boolean } = {},
  ) => {
    if (!currentUserId) {
      return;
    }

    const currentCache = readCasesPageCache(currentUserId);
    const latestCacheableState = latestCacheableStateRef.current;
    const nextPartyNamesByCase = buildPartyNamesByCase(nextCases);
    const nextClassificationsByCase = buildClassificationsByCase(nextCases);

    setPartyNamesByCase(nextPartyNamesByCase);
    setClassificationsByCase(nextClassificationsByCase);

    writeCasesPageCache(currentUserId, {
      cases: nextCases,
      partyNamesByCase: nextPartyNamesByCase,
      classificationsByCase: nextClassificationsByCase,
      hasAllCases: options.hasAllCases ?? currentCache?.hasAllCases ?? false,
      hasLoadedCases: true,
      searchTerm: currentCache?.searchTerm ?? latestCacheableState.searchTerm,
      selectedSearchColumns: currentCache?.selectedSearchColumns ?? latestCacheableState.selectedSearchColumns,
      selectedDocketTypes: currentCache?.selectedDocketTypes ?? latestCacheableState.selectedDocketTypes,
      selectedDocketYears: currentCache?.selectedDocketYears ?? latestCacheableState.selectedDocketYears,
      selectedDocketMonthsByYear: currentCache?.selectedDocketMonthsByYear ?? latestCacheableState.selectedDocketMonthsByYear,
      selectedColumnFilters: currentCache?.selectedColumnFilters ?? latestCacheableState.selectedColumnFilters,
      showColumnFilters: currentCache?.showColumnFilters ?? latestCacheableState.showColumnFilters,
    });
  }, [currentUserId]);

  const hydrateParticipantsLabelsAndQuickDetails = useCallback(async (shellCases: CompactCase[]) => {
    setIsLoadingAllCases(true);
    const caseIds = shellCases.map((caseDetail) => caseDetail.id);
    const [participantsResult, criminalCaseNumbersResult] = await Promise.all([
      getDocketParticipantsForCases(caseIds),
      canViewCriminalCaseNo
        ? getCriminalCaseNumbersForCases(caseIds)
        : Promise.resolve({ data: [], error: null }),
    ]);

    if (!isMountedRef.current) {
      return;
    }

    if (criminalCaseNumbersResult.error) {
      setErrorMessage(`Unable to load criminal case numbers: ${criminalCaseNumbersResult.error.message}`);
      setIsLoadingAllCases(false);
      return;
    }

    if (participantsResult.error) {
      setIsLoadingAllCases(false);
      return;
    }

    setErrorMessage(null);

    const participantCases = mergeCriminalCaseNumbersIntoCases(
      mergeParticipantsIntoCases(shellCases, participantsResult.data),
      criminalCaseNumbersResult.data,
    );
    setCases(participantCases);
    cacheCasesPageState(participantCases);

    const labelsResult = await getDocketCaseLabelsForCases(caseIds);

    if (!isMountedRef.current) {
      return;
    }

    if (labelsResult.error) {
      setIsLoadingAllCases(false);
      return;
    }

    const labeledCases = mergeLabelsIntoCases(participantCases, labelsResult.data);
    setCases(labeledCases);
    cacheCasesPageState(labeledCases);

    const canViewQuickDetailsResult = await canCurrentUserViewDocketQuickDetails();

    if (!isMountedRef.current) {
      return;
    }

    if (canViewQuickDetailsResult.error || !canViewQuickDetailsResult.data) {
      setIsLoadingAllCases(false);
      cacheCasesPageState(labeledCases, { hasAllCases: true });
      return;
    }

    const [quickDetailsResult, approvalsResult] = await Promise.all([
      getDocketQuickDetailsForCases(caseIds),
      getDocketApprovalsForCases(caseIds),
    ]);

    if (!isMountedRef.current) {
      return;
    }

    setIsLoadingAllCases(false);

    if (quickDetailsResult.error || approvalsResult.error) {
      return;
    }

    const hydratedCases = mergeApprovalsIntoCases(
      mergeQuickDetailsIntoCases(labeledCases, quickDetailsResult.data),
      approvalsResult.data,
    );
    setCases(hydratedCases);
    cacheCasesPageState(hydratedCases, { hasAllCases: true });
  }, [cacheCasesPageState, canViewCriminalCaseNo]);

  const loadCases = useCallback(async (options: { preserveExistingRows: boolean }) => {
    if (options.preserveExistingRows) {
      setIsRefreshing(true);
    } else {
      setIsLoading(true);
    }

    const shellResult = await getDocketShellDisplay();

    if (!isMountedRef.current) {
      return;
    }

    if (shellResult.error) {
      setErrorMessage(shellResult.error.message);

      if (!options.preserveExistingRows && (!currentUserId || !hasUsableCasesCache(readCasesPageCache(currentUserId)))) {
        setCases([]);
        setPartyNamesByCase({});
        setClassificationsByCase({});
      }

      setIsLoading(false);
      setIsRefreshing(false);
      return;
    }

    const shellCases = withEmptyHydratedColumns(shellResult.data);
    setErrorMessage(null);
    setCases(shellCases);
    setSelectedCaseKey(null);
    cacheCasesPageState(shellCases, { hasAllCases: false });
    setIsLoading(false);
    setIsRefreshing(false);

    void hydrateParticipantsLabelsAndQuickDetails(shellCases);
  }, [cacheCasesPageState, currentUserId, hydrateParticipantsLabelsAndQuickDetails]);

  useEffect(() => {
    isMountedRef.current = true;
    clearLegacyCasesPageCaches();

    async function resolveAuthenticatedUserCache() {
      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getUser();

      if (!isMountedRef.current) {
        return;
      }

      const userId = data.user?.id ?? null;
      setCurrentUserId(userId);

      if (!userId) {
        setCases([]);
        setPartyNamesByCase({});
        setClassificationsByCase({});
        setCachedInitialState(null);
        setIsLoading(false);
        setHasResolvedCurrentUser(true);
        return;
      }

      const userCache = readCasesPageCache(userId);
      setCachedInitialState(userCache);

      if (userCache && hasUsableCasesCache(userCache)) {
        applyCachedCasesPageState(userCache);
        setIsLoading(false);
      }

      setHasResolvedCurrentUser(true);
    }

    void resolveAuthenticatedUserCache();

    return () => {
      isMountedRef.current = false;
    };
  }, [applyCachedCasesPageState]);

  useEffect(() => {
    if (!hasResolvedCurrentUser || !currentUserId || hasUsableCasesCache(cachedInitialState)) {
      return;
    }

    void loadCases({ preserveExistingRows: false });
  }, [cachedInitialState, currentUserId, hasResolvedCurrentUser, loadCases]);

  function refreshCases() {
    void loadCases({ preserveExistingRows: true });
  }

  useEffect(() => {
    if (!currentUserId) {
      return;
    }

    const currentCache = readCasesPageCache(currentUserId);

    if (!currentCache) {
      return;
    }

    writeCasesPageCache(currentUserId, {
      ...currentCache,
      searchTerm,
      selectedSearchColumns,
      selectedDocketTypes,
      selectedDocketYears,
      selectedDocketMonthsByYear,
      selectedColumnFilters,
      showColumnFilters,
    });
  }, [
    currentUserId,
    searchTerm,
    selectedColumnFilters,
    selectedDocketTypes,
    selectedDocketYears,
    selectedDocketMonthsByYear,
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

  const casesMatchingPrimaryFilters = useMemo(() => {
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

      const selectedMonthsForYear = selectedDocketMonthsByYear[String(caseDetail.docket_year)] ?? [];
      if (!caseDetail.docket_month_code || !selectedMonthsForYear.includes(caseDetail.docket_month_code.trim().toUpperCase())) {
        return false;
      }

      const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
      const classification = caseDetail.id ? classificationsByCase[caseDetail.id] : undefined;

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
    selectedDocketTypes,
    selectedDocketYears,
    selectedDocketMonthsByYear,
    selectedSearchColumns,
  ]);

  const columnFilterOptions = useMemo(() => (
    CASE_TABLE_COLUMNS.reduce((options, column) => {
      const facetedAvailableCases = !showColumnFilters
        ? casesMatchingPrimaryFilters
        : casesMatchingPrimaryFilters.filter((caseDetail) => {
          const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
          const classification = caseDetail.id ? classificationsByCase[caseDetail.id] : undefined;

          return visibleCaseTableColumns.every((otherColumn) => {
            if (otherColumn.key === column.key || !columnFilterTouchedRef.current[otherColumn.key]) {
              return true;
            }

            const selectedValues = selectedColumnFilters[otherColumn.key];
            return selectedValues.includes(
              getCaseColumnFilterValue(caseDetail, otherColumn.key, casePartyNames, classification),
            );
          });
        });
      const isEmptySelection = columnFilterTouchedRef.current[column.key] && selectedColumnFilters[column.key].length === 0;
      const availableCases = facetedAvailableCases.length === 0 && isEmptySelection
        ? casesMatchingPrimaryFilters
        : facetedAvailableCases;

      options[column.key] = uniqueSortedOptions(
        availableCases.map((caseDetail) => {
          const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
          const classification = caseDetail.id ? classificationsByCase[caseDetail.id] : undefined;
          return getCaseColumnFilterValue(caseDetail, column.key, casePartyNames, classification);
        }),
      );
      return options;
    }, {} as ColumnFilters)
  ), [
    casesMatchingPrimaryFilters,
    classificationsByCase,
    partyNamesByCase,
    selectedColumnFilters,
    showColumnFilters,
    visibleCaseTableColumns,
  ]);

  const filteredCases = useMemo(() => {
    if (!showColumnFilters) {
      return casesMatchingPrimaryFilters;
    }

    return casesMatchingPrimaryFilters.filter((caseDetail) => {
      const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;
      const classification = caseDetail.id ? classificationsByCase[caseDetail.id] : undefined;

      return visibleCaseTableColumns.every((column) => {
        if (!columnFilterTouchedRef.current[column.key]) {
          return true;
        }

        return selectedColumnFilters[column.key].includes(
          getCaseColumnFilterValue(caseDetail, column.key, casePartyNames, classification),
        );
      });
    });
  }, [
    casesMatchingPrimaryFilters,
    classificationsByCase,
    partyNamesByCase,
    selectedColumnFilters,
    showColumnFilters,
    visibleCaseTableColumns,
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

  const docketMonthFiltersByYear = useMemo(() => {
    const monthsByYear = cases.reduce<DocketMonthsByYear>((result, caseDetail) => {
      const year = String(caseDetail.docket_year);
      const month = caseDetail.docket_month_code?.trim().toUpperCase();
      if (!Number.isFinite(caseDetail.docket_year) || !month) return result;
      result[year] = result[year] ?? [];
      if (!result[year].includes(month)) result[year].push(month);
      return result;
    }, {});

    for (const months of Object.values(monthsByYear)) months.sort((left, right) => left.localeCompare(right));
    return monthsByYear;
  }, [cases]);

  const activeColumnFilterCount = useMemo(() => (
    visibleCaseTableColumns.filter((column) => {
      const selectedValues = selectedColumnFilters[column.key];
      const availableValues = columnFilterOptions[column.key];
      return columnFilterTouchedRef.current[column.key] && !allOptionsSelected(selectedValues, availableValues);
    }).length
  ), [columnFilterOptions, selectedColumnFilters, visibleCaseTableColumns]);

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
    if (!docketFiltersTouchedRef.current) setSelectedDocketMonthsByYear(docketMonthFiltersByYear);
  }, [docketMonthFiltersByYear]);

  useEffect(() => {
    setSelectedColumnFilters((currentFilters) => {
      let nextFilters = currentFilters;

      for (const column of CASE_TABLE_COLUMNS) {
        const nextColumnOptions = columnFilterOptions[column.key];

        if (columnFilterTouchedRef.current[column.key]) {
          continue;
        }

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

    if (allOptionsSelected(selectedSearchColumns, availableSearchColumns)) {
      return 'All columns';
    }

    if (selectedSearchColumns.length === 1) {
      return searchColumnLabel(selectedSearchColumns[0]);
    }

    return `${selectedSearchColumns.length} columns`;
  }, [availableSearchColumns, selectedSearchColumns]);

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

    const hasEveryMonth = docketYearFilters.every((year) => allOptionsSelected(
      selectedDocketMonthsByYear[year] ?? [],
      docketMonthFiltersByYear[year] ?? [],
    ));
    if (allOptionsSelected(selectedDocketYears, docketYearFilters) && hasEveryMonth) {
      return 'All years';
    }

    if (selectedDocketYears.length === 1) {
      return selectedDocketYears[0];
    }

    return `${selectedDocketYears.length} years/months`;
  }, [docketMonthFiltersByYear, docketYearFilters, selectedDocketMonthsByYear, selectedDocketYears]);

  const allDocketTypesSelected = allOptionsSelected(selectedDocketTypes, docketTypeFilters);
  const allDocketYearsSelected = allOptionsSelected(selectedDocketYears, docketYearFilters) && docketYearFilters.every((year) =>
    allOptionsSelected(selectedDocketMonthsByYear[year] ?? [], docketMonthFiltersByYear[year] ?? []),
  );
  const docketTypeMobileSummary = selectedDocketTypes.length === 0
    ? 'None'
    : allDocketTypesSelected
      ? DEFAULT_DOCKET_TYPE
      : selectedDocketTypes.join(', ');
  const docketYearMobileSummary = selectedDocketYears.length === 0
    ? 'None'
    : allDocketYearsSelected
      ? 'All years'
      : selectedDocketYears.join(', ');
  const hideDocketTypeMobileLabel = !allDocketTypesSelected && selectedDocketTypes.length > 2;
  const hideDocketYearMobileLabel = !allDocketYearsSelected && selectedDocketYears.length > 2;
  const docketTypeMobileTextSize = docketTypeMobileSummary.length > 24
    ? 'text-[9px]'
    : docketTypeMobileSummary.length > 14
      ? 'text-[10px]'
      : 'text-xs';
  const docketYearMobileTextSize = docketYearMobileSummary.length > 24
    ? 'text-[9px]'
    : docketYearMobileSummary.length > 14
      ? 'text-[10px]'
      : 'text-xs';

  const tableWidth = useMemo(
    () => visibleCaseTableColumns.reduce((total, column) => total + columnWidths[column.key], 0) + (canViewLinkedDockets ? 180 : 0),
    [canViewLinkedDockets, columnWidths, visibleCaseTableColumns],
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
      allOptionsSelected(currentColumns, availableSearchColumns) ? [] : [...availableSearchColumns],
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
    const isSelected = allOptionsSelected(
      selectedDocketMonthsByYear[docketYear] ?? [],
      docketMonthFiltersByYear[docketYear] ?? [],
    );
    setSelectedDocketYears((currentYears) => {
      if (isSelected) {
        return currentYears.filter((currentYear) => currentYear !== docketYear);
      }

      return [...currentYears, docketYear];
    });
    setSelectedDocketMonthsByYear((current) => ({
      ...current,
      [docketYear]: isSelected ? [] : [...(docketMonthFiltersByYear[docketYear] ?? [])],
    }));
  }

  function toggleAllDocketYears() {
    docketFiltersTouchedRef.current = true;
    const hasEveryMonth = docketYearFilters.every((year) => allOptionsSelected(
      selectedDocketMonthsByYear[year] ?? [],
      docketMonthFiltersByYear[year] ?? [],
    ));
    const selectAll = !(allOptionsSelected(selectedDocketYears, docketYearFilters) && hasEveryMonth);
    setSelectedDocketYears(selectAll ? [...docketYearFilters] : []);
    setSelectedDocketMonthsByYear(selectAll ? docketMonthFiltersByYear : {});
  }

  function toggleDocketMonth(docketYear: DocketYearFilter, docketMonth: string) {
    docketFiltersTouchedRef.current = true;
    const currentMonths = selectedDocketMonthsByYear[docketYear] ?? [];
    const nextMonths = currentMonths.includes(docketMonth)
      ? currentMonths.filter((currentMonth) => currentMonth !== docketMonth)
      : [...currentMonths, docketMonth];
    setSelectedDocketMonthsByYear((current) => ({ ...current, [docketYear]: nextMonths }));
    setSelectedDocketYears((currentYears) => nextMonths.length > 0
      ? Array.from(new Set([...currentYears, docketYear]))
      : currentYears.filter((currentYear) => currentYear !== docketYear));
  }

  function toggleAllDocketMonthsForYear(docketYear: DocketYearFilter) {
    toggleDocketYear(docketYear);
  }

  function toggleDocketYearExpanded(docketYear: DocketYearFilter) {
    setExpandedDocketYears((currentYears) => currentYears.includes(docketYear)
      ? currentYears.filter((currentYear) => currentYear !== docketYear)
      : [...currentYears, docketYear]);
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

  function openCaseDetails(caseId: number) {
    router.push(`/cases/${caseId}`);
  }

  function openCaseQuickView(caseId: number) {
    setQuickViewCaseId(caseId);
  }

  function renderColumnFilter(columnKey: CaseTableColumnKey) {
    if (!showColumnFilters) {
      return null;
    }

    const availableValues = columnFilterOptions[columnKey];
    const selectedValues = selectedColumnFilters[columnKey];
    const isActive = columnFilterTouchedRef.current[columnKey] && !allOptionsSelected(selectedValues, availableValues);

    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className={`h-7 max-w-full justify-start gap-1 px-0 text-xs font-normal normal-case ${isActive ? 'text-primary' : ''}`}
            aria-label={`${columnFilterLabel(columnKey)} filter${isActive ? ' (active)' : ''}`}
          >
            {isActive ? <Filter className="size-3 fill-current" aria-hidden="true" /> : null}
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

  function multilineViolation(value: string | null | undefined) {
    const violations = value
      ?.split(/\s*(?:\||\r?\n)\s*/u)
      .map((violation) => violation.trim())
      .filter(Boolean);

    return violations && violations.length > 0 ? violations.join('\n') : '—';
  }

  function buildActiveColumnFilters() {
    if (!showColumnFilters) {
      return [];
    }

    return visibleCaseTableColumns.flatMap((column) => {
      const selectedValues = selectedColumnFilters[column.key];
      const availableValues = columnFilterOptions[column.key];
      const isActive =
        selectedValues.length !== availableValues.length ||
        selectedValues.some((value) => !availableValues.includes(value));

      return isActive
        ? [{ column: column.label, values: selectedValues }]
        : [];
    });
  }

  async function getAuthenticatedEmail() {
    try {
      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getUser();
      return data.user?.email ?? 'Authenticated user';
    } catch {
      return 'Authenticated user';
    }
  }

  function openPdfBlob(blob: Blob, previewWindow: Window | null, filename: string) {
    const pdfUrl = URL.createObjectURL(blob);

    if (previewWindow) {
      previewWindow.location.href = pdfUrl;
      setTimeout(() => URL.revokeObjectURL(pdfUrl), 60_000);
      return;
    }

    const downloadLink = document.createElement('a');
    downloadLink.href = pdfUrl;
    downloadLink.download = filename;
    document.body.appendChild(downloadLink);
    downloadLink.click();
    downloadLink.remove();
    setTimeout(() => URL.revokeObjectURL(pdfUrl), 1_000);
  }

  async function handlePrintPdf() {
    const previewWindow = window.open('', '_blank');
    const today = new Date().toISOString().slice(0, 10);
    const filename = `case-list-${today}.pdf`;

    setIsGeneratingPdf(true);
    setPdfError(null);

    try {
      const reportRows: CasesReportRow[] = sortedCases.map((caseDetail) => {
        const casePartyNames = caseDetail.id ? partyNamesByCase[caseDetail.id] : undefined;

        return {
          docketNumber: formatDisplayDocketNumber(caseDetail),
          complainant: expandedPartyNames(casePartyNames?.complainants ?? []),
          respondent: expandedPartyNames(casePartyNames?.respondents ?? []),
          violation: multilineViolation(caseViolations(caseDetail)),
          assignedProsecutor: assignedProsecutor(caseDetail) ?? '—',
          currentStatus: currentStatusLabel(caseDetail) ?? '—',
          dateApproved: formatDate(caseDetail.date_approved),
          dateReceived: formatDate(caseDetail.date_received),
        };
      });
      const reportFilters: CasesReportFilters = {
        searchTerm: searchTerm.trim(),
        searchColumns: selectedSearchColumns.map(searchColumnLabel),
        docketTypes: selectedDocketTypes,
        docketYears: selectedDocketYears,
        docketMonths: selectedDocketYears.map((year) =>
          `${year} - ${(selectedDocketMonthsByYear[year] ?? []).map(docketMonthShortName).join(', ')}`,
        ),
        activeColumnFilters: buildActiveColumnFilters(),
        sortOrder: 'Docket Number ascending',
      };
      const [{ generateCasesReportPdf }, generatedBy] = await Promise.all([
        import('@/lib/pdf/cases-report'),
        getAuthenticatedEmail(),
      ]);
      const pdfBlob = await generateCasesReportPdf({
        rows: reportRows,
        filters: reportFilters,
        generatedBy,
      });

      openPdfBlob(pdfBlob, previewWindow, filename);
    } catch (error) {
      previewWindow?.close();
      setPdfError(error instanceof Error ? error.message : 'The PDF could not be generated.');
    } finally {
      setIsGeneratingPdf(false);
    }
  }

  return (
    <div className="flex h-[100dvh] overflow-hidden bg-background">
      <Sidebar collapseSignal={quickViewCaseId} />
      <PanelGroup direction="horizontal" autoSaveId="case-list-quick-view-layout" className="min-w-0 flex-1">
        <Panel id="cases-list" order={1} minSize={30} defaultSize={quickViewCaseId ? 70 : 100} className="min-w-0">
      <main className="flex h-full min-w-0 flex-1 flex-col overflow-hidden p-4 pt-3 md:p-8">
        <div className={`${quickViewCaseId ? 'max-w-none' : 'max-w-[1400px]'} mx-auto flex min-h-0 w-full flex-1 flex-col gap-6`}>
          <div className="shrink-0 pl-12 md:pl-0">
            <div className="flex items-center justify-between gap-3 sm:items-start">
              <div>
                <h1 className="text-2xl font-bold text-foreground sm:text-3xl">Cases</h1>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                {canShowExcelExport ? (
                  <ExportCasesDialog
                    caseIds={sortedCases.map((caseDetail) => caseDetail.id)}
                    yearLabel={selectedDocketYears.length === 1 ? selectedDocketYears[0] : 'ALL_YEARS'}
                    docketTypeLabel={selectedDocketTypes.length === 1 ? selectedDocketTypes[0] : 'ALL_TYPES'}
                    docketTypeId={null}
                    disabled={isLoading || isLoadingAllCases || sortedCases.length === 0}
                  />
                ) : null}
                <Button
                  type="button"
                  variant="outline"
                  className="size-9 px-0 sm:h-9 sm:w-auto sm:px-3"
                  onClick={handlePrintPdf}
                  disabled={isLoading || isLoadingAllCases || isGeneratingPdf || sortedCases.length === 0}
                  aria-label={isGeneratingPdf ? 'Generating PDF' : 'Print PDF'}
                >
                  <Printer className="size-4" />
                  <span className="hidden sm:inline">{isGeneratingPdf ? 'Generating PDF…' : 'Print PDF'}</span>
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  className="size-9 px-0 sm:h-9 sm:w-auto sm:px-3"
                  onClick={refreshCases}
                  disabled={isLoading || isLoadingAllCases || isRefreshing || isGeneratingPdf}
                  aria-label="Refresh cases"
                >
                  <RefreshCw className={`size-4 ${(isLoading || isLoadingAllCases || isRefreshing) ? 'animate-spin' : ''}`} />
                  <span className="hidden sm:inline">Refresh</span>
                </Button>
              </div>
            </div>
          </div>

          {errorMessage ? (
            <Alert variant="destructive" className="shrink-0">
              <AlertTitle>Unable to fully load cases</AlertTitle>
              <AlertDescription>{errorMessage}</AlertDescription>
            </Alert>
          ) : null}

          {pdfError ? (
            <Alert variant="destructive" className="shrink-0">
              <AlertTitle>Unable to generate PDF</AlertTitle>
              <AlertDescription>{pdfError}</AlertDescription>
            </Alert>
          ) : null}

          <Card aria-busy={isLoading || isLoadingAllCases || isRefreshing} className="min-h-0 flex-1 gap-4 overflow-hidden py-4">
            <CardHeader className="shrink-0 px-4 md:px-6">
              <div className="grid grid-cols-2 gap-3 sm:max-w-xl sm:gap-4">
                <div className="col-span-2 flex flex-col gap-2">
                  <label className="sr-only" htmlFor="case-search">
                    Search Cases
                  </label>
                  <div className="flex gap-2">
                    <div className="relative flex-1">
                      <Input
                        id="case-search"
                        className="pr-44 sm:pr-10"
                        placeholder="Search"
                        value={searchTerm}
                        onChange={(event) => setSearchTerm(event.target.value)}
                      />
                      {searchTerm ? (
                        <button
                          type="button"
                          className="absolute right-36 top-1/2 flex size-6 -translate-y-1/2 items-center justify-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring sm:right-2"
                          aria-label="Clear case search"
                          onClick={clearSearch}
                        >
                          <X className="size-4" />
                        </button>
                      ) : null}
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button type="button" variant="ghost" className="absolute right-1 top-1/2 h-8 w-32 -translate-y-1/2 justify-between px-2 text-muted-foreground sm:hidden">
                            <span className="truncate">{searchColumnSummary}</span>
                            <ChevronDown className="size-4 opacity-70" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-56">
                          <DropdownMenuLabel>Search columns</DropdownMenuLabel>
                          <DropdownMenuCheckboxItem
                            checked={allOptionsSelected(selectedSearchColumns, availableSearchColumns)}
                            onCheckedChange={toggleSearchAllColumns}
                            onSelect={(event) => event.preventDefault()}
                          >
                            Search all columns
                          </DropdownMenuCheckboxItem>
                          {availableSearchColumnOptions.map((column) => (
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
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button type="button" variant="outline" className="hidden justify-between sm:flex sm:w-56">
                          {searchColumnSummary}
                          <ChevronDown className="size-4 opacity-70" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" className="w-56">
                        <DropdownMenuLabel>Search columns</DropdownMenuLabel>
                        <DropdownMenuCheckboxItem
                          checked={allOptionsSelected(selectedSearchColumns, availableSearchColumns)}
                          onCheckedChange={toggleSearchAllColumns}
                          onSelect={(event) => event.preventDefault()}
                        >
                          Search all columns
                        </DropdownMenuCheckboxItem>
                        {availableSearchColumnOptions.map((column) => (
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
                  <label className="sr-only text-sm font-medium text-foreground sm:not-sr-only" htmlFor="docket-type-filter">
                    Docket Type
                  </label>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button id="docket-type-filter" type="button" variant="outline" className="h-auto min-h-9 w-full min-w-0 justify-between px-2 py-1 sm:h-9 sm:px-4 sm:py-2">
                        {!hideDocketTypeMobileLabel ? <span className="text-xs sm:hidden">Docket Type</span> : null}
                        <span className="hidden sm:inline">{docketTypeSummary}</span>
                        <span className={`flex min-w-0 items-center gap-1 ${hideDocketTypeMobileLabel ? 'flex-1 justify-between' : ''}`}>
                          <span className={`min-w-0 whitespace-normal text-left leading-tight text-muted-foreground italic sm:hidden ${docketTypeMobileTextSize}`}>
                            {docketTypeMobileSummary}
                          </span>
                          <ChevronDown className="size-4 opacity-70" />
                        </span>
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
                  <label className="sr-only text-sm font-medium text-foreground sm:not-sr-only" htmlFor="docket-year-filter">
                    Docket Year
                  </label>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button id="docket-year-filter" type="button" variant="outline" className="h-auto min-h-9 w-full min-w-0 justify-between px-2 py-1 sm:h-9 sm:px-4 sm:py-2">
                        {!hideDocketYearMobileLabel ? <span className="text-xs sm:hidden">Docket Year</span> : null}
                        <span className="hidden sm:inline">{docketYearSummary}</span>
                        <span className={`flex min-w-0 items-center gap-1 ${hideDocketYearMobileLabel ? 'flex-1 justify-between' : ''}`}>
                          <span className={`min-w-0 whitespace-normal text-left leading-tight text-muted-foreground italic sm:hidden ${docketYearMobileTextSize}`}>
                            {docketYearMobileSummary}
                          </span>
                          <ChevronDown className="size-4 opacity-70" />
                        </span>
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent
                      align="start"
                      className="flex w-56 flex-col overflow-hidden"
                      style={{ maxHeight: 'min(20rem, var(--radix-dropdown-menu-content-available-height))' }}
                    >
                      <DropdownMenuCheckboxItem
                        checked={allOptionsSelected(selectedDocketYears, docketYearFilters) && docketYearFilters.every((year) =>
                          allOptionsSelected(selectedDocketMonthsByYear[year] ?? [], docketMonthFiltersByYear[year] ?? []),
                        )}
                        onCheckedChange={toggleAllDocketYears}
                        onSelect={(event) => event.preventDefault()}
                      >
                        All years
                      </DropdownMenuCheckboxItem>
                      <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain pr-1">
                        {docketYearFilters.map((docketYear) => (
                          <div key={docketYear}>
                            <div className="flex items-center">
                              <button
                                type="button"
                                className="ml-1 flex size-7 shrink-0 items-center justify-center rounded-sm text-muted-foreground hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                                aria-label={`${expandedDocketYears.includes(docketYear) ? 'Collapse' : 'Expand'} ${docketYear} months`}
                                aria-expanded={expandedDocketYears.includes(docketYear)}
                                onClick={(event) => {
                                  event.preventDefault();
                                  event.stopPropagation();
                                  toggleDocketYearExpanded(docketYear);
                                }}
                              >
                                {expandedDocketYears.includes(docketYear)
                                  ? <ChevronDown className="size-4" />
                                  : <ChevronRight className="size-4" />}
                              </button>
                              <DropdownMenuCheckboxItem
                                checked={allOptionsSelected(
                                  selectedDocketMonthsByYear[docketYear] ?? [],
                                  docketMonthFiltersByYear[docketYear] ?? [],
                                )}
                                onCheckedChange={() => toggleDocketYear(docketYear)}
                                onSelect={(event) => event.preventDefault()}
                                className="min-w-0 flex-1 pl-8 font-medium"
                              >
                                {docketYear}
                              </DropdownMenuCheckboxItem>
                            </div>
                            {expandedDocketYears.includes(docketYear) ? (
                              <div className="ml-4 border-l border-border/70 pl-4">
                                <DropdownMenuCheckboxItem
                                  checked={allOptionsSelected(
                                    selectedDocketMonthsByYear[docketYear] ?? [],
                                    docketMonthFiltersByYear[docketYear] ?? [],
                                  )}
                                  onCheckedChange={() => toggleAllDocketMonthsForYear(docketYear)}
                                  onSelect={(event) => event.preventDefault()}
                                  className="pl-8 italic"
                                >
                                  Select all months
                                </DropdownMenuCheckboxItem>
                                {(docketMonthFiltersByYear[docketYear] ?? []).map((docketMonth) => (
                                  <DropdownMenuCheckboxItem
                                    key={`${docketYear}-${docketMonth}`}
                                    checked={(selectedDocketMonthsByYear[docketYear] ?? []).includes(docketMonth)}
                                    onCheckedChange={() => toggleDocketMonth(docketYear, docketMonth)}
                                    onSelect={(event) => event.preventDefault()}
                                    className="pl-8"
                                  >
                                    {docketMonthName(docketMonth)}
                                  </DropdownMenuCheckboxItem>
                                ))}
                              </div>
                            ) : null}
                          </div>
                        ))}
                      </div>
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
                  className="min-h-0 flex-1 overflow-x-auto overflow-y-auto rounded-lg border border-border"
                  aria-label="Cases table with native horizontal and vertical scrollbars"
                  onScroll={(event) => setScrollTop(event.currentTarget.scrollTop)}
                >
                  <table className="w-full caption-bottom table-fixed text-sm" style={{ width: tableWidth, minWidth: '100%' }}>
                    <colgroup>
                      {canViewLinkedDockets ? <col style={{ width: 180 }} /> : null}
                      {visibleCaseTableColumns.map((column) => (
                        <col key={column.key} style={{ width: columnWidths[column.key] }} />
                      ))}
                    </colgroup>
                    <TableHeader className="sticky top-0 z-20 bg-muted shadow-sm">
                      <TableRow className="bg-muted hover:bg-muted">
                        {canViewLinkedDockets ? <TableHead className="whitespace-nowrap uppercase">Linked Docket</TableHead> : null}
                        {visibleCaseTableColumns.map((column) => (
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
                          <TableCell colSpan={renderedColumnCount} style={{ height: virtualRows.topPadding, padding: 0 }} />
                        </TableRow>
                      ) : null}

                      {sortedCases.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={renderedColumnCount} className="py-8 text-center text-sm text-muted-foreground">
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
                          <ContextMenu key={caseKey}>
                            <ContextMenuTrigger asChild>
                              <TableRow
                                aria-selected={isSelected}
                                className={`cursor-pointer ${isSelected ? 'bg-primary/10 hover:bg-primary/15' : 'h-12 hover:bg-muted/50'}`}
                                tabIndex={caseDetail.id ? 0 : -1}
                                onClick={() => setSelectedCaseKey(caseKey)}
                                onDoubleClick={() => {
                                  if (caseDetail.id) {
                                    openCaseDetails(caseDetail.id);
                                  }
                                }}
                            onKeyDown={(event) => {
                              if (!caseDetail.id) {
                                return;
                              }

                              if (event.key === 'Enter') {
                                event.preventDefault();
                                openCaseDetails(caseDetail.id);
                              }

                              if (event.key === ' ') {
                                event.preventDefault();
                                setSelectedCaseKey(caseKey);
                              }
                            }}
                          >
                            {canViewLinkedDockets ? <TableCell className="truncate text-sm">{caseDetail.id ? linkedDocketsByCase[caseDetail.id] ?? '—' : '—'}</TableCell> : null}
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
                              <StatusBadge status={currentStatusLabel(caseDetail) ?? '—'} size="sm" />
                            </TableCell>
                            <TableCell>
                              <StageBadge stage={currentStageLabel(caseDetail) ?? '—'} size="sm" />
                            </TableCell>
                            {canViewCriminalCaseNo ? <TableCell className="truncate text-sm">{caseDetail.criminal_case_numbers ?? '—'}</TableCell> : null}
                            <TableCell className="truncate text-sm">{formatDate(caseDetail.date_approved)}</TableCell>
                            <TableCell className="truncate text-sm">{formatDate(caseDetail.date_received)}</TableCell>
                            {canViewAging ? <TableCell className="truncate text-sm">{formatCaseAging(caseDetail)}</TableCell> : null}
                              </TableRow>
                            </ContextMenuTrigger>
                            <ContextMenuContent className="w-44">
                              <ContextMenuItem disabled={!caseDetail.id} onSelect={() => { if (caseDetail.id) openCaseDetails(caseDetail.id); }}>
                                <ExternalLink className="size-4" />
                                Open
                              </ContextMenuItem>
                              <ContextMenuItem disabled={!caseDetail.id} onSelect={() => { if (caseDetail.id) openCaseQuickView(caseDetail.id); }}>
                                <Eye className="size-4" />
                                Quickview
                              </ContextMenuItem>
                            </ContextMenuContent>
                          </ContextMenu>
                        );
                      })}

                      {virtualRows.bottomPadding > 0 ? (
                        <TableRow aria-hidden="true">
                          <TableCell colSpan={renderedColumnCount} style={{ height: virtualRows.bottomPadding, padding: 0 }} />
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
                  {showColumnFilters ? (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={clearColumnFilters}
                      disabled={activeColumnFilterCount === 0}
                    >
                      Clear all filters
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
        </Panel>
      {quickViewCaseId ? (
        <>
          <PanelResizeHandle className="relative flex w-2 cursor-col-resize items-center justify-center bg-border transition-colors hover:bg-primary/30 data-[resize-handle-active]:bg-primary/40" aria-label="Resize case quick view">
            <span className="absolute flex h-10 w-5 items-center justify-center rounded border bg-background shadow">
              <GripVertical className="size-4" />
            </span>
          </PanelResizeHandle>
          <Panel id="case-quick-view" order={2} defaultSize={30} minSize={20} maxSize={70} className="min-w-0 animate-in slide-in-from-right border-l bg-background shadow-2xl duration-300">
        <aside
          className="h-full"
          aria-label="Case details quick view"
        >
          <div className="flex h-12 items-center justify-between border-b px-4">
            <h2 className="truncate text-sm font-semibold">Case quick view</h2>
            <Button type="button" variant="ghost" size="icon" onClick={() => setQuickViewCaseId(null)} aria-label="Close quick view">
              <X className="size-4" />
            </Button>
          </div>
          <iframe
            key={quickViewCaseId}
            title="Case details quick view"
            src={`/cases/${quickViewCaseId}?quickview=1`}
            className="h-[calc(100%-3rem)] w-full border-0"
          />
        </aside>
          </Panel>
        </>
      ) : null}
      </PanelGroup>
    </div>
  );
}
