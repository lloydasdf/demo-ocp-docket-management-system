'use client';

import type React from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { ArrowLeft, ExternalLink } from 'lucide-react';

import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import {
  getCaseAssignments,
  getCaseAttachmentsIndex,
  getCaseCompactById,
  getCaseDetailsById,
  getCaseMotions,
  getCaseParticipants,
  getCaseStatusHistory,
  type CaseAssignmentRecord,
  type CaseDetailsRecord,
  type CaseParticipantRecord,
  type CaseStatusHistoryRecord,
} from '@/lib/supabase/queries';
import type { TableRow as SupabaseTableRow, ViewRow } from '@/lib/supabase/types';

const SUPPORTED_DOCKET_TYPES = new Set(['INV', 'INQ']);
const SUPPORTED_DOCKET_YEAR = 2022;

type CaseDetailsState = {
  compact: ViewRow<'v_cases_table_compact'> | null;
  details: CaseDetailsRecord | null;
  participants: CaseParticipantRecord[];
  assignments: CaseAssignmentRecord[];
  statusHistory: CaseStatusHistoryRecord[];
  motions: SupabaseTableRow<'case_motions'>[];
  attachments: SupabaseTableRow<'case_attachment_index'>[];
  warnings: string[];
};

function formatDate(value: string | null | undefined) {
  if (!value) {
    return '—';
  }

  const parsedDate = new Date(value);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleDateString();
}

function formatDateTime(value: string | null | undefined) {
  if (!value) {
    return '—';
  }

  const parsedDate = new Date(value);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleString();
}

function formatFileSize(bytes: number | null) {
  if (bytes === null) {
    return '—';
  }

  if (bytes < 1024) {
    return `${bytes} B`;
  }

  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }

  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function displayValue(value: string | number | null | undefined) {
  return value === null || value === undefined || value === '' ? '—' : String(value);
}

function personName(participant: CaseParticipantRecord) {
  return participant.persons?.full_name ?? participant.raw_name_text ?? 'Unnamed participant';
}

function roleLabel(participant: CaseParticipantRecord) {
  return participant.participant_roles?.display_label ?? participant.participant_roles?.code ?? 'Party';
}

function SectionEmpty({ children = 'No records yet.' }: { children?: string }) {
  return <p className="rounded-md border border-dashed p-4 text-sm text-muted-foreground">{children}</p>;
}

function DetailItem({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="space-y-1">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
      <div className="text-sm font-medium text-foreground">{value}</div>
    </div>
  );
}

export default function CaseDetailsPage() {
  const params = useParams<{ caseId: string }>();
  const caseId = Number.parseInt(params.caseId, 10);
  const [data, setData] = useState<CaseDetailsState | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function loadCase() {
      if (!Number.isFinite(caseId)) {
        setErrorMessage('Invalid case id.');
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setErrorMessage(null);

      const [compact, details, participants, assignments, statusHistory, motions, attachments] = await Promise.all([
        getCaseCompactById(caseId),
        getCaseDetailsById(caseId),
        getCaseParticipants(caseId),
        getCaseAssignments(caseId),
        getCaseStatusHistory(caseId),
        getCaseMotions(caseId),
        getCaseAttachmentsIndex(caseId),
      ]);

      if (!isMounted) {
        return;
      }

      const criticalError = details.error ?? compact.error;

      if (criticalError) {
        setErrorMessage(criticalError.message);
        setData(null);
        setIsLoading(false);
        return;
      }

      const warnings = [participants, assignments, statusHistory, motions, attachments]
        .map((result) => result.error?.message)
        .filter((message): message is string => Boolean(message));

      setData({
        compact: compact.data,
        details: details.data,
        participants: participants.data ?? [],
        assignments: assignments.data ?? [],
        statusHistory: statusHistory.data ?? [],
        motions: motions.data ?? [],
        attachments: attachments.data ?? [],
        warnings,
      });
      setIsLoading(false);
    }

    loadCase();

    return () => {
      isMounted = false;
    };
  }, [caseId]);

  const partiesByRole = useMemo(() => {
    const grouped = new Map<string, CaseParticipantRecord[]>();

    for (const participant of data?.participants ?? []) {
      const role = roleLabel(participant);
      grouped.set(role, [...(grouped.get(role) ?? []), participant]);
    }

    return Array.from(grouped.entries());
  }, [data?.participants]);

  const isSupportedFocus = Boolean(
    data?.compact?.docket_type &&
      SUPPORTED_DOCKET_TYPES.has(data.compact.docket_type) &&
      data.compact.docket_year === SUPPORTED_DOCKET_YEAR,
  );

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto p-3 pt-16 md:p-8">
        <div className="flex w-full max-w-[824px] flex-col gap-4 md:gap-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <Button variant="outline" size="sm" asChild className="w-fit">
              <Link href="/cases">
                <ArrowLeft className="mr-2 h-4 w-4" />
                Back to cases
              </Link>
            </Button>
          </div>

          {isLoading ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Loading case details from Supabase...
              </CardContent>
            </Card>
          ) : errorMessage ? (
            <Alert variant="destructive">
              <AlertTitle>Unable to load case details</AlertTitle>
              <AlertDescription>{errorMessage}</AlertDescription>
            </Alert>
          ) : !data?.details || !data.compact ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">Case not found.</CardContent>
            </Card>
          ) : (
            <>
              {!isSupportedFocus ? (
                <Alert>
                  <AlertTitle>Outside first implementation focus</AlertTitle>
                  <AlertDescription>
                    This details page is currently optimized for INV and INQ 2022 cases. Available schema-backed data is still shown.
                  </AlertDescription>
                </Alert>
              ) : null}

              {data.warnings.length > 0 ? (
                <Alert>
                  <AlertTitle>Some related sections could not be loaded</AlertTitle>
                  <AlertDescription>{data.warnings.join(' ')}</AlertDescription>
                </Alert>
              ) : null}

              <Card>
                <CardHeader className="gap-5 p-4 sm:p-6">
                  <div className="min-w-0">
                    <CardTitle className="whitespace-nowrap text-2xl sm:text-3xl">
                      {data.compact.docket_number ?? data.details.docket_display_number}
                    </CardTitle>
                    <CardDescription className="mt-3 text-sm text-foreground sm:text-base">
                      {data.compact.violations ?? data.details.violations?.title ?? 'No violation recorded'}
                    </CardDescription>
                  </div>

                  <div className="grid gap-3 border-t pt-4 sm:grid-cols-[max-content_minmax(0,14rem)_max-content] sm:gap-x-10">
                    <DetailItem label="Date received" value={formatDate(data.compact.date_received ?? data.details.date_received)} />
                    <DetailItem
                      label="Assigned prosecutor"
                      value={data.compact.assigned_prosecutor ?? data.details.prosecutors?.full_name ?? '—'}
                    />
                    <DetailItem
                      label="Current status"
                      value={<Badge variant="outline">{data.compact.current_status ?? data.details.case_statuses?.display_label ?? '—'}</Badge>}
                    />
                  </div>
                </CardHeader>
              </Card>

              <div className="grid gap-6 xl:grid-cols-[2fr_1fr]">
                <div className="space-y-6">
                  <Card>
                    <CardHeader className="p-4 sm:p-6">
                      <CardTitle>Parties</CardTitle>
                      <CardDescription>Complainants, respondents, and any other schema-backed participant roles.</CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4 p-4 pt-0 sm:p-6 sm:pt-0">
                      {partiesByRole.length === 0 ? (
                        <SectionEmpty />
                      ) : (
                        partiesByRole.map(([role, participants]) => (
                          <div key={role} className="space-y-3">
                            <h3 className="font-semibold">{role}</h3>
                            <div className="grid gap-3 md:grid-cols-2">
                              {participants.map((participant) => (
                                <div key={participant.id} className="rounded-lg border p-4">
                                  <div className="flex items-start justify-between gap-3">
                                    <div>
                                      <p className="font-medium">{personName(participant)}</p>
                                      <p className="text-sm text-muted-foreground">{participant.persons?.gender ?? participant.gender_snapshot ?? 'Gender not recorded'}</p>
                                    </div>
                                    {participant.is_primary ? <Badge>Primary</Badge> : null}
                                  </div>
                                  <Separator className="my-3" />
                                  <div className="grid gap-2 text-sm sm:grid-cols-2">
                                    <DetailItem label="Age" value={participant.age_text ?? participant.age_at_case ?? '—'} />
                                    <DetailItem label="Birthdate" value={formatDate(participant.persons?.birth_date)} />
                                    <DetailItem label="Role" value={role} />
                                    <DetailItem label="Remarks" value={participant.remarks ?? '—'} />
                                  </div>
                                </div>
                              ))}
                            </div>
                          </div>
                        ))
                      )}
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Case information</CardTitle>
                    </CardHeader>
                    <CardContent className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                      <DetailItem label="Violation/s" value={data.compact.violations ?? data.details.violations?.title ?? '—'} />
                      <DetailItem label="Law reference" value={data.details.violations?.law_reference ?? data.details.violations?.reference_code ?? '—'} />
                      <DetailItem label="Charge filed" value={data.details.charge_filed ?? '—'} />
                      <DetailItem label="Date received" value={formatDate(data.details.date_received)} />
                      <DetailItem label="Date filed in court" value={formatDate(data.details.date_filed_in_court)} />
                      <DetailItem label="Date resolved" value={formatDate(data.details.date_resolved)} />
                      <DetailItem label="Court" value={data.details.courts?.name ?? '—'} />
                      <DetailItem label="Branch" value={data.details.court_branch ?? '—'} />
                      <DetailItem label="Criminal case #" value={data.details.criminal_case_number ?? '—'} />
                      <DetailItem label="Remarks" value={data.details.remarks ?? '—'} />
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Status history</CardTitle>
                      <CardDescription>Current status and recorded prior movements.</CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <div className="rounded-lg border p-4">
                        <DetailItem label="Current status" value={data.compact.current_status ?? data.details.case_statuses?.display_label ?? '—'} />
                      </div>
                      {data.statusHistory.length === 0 ? (
                        <SectionEmpty />
                      ) : (
                        <div className="overflow-hidden rounded-lg border">
                          <Table>
                            <TableHeader>
                              <TableRow>
                                <TableHead>Changed at</TableHead>
                                <TableHead>From</TableHead>
                                <TableHead>To</TableHead>
                                <TableHead>Notes</TableHead>
                              </TableRow>
                            </TableHeader>
                            <TableBody>
                              {data.statusHistory.map((history) => (
                                <TableRow key={history.id}>
                                  <TableCell>{formatDateTime(history.changed_at)}</TableCell>
                                  <TableCell>{history.from_status?.display_label ?? '—'}</TableCell>
                                  <TableCell>{history.to_status?.display_label ?? '—'}</TableCell>
                                  <TableCell>{history.remarks ?? '—'}</TableCell>
                                </TableRow>
                              ))}
                            </TableBody>
                          </Table>
                        </div>
                      )}
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Motions</CardTitle>
                    </CardHeader>
                    <CardContent>
                      {data.motions.length === 0 ? (
                        <SectionEmpty />
                      ) : (
                        <div className="overflow-hidden rounded-lg border">
                          <Table>
                            <TableHeader>
                              <TableRow>
                                <TableHead>Motion received</TableHead>
                                <TableHead>Date received</TableHead>
                                <TableHead>Filed by</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead>Remarks</TableHead>
                              </TableRow>
                            </TableHeader>
                            <TableBody>
                              {data.motions.map((motion) => (
                                <TableRow key={motion.id}>
                                  <TableCell>{motion.motion_name}</TableCell>
                                  <TableCell>{formatDate(motion.date_received)}</TableCell>
                                  <TableCell>{motion.filed_by ?? '—'}</TableCell>
                                  <TableCell>{motion.motion_status ?? '—'}</TableCell>
                                  <TableCell>{motion.remarks ?? '—'}</TableCell>
                                </TableRow>
                              ))}
                            </TableBody>
                          </Table>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                </div>

                <div className="space-y-6">
                  <Card>
                    <CardHeader>
                      <CardTitle>Prosecutor assignment</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <DetailItem label="Current prosecutor" value={data.compact.assigned_prosecutor ?? data.details.prosecutors?.full_name ?? '—'} />
                      <DetailItem label="Date assigned" value={formatDate(data.details.date_assigned_to_prosecutor)} />
                      {data.assignments.length === 0 ? (
                        <SectionEmpty />
                      ) : (
                        <div className="space-y-3">
                          {data.assignments.map((assignment) => (
                            <div key={assignment.id} className="rounded-lg border p-3 text-sm">
                              <p className="font-medium">{assignment.prosecutors?.full_name ?? 'Unrecorded prosecutor'}</p>
                              <p className="text-muted-foreground">Assigned {formatDateTime(assignment.assigned_at)}</p>
                              <p className="text-muted-foreground">Staff: {assignment.staff?.full_name ?? '—'}</p>
                              {assignment.unassigned_at ? <p className="text-muted-foreground">Unassigned {formatDateTime(assignment.unassigned_at)}</p> : null}
                              {assignment.remarks ? <p className="mt-2">{assignment.remarks}</p> : null}
                            </div>
                          ))}
                        </div>
                      )}
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Court / criminal case info</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <DetailItem label="Court" value={data.details.courts?.name ?? '—'} />
                      <DetailItem label="Branch" value={data.details.court_branch ?? '—'} />
                      <DetailItem label="Criminal case #" value={data.details.criminal_case_number ?? '—'} />
                      <DetailItem label="Number of information" value={displayValue(data.details.information_count)} />
                      <DetailItem label="Court status" value={data.details.court_status ?? '—'} />
                      <DetailItem label="Court remarks" value={data.details.court_remarks ?? '—'} />
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Attachments</CardTitle>
                      <CardDescription>Google Drive folder and indexed file records, when available.</CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      {data.details.gdrive_folder_link ? (
                        <Button variant="outline" asChild>
                          <a href={data.details.gdrive_folder_link} target="_blank" rel="noreferrer">
                            Open Google Drive folder
                            <ExternalLink className="ml-2 h-4 w-4" />
                          </a>
                        </Button>
                      ) : null}

                      {data.attachments.length === 0 ? (
                        <SectionEmpty>Attachments integration not yet connected.</SectionEmpty>
                      ) : (
                        <div className="space-y-3">
                          {data.attachments.map((attachment) => (
                            <div key={attachment.id} className="rounded-lg border p-3 text-sm">
                              <div className="flex items-start justify-between gap-3">
                                <div className="min-w-0">
                                  <p className="truncate font-medium">{attachment.file_name}</p>
                                  <p className="text-muted-foreground">{formatFileSize(attachment.file_size_bytes)} • {attachment.file_status}</p>
                                </div>
                                {attachment.web_view_link ? (
                                  <Button variant="ghost" size="sm" asChild>
                                    <a href={attachment.web_view_link} target="_blank" rel="noreferrer" aria-label={`Open ${attachment.file_name}`}>
                                      <ExternalLink className="h-4 w-4" />
                                    </a>
                                  </Button>
                                ) : null}
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </CardContent>
                  </Card>
                </div>
              </div>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
