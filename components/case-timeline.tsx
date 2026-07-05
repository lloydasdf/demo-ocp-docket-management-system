"use client";

import type React from "react";
import { useMemo, useState } from "react";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  type CaseCourtRecord,
  type CaseMotionRecord,
  type CasePetitionForReviewRecord,
  type CaseTimelineEventRecord,
  type CaseEventTypeReference,
  createCaseEvent,
  editCaseEvent,
  getCaseEventTypes,
  voidCaseEvent,
} from "@/lib/supabase/queries";

export type CaseTimelineProps = {
  caseId: number;
  events: CaseTimelineEventRecord[];
  courts?: CaseCourtRecord[];
  motions?: CaseMotionRecord[];
  petitionsForReview?: CasePetitionForReviewRecord[];
  onChanged?: () => void | Promise<void>;
  onAssignReassign?: () => void;
  onUpdateStatus?: () => void;
};

function toDateInputValue(value: string | null | undefined) {
  return value?.slice(0, 10) ?? "";
}

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

function formatOptionalDate(
  value: string | null | undefined,
  rawValue?: string | null,
) {
  return firstDisplayValue(rawValue, value ? formatDate(value) : null);
}

function firstDisplayValue(...values: (string | number | null | undefined)[]) {
  return values.find((value) => value !== null && value !== undefined && String(value).trim() !== "");
}

function hasDetailValue(value: React.ReactNode) {
  return value !== null && value !== undefined && value !== "" && value !== "—";
}

function SectionEmpty({ children = "No records yet." }: { children?: string }) {
  return (
    <p className="rounded-md border border-dashed p-4 text-sm text-muted-foreground">
      {children}
    </p>
  );
}

function OptionalDetailItem({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  if (!hasDetailValue(value)) {
    return null;
  }

  return <DetailItem label={label} value={value} />;
}

function isMotionForReconsideration(event: CaseTimelineEventRecord) {
  const text = `${event.title ?? ""} ${event.event_type_label ?? ""} ${event.event_type_code ?? ""}`.toLowerCase();
  return text.includes("motion for reconsideration");
}

function eventRemarks(event: CaseTimelineEventRecord) {
  if (event.details_jsonb && typeof event.details_jsonb === "object") {
    const details = event.details_jsonb as Record<string, unknown>;
    const remarks = details.remarks ?? details.remark ?? details.notes;

    if (remarks !== null && remarks !== undefined && String(remarks).trim()) {
      return String(remarks);
    }
  }

  return event.description;
}


function stringDetail(value: unknown) {
  if (value === null || value === undefined || !String(value).trim()) {
    return null;
  }

  return String(value);
}

function assignmentEventDetails(event: CaseTimelineEventRecord) {
  if (eventSourceTable(event) !== "case_assignments") {
    return null;
  }

  const details = event.details_jsonb && typeof event.details_jsonb === "object"
    ? event.details_jsonb as Record<string, unknown>
    : {};

  return [
    { label: "Previous Prosecutor", value: stringDetail(details.previous_prosecutor_name) },
    { label: "New Prosecutor", value: stringDetail(details.new_prosecutor_name) ?? event.prosecutor_short_name },
    { label: "Reason", value: stringDetail(details.reason) },
    { label: "Remarks", value: stringDetail(details.remarks) ?? event.description },
  ];
}

function isCourtSourceEvent(event: CaseTimelineEventRecord) {
  return eventSourceTable(event).includes("case_courts");
}

function isPetitionForReviewEvent(event: CaseTimelineEventRecord) {
  return event.event_type_code === "PETITION_FOR_REVIEW";
}

function isPetitionForReviewSourceEvent(event: CaseTimelineEventRecord) {
  return (
    isPetitionForReviewEvent(event) &&
    eventSourceTable(event) === "case_petitions_for_review"
  );
}

function timelineDetailItems(event: CaseTimelineEventRecord) {
  if (isPetitionForReviewEvent(event)) {
    return [];
  }

  if (event.event_type_code === "CASE_RECEIVED") {
    return [{ label: "Date", value: formatDate(event.event_date) }];
  }

  const assignmentDetails = assignmentEventDetails(event);
  if (assignmentDetails) {
    return [
      { label: "Date", value: formatDate(event.event_date) },
      ...assignmentDetails,
    ];
  }

  if (isMotionForReconsideration(event)) {
    return [{ label: "Date", value: formatDate(event.event_date) }];
  }

  const details = [
    { label: "Date", value: formatDate(event.event_date) },
    { label: "Status", value: event.status_label },
    { label: "Prosecutor", value: event.prosecutor_short_name },
  ];

  if (!isCourtSourceEvent(event)) {
    details.push({ label: "Court", value: event.court_name });
  }

  return details;
}

function visibleEventDetails(event: CaseTimelineEventRecord) {
  if (isPetitionForReviewEvent(event) || !event.details_jsonb || typeof event.details_jsonb !== "object") {
    return [];
  }

  const hiddenKeys = event.event_type_code === "CASE_RECEIVED"
    ? new Set(Object.keys(event.details_jsonb as Record<string, unknown>))
    : eventSourceTable(event) === "case_assignments"
      ? new Set(["action", "previous_assignment_id", "new_assignment_id", "previous_prosecutor_id", "new_prosecutor_id", "previous_prosecutor_name", "new_prosecutor_name", "voided_assignment_id", "voided_event_id", "reason", "remarks"])
      : isMotionForReconsideration(event)
        ? new Set(["status", "status_label", "prosecutor", "prosecutor_short_name", "court", "court_name"])
        : new Set<string>();

  return Object.entries(event.details_jsonb as Record<string, unknown>).filter(
    ([key, value]) => !hiddenKeys.has(key) && hasDetailValue(value === null || value === undefined ? null : String(value)),
  );
}

function eventSourceTable(event: CaseTimelineEventRecord) {
  return (event.source_table ?? "").toLowerCase();
}

function sourceIdMatches(event: CaseTimelineEventRecord, id: number) {
  return event.source_id !== null && event.source_id !== undefined && Number(event.source_id) === Number(id);
}

function eventText(event: CaseTimelineEventRecord) {
  return `${event.title ?? ""} ${event.description ?? ""} ${event.event_type_label ?? ""}`.toLowerCase();
}

function sameDate(left: string | null | undefined, right: string | null | undefined) {
  return Boolean(left && right && left === right);
}

function eventCourtDetails(event: CaseTimelineEventRecord, courts: CaseCourtRecord[]) {
  if (!isCourtSourceEvent(event)) {
    return null;
  }

  const exactSourceCourt = courts.find((court) => sourceIdMatches(event, court.id));

  if (exactSourceCourt) {
    return exactSourceCourt;
  }

  return (
    courts.find(
      (court) =>
        sameDate(court.date_filed_in_court, event.event_date) ||
        sameDate(court.actual_filing_date, event.event_date),
    ) ??
    (courts.length === 1 ? courts[0] : null)
  );
}

function eventMotionDetails(event: CaseTimelineEventRecord, motions: CaseMotionRecord[]) {
  const sourceTable = eventSourceTable(event);

  if (!sourceTable.includes("case_motions") && !isMotionForReconsideration(event)) {
    return null;
  }

  const exactSourceMotion = motions.find((motion) => sourceIdMatches(event, motion.id));

  if (exactSourceMotion) {
    return exactSourceMotion;
  }

  const text = eventText(event);

  return (
    motions.find((motion) => {
      const motionName = motion.motion_name.toLowerCase();
      const nameMatches = text.includes(motionName) || motionName.includes(text.trim());
      const dateMatches =
        sameDate(motion.date_received, event.event_date) ||
        sameDate(motion.date_resolved, event.event_date) ||
        sameDate(motion.date_approved, event.event_date);

      return nameMatches || dateMatches;
    }) ??
    (motions.length === 1 ? motions[0] : null)
  );
}

function eventPetitionForReviewDetails(
  event: CaseTimelineEventRecord,
  petitionsForReview: CasePetitionForReviewRecord[],
) {
  if (!isPetitionForReviewSourceEvent(event)) {
    return null;
  }

  return petitionsForReview.find((petition) => sourceIdMatches(event, petition.id)) ?? null;
}

function petitionTitle(
  event: CaseTimelineEventRecord,
  petition: CasePetitionForReviewRecord | null,
) {
  return firstDisplayValue(
    petition?.petition_title,
    event.title,
    event.event_type_label,
    "Petition for Review",
  );
}

function petitionSubtitle(petition: CasePetitionForReviewRecord | null) {
  if (!petition) {
    return null;
  }

  const dateReceived = formatOptionalDate(petition.date_received, petition.date_received_raw);
  const dateResolved = formatOptionalDate(petition.date_resolved, petition.date_resolved_raw);
  const dateApproved = formatOptionalDate(petition.date_approved, petition.date_approved_raw);
  const parts = [
    petition.filed_by ? `Filed by ${petition.filed_by}` : null,
    petition.petition_status,
    dateReceived ? `Received ${dateReceived}` : null,
    dateResolved ? `Resolved ${dateResolved}` : null,
    dateApproved ? `Approved ${dateApproved}` : null,
  ].filter((part): part is string => Boolean(part));

  return parts.length > 0 ? parts.join(" • ") : null;
}

function timelineTitle(
  event: CaseTimelineEventRecord,
  petition: CasePetitionForReviewRecord | null,
) {
  if (isPetitionForReviewEvent(event)) {
    return petitionTitle(event, petition);
  }

  return event.title ?? event.event_type_label ?? "Untitled event";
}

function timelineSubtitle(
  event: CaseTimelineEventRecord,
  petition: CasePetitionForReviewRecord | null,
) {
  if (isPetitionForReviewEvent(event)) {
    return petitionSubtitle(petition) ?? event.description ?? "Petition for Review";
  }

  return event.description ?? "No description provided.";
}

function PetitionForReviewEventDetails({
  petition,
}: {
  petition: CasePetitionForReviewRecord;
}) {
  const details = [
    { label: "Handling Prosecutor", value: petition.handling_prosecutor_text },
    { label: "Filed By", value: petition.filed_by },
    { label: "Status", value: petition.petition_status },
    { label: "Date Received", value: formatOptionalDate(petition.date_received, petition.date_received_raw) },
    { label: "Date Resolved", value: formatOptionalDate(petition.date_resolved, petition.date_resolved_raw) },
    { label: "Date Approved", value: formatOptionalDate(petition.date_approved, petition.date_approved_raw) },
    { label: "Remarks", value: petition.remarks },
  ].filter((detail) => hasDetailValue(detail.value));

  if (details.length === 0) {
    return null;
  }

  return (
    <div className="rounded-md border bg-background p-3">
      <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
        Petition for review details
      </p>
      <div className="grid gap-3 sm:grid-cols-2">
        {details.map((detail) => (
          <DetailItem key={detail.label} label={detail.label} value={detail.value} />
        ))}
      </div>
    </div>
  );
}

function CourtEventDetails({ court }: { court: CaseCourtRecord }) {
  return (
    <div className="rounded-md border bg-background p-3">
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          Court source details
        </p>
        {court.needs_review ? <Badge variant="secondary">Needs review</Badge> : null}
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <OptionalDetailItem label="Court code" value={court.courts?.code} />
        <OptionalDetailItem label="Branch" value={court.court_branch} />
        <OptionalDetailItem label="Criminal case no." value={court.criminal_case_number} />
        <OptionalDetailItem label="Charge filed" value={court.charge_filed} />
        <OptionalDetailItem label="Court status" value={court.court_status} />
        <OptionalDetailItem label="Date filed in court" value={formatDate(court.date_filed_in_court)} />
        <OptionalDetailItem label="Actual filing date" value={formatDate(court.actual_filing_date)} />
        <OptionalDetailItem label="Information count" value={court.information_count} />
        <OptionalDetailItem label="Remarks" value={court.court_remarks} />
      </div>
    </div>
  );
}

function MotionEventDetails({ motion }: { motion: CaseMotionRecord }) {
  return (
    <div className="rounded-md border bg-background p-3">
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          Motion source details
        </p>
        {firstDisplayValue(motion.motion_status_raw, motion.motion_status) ? (
          <Badge variant="outline">
            {firstDisplayValue(motion.motion_status_raw, motion.motion_status)}
          </Badge>
        ) : null}
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <OptionalDetailItem label="Motion" value={motion.motion_name} />
        <OptionalDetailItem label="Motion order" value={motion.motion_order} />
        <OptionalDetailItem label="Date received" value={firstDisplayValue(motion.date_received_raw, formatDate(motion.date_received))} />
        <OptionalDetailItem label="Date resolved" value={firstDisplayValue(motion.date_resolved_raw, formatDate(motion.date_resolved))} />
        <OptionalDetailItem label="Date approved" value={firstDisplayValue(motion.date_approved_raw, formatDate(motion.date_approved))} />
        <OptionalDetailItem label="Filed by" value={firstDisplayValue(motion.filed_by_raw, motion.filed_by)} />
        <OptionalDetailItem label="Remarks" value={firstDisplayValue(motion.remarks_raw, motion.remarks)} />
      </div>
    </div>
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

const ADD_EVENT_TYPE_CODES = new Set([
  "CASE_ASSIGNMENT",
  "CASE_REASSIGNMENT",
  "CASE_RESOLVED",
  "CASE_DECISION_APPROVED",
  "COURT_FILING",
  "COURT_STATUS_UPDATE",
  "MOTION_RECEIVED",
  "MOTION_RESOLVED",
  "MOTION_DECISION_APPROVED",
  "PETITION_FOR_REVIEW",
  "CUSTOM_EVENT",
  "ADD_EVENT_TYPE",
]);

function addableEventTypes(eventTypes: CaseEventTypeReference[]) {
  return eventTypes.filter((eventType) => ADD_EVENT_TYPE_CODES.has(eventType.code));
}

export function CaseTimeline({
  caseId,
  courts = [],
  events,
  motions = [],
  onAssignReassign,
  onChanged,
  onUpdateStatus,
  petitionsForReview = [],
}: CaseTimelineProps) {
  const [showVoided, setShowVoided] = useState(false);
  const [editingEvent, setEditingEvent] = useState<CaseTimelineEventRecord | null>(null);
  const [voidingEvent, setVoidingEvent] = useState<CaseTimelineEventRecord | null>(null);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [eventTypes, setEventTypes] = useState<CaseEventTypeReference[]>([]);
  const [eventTypesError, setEventTypesError] = useState<string | null>(null);
  const [addForm, setAddForm] = useState({ eventTypeCode: "", eventDate: new Date().toISOString().slice(0, 10), title: "", description: "" });
  const [editForm, setEditForm] = useState({ eventDate: "", title: "", description: "", editReason: "" });
  const [voidReason, setVoidReason] = useState("");
  const [voidConfirmed, setVoidConfirmed] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);


  const openAddDialog = async () => {
    setActionError(null);
    setEventTypesError(null);
    setAddForm({ eventTypeCode: addableEventTypes(eventTypes)[0]?.code ?? "", eventDate: new Date().toISOString().slice(0, 10), title: "", description: "" });
    setIsAddDialogOpen(true);

    if (eventTypes.length === 0) {
      const result = await getCaseEventTypes();
      if (result.error) {
        setEventTypesError(result.error.message);
        return;
      }

      const filteredEventTypes = addableEventTypes(result.data);
      setEventTypes(filteredEventTypes);
      setAddForm((form) => ({ ...form, eventTypeCode: form.eventTypeCode || filteredEventTypes[0]?.code || "" }));
    }
  };

  const handleAddSave = async () => {
    if (!addForm.eventTypeCode || !addForm.eventDate || !addForm.title.trim()) return;
    setIsSaving(true);
    setActionError(null);
    const result = await createCaseEvent({
      caseId,
      eventTypeCode: addForm.eventTypeCode,
      eventDate: addForm.eventDate,
      title: addForm.title,
      description: addForm.description,
      detailsJson: {},
    });
    setIsSaving(false);
    if (result.error) {
      setActionError(result.error.message);
      return;
    }
    setIsAddDialogOpen(false);
    await onChanged?.();
  };

  const openEditDialog = (event: CaseTimelineEventRecord) => {
    if (event.is_voided) return;
    setActionError(null);
    setEditingEvent(event);
    setEditForm({
      eventDate: toDateInputValue(event.event_date),
      title: event.title ?? "",
      description: event.description ?? "",
      editReason: "",
    });
  };

  const openVoidDialog = (event: CaseTimelineEventRecord) => {
    if (event.is_voided) return;
    setActionError(null);
    setVoidReason("");
    setVoidConfirmed(false);
    setVoidingEvent(event);
  };

  const handleEditSave = async () => {
    if (!editingEvent || !editForm.eventDate || !editForm.title.trim() || !editForm.editReason.trim()) return;
    setIsSaving(true);
    setActionError(null);
    const result = await editCaseEvent({
      caseEventId: editingEvent.case_event_id,
      eventDate: editForm.eventDate,
      title: editForm.title,
      description: editForm.description,
      detailsJsonb: editingEvent.details_jsonb,
      editReason: editForm.editReason,
    });
    setIsSaving(false);
    if (result.error) {
      setActionError(result.error.message);
      return;
    }
    setEditingEvent(null);
    await onChanged?.();
  };

  const handleVoidSave = async () => {
    if (!voidingEvent || !voidReason.trim() || !voidConfirmed) return;
    setIsSaving(true);
    setActionError(null);
    const result = await voidCaseEvent(voidingEvent.case_event_id, voidReason);
    setIsSaving(false);
    if (result.error) {
      setActionError(result.error.message);
      return;
    }
    setVoidingEvent(null);
    await onChanged?.();
  };

  const visibleEvents = useMemo(() => events.filter((event) => showVoided || !event.is_voided), [events, showVoided]);
  const timelineGroupedByDate = useMemo(() => {
    const grouped = new Map<string, CaseTimelineEventRecord[]>();

    for (const event of visibleEvents) {
      const dateLabel = event.event_date ? formatDate(event.event_date) : "No date";
      grouped.set(dateLabel, [...(grouped.get(dateLabel) ?? []), event]);
    }

    return Array.from(grouped.entries());
  }, [visibleEvents]);

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <CardTitle>Timeline</CardTitle>
          <label className="flex items-center gap-2 text-sm text-muted-foreground">
            <Checkbox checked={showVoided} onCheckedChange={(checked) => setShowVoided(checked === true)} />
            Show voided activities
          </label>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {timelineGroupedByDate.length === 0 ? (
          <SectionEmpty>No timeline events found.</SectionEmpty>
        ) : (
          <div className="space-y-4">
            {timelineGroupedByDate.map(([dateLabel, groupedEvents]) => (
              <div key={dateLabel}>
                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  {dateLabel}
                </p>
                <Accordion
                  type="single"
                  collapsible
                  className="relative ml-2 space-y-3 border-l border-border pl-6"
                >
                  {groupedEvents.map((event) => {
                    const courtDetails = eventCourtDetails(event, courts);
                    const motionDetails = eventMotionDetails(event, motions);
                    const petitionDetails = eventPetitionForReviewDetails(
                      event,
                      petitionsForReview,
                    );
                    const detailItems = timelineDetailItems(event);

                    return (
                      <div key={event.case_event_id} className="relative">
                        <span
                          aria-hidden="true"
                          className="absolute -left-[33px] top-4 flex h-5 w-5 items-center justify-center rounded-full border-2 border-primary bg-background shadow-sm"
                        >
                          <span className="h-2 w-2 rounded-full bg-primary" />
                        </span>
                        <AccordionItem
                          value={`event-${event.case_event_id}`}
                          className={`rounded-lg border px-3 ${event.is_voided ? "opacity-60" : ""}`}
                        >
                          <AccordionTrigger className="py-3 text-left hover:no-underline">
                            <div className="flex w-full items-start justify-between gap-3">
                              <div className="min-w-0">
                                <p className="truncate font-medium">
                                  {timelineTitle(event, petitionDetails)}
                                  {event.is_voided ? <Badge variant="destructive" className="ml-2">VOIDED</Badge> : null}
                                </p>
                                <p className="line-clamp-2 text-xs text-muted-foreground">
                                  {timelineSubtitle(event, petitionDetails)}
                                </p>
                              </div>
                            </div>
                          </AccordionTrigger>
                          <AccordionContent className="space-y-3 pb-3">
                            {!event.is_voided ? (
                              <div className="flex gap-2">
                                <Button type="button" variant="outline" size="sm" onClick={() => openEditDialog(event)}>Edit</Button>
                                <Button type="button" variant="destructive" size="sm" onClick={() => openVoidDialog(event)}>Void</Button>
                              </div>
                            ) : (
                              <div className="rounded-md border border-destructive/30 bg-destructive/5 p-3 text-sm">
                                <p className="font-medium text-destructive">VOIDED</p>
                                <p className="text-muted-foreground">Reason: {event.void_reason ?? "—"}</p>
                                <p className="text-muted-foreground">Voided: {formatDate(event.voided_at)} by {event.voided_by_email ?? "—"}</p>
                              </div>
                            )}
                            {detailItems.length > 0 ? (
                              <div className="grid gap-3 sm:grid-cols-2">
                                {detailItems.map((detail) => (
                                  <OptionalDetailItem
                                    key={detail.label}
                                    label={detail.label}
                                    value={detail.value}
                                  />
                                ))}
                              </div>
                            ) : null}
                            {visibleEventDetails(event).length > 0 ? (
                              <div className="rounded-md border bg-background p-3">
                                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                                  Event details
                                </p>
                                <div className="grid gap-2 sm:grid-cols-2">
                                  {visibleEventDetails(event).map(([key, value]) => (
                                    <DetailItem
                                      key={key}
                                      label={key.replace(/_/g, " ")}
                                      value={String(value)}
                                    />
                                  ))}
                                </div>
                              </div>
                            ) : null}
                            {courtDetails ? <CourtEventDetails court={courtDetails} /> : null}
                            {motionDetails ? <MotionEventDetails motion={motionDetails} /> : null}
                            {petitionDetails ? (
                              <PetitionForReviewEventDetails petition={petitionDetails} />
                            ) : null}
                          </AccordionContent>
                        </AccordionItem>
                      </div>
                    );
                  })}
                </Accordion>
              </div>
            ))}
          </div>
        )}
        <div className="flex flex-wrap justify-end gap-2 border-t pt-4">
          <Button type="button" variant="outline" onClick={onUpdateStatus}>Update Status</Button>
          <Button type="button" variant="outline" onClick={onAssignReassign}>Assign / Reassign</Button>
          <Button type="button" onClick={openAddDialog}>Add Event</Button>
        </div>
      </CardContent>

      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add event</DialogTitle>
            <DialogDescription>Add a new activity to this case timeline.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {eventTypesError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{eventTypesError}</p> : null}
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            <div className="space-y-2">
              <Label htmlFor="add-event-type">Event Type</Label>
              <select id="add-event-type" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.eventTypeCode} onChange={(e) => setAddForm((form) => ({ ...form, eventTypeCode: e.target.value }))}>
                {eventTypes.map((eventType) => <option key={eventType.code} value={eventType.code}>{eventType.display_label}</option>)}
              </select>
            </div>
            <div className="space-y-2"><Label htmlFor="add-event-date">Event Date</Label><Input id="add-event-date" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div>
            <div className="space-y-2"><Label htmlFor="add-event-title">Title</Label><Input id="add-event-title" value={addForm.title} onChange={(e) => setAddForm((form) => ({ ...form, title: e.target.value }))} /></div>
            <div className="space-y-2"><Label htmlFor="add-event-description">Description / Remarks</Label><Textarea id="add-event-description" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setIsAddDialogOpen(false)}>Cancel</Button>
            <Button type="button" onClick={handleAddSave} disabled={isSaving || !addForm.eventTypeCode || !addForm.eventDate || !addForm.title.trim()}>{isSaving ? "Saving..." : "Add event"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={Boolean(editingEvent)} onOpenChange={(open) => !open && setEditingEvent(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit activity</DialogTitle>
            <DialogDescription>Update this case timeline activity and record an audit reason.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            <div className="space-y-2"><Label htmlFor="event-date">Event Date</Label><Input id="event-date" type="date" value={editForm.eventDate} onChange={(e) => setEditForm((form) => ({ ...form, eventDate: e.target.value }))} /></div>
            <div className="space-y-2"><Label htmlFor="event-title">Title</Label><Input id="event-title" value={editForm.title} onChange={(e) => setEditForm((form) => ({ ...form, title: e.target.value }))} /></div>
            <div className="space-y-2"><Label htmlFor="event-description">Description / Remarks</Label><Textarea id="event-description" value={editForm.description} onChange={(e) => setEditForm((form) => ({ ...form, description: e.target.value }))} /></div>
            <div className="space-y-2"><Label htmlFor="edit-reason">Reason for Edit</Label><Textarea id="edit-reason" required value={editForm.editReason} onChange={(e) => setEditForm((form) => ({ ...form, editReason: e.target.value }))} /></div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setEditingEvent(null)}>Cancel</Button>
            <Button type="button" onClick={handleEditSave} disabled={isSaving || !editForm.eventDate || !editForm.title.trim() || !editForm.editReason.trim()}>{isSaving ? "Saving..." : "Save"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={Boolean(voidingEvent)} onOpenChange={(open) => !open && setVoidingEvent(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Void activity</DialogTitle>
            <DialogDescription>{voidingEvent ? `${timelineTitle(voidingEvent, null)} • ${formatDate(voidingEvent.event_date)}` : "Confirm this activity should be voided."}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            <div className="space-y-2"><Label htmlFor="void-reason">Void Reason</Label><Textarea id="void-reason" required value={voidReason} onChange={(e) => setVoidReason(e.target.value)} /></div>
            <label className="flex items-center gap-2 text-sm"><Checkbox checked={voidConfirmed} onCheckedChange={(checked) => setVoidConfirmed(checked === true)} />I understand this activity will be voided.</label>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setVoidingEvent(null)}>Cancel</Button>
            <Button type="button" variant="destructive" onClick={handleVoidSave} disabled={isSaving || !voidReason.trim() || !voidConfirmed}>{isSaving ? "Voiding..." : "Void activity"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
