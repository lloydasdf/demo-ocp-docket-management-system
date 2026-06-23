'use client';

import { useEffect, useMemo, useState } from 'react';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { getCaseEventTypes, getCasesDisplay, type CaseEventTypeReference, type CasesDisplayRecord } from '@/lib/supabase/queries';
import type { CaseStatus } from '@/lib/types';
import Link from 'next/link';
import { CheckCircle, ExternalLink, Search as SearchIcon } from 'lucide-react';

type CompactCase = CasesDisplayRecord;

type CasesPageCache = {
  cases?: CompactCase[];
};

const CASES_PAGE_CACHE_KEY = 'ocp-cases-page-cache-v15';

function getFallbackCases(): CompactCase[] {
  return dockets.flatMap((docket) =>
    docket.cases.map((caseDetail) => ({
      prosecutor_full_name: caseDetail.prosecutor ?? null,
      prosecutor_short_name: caseDetail.prosecutor ?? null,
      id: Number.parseInt(caseDetail.id.replace(/\D/g, ''), 10) || 0,
      docket_type_id: 0,
      complainant:
        caseDetail.complainants.length > 0
          ? caseDetail.complainants.map((person) => `${person.firstName} ${person.lastName}`).join(' | ')
          : null,
      respondent:
        caseDetail.respondents.length > 0
          ? caseDetail.respondents.map((person) => `${person.firstName} ${person.lastName}`).join(' | ')
          : null,
      case_classification_label: null,
      summary_text:
        caseDetail.complainants.length > 0
          ? `Complainant: ${caseDetail.complainants[0].firstName} ${caseDetail.complainants[0].lastName}${
              caseDetail.complainants.length > 1 ? ' et al.' : ''
            }`
          : null,
      created_at: docket.createdDate,
      current_status_label: caseDetail.status,
      current_status_code: caseDetail.status,
      date_received: caseDetail.dateOfIncident,
      docket_month_code: null,
      docket_display_number: docket.docketNumber,
      docket_number: Number.parseInt(docket.docketNumber.match(/\d+$/)?.[0] ?? '', 10) || null,
      docket_type_prefix: docket.docketNumber.split('-')[0] ?? null,
      docket_type_name: docket.docketNumber.split('-')[0] ?? null,
      docket_year: Number.parseInt(docket.docketNumber.match(/\d{4}/)?.[0] ?? '', 10) || null,
      updated_at: null,
      violations:
        caseDetail.violations.length > 0
          ? caseDetail.violations.map((violation) => violation.statute).join(', ')
          : null,
    })) as CompactCase[],
  );
}

function readCasesPageCache(): CompactCase[] | null {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const cachedValue = window.sessionStorage.getItem(CASES_PAGE_CACHE_KEY);
    if (!cachedValue) {
      return null;
    }

    const cache = JSON.parse(cachedValue) as CasesPageCache;
    return Array.isArray(cache.cases) ? cache.cases : null;
  } catch {
    return null;
  }
}

function getDocketNumber(caseDetail: CompactCase) {
  return (
    caseDetail.docket_display_number ||
    `${caseDetail.docket_type_prefix ?? 'Case'}-${caseDetail.docket_year ?? '—'}-${String(
      caseDetail.docket_number ?? '',
    ).padStart(6, '0')}`
  );
}

function getCurrentStatus(caseDetail: CompactCase) {
  return caseDetail.current_status_label || caseDetail.current_status_code || '—';
}

function getProsecutor(caseDetail: CompactCase) {
  return caseDetail.prosecutor_full_name || caseDetail.prosecutor_short_name || 'Unassigned';
}

function getCaseSearchText(caseDetail: CompactCase) {
  return [
    getDocketNumber(caseDetail),
    caseDetail.summary_text,
    caseDetail.complainant,
    caseDetail.respondent,
    caseDetail.violations,
    caseDetail.case_classification_label,
    getProsecutor(caseDetail),
    getCurrentStatus(caseDetail),
    caseDetail.docket_type_name,
    caseDetail.docket_type_prefix,
    caseDetail.docket_year,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
}

interface StatusUpdateRecord {
  id: string;
  caseNumber: string;
  newStatus: CaseStatus;
  remarks: string;
  updateDate: string;
  updatedBy: string;
}

export default function StatusUpdate() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCaseNumber, setSelectedCaseNumber] = useState('');
  const [activityTypeCode, setActivityTypeCode] = useState('');
  const [notes, setNotes] = useState('');
  const [remarks, setRemarks] = useState('');
  const [alsoUpdateCurrentStatus, setAlsoUpdateCurrentStatus] = useState(false);
  const [statusUpdates, setStatusUpdates] = useState<StatusUpdateRecord[]>([]);
  const [successMessage, setSuccessMessage] = useState('');
  const fallbackCases = useMemo(getFallbackCases, []);
  const [allCases, setAllCases] = useState<CompactCase[]>(fallbackCases);
  const [isLoadingCases, setIsLoadingCases] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);
  const [activityTypes, setActivityTypes] = useState<CaseEventTypeReference[]>([]);
  const [activityTypeError, setActivityTypeError] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    const cachedCases = readCasesPageCache();

    if (cachedCases?.length) {
      setAllCases(cachedCases);
      setIsUsingFallback(false);
      setIsLoadingCases(false);
    }

    async function loadCases() {
      if (!cachedCases?.length) {
        setIsLoadingCases(true);
      }

      const casesResult = await getCasesDisplay();

      if (!isMounted) {
        return;
      }

      if (casesResult.error) {
        setLoadError(casesResult.error.message);
        if (!cachedCases?.length) {
          setAllCases(fallbackCases);
          setIsUsingFallback(true);
        }
      } else {
        setLoadError(null);
        setAllCases(casesResult.data);
        setIsUsingFallback(false);
      }

      setIsLoadingCases(false);
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, [fallbackCases]);

  useEffect(() => {
    let isMounted = true;

    async function loadActivityTypes() {
      const result = await getCaseEventTypes();

      if (!isMounted) {
        return;
      }

      if (result.error) {
        setActivityTypeError(result.error.message);
        setActivityTypes([]);
      } else {
        setActivityTypeError(null);
        setActivityTypes(result.data);
        setActivityTypeCode((currentCode) => currentCode || result.data[0]?.code || '');
      }
    }

    loadActivityTypes();

    return () => {
      isMounted = false;
    };
  }, []);

  const filteredCases = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();

    if (!normalizedQuery) {
      return allCases;
    }

    return allCases.filter((caseDetail) => getCaseSearchText(caseDetail).includes(normalizedQuery));
  }, [allCases, searchQuery]);

  const selectedCase = allCases.find((caseDetail) => String(caseDetail.id) === selectedCaseNumber);
  const selectedActivityType = activityTypes.find((type) => type.code === activityTypeCode);

  const handleStatusUpdate = () => {
    if (!selectedCaseNumber || !activityTypeCode || !remarks.trim()) {
      return;
    }

    const update: StatusUpdateRecord = {
      id: `update-${Date.now()}`,
      caseNumber: selectedCase ? getDocketNumber(selectedCase) : selectedCaseNumber,
      newStatus: (selectedActivityType?.display_label as CaseStatus | undefined) ?? 'Pending',
      remarks: [notes.trim(), remarks.trim()].filter(Boolean).join('\n\n'),
      updateDate: new Date().toISOString().split('T')[0],
      updatedBy: alsoUpdateCurrentStatus ? 'Admin User · current status updated' : 'Admin User',
    };

    setStatusUpdates([update, ...statusUpdates]);
    setSelectedCaseNumber('');
    setNotes('');
    setRemarks('');
    setAlsoUpdateCurrentStatus(false);
    setSuccessMessage('Activity recorded successfully!');
    setTimeout(() => setSuccessMessage(''), 3000);
  };

  return (
    <div className="p-8 space-y-6">
      {successMessage && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded flex items-center gap-2">
          <CheckCircle className="w-5 h-5" />
          {successMessage}
        </div>
      )}

      {loadError ? (
        <Alert variant="destructive">
          <AlertTitle>Unable to refresh live cases</AlertTitle>
          <AlertDescription>
            {loadError}{' '}
            {isUsingFallback ? 'Showing fallback docket data.' : 'Showing the cases already loaded from the Cases page.'}
          </AlertDescription>
        </Alert>
      ) : null}

      {activityTypeError ? (
        <Alert variant="destructive">
          <AlertTitle>Unable to load activity types</AlertTitle>
          <AlertDescription>{activityTypeError}</AlertDescription>
        </Alert>
      ) : null}

      <Card>
        <CardHeader>
          <CardTitle>Select Case</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="relative">
            <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              id="case-search"
              placeholder="Search by docket number, party, violation, prosecutor, or status..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />

            {searchQuery.trim() && (
              <div className="absolute z-10 mt-1 max-h-72 w-full overflow-y-auto rounded-md border border-border bg-background shadow-lg">
                {isLoadingCases ? (
                  <p className="px-4 py-3 text-sm text-muted-foreground">Loading cases...</p>
                ) : filteredCases.length > 0 ? (
                  filteredCases.slice(0, 25).map((caseDetail) => {
                    const docketNumber = getDocketNumber(caseDetail);
                    const caseId = String(caseDetail.id ?? docketNumber);

                    return (
                      <button
                        key={`${caseId}-${docketNumber}`}
                        type="button"
                        onClick={() => {
                          setSelectedCaseNumber(caseId);
                          setSearchQuery('');
                        }}
                        className="w-full border-b border-border px-4 py-3 text-left last:border-b-0 hover:bg-muted"
                      >
                        <p className="font-medium">{docketNumber}</p>
                        <p className="text-xs text-muted-foreground">
                          {caseDetail.summary_text ||
                            caseDetail.complainant ||
                            caseDetail.respondent ||
                            caseDetail.violations ||
                            'No summary available'}
                        </p>
                      </button>
                    );
                  })
                ) : (
                  <p className="px-4 py-3 text-sm text-muted-foreground">No loaded cases match this search.</p>
                )}
              </div>
            )}
          </div>

          {selectedCase && (
            <div className="rounded-lg bg-muted p-4">
              <h4 className="font-semibold mb-2">Selected Case</h4>
              <p className="font-medium">{getDocketNumber(selectedCase)}</p>
              <p className="text-sm">Current Status: {getCurrentStatus(selectedCase)}</p>
              <p className="text-sm">Assigned Prosecutor: {getProsecutor(selectedCase)}</p>
              <Button asChild variant="secondary" size="sm" className="mt-3">
                <Link href={`/cases/${selectedCase.id}`}>
                  <ExternalLink className="mr-2 h-4 w-4" />
                  Open Full Case Details
                </Link>
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Activity Type</CardTitle>
          <CardDescription>Event-specific fields appear below.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Select value={activityTypeCode} onValueChange={setActivityTypeCode}>
            <SelectTrigger className="w-full sm:w-[220px]">
              <SelectValue placeholder="Select activity type" />
            </SelectTrigger>
            <SelectContent>
              {activityTypes.map((type) => (
                <SelectItem key={type.id} value={type.code}>
                  {type.display_label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Textarea
            id="activity-notes"
            aria-label="Activity notes"
            placeholder="Activity notes..."
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
          />

          <Textarea
            id="activity-remarks"
            aria-label="Remarks"
            placeholder="Remarks..."
            value={remarks}
            onChange={(e) => setRemarks(e.target.value)}
            rows={4}
          />

          <div className="rounded-lg border border-border p-4">
            <div className="flex items-center space-x-2">
              <Checkbox
                id="also-update-current-status"
                checked={alsoUpdateCurrentStatus}
                onCheckedChange={(checked) => setAlsoUpdateCurrentStatus(checked === true)}
              />
              <Label htmlFor="also-update-current-status" className="font-normal">
                Also update the current status
              </Label>
            </div>
          </div>

          <Button
            onClick={handleStatusUpdate}
            disabled={!selectedCaseNumber || !activityTypeCode || !remarks.trim()}
            className="w-full"
          >
            Record Activity
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Status Update History</CardTitle>
          <CardDescription>
            {statusUpdates.length === 0
              ? 'No updates yet'
              : `${statusUpdates.length} update${statusUpdates.length === 1 ? '' : 's'}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {statusUpdates.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No status updates yet</p>
            </div>
          ) : (
            <div className="space-y-4">
              {statusUpdates.map((update) => (
                <div key={update.id} className="p-4 border border-border rounded-lg">
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <p className="font-semibold">{update.caseNumber}</p>
                      <p className="text-sm text-muted-foreground">
                        {new Date(update.updateDate).toLocaleDateString()}
                      </p>
                    </div>
                    <StatusBadge status={update.newStatus} size="sm" />
                  </div>
                  <p className="text-sm mb-2 whitespace-pre-line">{update.remarks}</p>
                  <p className="text-xs text-muted-foreground">By: {update.updatedBy}</p>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
