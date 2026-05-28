"use client";

import type React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, ExternalLink, Plus, Trash2 } from "lucide-react";

import { Sidebar } from "@/components/sidebar";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import {
  getCaseAssignments,
  getCaseAttachmentsIndex,
  getCaseCompactById,
  getCaseCourtDetails,
  getCaseDetailsById,
  getCaseMotions,
  getCaseParticipants,
  getCaseStatusHistory,
  getCaseTimelineEvents,
  createCaseEvent,
  voidCaseEvent,
  type CaseAssignmentRecord,
  type CaseCourtRecord,
  type CaseDetailsRecord,
  type CaseParticipantRecord,
  type CaseStatusHistoryRecord,
  type CaseTimelineEventRecord,
} from "@/lib/supabase/queries";
import type {
  TableRow as SupabaseTableRow,
  ViewRow,
} from "@/lib/supabase/types";

const SUPPORTED_DOCKET_TYPES = new Set(["INV", "INQ"]);
const SUPPORTED_DOCKET_YEAR = 2022;

type CaseDetailsState = {
  compact: ViewRow<"v_cases_display"> | null;
  details: CaseDetailsRecord | null;
  participants: CaseParticipantRecord[];
  assignments: CaseAssignmentRecord[];
  courtDetails: CaseCourtRecord[];
  statusHistory: CaseStatusHistoryRecord[];
  motions: SupabaseTableRow<"case_motions">[];
  timeline: CaseTimelineEventRecord[];
  attachments: SupabaseTableRow<"case_attachment_index">[];
  warnings: string[];
};
const EVENT_TYPE_CODES = [
  "CASE_RECEIVED",
  "CASE_RAFFLED",
  "STATUS_CHANGE",
  "COURT_FILING",
  "COURT_UPDATE",
  "MOTION",
  "PETITION_FOR_REVIEW",
  "CUSTOM",
] as const;
type EventDetailField = { id: string; key: string; value: string };

function formatDate(value: string | null | undefined) {
  if (!value) {
    return "—";
  }

  const parsedDate = new Date(value);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleDateString();
}

function formatDateTime(value: string | null | undefined) {
  if (!value) {
    return "—";
  }

  const parsedDate = new Date(value);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleString();
}

function formatFileSize(bytes: number | null) {
  if (bytes === null) {
    return "—";
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
  return value === null || value === undefined || value === ""
    ? "—"
    : String(value);
}

function personName(participant: CaseParticipantRecord) {
  return participant.persons?.full_name ?? "Unnamed participant";
}

function roleLabel(participant: CaseParticipantRecord) {
  return (
    participant.participant_roles?.display_label ??
    participant.participant_roles?.code ??
    "Party"
  );
}

function formatPersonDemographics(participant: CaseParticipantRecord) {
  const attributes = participant.case_participant_attributes;
  const age = displayValue(
    attributes?.age_text ?? attributes?.age_years ?? participant.persons?.age,
  );
  const gender =
    attributes?.gender_text ??
    attributes?.gender_normalized ??
    participant.persons?.gender ??
    "Gender not recorded";

  return `Case age: ${age} • ${gender}`;
}

function caseSpecificFlags(participant: CaseParticipantRecord) {
  const attributes = participant.case_participant_attributes;
  const flags = [
    attributes?.is_minor_at_case ? "Minor" : null,
    attributes?.is_senior_at_case ? "Senior" : null,
    attributes?.is_pwd_at_case ? "PWD" : null,
  ].filter((flag): flag is string => Boolean(flag));

  return flags.length > 0 ? flags.join(", ") : "—";
}

function formatAddress(
  address: NonNullable<
    NonNullable<CaseParticipantRecord["persons"]>["person_addresses"]
  >[number]["addresses"],
) {
  if (!address) {
    return null;
  }

  const parts = [
    address.line1,
    address.line2,
    address.barangay ? `Brgy. ${address.barangay}` : null,
    address.city,
    address.province,
    address.region,
    address.zip_code,
    address.country,
  ].filter((part): part is string => Boolean(part?.trim()));

  return parts.length > 0 ? parts.join(", ") : null;
}

function primaryAddress(participant: CaseParticipantRecord) {
  const addresses = participant.persons?.person_addresses ?? [];
  const preferredAddress =
    addresses.find((address) => address.is_primary) ?? addresses[0];
  return formatAddress(preferredAddress?.addresses ?? null) ?? "—";
}

function joinedValues(values: Array<string | null | undefined>) {
  const uniqueValues = Array.from(
    new Set(
      values
        .map((value) => value?.trim())
        .filter((value): value is string => Boolean(value)),
    ),
  );
  return uniqueValues.length > 0 ? uniqueValues.join(", ") : "—";
}

function joinedDates(values: Array<string | null | undefined>) {
  return joinedValues(
    values.map((value) => (value ? formatDate(value) : null)),
  );
}

function SectionEmpty({ children = "No records yet." }: { children?: string }) {
  return (
    <p className="rounded-md border border-dashed p-4 text-sm text-muted-foreground">
      {children}
    </p>
  );
}

function DetailItem({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="space-y-1">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </p>
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
  const [isSavingEvent, setIsSavingEvent] = useState(false);
  const [eventTypeCode, setEventTypeCode] = useState<string>("CUSTOM");
  const [eventDate, setEventDate] = useState<string>("");
  const [eventTitle, setEventTitle] = useState<string>("");
  const [eventDescription, setEventDescription] = useState<string>("");
  const [eventDetailFields, setEventDetailFields] = useState<EventDetailField[]>([
    { id: crypto.randomUUID(), key: "", value: "" },
  ]);

  useEffect(() => {
    let isMounted = true;

    async function loadCase() {
      if (!Number.isFinite(caseId)) {
        setErrorMessage("Invalid case id.");
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setErrorMessage(null);

      const [
        compact,
        details,
        participants,
        assignments,
        courtDetails,
        statusHistory,
        motions,
        attachments,
        timeline,
      ] = await Promise.all([
        getCaseCompactById(caseId),
        getCaseDetailsById(caseId),
        getCaseParticipants(caseId),
        getCaseAssignments(caseId),
        getCaseCourtDetails(caseId),
        getCaseStatusHistory(caseId),
        getCaseMotions(caseId),
        getCaseAttachmentsIndex(caseId),
        getCaseTimelineEvents(caseId),
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

      const warnings = [
        participants,
        assignments,
        courtDetails,
        statusHistory,
        motions,
        attachments,
        timeline,
      ]
        .map((result) => result.error?.message)
        .filter((message): message is string => Boolean(message));

      setData({
        compact: compact.data,
        details: details.data,
        participants: participants.data ?? [],
        assignments: assignments.data ?? [],
        courtDetails: courtDetails.data ?? [],
        statusHistory: statusHistory.data ?? [],
        motions: motions.data ?? [],
        attachments: attachments.data ?? [],
        timeline: timeline.data ?? [],
        warnings,
      });
      setIsLoading(false);
    }

    loadCase();

    return () => {
      isMounted = false;
    };
  }, [caseId]);

  async function refreshTimeline() {
    const timeline = await getCaseTimelineEvents(caseId);
    if (timeline.error) {
      setErrorMessage(timeline.error.message);
      return;
    }
    setData((previous) =>
      previous ? { ...previous, timeline: timeline.data ?? [] } : previous,
    );
  }

  async function handleAddEvent() {
    if (!eventDate || !eventTitle.trim()) {
      setErrorMessage("Event date and title are required.");
      return;
    }
    const parsedDetails = eventDetailFields.reduce<Record<string, string>>(
      (details, field) => {
        const key = field.key.trim();
        if (key) {
          details[key] = field.value.trim();
        }
        return details;
      },
      {},
    );
    setIsSavingEvent(true);
    setErrorMessage(null);
    const created = await createCaseEvent({
      caseId,
      eventTypeCode,
      eventDate,
      title: eventTitle.trim(),
      description: eventDescription.trim(),
      detailsJson: parsedDetails as never,
    });
    setIsSavingEvent(false);
    if (created.error) {
      setErrorMessage(created.error.message);
      return;
    }
    setEventTitle("");
    setEventDescription("");
    setEventDetailFields([{ id: crypto.randomUUID(), key: "", value: "" }]);
    await refreshTimeline();
  }

  async function handleVoidEvent(caseEventId: number) {
    const reason = window.prompt("Void reason (required):");
    if (!reason?.trim()) return;
    const result = await voidCaseEvent(caseEventId, reason.trim());
    if (result.error) {
      setErrorMessage(result.error.message);
      return;
    }
    await refreshTimeline();
  }

  function upsertDetailField(
    id: string,
    field: "key" | "value",
    value: string,
  ) {
    setEventDetailFields((current) =>
      current.map((detail) =>
        detail.id === id ? { ...detail, [field]: value } : detail,
      ),
    );
  }

  function addDetailField() {
    setEventDetailFields((current) => [
      ...current,
      { id: crypto.randomUUID(), key: "", value: "" },
    ]);
  }

  function removeDetailField(id: string) {
    setEventDetailFields((current) =>
      current.length === 1 ? current : current.filter((field) => field.id !== id),
    );
  }

  const timelineGroupedByDate = useMemo(() => {
    const grouped = new Map<string, CaseTimelineEventRecord[]>();

    for (const event of data?.timeline ?? []) {
      const dateLabel = event.event_date ? formatDate(event.event_date) : "No date";
      grouped.set(dateLabel, [...(grouped.get(dateLabel) ?? []), event]);
    }

    return Array.from(grouped.entries());
  }, [data?.timeline]);

  const partiesByRole = useMemo(() => {
    const grouped = new Map<string, CaseParticipantRecord[]>();

    for (const participant of data?.participants ?? []) {
      const role = roleLabel(participant);
      grouped.set(role, [...(grouped.get(role) ?? []), participant]);
    }

    return Array.from(grouped.entries());
  }, [data?.participants]);

  const isSupportedFocus = Boolean(
    data?.compact?.docket_type_prefix &&
    SUPPORTED_DOCKET_TYPES.has(data.compact.docket_type_prefix) &&
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
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Case not found.
              </CardContent>
            </Card>
          ) : (
            <>
              {!isSupportedFocus ? (
                <Alert>
                  <AlertTitle>Outside first implementation focus</AlertTitle>
                  <AlertDescription>
                    This details page is currently optimized for INV and INQ
                    2022 cases. Available schema-backed data is still shown.
                  </AlertDescription>
                </Alert>
              ) : null}

              {data.warnings.length > 0 ? (
                <Alert>
                  <AlertTitle>
                    Some related sections could not be loaded
                  </AlertTitle>
                  <AlertDescription>{data.warnings.join(" ")}</AlertDescription>
                </Alert>
              ) : null}

              <Card>
                <CardHeader className="gap-5 p-4 sm:p-6">
                  <div className="min-w-0">
                    <CardTitle className="whitespace-nowrap text-2xl sm:text-3xl">
                      {data.compact.docket_display_number ??
                        displayValue(data.details.docket_number)}
                    </CardTitle>
                    <CardDescription className="mt-3 text-sm text-foreground sm:text-base">
                      {data.compact.violations ?? "No violation recorded"}
                    </CardDescription>
                  </div>

                  <div className="grid gap-3 border-t pt-4 sm:grid-cols-[max-content_minmax(0,14rem)_max-content] sm:gap-x-10">
                    <DetailItem
                      label="Date received"
                      value={formatDate(
                        data.compact.date_received ??
                          data.details.date_received,
                      )}
                    />
                    <DetailItem
                      label="Assigned prosecutor"
                      value={
                        data.compact.prosecutor_full_name ??
                        data.compact.prosecutor_short_name ??
                        "—"
                      }
                    />
                    <DetailItem
                      label="Current status"
                      value={
                        <Badge variant="outline">
                          {data.compact.current_status_label ??
                            data.compact.current_status_code ??
                            "—"}
                        </Badge>
                      }
                    />
                  </div>
                </CardHeader>
              </Card>

              <div className="grid gap-6 xl:grid-cols-[2fr_1fr]">
                <div className="space-y-6">
                  <Card>
                    <CardHeader className="p-4 sm:p-6">
                      <CardTitle>Parties</CardTitle>
                      <CardDescription>
                        Complainants, respondents, and any other schema-backed
                        participant roles.
                      </CardDescription>
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
                                <div
                                  key={participant.id}
                                  className="rounded-lg border p-4"
                                >
                                  <div className="flex items-start justify-between gap-3">
                                    <div>
                                      {participant.persons?.id ? (
                                        <Link
                                          href={`/persons/${participant.persons.id}`}
                                          className="font-medium text-primary hover:underline"
                                        >
                                          {personName(participant)}
                                        </Link>
                                      ) : (
                                        <p className="font-medium">
                                          {personName(participant)}
                                        </p>
                                      )}
                                      <p className="text-sm text-muted-foreground">
                                        {formatPersonDemographics(participant)}
                                      </p>
                                    </div>
                                  </div>
                                  <Separator className="my-3" />
                                  <div className="grid gap-2 text-sm sm:grid-cols-2">
                                    <DetailItem label="Role" value={role} />
                                    <DetailItem
                                      label="Birthdate"
                                      value={formatDate(
                                        participant.persons?.birth_date,
                                      )}
                                    />
                                    <DetailItem
                                      label="Address"
                                      value={primaryAddress(participant)}
                                    />
                                    <DetailItem
                                      label="Case flags"
                                      value={caseSpecificFlags(participant)}
                                    />
                                    <DetailItem
                                      label="Remarks"
                                      value={participant.remarks ?? "—"}
                                    />
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
                      <DetailItem
                        label="Violation/s"
                        value={data.compact.violations ?? "—"}
                      />
                      <DetailItem
                        label="Date received"
                        value={formatDate(data.details.date_received)}
                      />
                      <DetailItem
                        label="Remarks"
                        value={data.details.remarks ?? "—"}
                      />
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Timeline</CardTitle>
                      <CardDescription>
                        Canonical case timeline from v_case_timeline. Expand an
                        event to review complete details.
                      </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <div className="rounded-lg border bg-muted/20 p-4">
                        <h4 className="mb-3 font-medium">Log custom event</h4>
                        <div className="grid gap-4 md:grid-cols-2">
                          <div className="space-y-2">
                            <Label htmlFor="event-date">Event date</Label>
                            <Input id="event-date" value={eventDate} onChange={(event) => setEventDate(event.target.value)} type="date" />
                          </div>
                          <div className="space-y-2">
                            <Label>Event type</Label>
                            <Select value={eventTypeCode} onValueChange={setEventTypeCode}>
                              <SelectTrigger>
                                <SelectValue />
                              </SelectTrigger>
                              <SelectContent>
                                {EVENT_TYPE_CODES.map((code) => (
                                  <SelectItem key={code} value={code}>
                                    {code}
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          </div>
                          <div className="space-y-2 md:col-span-2">
                            <Label htmlFor="event-title">Title</Label>
                            <Input id="event-title" placeholder="e.g. Follow-up conference scheduled" value={eventTitle} onChange={(event) => setEventTitle(event.target.value)} />
                          </div>
                          <div className="space-y-2 md:col-span-2">
                            <Label htmlFor="event-description">Description</Label>
                            <Textarea id="event-description" placeholder="Short timeline summary..." value={eventDescription} onChange={(event) => setEventDescription(event.target.value)} />
                          </div>
                          <div className="space-y-3 md:col-span-2">
                            <div className="flex items-center justify-between">
                              <Label>Custom details (key-value)</Label>
                              <Button variant="outline" size="sm" onClick={addDetailField}>
                                <Plus className="mr-2 h-4 w-4" />
                                Add detail
                              </Button>
                            </div>
                            <div className="space-y-2">
                              {eventDetailFields.map((field) => (
                                <div key={field.id} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]">
                                  <Input placeholder="Field name (e.g. hearing_room)" value={field.key} onChange={(event) => upsertDetailField(field.id, "key", event.target.value)} />
                                  <Input placeholder="Value" value={field.value} onChange={(event) => upsertDetailField(field.id, "value", event.target.value)} />
                                  <Button variant="ghost" size="icon" onClick={() => removeDetailField(field.id)} aria-label="Remove detail row">
                                    <Trash2 className="h-4 w-4" />
                                  </Button>
                                </div>
                              ))}
                            </div>
                          </div>
                        </div>
                        <Button className="mt-3" onClick={handleAddEvent} disabled={isSavingEvent}>
                          {isSavingEvent ? "Saving..." : "Add Event"}
                        </Button>
                      </div>
                      {timelineGroupedByDate.length === 0 ? (
                        <SectionEmpty>No timeline events found.</SectionEmpty>
                      ) : (
                        <div className="space-y-4">
                          {timelineGroupedByDate.map(([dateLabel, events]) => (
                            <div key={dateLabel}>
                              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{dateLabel}</p>
                              <Accordion type="single" collapsible className="space-y-2">
                                {events.map((event) => (
                                  <AccordionItem key={event.case_event_id} value={`event-${event.case_event_id}`} className={`rounded-lg border px-3 ${event.is_voided ? "opacity-60" : ""}`}>
                                    <AccordionTrigger className="py-3 text-left hover:no-underline">
                                      <div className="flex w-full items-start justify-between gap-3">
                                        <div className="min-w-0">
                                          <p className="truncate font-medium">
                                            {event.title ?? event.event_type_label ?? "Untitled event"}
                                          </p>
                                          <p className="line-clamp-2 text-xs text-muted-foreground">
                                            {event.description ?? "No description provided."}
                                          </p>
                                        </div>
                                        <div className="flex shrink-0 flex-wrap items-center gap-2">
                                          <Badge variant="outline">{event.event_type_label ?? event.event_type_code ?? "Event"}</Badge>
                                          {event.needs_review ? <Badge variant="destructive">Needs review</Badge> : null}
                                        </div>
                                      </div>
                                    </AccordionTrigger>
                                    <AccordionContent className="space-y-3 pb-3">
                                      <div className="grid gap-3 sm:grid-cols-2">
                                        <DetailItem label="Date" value={formatDate(event.event_date)} />
                                        <DetailItem label="Status" value={event.status_label ?? "—"} />
                                        <DetailItem label="Prosecutor" value={event.prosecutor_short_name ?? "—"} />
                                        <DetailItem label="Court" value={event.court_name ?? "—"} />
                                      </div>
                                      {event.details_jsonb && typeof event.details_jsonb === "object" ? (
                                        <div className="rounded-md border bg-background p-3">
                                          <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Event details</p>
                                          <div className="grid gap-2 sm:grid-cols-2">
                                            {Object.entries(event.details_jsonb as Record<string, unknown>).map(([key, value]) => (
                                              <DetailItem key={key} label={key.replace(/_/g, " ")} value={String(value ?? "—")} />
                                            ))}
                                          </div>
                                        </div>
                                      ) : null}
                                      <div className="flex items-center justify-between">
                                        {event.is_voided ? (
                                          <p className="text-xs font-medium text-amber-600">Voided event</p>
                                        ) : (
                                          <Button variant="outline" size="sm" onClick={() => handleVoidEvent(event.case_event_id)}>
                                            Void event
                                          </Button>
                                        )}
                                        <p className="text-xs text-muted-foreground">
                                          Source: {event.source_table ?? event.source ?? "—"}
                                        </p>
                                      </div>
                                    </AccordionContent>
                                  </AccordionItem>
                                ))}
                              </Accordion>
                            </div>
                          ))}
                        </div>
                      )}
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Status history</CardTitle>
                      <CardDescription>
                        Current status and recorded prior movements.
                      </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <div className="rounded-lg border p-4">
                        <DetailItem
                          label="Current status"
                          value={
                            data.compact.current_status_label ??
                            data.compact.current_status_code ??
                            "—"
                          }
                        />
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
                                  <TableCell>
                                    {formatDateTime(history.changed_at)}
                                  </TableCell>
                                  <TableCell>
                                    {history.from_status?.display_label ?? "—"}
                                  </TableCell>
                                  <TableCell>
                                    {history.to_status?.display_label ?? "—"}
                                  </TableCell>
                                  <TableCell>
                                    {history.remarks ?? "—"}
                                  </TableCell>
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
                                  <TableCell>
                                    {formatDate(motion.date_received)}
                                  </TableCell>
                                  <TableCell>
                                    {motion.filed_by ?? "—"}
                                  </TableCell>
                                  <TableCell>
                                    {motion.motion_status ?? "—"}
                                  </TableCell>
                                  <TableCell>{motion.remarks ?? "—"}</TableCell>
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
                      <DetailItem
                        label="Current prosecutor"
                        value={
                          data.compact.prosecutor_full_name ??
                          data.compact.prosecutor_short_name ??
                          "—"
                        }
                      />
                      <DetailItem
                        label="Date assigned"
                        value={formatDate(data.compact.current_assigned_at)}
                      />
                      {data.assignments.length === 0 ? (
                        <SectionEmpty />
                      ) : (
                        <div className="space-y-3">
                          {data.assignments.map((assignment) => (
                            <div
                              key={assignment.id}
                              className="rounded-lg border p-3 text-sm"
                            >
                              <p className="font-medium">
                                {assignment.prosecutors?.full_name ??
                                  "Unrecorded prosecutor"}
                              </p>
                              <p className="text-muted-foreground">
                                Assigned{" "}
                                {formatDateTime(assignment.assigned_at)}
                              </p>
                              <p className="text-muted-foreground">
                                Staff: {assignment.staff?.full_name ?? "—"}
                              </p>
                              {assignment.unassigned_at ? (
                                <p className="text-muted-foreground">
                                  Unassigned{" "}
                                  {formatDateTime(assignment.unassigned_at)}
                                </p>
                              ) : null}
                              {assignment.remarks ? (
                                <p className="mt-2">{assignment.remarks}</p>
                              ) : null}
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
                      <DetailItem
                        label="Court"
                        value={data.compact.court_codes ?? "—"}
                      />
                      <DetailItem
                        label="Criminal case #"
                        value={data.compact.criminal_case_numbers ?? "—"}
                      />
                      <DetailItem
                        label="Charge filed"
                        value={joinedValues(
                          data.courtDetails.map((court) => court.charge_filed),
                        )}
                      />
                      <DetailItem
                        label="Date filed in court"
                        value={joinedDates(
                          data.courtDetails.map(
                            (court) => court.date_filed_in_court,
                          ),
                        )}
                      />
                      <DetailItem
                        label="Court review"
                        value={
                          data.compact.court_needs_review ? "Needs review" : "—"
                        }
                      />
                    </CardContent>
                  </Card>

                  <Card>
                    <CardHeader>
                      <CardTitle>Attachments</CardTitle>
                      <CardDescription>
                        Google Drive folder and indexed file records, when
                        available.
                      </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      {data.details.gdrive_folder_link ? (
                        <Button variant="outline" asChild>
                          <a
                            href={data.details.gdrive_folder_link}
                            target="_blank"
                            rel="noreferrer"
                          >
                            Open Google Drive folder
                            <ExternalLink className="ml-2 h-4 w-4" />
                          </a>
                        </Button>
                      ) : null}

                      {data.attachments.length === 0 ? (
                        <SectionEmpty>
                          Attachments integration not yet connected.
                        </SectionEmpty>
                      ) : (
                        <div className="space-y-3">
                          {data.attachments.map((attachment) => (
                            <div
                              key={attachment.id}
                              className="rounded-lg border p-3 text-sm"
                            >
                              <div className="flex items-start justify-between gap-3">
                                <div className="min-w-0">
                                  <p className="truncate font-medium">
                                    {attachment.file_name}
                                  </p>
                                  <p className="text-muted-foreground">
                                    {formatFileSize(attachment.file_size_bytes)}{" "}
                                    • {attachment.file_status}
                                  </p>
                                </div>
                                {attachment.web_view_link ? (
                                  <Button variant="ghost" size="sm" asChild>
                                    <a
                                      href={attachment.web_view_link}
                                      target="_blank"
                                      rel="noreferrer"
                                      aria-label={`Open ${attachment.file_name}`}
                                    >
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
