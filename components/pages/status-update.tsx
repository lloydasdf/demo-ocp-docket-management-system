'use client';

import { useEffect, useMemo, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { getCasesDisplay, type CasesDisplayRecord } from '@/lib/supabase/queries';
import type { CaseStatus } from '@/lib/types';
import { Search as SearchIcon, CheckCircle } from 'lucide-react';

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
  const [newStatus, setNewStatus] = useState<CaseStatus>('Pending');
  const [remarks, setRemarks] = useState('');
  const [updatedBy, setUpdatedBy] = useState('Admin User');
  const [statusUpdates, setStatusUpdates] = useState<StatusUpdateRecord[]>([]);
  const [successMessage, setSuccessMessage] = useState('');
  const fallbackCases = useMemo(getFallbackCases, []);
  const [allCases, setAllCases] = useState<CompactCase[]>(fallbackCases);
  const [isLoadingCases, setIsLoadingCases] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);

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

  const filteredCases = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();

    if (!normalizedQuery) {
      return allCases;
    }

    return allCases.filter((caseDetail) => getCaseSearchText(caseDetail).includes(normalizedQuery));
  }, [allCases, searchQuery]);

  const selectedCase = allCases.find((caseDetail) => String(caseDetail.id) === selectedCaseNumber);

  const handleStatusUpdate = () => {
    if (!selectedCaseNumber || !newStatus || !remarks.trim()) {
      return;
    }

    const update: StatusUpdateRecord = {
      id: `update-${Date.now()}`,
      caseNumber: selectedCase ? getDocketNumber(selectedCase) : selectedCaseNumber,
      newStatus,
      remarks,
      updateDate: new Date().toISOString().split('T')[0],
      updatedBy,
    };

    setStatusUpdates([update, ...statusUpdates]);
    setSelectedCaseNumber('');
    setNewStatus('Pending');
    setRemarks('');
    setSuccessMessage('Status updated successfully!');
    setTimeout(() => setSuccessMessage(''), 3000);
  };

  const statuses: CaseStatus[] = ['Pending', 'Filed', 'Dismissed', 'Resolved', 'RFI'];

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Status Update</h1>
        <p className="text-muted-foreground mt-1">Update case status and add remarks</p>
      </div>

      {/* Success Message */}
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

      {/* Status Update Form */}
      <Card>
        <CardHeader>
          <CardTitle>Update Case Status</CardTitle>
          <CardDescription>Change case status and add remarks</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Case Selection */}
          <div className="relative">
            <Label htmlFor="case-search">Select Case</Label>
            <p className="text-sm text-muted-foreground">
              Searches all cases loaded on the Cases page, then refreshes from live case data.
            </p>
            <div className="relative mt-1">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                id="case-search"
                placeholder="Search loaded cases by docket, party, violation, prosecutor, or status..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>

            {/* Search Results Dropdown */}
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

          {/* Selected Case Info */}
          {selectedCase && (
            <div className="p-4 bg-muted rounded-lg">
              <h4 className="font-semibold mb-2">Selected Case</h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-muted-foreground">Case Number:</span>
                  <p className="font-medium">{getDocketNumber(selectedCase)}</p>
                </div>
                <div>
                  <span className="text-muted-foreground">Current Status:</span>
                  <div className="mt-1">
                    <StatusBadge status={getCurrentStatus(selectedCase)} size="sm" />
                  </div>
                </div>
                <div>
                  <span className="text-muted-foreground">Prosecutor:</span>
                  <p className="font-medium">{getProsecutor(selectedCase)}</p>
                </div>
              </div>
            </div>
          )}

          {/* Status and Remarks */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="new-status">New Status *</Label>
              <Select value={newStatus} onValueChange={(value) => setNewStatus(value as CaseStatus)}>
                <SelectTrigger id="new-status" className="mt-1">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {statuses.map((status) => (
                    <SelectItem key={status} value={status}>
                      {status}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div>
              <Label htmlFor="updated-by">Updated By</Label>
              <Input
                id="updated-by"
                value={updatedBy}
                onChange={(e) => setUpdatedBy(e.target.value)}
                className="mt-1"
                placeholder="Your name or title"
              />
            </div>
          </div>

          <div>
            <Label htmlFor="remarks">Remarks *</Label>
            <Textarea
              id="remarks"
              placeholder="Add remarks or notes about this status change..."
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              className="mt-1"
              rows={4}
            />
          </div>

          <Button
            onClick={handleStatusUpdate}
            disabled={!selectedCaseNumber || !newStatus || !remarks.trim()}
            className="w-full"
          >
            Update Status
          </Button>
        </CardContent>
      </Card>

      {/* Status Update History */}
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
                  <p className="text-sm mb-2">{update.remarks}</p>
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
