'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ArrowRight } from 'lucide-react';
import { dockets } from '@/lib/dummy-data';
import { getCasesCompact } from '@/lib/supabase/queries';
import type { ViewRow } from '@/lib/supabase/types';

type CompactCase = ViewRow<'v_cases_table_compact'>;
type DocketTypeFilter = 'All' | 'INV' | 'INQ' | 'PE' | 'DC20';
type DocketYearFilter = 'All' | '2022';

const DOCKET_TYPE_FILTERS: DocketTypeFilter[] = ['All', 'INV', 'INQ', 'PE', 'DC20'];
const DOCKET_YEAR_FILTERS: DocketYearFilter[] = ['2022', 'All'];

function getFallbackCases(): CompactCase[] {
  return dockets.flatMap((docket) =>
    docket.cases.map((caseDetail) => ({
      assigned_prosecutor: caseDetail.prosecutor ?? null,
      case_id: Number.parseInt(caseDetail.id.replace(/\D/g, ''), 10) || null,
      complainant:
        caseDetail.complainants.length > 0
          ? `${caseDetail.complainants[0].firstName} ${caseDetail.complainants[0].lastName}${
              caseDetail.complainants.length > 1 ? ' et al.' : ''
            }`
          : null,
      created_at: docket.createdDate,
      current_status: caseDetail.status,
      date_received: caseDetail.dateOfIncident,
      docket_month_code: null,
      docket_number: docket.docketNumber,
      docket_sequence_number: null,
      docket_type: docket.docketNumber.split('-')[0] ?? null,
      docket_year: Number.parseInt(docket.docketNumber.match(/\d{4}/)?.[0] ?? '', 10) || null,
      respondent:
        caseDetail.respondents.length > 0
          ? `${caseDetail.respondents[0].firstName} ${caseDetail.respondents[0].lastName}${
              caseDetail.respondents.length > 1 ? ' et al.' : ''
            }`
          : null,
      status_background_hex: null,
      status_border_hex: null,
      status_code: caseDetail.status,
      status_color_key: null,
      status_text_hex: null,
      updated_at: null,
      violations:
        caseDetail.violations.length > 0
          ? caseDetail.violations.map((violation) => violation.statute).join(', ')
          : null,
    })),
  );
}

function formatDate(date: string | null) {
  if (!date) {
    return '—';
  }

  const parsedDate = new Date(date);

  if (Number.isNaN(parsedDate.getTime())) {
    return date;
  }

  return parsedDate.toLocaleDateString();
}

export default function CasesPage() {
  const router = useRouter();
  const fallbackCases = useMemo(getFallbackCases, []);
  const [cases, setCases] = useState<CompactCase[]>([]);
  const [selectedDocketType, setSelectedDocketType] = useState<DocketTypeFilter>('All');
  const [selectedDocketYear, setSelectedDocketYear] = useState<DocketYearFilter>('2022');
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function loadCases() {
      setIsLoading(true);
      const result = await getCasesCompact({
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
            const matchesType = selectedDocketType === 'All' || caseDetail.docket_type === selectedDocketType;
            const matchesYear = selectedDocketYear === 'All' || caseDetail.docket_year === Number(selectedDocketYear);
            return matchesType && matchesYear;
          }),
        );
        setIsUsingFallback(true);
      } else {
        setErrorMessage(null);
        setCases(result.data);
        setIsUsingFallback(false);
      }

      setIsLoading(false);
    }

    loadCases();

    return () => {
      isMounted = false;
    };
  }, [fallbackCases, selectedDocketType, selectedDocketYear]);

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="flex min-w-0 flex-1 flex-col overflow-hidden p-4 md:p-8">
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
              ) : cases.length === 0 ? (
                <div className="py-8 text-center text-sm text-muted-foreground">No cases found.</div>
              ) : (
                <div className="h-full overflow-auto rounded-lg border border-border">
                  <Table className="min-w-[980px]">
                    <TableHeader className="sticky top-0 z-10 bg-muted">
                      <TableRow className="bg-muted hover:bg-muted">
                        <TableHead>Docket #</TableHead>
                        <TableHead>Docket Type</TableHead>
                        <TableHead>Date Received</TableHead>
                        <TableHead>Complainant</TableHead>
                        <TableHead>Respondent</TableHead>
                        <TableHead>Violations</TableHead>
                        <TableHead>Assigned Prosecutor</TableHead>
                        <TableHead>Current Status</TableHead>
                        <TableHead className="text-right">Action</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {cases.map((caseDetail) => (
                        <TableRow
                          key={`${caseDetail.case_id ?? 'case'}-${caseDetail.docket_number ?? 'docket'}`}
                          className="cursor-pointer hover:bg-muted/50"
                          tabIndex={caseDetail.case_id ? 0 : -1}
                          onClick={() => {
                            if (caseDetail.case_id) {
                              router.push(`/cases/${caseDetail.case_id}`);
                            }
                          }}
                          onKeyDown={(event) => {
                            if (caseDetail.case_id && (event.key === 'Enter' || event.key === ' ')) {
                              event.preventDefault();
                              router.push(`/cases/${caseDetail.case_id}`);
                            }
                          }}
                        >
                          <TableCell className="font-medium text-primary">{caseDetail.docket_number ?? '—'}</TableCell>
                          <TableCell className="text-sm">{caseDetail.docket_type ?? '—'}</TableCell>
                          <TableCell className="text-sm">{formatDate(caseDetail.date_received)}</TableCell>
                          <TableCell className="text-sm">{caseDetail.complainant ?? '—'}</TableCell>
                          <TableCell className="text-sm">{caseDetail.respondent ?? '—'}</TableCell>
                          <TableCell className="text-sm max-w-xs truncate">{caseDetail.violations ?? '—'}</TableCell>
                          <TableCell className="text-sm">{caseDetail.assigned_prosecutor ?? '—'}</TableCell>
                          <TableCell>
                            <Badge variant="outline">{caseDetail.current_status ?? '—'}</Badge>
                          </TableCell>
                          <TableCell className="text-right">
                            <Button variant="ghost" size="sm" asChild onClick={(event) => event.stopPropagation()}>
                              <Link
                                href={caseDetail.case_id ? `/cases/${caseDetail.case_id}` : '/cases'}
                                aria-label={`View ${caseDetail.docket_number ?? 'case'}`}
                              >
                                <ArrowRight className="w-4 h-4" />
                              </Link>
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
      </main>
    </div>
  );
}
