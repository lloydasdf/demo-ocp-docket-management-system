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
import { getCaseStatuses, getCasesList, type CasesListItem } from '@/lib/supabase/queries';
import { Search as SearchIcon } from 'lucide-react';

function getFallbackCases(): CasesListItem[] {
  return dockets.flatMap((docket) =>
    docket.cases.map((caseDetail) => ({
      id: Number.parseInt(caseDetail.id.replace(/\D/g, ''), 10) || 0,
      docketNumber: docket.docketNumber,
      complainant:
        caseDetail.complainants.length > 0
          ? `${caseDetail.complainants[0].firstName} ${caseDetail.complainants[0].lastName}${
              caseDetail.complainants.length > 1 ? ' et al.' : ''
            }`
          : '—',
      respondent:
        caseDetail.respondents.length > 0
          ? `${caseDetail.respondents[0].firstName} ${caseDetail.respondents[0].lastName}${
              caseDetail.respondents.length > 1 ? ' et al.' : ''
            }`
          : '—',
      violations:
        caseDetail.violations.length > 0
          ? caseDetail.violations.map((violation) => violation.statute).join(', ')
          : '—',
      assignedProsecutor: caseDetail.prosecutor || '—',
      currentStatus: caseDetail.status,
      dateReceived: caseDetail.dateOfIncident,
      createdAt: docket.createdDate,
    })),
  );
}

export default function DocketSearch() {
  const fallbackCases = useMemo(getFallbackCases, []);
  const [cases, setCases] = useState<CasesListItem[]>(fallbackCases);
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
      const [casesResult, statusesResult] = await Promise.all([getCasesList(), getCaseStatuses()]);

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
        const matchesStatus = selectedStatus === 'All' || caseDetail.currentStatus === selectedStatus;
        const matchesSearch =
          normalizedQuery.length === 0 ||
          caseDetail.docketNumber.toLowerCase().includes(normalizedQuery) ||
          caseDetail.complainant.toLowerCase().includes(normalizedQuery) ||
          caseDetail.respondent.toLowerCase().includes(normalizedQuery) ||
          caseDetail.violations.toLowerCase().includes(normalizedQuery);

        return matchesStatus && matchesSearch;
      })
      .sort((firstCase, secondCase) => {
        if (sortBy === 'date') {
          return (
            new Date(secondCase.createdAt ?? secondCase.dateReceived ?? '').getTime() -
            new Date(firstCase.createdAt ?? firstCase.dateReceived ?? '').getTime()
          );
        }

        return firstCase.docketNumber.localeCompare(secondCase.docketNumber);
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
              ? 'Loading live cases from Supabase...'
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
                    <TableRow key={caseDetail.id} className="hover:bg-muted/50">
                      <TableCell className="font-medium text-primary">{caseDetail.docketNumber}</TableCell>
                      <TableCell className="text-sm">{caseDetail.complainant}</TableCell>
                      <TableCell className="text-sm">{caseDetail.respondent}</TableCell>
                      <TableCell className="text-sm max-w-xs truncate">{caseDetail.violations}</TableCell>
                      <TableCell className="text-sm">{caseDetail.assignedProsecutor}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{caseDetail.currentStatus}</Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <Button variant="ghost" size="sm" asChild>
                          <a href={`/case-details?caseId=${caseDetail.id}`}>View</a>
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
