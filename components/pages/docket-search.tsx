'use client';

import { useEffect, useMemo, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { dockets } from '@/lib/dummy-data';
import { getCaseStatuses, getCompactCases } from '@/lib/supabase/queries';
import type { ViewRow } from '@/lib/supabase/types';
import { Search as SearchIcon } from 'lucide-react';

type CompactCase = ViewRow<'v_cases_display'>;

function getFallbackCases(): CompactCase[] {
  return dockets.flatMap((docket) =>
    docket.cases.map((caseDetail) => ({
      prosecutor_full_name: caseDetail.prosecutor ?? null,
      prosecutor_short_name: caseDetail.prosecutor ?? null,
      id: Number.parseInt(caseDetail.id.replace(/\D/g, ''), 10) || null,
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

export default function DocketSearch() {
  const fallbackCases = useMemo(getFallbackCases, []);
  const [cases, setCases] = useState<CompactCase[]>(fallbackCases);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('All');
  const [sortBy, setSortBy] = useState<'date' | 'number'>('date');
  const [statuses, setStatuses] = useState<string[]>(['All', 'Pending', 'Filed', 'Dismissed', 'Resolved', 'RFI']);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function loadCases() {
      setIsLoading(true);
      const [casesResult, statusesResult] = await Promise.all([getCompactCases(), getCaseStatuses()]);

      if (!isMounted) {
        return;
      }

      if (statusesResult.data) {
        setStatuses(['All', ...statusesResult.data.map((status) => status.display_label)]);
      }

      if (casesResult.error) {
        setErrorMessage(casesResult.error.message);
        setCases(fallbackCases);
        setIsUsingFallback(true);
      } else {
        setErrorMessage(null);
        setCases(casesResult.data);
        setIsUsingFallback(false);
      }

      setIsLoading(false);
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, [fallbackCases]);

  const filteredCases = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();

    return [...cases]
      .filter((caseDetail) => {
        const currentStatus = caseDetail.current_status_label ?? '';
        const matchesStatus = selectedStatus === 'All' || currentStatus === selectedStatus;
        const matchesSearch =
          normalizedQuery.length === 0 ||
          (caseDetail.docket_display_number ?? '').toLowerCase().includes(normalizedQuery) ||
          (caseDetail.summary_text ?? '').toLowerCase().includes(normalizedQuery) ||
          (caseDetail.violations ?? '').toLowerCase().includes(normalizedQuery);

        return matchesStatus && matchesSearch;
      })
      .sort((firstCase, secondCase) => {
        if (sortBy === 'date') {
          return (
            new Date(secondCase.created_at ?? secondCase.date_received ?? '').getTime() -
            new Date(firstCase.created_at ?? firstCase.date_received ?? '').getTime()
          );
        }

        return (firstCase.docket_display_number ?? '').localeCompare(secondCase.docket_display_number ?? '');
      });
  }, [cases, searchQuery, selectedStatus, sortBy]);

  return (
    <div className="p-8 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Docket Search</h1>
        <p className="text-muted-foreground mt-1">Search and filter dockets by various criteria</p>
      </div>

      {errorMessage ? (
        <Alert variant="destructive">
          <AlertTitle>Unable to load live Supabase cases</AlertTitle>
          <AlertDescription>{errorMessage} Showing fallback dummy data.</AlertDescription>
        </Alert>
      ) : null}

      <Card>
        <CardHeader>
          <CardTitle>Search Criteria</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-4">
            <div className="flex-1 relative">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                placeholder="Search by docket #, complainant, respondent, or violation..."
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                className="pl-10"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-sm font-medium text-foreground block mb-2">Status</label>
              <Select value={selectedStatus} onValueChange={setSelectedStatus}>
                <SelectTrigger>
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
              <label className="text-sm font-medium text-foreground block mb-2">Sort By</label>
              <Select value={sortBy} onValueChange={(value) => setSortBy(value as 'date' | 'number')}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="date">Date (Newest)</SelectItem>
                  <SelectItem value="number">Docket Number</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <label className="text-sm font-medium text-foreground block mb-2">Results</label>
              <div className="flex items-center h-10 px-3 border border-input rounded-md bg-background">
                <span className="text-sm font-medium">
                  {isLoading ? 'Loading...' : `${filteredCases.length} found`}
                </span>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Search Results</CardTitle>
          <CardDescription>
            {isLoading
              ? 'Loading live cases...'
              : filteredCases.length === 0
                ? 'No cases found matching your criteria'
                : `Showing ${filteredCases.length} case${filteredCases.length === 1 ? '' : 's'}${
                    isUsingFallback ? ' from fallback data' : ''
                  }`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">Loading cases...</p>
            </div>
          ) : filteredCases.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No cases match your search criteria</p>
            </div>
          ) : (
            <div className="rounded-lg border border-border overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>Docket #</TableHead>
                    <TableHead>Complainant</TableHead>
                    <TableHead>Respondent</TableHead>
                    <TableHead>Violations</TableHead>
                    <TableHead>Assigned Prosecutor</TableHead>
                    <TableHead>Current Status</TableHead>
                    <TableHead className="text-right">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredCases.map((caseDetail) => (
                    <TableRow key={`${caseDetail.id ?? 'case'}-${caseDetail.docket_display_number ?? 'docket'}`} className="hover:bg-muted/50">
                      <TableCell className="font-medium text-primary">{caseDetail.docket_display_number ?? '—'}</TableCell>
                      <TableCell className="text-sm">{caseDetail.summary_text ?? '—'}</TableCell>
                      <TableCell className="text-sm">{caseDetail.summary_text ?? '—'}</TableCell>
                      <TableCell className="text-sm max-w-xs truncate">{caseDetail.violations ?? '—'}</TableCell>
                      <TableCell className="text-sm">{caseDetail.prosecutor_full_name ?? caseDetail.prosecutor_short_name ?? '—'}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{caseDetail.current_status_label ?? '—'}</Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <Button variant="ghost" size="sm" asChild>
                          <a href={`/case-details?caseId=${caseDetail.id ?? ''}`}>View</a>
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
    </div>
  );
}
