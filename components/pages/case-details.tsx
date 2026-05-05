'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { StatusBadge } from '@/components/status-badge';
import { getCaseById, getCaseWithAttachments, dockets } from '@/lib/dummy-data';
import { Button } from '@/components/ui/button';
import { Download, Mail, ArrowRight } from 'lucide-react';

interface CaseDetailsProps {
  caseId?: string;
  docketId: string;
}

export default function CaseDetails({ caseId, docketId }: CaseDetailsProps) {
  const docket = dockets.find((d) => d.id === docketId);
  const caseDetail = caseId ? getCaseById(caseId) : null;
  const caseWithAttachments = caseId ? getCaseWithAttachments(caseId) : null;

  if (!docket) {
    return (
      <div className="p-8">
        <Card>
          <CardContent className="pt-8">
            <p className="text-center text-muted-foreground">Docket not found</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6">
      {/* Docket Header */}
      <div className="space-y-4">
        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">DOCKET</span>
              <Badge variant="outline" className="text-xs">{docket.docketNumber}</Badge>
            </div>
            <h1 className="text-3xl font-bold text-foreground">{docket.description || `Docket ${docket.docketNumber}`}</h1>
          </div>
          <div className="text-right">
            <p className="text-xs text-muted-foreground mb-1">DOCKET STATUS</p>
            <StatusBadge status={docket.status} size="lg" />
          </div>
        </div>

        {/* Docket Overview Grid */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="p-4 border border-border rounded-lg bg-card/50">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Created</p>
            <p className="font-semibold">{new Date(docket.createdDate).toLocaleDateString()}</p>
          </div>
          <div className="p-4 border border-border rounded-lg bg-card/50">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Total Cases</p>
            <p className="font-semibold">{docket.cases.length} case{docket.cases.length !== 1 ? 's' : ''}</p>
          </div>
          <div className="p-4 border border-border rounded-lg bg-card/50">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Status Breakdown</p>
            <div className="flex gap-2 mt-1">
              {['Pending', 'Filed', 'Resolved'].map((status) => {
                const count = docket.cases.filter((c) => c.status === status).length;
                return count > 0 ? (
                  <span key={status} className="text-xs font-medium">
                    <StatusBadge status={status as any} size="sm" />
                  </span>
                ) : null;
              })}
            </div>
          </div>
          <div className="p-4 border border-border rounded-lg bg-card/50">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Prosecutors</p>
            <p className="font-semibold">{new Set(docket.cases.filter(c => c.prosecutor).map(c => c.prosecutor)).size}</p>
          </div>
        </div>
      </div>

      {/* Cases Section */}
      <Card className="border-2 border-primary/20">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-lg">Cases Under This Docket</CardTitle>
              <CardDescription>Individual case status and details</CardDescription>
            </div>
            <Badge variant="secondary" className="text-sm">{docket.cases.length} total</Badge>
          </div>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 gap-3">
            {docket.cases.map((caseItem, index) => (
              <div
                key={caseItem.id}
                className={`p-4 border-2 rounded-lg cursor-pointer transition-colors ${
                  caseDetail?.id === caseItem.id
                    ? 'border-primary bg-primary/5'
                    : 'border-border hover:border-primary/50'
                }`}
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <span className="font-mono text-sm font-semibold text-primary">{caseItem.caseNumber}</span>
                      <StatusBadge status={caseItem.status} size="sm" />
                    </div>
                    <p className="text-sm text-muted-foreground mb-2">
                      Incident: {new Date(caseItem.dateOfIncident).toLocaleDateString()}
                    </p>
                    <div className="flex items-center gap-4 text-xs">
                      <span>
                        <span className="text-muted-foreground">Violations:</span> {caseItem.violations.length}
                      </span>
                      <span>
                        <span className="text-muted-foreground">Prosecutor:</span> {caseItem.prosecutor || 'Unassigned'}
                      </span>
                    </div>
                  </div>
                  <ArrowRight className="w-5 h-5 text-muted-foreground flex-shrink-0 mt-1" />
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Selected Case Details */}
      {caseDetail && (
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>Case Details</CardTitle>
                <CardDescription className="mt-1">Case {caseDetail.caseNumber} information</CardDescription>
              </div>
              <StatusBadge status={caseDetail.status} size="lg" />
            </div>
          </CardHeader>
          <CardContent className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <p className="text-sm text-muted-foreground">Date of Incident</p>
              <p className="text-lg font-semibold">
                {new Date(caseDetail.dateOfIncident).toLocaleDateString()}
              </p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Assigned Prosecutor</p>
              <p className="text-lg font-semibold">{caseDetail.prosecutor || 'Unassigned'}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Violations</p>
              <p className="text-lg font-semibold">{caseDetail.violations.length}</p>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Tabs - Only show when a case is selected */}
      {caseDetail && (
      <Tabs defaultValue="overview" className="w-full">
        <TabsList className="grid w-full grid-cols-6">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="parties">Parties</TabsTrigger>
          <TabsTrigger value="violations">Violations</TabsTrigger>
          <TabsTrigger value="history">History</TabsTrigger>
          <TabsTrigger value="attachments">Attachments</TabsTrigger>
          <TabsTrigger value="summary">Summary</TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview">
          <Card>
            <CardHeader>
              <CardTitle>Case Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h4 className="font-semibold mb-3">Key Details</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Case Number:</span>
                      <span className="font-medium">{caseDetail.caseNumber}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Status:</span>
                      <StatusBadge status={caseDetail.status} size="sm" />
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Date of Incident:</span>
                      <span className="font-medium">
                        {new Date(caseDetail.dateOfIncident).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Prosecutor:</span>
                      <span className="font-medium">{caseDetail.prosecutor || '—'}</span>
                    </div>
                  </div>
                </div>
                <div>
                  <h4 className="font-semibold mb-3">Parties Involved</h4>
                  <div className="space-y-2 text-sm">
                    <div>
                      <span className="text-muted-foreground">Complainants:</span>
                      <span className="ml-2 font-medium">{caseDetail.complainants.length}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Respondents:</span>
                      <span className="ml-2 font-medium">{caseDetail.respondents.length}</span>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Witnesses:</span>
                      <span className="ml-2 font-medium">{caseDetail.witnesses.length}</span>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Parties Tab */}
        <TabsContent value="parties" className="space-y-4">
          {/* Complainants */}
          <Card>
            <CardHeader>
              <CardTitle>Complainants</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.complainants.length === 0 ? (
                <p className="text-muted-foreground">No complainants recorded</p>
              ) : (
                <div className="space-y-3">
                  {caseDetail.complainants.map((person) => (
                    <div key={person.id} className="p-3 border border-border rounded">
                      <p className="font-semibold">
                        {person.firstName} {person.middleName} {person.lastName}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {person.contactNumber} | {person.email}
                      </p>
                      {person.aliases.length > 0 && (
                        <div className="mt-2 flex flex-wrap gap-2">
                          {person.aliases.map((alias) => (
                            <Badge key={alias} variant="secondary" className="text-xs">
                              {alias}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Respondents */}
          <Card>
            <CardHeader>
              <CardTitle>Respondents</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.respondents.length === 0 ? (
                <p className="text-muted-foreground">No respondents recorded</p>
              ) : (
                <div className="space-y-3">
                  {caseDetail.respondents.map((person) => (
                    <div key={person.id} className="p-3 border border-border rounded">
                      <p className="font-semibold">
                        {person.firstName} {person.middleName} {person.lastName}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {person.contactNumber} | {person.email}
                      </p>
                      {person.aliases.length > 0 && (
                        <div className="mt-2 flex flex-wrap gap-2">
                          {person.aliases.map((alias) => (
                            <Badge key={alias} variant="secondary" className="text-xs">
                              {alias}
                            </Badge>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          {/* Witnesses */}
          <Card>
            <CardHeader>
              <CardTitle>Witnesses</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.witnesses.length === 0 ? (
                <p className="text-muted-foreground">No witnesses recorded</p>
              ) : (
                <div className="space-y-3">
                  {caseDetail.witnesses.map((person) => (
                    <div key={person.id} className="p-3 border border-border rounded">
                      <p className="font-semibold">
                        {person.firstName} {person.middleName} {person.lastName}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {person.contactNumber} | {person.email}
                      </p>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>



        {/* Violations Tab */}
        <TabsContent value="violations">
          <Card>
            <CardHeader>
              <CardTitle>Alleged Violations</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.violations.length === 0 ? (
                <p className="text-muted-foreground">No violations recorded</p>
              ) : (
                <div className="space-y-4">
                  {caseDetail.violations.map((violation) => (
                    <div key={violation.id} className="p-4 border border-border rounded-lg">
                      <div className="flex items-start justify-between mb-2">
                        <h4 className="font-semibold">{violation.description}</h4>
                        <Badge className="bg-primary">{violation.statute}</Badge>
                      </div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
                        <div>
                          <span className="text-muted-foreground">Date Committed:</span>
                          <p className="font-medium">
                            {violation.dateCommitted
                              ? new Date(violation.dateCommitted).toLocaleDateString()
                              : '—'}
                          </p>
                        </div>
                        <div>
                          <span className="text-muted-foreground">Location:</span>
                          <p className="font-medium">{violation.location || '—'}</p>
                        </div>
                      </div>
                      {violation.details && (
                        <div className="mt-3 pt-3 border-t border-border">
                          <p className="text-sm text-muted-foreground mb-1">Details:</p>
                          <p className="text-sm">{violation.details}</p>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Status History Tab */}
        <TabsContent value="history">
          <Card>
            <CardHeader>
              <CardTitle>Status History</CardTitle>
            </CardHeader>
            <CardContent>
              {caseDetail.statusHistory.length === 0 ? (
                <p className="text-muted-foreground">No status history recorded</p>
              ) : (
                <div className="space-y-4">
                  {caseDetail.statusHistory.map((update, index) => (
                    <div key={update.id} className="flex gap-4">
                      <div className="flex flex-col items-center">
                        <div className="w-4 h-4 rounded-full bg-primary"></div>
                        {index < caseDetail.statusHistory.length - 1 && (
                          <div className="w-1 h-12 bg-border mt-1"></div>
                        )}
                      </div>
                      <div className="pb-4">
                        <div className="flex items-center gap-2 mb-1">
                          <p className="font-semibold">{update.status}</p>
                          <p className="text-xs text-muted-foreground">
                            {new Date(update.date).toLocaleDateString()}
                          </p>
                        </div>
                        <p className="text-sm text-muted-foreground mb-1">{update.remarks}</p>
                        <p className="text-xs text-muted-foreground">By: {update.updatedBy}</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Attachments Tab */}
        <TabsContent value="attachments">
          <Card>
            <CardHeader>
              <CardTitle>Attachments</CardTitle>
            </CardHeader>
            <CardContent>
              {!caseWithAttachments || caseWithAttachments.attachments.length === 0 ? (
                <p className="text-muted-foreground">No attachments</p>
              ) : (
                <div className="space-y-2">
                  {caseWithAttachments.attachments.map((attachment) => (
                    <div
                      key={attachment.id}
                      className="flex items-center justify-between p-3 border border-border rounded-lg hover:bg-muted/50"
                    >
                      <div className="flex-1 min-w-0">
                        <p className="font-medium truncate">{attachment.fileName}</p>
                        <p className="text-xs text-muted-foreground">
                          {attachment.size} • Uploaded {new Date(attachment.uploadDate).toLocaleDateString()} by{' '}
                          {attachment.uploadedBy}
                        </p>
                      </div>
                      <Button variant="ghost" size="sm">
                        <Download className="w-4 h-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Summary Tab */}
        <TabsContent value="summary">
          <div className="space-y-4">
            <Card className="border-primary/20">
              <CardHeader>
                <CardTitle>Complete Case Summary</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Case Status</p>
                      <StatusBadge status={caseDetail.status} size="lg" />
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Case Number</p>
                      <p className="font-mono font-semibold">{caseDetail.caseNumber}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Date of Incident</p>
                      <p className="font-semibold">{new Date(caseDetail.dateOfIncident).toLocaleDateString()}</p>
                    </div>
                  </div>
                  <div className="space-y-4">
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Assigned Prosecutor</p>
                      <p className="font-semibold text-lg">{caseDetail.prosecutor || '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Violations Count</p>
                      <p className="font-semibold text-lg">{caseDetail.violations.length}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Parties Involved</p>
                      <p className="text-sm">
                        {caseDetail.complainants.length} Complainant{caseDetail.complainants.length !== 1 ? 's' : ''} • {caseDetail.respondents.length} Respondent{caseDetail.respondents.length !== 1 ? 's' : ''} • {caseDetail.witnesses.length} Witness{caseDetail.witnesses.length !== 1 ? 'es' : ''}
                      </p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
      )}
    </div>
  );
}
