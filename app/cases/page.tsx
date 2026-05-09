'use client';

import { useEffect, useMemo, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ArrowRight } from 'lucide-react';
import { dockets } from '@/lib/dummy-data';
import { getCasesList, type CasesListItem } from '@/lib/supabase/queries';

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

export default function CasesPage() {
  const fallbackCases = useMemo(getFallbackCases, []);
  const [cases, setCases] = useState<CasesListItem[]>(fallbackCases);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isUsingFallback, setIsUsingFallback] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function loadCases() {
      setIsLoading(true);
      const result = await getCasesList();

      if (!isMounted) {
        return;
      }

      if (result.error) {
        setErrorMessage(result.error.message);
        setCases(fallbackCases);
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
  }, [fallbackCases]);

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto p-8 space-y-6">
        <div>
          <h1 className="text-3xl font-bold text-foreground">All Cases</h1>
          <p className="text-muted-foreground mt-1">Browse all cases in the system</p>
        </div>

        {errorMessage ? (
          <Alert variant="destructive">
            <AlertTitle>Unable to load live Supabase cases</AlertTitle>
            <AlertDescription>{errorMessage} Showing fallback dummy data.</AlertDescription>
          </Alert>
        ) : null}

        <Card>
          <CardHeader>
            <CardTitle>Cases List</CardTitle>
            <CardDescription>
              {isLoading
                ? 'Loading live cases from Supabase...'
                : isUsingFallback
                  ? `${cases.length} fallback cases`
                  : `${cases.length} total cases`}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <div className="py-8 text-center text-sm text-muted-foreground">Loading cases...</div>
            ) : cases.length === 0 ? (
              <div className="py-8 text-center text-sm text-muted-foreground">No cases found.</div>
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
                    {cases.map((caseDetail) => (
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
                            <a href={`/case-details?caseId=${caseDetail.id}`} aria-label={`View ${caseDetail.docketNumber}`}>
                              <ArrowRight className="w-4 h-4" />
                            </a>
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
      </main>
    </div>
  );
}
