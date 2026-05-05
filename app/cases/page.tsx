'use client';

import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { ArrowRight } from 'lucide-react';

export default function CasesPage() {
  // Flatten all cases from dockets
  const allCases = dockets.flatMap((docket) =>
    docket.cases.map((c) => ({
      ...c,
      docketNumber: docket.docketNumber,
      docketId: docket.id,
    }))
  );

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto p-8 space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold text-foreground">All Cases</h1>
          <p className="text-muted-foreground mt-1">Browse all cases in the system</p>
        </div>

        {/* Cases Table */}
        <Card>
          <CardHeader>
            <CardTitle>Cases List</CardTitle>
            <CardDescription>{allCases.length} total cases</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="rounded-lg border border-border overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>Case #</TableHead>
                    <TableHead>Docket #</TableHead>
                    <TableHead>Date</TableHead>
                    <TableHead>Prosecutor</TableHead>
                    <TableHead>Violations</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {allCases.map((caseDetail) => (
                    <TableRow key={caseDetail.id} className="hover:bg-muted/50">
                      <TableCell className="font-medium text-primary">{caseDetail.caseNumber}</TableCell>
                      <TableCell>{caseDetail.docketNumber}</TableCell>
                      <TableCell className="text-sm">
                        {new Date(caseDetail.dateOfIncident).toLocaleDateString()}
                      </TableCell>
                      <TableCell className="text-sm">{caseDetail.prosecutor || '—'}</TableCell>
                      <TableCell>
                        <span className="text-sm font-medium">{caseDetail.violations.length}</span>
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={caseDetail.status} size="sm" />
                      </TableCell>
                      <TableCell className="text-right">
                        <Button
                          variant="ghost"
                          size="sm"
                          asChild
                        >
                          <a href={`/case-details?docketId=${caseDetail.docketId}&caseId=${caseDetail.id}`}>
                            <ArrowRight className="w-4 h-4" />
                          </a>
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
