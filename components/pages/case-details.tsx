'use client';

import { useState, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { StatusBadge } from '@/components/status-badge';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getCasesByDocketId, getDocketById, getAttachmentsByDocketId, getProsecutorAssignments, getCaseStatusHistory } from '@/lib/supabase-queries';
import { FileText, Users, Scale, MapPin, Calendar, AlertTriangle } from 'lucide-react';

export default function CaseDetails() {
  const searchParams = useSearchParams();
  const docketId = searchParams.get('docketId');

  const [docket, setDocket] = useState<any>(null);
  const [cases, setCases] = useState<any[]>([]);
  const [attachments, setAttachments] = useState<any[]>([]);
  const [assignments, setAssignments] = useState<any[]>([]);
  const [statusHistory, setStatusHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!docketId) {
      setError('No docket ID provided');
      setLoading(false);
      return;
    }

    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);

        const [docketData, casesData, attachmentsData, assignmentsData] = await Promise.all([
          getDocketById(docketId),
          getCasesByDocketId(docketId),
          getAttachmentsByDocketId(docketId),
          getProsecutorAssignments(docketId),
        ]);

        setDocket(docketData);
        setCases(casesData);
        setAttachments(attachmentsData);
        setAssignments(assignmentsData);

        // Load status history for first case
        if (casesData && casesData.length > 0) {
          const history = await getCaseStatusHistory(casesData[0].id);
          setStatusHistory(history);
        }
      } catch (err) {
        console.error('[v0] Error loading case details:', err);
        setError('Failed to load case details');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, [docketId]);

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <Spinner className="w-12 h-12 mx-auto mb-4" />
          <p className="text-muted-foreground">Loading case details...</p>
        </div>
      </div>
    );
  }

  if (error || !docket) {
    return (
      <div className="p-8">
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription>{error || 'Case details not found'}</AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-3xl font-bold text-foreground">{docket.docket_number}</h1>
            <p className="text-muted-foreground mt-1">{docket.description}</p>
          </div>
          <StatusBadge status={docket.status} />
        </div>
      </div>

      {/* Docket Overview */}
      <Card>
        <CardHeader>
          <CardTitle>Docket Information</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <p className="text-sm text-muted-foreground">Docket Number</p>
              <p className="font-mono font-semibold mt-1">{docket.docket_number}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Date Received</p>
              <p className="font-semibold mt-1">{new Date(docket.date_received).toLocaleDateString()}</p>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Status</p>
              <div className="mt-1">
                <StatusBadge status={docket.status} size="sm" />
              </div>
            </div>
            <div>
              <p className="text-sm text-muted-foreground">Total Cases</p>
              <p className="font-semibold mt-1">{cases.length}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Cases */}
      <Tabs defaultValue="cases" className="space-y-4">
        <TabsList>
          <TabsTrigger value="cases">Cases ({cases.length})</TabsTrigger>
          <TabsTrigger value="assignments">Assignments ({assignments.length})</TabsTrigger>
          <TabsTrigger value="attachments">Attachments ({attachments.length})</TabsTrigger>
          <TabsTrigger value="history">Status History</TabsTrigger>
        </TabsList>

        <TabsContent value="cases" className="space-y-4">
          {cases.length === 0 ? (
            <Card>
              <CardContent className="pt-8 text-center text-muted-foreground">
                No cases found for this docket.
              </CardContent>
            </Card>
          ) : (
            cases.map((caseItem) => (
              <Card key={caseItem.id}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle className="font-mono">{caseItem.case_number}</CardTitle>
                      <CardDescription>Incident: {new Date(caseItem.date_received).toLocaleDateString()}</CardDescription>
                    </div>
                    <StatusBadge status={caseItem.status} size="sm" />
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  {caseItem.case_participants && caseItem.case_participants.length > 0 && (
                    <div>
                      <h4 className="font-semibold text-sm mb-2 flex items-center gap-2">
                        <Users className="w-4 h-4" /> Participants
                      </h4>
                      <div className="space-y-2">
                        {caseItem.case_participants.map((p: any) => (
                          <div key={p.id} className="text-sm">
                            <span className="font-medium">{p.persons?.first_name} {p.persons?.last_name}</span>
                            <span className="text-muted-foreground ml-2">({p.role})</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {caseItem.case_violations && caseItem.case_violations.length > 0 && (
                    <div>
                      <h4 className="font-semibold text-sm mb-2 flex items-center gap-2">
                        <Scale className="w-4 h-4" /> Violations
                      </h4>
                      <div className="space-y-2">
                        {caseItem.case_violations.map((v: any) => (
                          <div key={v.id} className="text-sm">
                            <Badge variant="outline">{v.violations?.statute_code}</Badge>
                            <p className="text-muted-foreground mt-1">{v.violations?.description}</p>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            ))
          )}
        </TabsContent>

        <TabsContent value="assignments" className="space-y-4">
          {assignments.length === 0 ? (
            <Card>
              <CardContent className="pt-8 text-center text-muted-foreground">
                No assignments found.
              </CardContent>
            </Card>
          ) : (
            assignments.map((assignment) => (
              <Card key={assignment.id}>
                <CardContent className="pt-6">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-semibold">{assignment.app_users?.full_name}</p>
                        <p className="text-sm text-muted-foreground">{assignment.app_users?.email}</p>
                      </div>
                      <p className="text-sm text-muted-foreground">
                        {new Date(assignment.assigned_at).toLocaleDateString()}
                      </p>
                    </div>
                    {assignment.notes && (
                      <p className="text-sm mt-2 p-2 bg-muted rounded">{assignment.notes}</p>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))
          )}
        </TabsContent>

        <TabsContent value="attachments" className="space-y-4">
          {attachments.length === 0 ? (
            <Card>
              <CardContent className="pt-8 text-center text-muted-foreground">
                No attachments found.
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-2">
              {attachments.map((attachment) => (
                <Card key={attachment.id}>
                  <CardContent className="pt-6">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <FileText className="w-5 h-5 text-muted-foreground" />
                        <div>
                          <p className="font-semibold text-sm">{attachment.file_name}</p>
                          <p className="text-xs text-muted-foreground">
                            {attachment.file_size} • {attachment.file_type}
                          </p>
                        </div>
                      </div>
                      <p className="text-xs text-muted-foreground">
                        {new Date(attachment.uploaded_at).toLocaleDateString()}
                      </p>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="history" className="space-y-4">
          {statusHistory.length === 0 ? (
            <Card>
              <CardContent className="pt-8 text-center text-muted-foreground">
                No status history found.
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-2">
              {statusHistory.map((history) => (
                <Card key={history.id}>
                  <CardContent className="pt-6">
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <StatusBadge status={history.status} size="sm" />
                        <p className="text-sm text-muted-foreground">
                          {new Date(history.updated_at).toLocaleDateString()}
                        </p>
                      </div>
                      <p className="text-sm">
                        Updated by <span className="font-medium">{history.app_users?.full_name}</span>
                      </p>
                      {history.notes && (
                        <p className="text-sm p-2 bg-muted rounded mt-2">{history.notes}</p>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
