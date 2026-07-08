"use client";

import type React from "react";
import { useEffect, useMemo, useState } from "react";

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
  type CaseAssignmentRecord,
  type CaseResolutionApprovalActionInput,
  type CaseResolutionChargeInput,
  getCaseResolutionsWithActions,
  type CaseResolutionWithActionsRecord,
  type CaseViolationManagementRecord,
  createCaseEvent,
  getCaseAssignments,
  getCaseManagedViolations,
  getViolations,
  getProsecutors,
  getStaff,
  recordCaseAssignmentEvent,
  recordCaseReassignmentEvent,
  recordCaseResolvedEvent,
  recordCaseDecisionApprovedEvent,
  getAvailableCourtFilingDecisions,
  getCourts,
  type CourtFilingDecisionRecord,
  type CourtReferenceRecord,
  recordCourtFilingEvent,
  editCaseEvent,
  getCaseEventTypes,
  voidCaseEvent,
} from "@/lib/supabase/queries";
import type { TableRow } from "@/lib/supabase/types";

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

function formatDateTimeDate(value: string | null | undefined) {
  return value ? formatDate(value) : null;
}

function formatDateTimeTime(value: string | null | undefined) {
  if (!value) {
    return null;
  }

  const parsedDate = new Date(value);
  if (Number.isNaN(parsedDate.getTime())) {
    return null;
  }

  return parsedDate.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function formatTime(value: string | null | undefined) {
  if (!value) {
    return null;
  }

  const [hours, minutes] = value.split(":");
  if (!hours || !minutes) {
    return value;
  }

  const parsedDate = new Date();
  parsedDate.setHours(Number(hours), Number(minutes), 0, 0);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
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


function resolutionEventDetails(event: CaseTimelineEventRecord) {
  if (event.event_type_code !== "CASE_RESOLVED") {
    return null;
  }

  const details = event.details_jsonb && typeof event.details_jsonb === "object"
    ? event.details_jsonb as Record<string, unknown>
    : {};
  const chargeActions = Array.isArray(details.charge_actions) ? details.charge_actions as Record<string, unknown>[] : [];
  const filingCharges = chargeActions
    .filter((charge) => charge.action_code === "FOR_FILING")
    .map((charge) => stringDetail(charge.charge_text))
    .filter(Boolean)
    .join("; ");
  const dismissalCharges = chargeActions
    .filter((charge) => charge.action_code === "DISMISSAL")
    .map((charge) => stringDetail(charge.charge_text))
    .filter(Boolean)
    .join("; ");

  return [
    { label: "Recommendation", value: stringDetail(details.recommendation_label) },
    { label: "Date Resolved", value: formatDate(event.event_date) },
    { label: "Time Resolved", value: formatTime(event.event_time) },
    { label: "Charges for Filing", value: filingCharges },
    { label: "Charges for Dismissal", value: dismissalCharges },
    { label: "Remarks", value: stringDetail(details.remarks) },
  ];
}

function courtFilingEventDetails(event: CaseTimelineEventRecord) {
  if (event.event_type_code !== "COURT_FILING" && eventSourceTable(event) !== "case_court_filings") return null;
  const details = event.details_jsonb && typeof event.details_jsonb === "object" ? event.details_jsonb as Record<string, unknown> : {};
  return [
    { label: "Court", value: stringDetail(details.court) ?? event.court_name },
    { label: "Court Branch", value: stringDetail(details.court_branch) },
    { label: "Charge Filed", value: stringDetail(details.charge_filed) },
    { label: "Date Filed", value: formatDate(stringDetail(details.date_filed) ?? event.event_date) },
    { label: "Time Filed", value: formatTime(stringDetail(details.time_filed) ?? event.event_time) },
    { label: "Information Count", value: stringDetail(details.information_count) },
    { label: "Criminal Case No.", value: stringDetail(details.criminal_case_no) },
    { label: "Remarks", value: stringDetail(details.remarks) },
  ];
}

function approvalEventDetails(event: CaseTimelineEventRecord) {
  if (event.event_type_code !== "CASE_DECISION_APPROVED") {
    return null;
  }

  const details = event.details_jsonb && typeof event.details_jsonb === "object"
    ? event.details_jsonb as Record<string, unknown>
    : {};
  const approvalActions = Array.isArray(details.approval_actions) ? details.approval_actions as Record<string, unknown>[] : [];
  const filingDecisions = approvalActions
    .filter((action) => action.decision_code === "FOR_FILING")
    .map((action) => stringDetail(action.charge_text))
    .filter(Boolean)
    .join("; ");
  const dismissedDecisions = approvalActions
    .filter((action) => action.decision_code === "DISMISSAL")
    .map((action) => stringDetail(action.charge_text))
    .filter(Boolean)
    .join("; ");

  return [
    { label: "Approved By", value: stringDetail(details.approved_by_name) },
    { label: "Date Approved", value: formatDate(event.event_date) },
    { label: "Time Approved", value: formatTime(event.event_time) },
    { label: "Final Status", value: stringDetail(details.final_status_label) },
    { label: "Decisions For Filing", value: filingDecisions },
    { label: "Decisions Dismissed", value: dismissedDecisions },
    { label: "Remarks", value: stringDetail(details.remarks) },
  ];
}

function isAssignmentEvent(event: CaseTimelineEventRecord) {
  return eventSourceTable(event) === "case_assignments" || event.event_type_code === "CASE_ASSIGNMENT" || event.event_type_code === "CASE_REASSIGNMENT";
}

function assignmentEventDetails(event: CaseTimelineEventRecord, assignment?: CaseAssignmentRecord | null) {
  if (!isAssignmentEvent(event)) {
    return null;
  }

  const details = event.details_jsonb && typeof event.details_jsonb === "object"
    ? event.details_jsonb as Record<string, unknown>
    : {};

  const unassignmentReason = assignment && "unassignment_reason" in assignment
    ? stringDetail(assignment.unassignment_reason)
    : null;

  return [
    { label: "Assigned prosecutor", value: stringDetail(details.new_prosecutor_name) ?? event.prosecutor_short_name },
    { label: "Assignment date", value: formatDate(event.event_date) },
    { label: "Assignment time", value: formatTime(event.event_time) },
    { label: "Assigned staff", value: stringDetail(details.staff_name) ?? event.staff_short_name },
    { label: "Unassigned date", value: formatDateTimeDate(assignment?.unassigned_at) },
    { label: "Unassigned time", value: formatDateTimeTime(assignment?.unassigned_at) },
    { label: "Unassignment reason", value: unassignmentReason },
    { label: "Remarks", value: stringDetail(details.remarks) },
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

function timelineDetailItems(event: CaseTimelineEventRecord, assignment?: CaseAssignmentRecord | null) {
  if (isPetitionForReviewEvent(event)) {
    return [];
  }

  if (event.event_type_code === "CASE_RECEIVED") {
    return [{ label: "Date", value: formatDate(event.event_date) }];
  }

  const resolutionDetails = resolutionEventDetails(event);
  if (resolutionDetails) {
    return resolutionDetails;
  }

  const approvalDetails = approvalEventDetails(event);
  if (approvalDetails) {
    return approvalDetails;
  }

  const courtFilingDetails = courtFilingEventDetails(event);
  if (courtFilingDetails) {
    return courtFilingDetails;
  }

  const assignmentDetails = assignmentEventDetails(event, assignment);
  if (assignmentDetails) {
    return assignmentDetails;
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
    : event.event_type_code === "CASE_RESOLVED" || event.event_type_code === "CASE_DECISION_APPROVED" || event.event_type_code === "COURT_FILING"
      ? new Set(Object.keys(event.details_jsonb as Record<string, unknown>))
      : eventSourceTable(event) === "case_assignments"
      ? new Set(Object.keys(event.details_jsonb as Record<string, unknown>))
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
    return petitionSubtitle(petition) ?? event.description ?? null;
  }

  return event.description;
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

function emptyResolutionCharge(): CaseResolutionChargeInput {
  return { chargeText: "", caseViolationId: null, violationId: null };
}

function emptyApprovalAction(): CaseResolutionApprovalActionInput {
  return { chargeText: "", caseViolationId: null, violationId: null, sourceResolutionChargeActionId: null, decisionCode: "FOR_FILING" };
}

function caseViolationChargeText(caseViolation: CaseViolationManagementRecord) {
  return firstDisplayValue(
    caseViolation.raw_violation_text,
    caseViolation.violations?.short_label,
    caseViolation.violations?.title,
    caseViolation.violations?.description,
  )?.toString() ?? "";
}

function violationOptionText(violation: Pick<TableRow<"violations">, "title" | "short_label" | "reference_code" | "law_reference">) {
  return [violation.short_label ?? violation.title, violation.reference_code ?? violation.law_reference]
    .filter(Boolean)
    .join(" • ");
}

function ChargeEntries({
  caseViolations,
  charges,
  onChange,
  title,
  violations,
}: {
  caseViolations: CaseViolationManagementRecord[];
  charges: CaseResolutionChargeInput[];
  onChange: (charges: CaseResolutionChargeInput[]) => void;
  title: string;
  violations: TableRow<"violations">[];
}) {
  const [caseViolationPickerIndex, setCaseViolationPickerIndex] = useState<number | null>(null);
  const [databasePickerIndex, setDatabasePickerIndex] = useState<number | null>(null);
  const [violationSearch, setViolationSearch] = useState("");

  const updateCharge = (index: number, charge: CaseResolutionChargeInput) => {
    onChange(charges.map((item, itemIndex) => itemIndex === index ? charge : item));
  };

  const filteredViolations = violations.filter((violation) => {
    const searchText = violationSearch.trim().toLowerCase();
    if (!searchText) return true;

    return [violation.title, violation.short_label, violation.reference_code, violation.law_reference, violation.description]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(searchText));
  }).slice(0, 25);

  return (
    <div className="space-y-2 rounded-md border bg-muted/20 p-2">
      <div className="flex items-start justify-between gap-3">
        <div>
          <Label>{title}</Label>
          <p className="text-xs leading-tight text-muted-foreground">Type or choose from current case violations.</p>
        </div>
        <Button type="button" variant="outline" size="sm" onClick={() => onChange([...charges, emptyResolutionCharge()])}>Add charge</Button>
      </div>
      <div className="space-y-2">
        {charges.map((charge, index) => {
          return (
            <div key={index} className="space-y-1.5 rounded-md border bg-background p-2">
              <div className="flex items-end gap-2">
                <div className="min-w-0 flex-1 space-y-1">
                  <Label className="sr-only" htmlFor={`${title}-${index}-charge-text`}>Charge</Label>
                  <div className="flex rounded-md shadow-sm">
                    <Input
                      id={`${title}-${index}-charge-text`}
                      value={charge.chargeText}
                      className="rounded-r-none"
                      placeholder="Type charge or select a current case violation"
                      onChange={(event) => updateCharge(index, { ...charge, chargeText: event.target.value, caseViolationId: null, violationId: null })}
                    />
                    <Button
                      type="button"
                      variant="outline"
                      className="rounded-l-none border-l-0 px-3"
                      aria-label="Show current case violations"
                      onClick={() => setCaseViolationPickerIndex(caseViolationPickerIndex === index ? null : index)}
                    >
                      ▼
                    </Button>
                  </div>
                  {caseViolationPickerIndex === index ? (
                    <div className="max-h-40 overflow-y-auto rounded-md border bg-popover p-1 shadow-md">
                      {caseViolations.length === 0 ? (
                        <p className="px-2 py-1 text-xs text-muted-foreground">No current case violations found.</p>
                      ) : null}
                      {caseViolations.map((caseViolation) => (
                        <button
                          key={caseViolation.id}
                          type="button"
                          className="block w-full rounded-sm px-2 py-1 text-left text-sm hover:bg-accent hover:text-accent-foreground"
                          onClick={() => {
                            updateCharge(index, {
                              chargeText: caseViolationChargeText(caseViolation),
                              caseViolationId: caseViolation.id,
                              violationId: caseViolation.violation_id ?? caseViolation.violations?.id ?? null,
                            });
                            setCaseViolationPickerIndex(null);
                          }}
                        >
                          {caseViolationChargeText(caseViolation)}
                        </button>
                      ))}
                    </div>
                  ) : null}
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="self-end"
                  onClick={() => onChange(charges.length === 1 ? [emptyResolutionCharge()] : charges.filter((_, itemIndex) => itemIndex !== index))}
                >
                  Remove
                </Button>
              </div>
              <button
                type="button"
                className="text-xs font-medium leading-none text-primary underline-offset-4 hover:underline"
                onClick={() => {
                  setCaseViolationPickerIndex(null);
                  setDatabasePickerIndex(databasePickerIndex === index ? null : index);
                  setViolationSearch("");
                }}
              >
                Find Violation in Database
              </button>
              {databasePickerIndex === index ? (
                <div className="space-y-1.5 rounded-md border bg-muted/30 p-2">
                  <Input
                    value={violationSearch}
                    placeholder="Search violations..."
                    onChange={(event) => setViolationSearch(event.target.value)}
                  />
                  <div className="max-h-40 space-y-1 overflow-y-auto">
                    {filteredViolations.length === 0 ? (
                      <p className="px-2 py-1 text-xs text-muted-foreground">No violations found.</p>
                    ) : null}
                    {filteredViolations.map((violation) => (
                      <button
                        key={violation.id}
                        type="button"
                        className="block w-full rounded-sm px-2 py-1 text-left text-sm hover:bg-accent hover:text-accent-foreground"
                        onClick={() => {
                          updateCharge(index, {
                            chargeText: violationOptionText(violation),
                            caseViolationId: null,
                            violationId: violation.id,
                          });
                          setDatabasePickerIndex(null);
                          setViolationSearch("");
                        }}
                      >
                        {violationOptionText(violation)}
                      </button>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function ApprovalDecisionEntries({
  actions,
  onChange,
}: {
  actions: CaseResolutionApprovalActionInput[];
  onChange: (actions: CaseResolutionApprovalActionInput[]) => void;
}) {
  const updateAction = (index: number, action: CaseResolutionApprovalActionInput) => {
    onChange(actions.map((item, itemIndex) => itemIndex === index ? action : item));
  };

  return (
    <div className="space-y-2 rounded-md border bg-muted/20 p-2">
      <div className="flex items-start justify-between gap-3">
        <div>
          <Label>Approved decisions</Label>
          <p className="text-xs leading-tight text-muted-foreground">Review imported recommendation rows or add a new final decision row.</p>
        </div>
        <Button type="button" variant="outline" size="sm" onClick={() => onChange([...actions, emptyApprovalAction()])}>Add decision</Button>
      </div>
      <div className="space-y-2">
        {actions.map((action, index) => (
          <div key={index} className="space-y-2 rounded-md border bg-background p-2">
            {action.sourceResolutionChargeActionId ? <Badge variant="secondary">From recommendation</Badge> : null}
            <div className="grid gap-2 sm:grid-cols-[1fr_10rem_auto]">
              <div className="space-y-1">
                <Label htmlFor={`approval-${index}-charge`}>Charge text</Label>
                <Input id={`approval-${index}-charge`} value={action.chargeText} onChange={(event) => updateAction(index, { ...action, chargeText: event.target.value })} />
              </div>
              <div className="space-y-1">
                <Label htmlFor={`approval-${index}-decision`}>Decision</Label>
                <select id={`approval-${index}-decision`} className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={action.decisionCode} onChange={(event) => updateAction(index, { ...action, decisionCode: event.target.value as "FOR_FILING" | "DISMISSAL" })}>
                  <option value="FOR_FILING">For Filing</option>
                  <option value="DISMISSAL">Dismissal</option>
                </select>
              </div>
              <Button type="button" variant="outline" size="sm" className="self-end" onClick={() => onChange(actions.length === 1 ? [emptyApprovalAction()] : actions.filter((_, itemIndex) => itemIndex !== index))}>Remove</Button>
            </div>
          </div>
        ))}
      </div>
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
  const [prosecutors, setProsecutors] = useState<TableRow<"prosecutors">[]>([]);
  const [staffMembers, setStaffMembers] = useState<TableRow<"staff">[]>([]);
  const [caseViolations, setCaseViolations] = useState<CaseViolationManagementRecord[]>([]);
  const [violations, setViolations] = useState<TableRow<"violations">[]>([]);
  const [assignments, setAssignments] = useState<CaseAssignmentRecord[]>([]);
  const [caseResolutions, setCaseResolutions] = useState<CaseResolutionWithActionsRecord[]>([]);
  const [courtFilingDecisions, setCourtFilingDecisions] = useState<CourtFilingDecisionRecord[]>([]);
  const [courtOptions, setCourtOptions] = useState<CourtReferenceRecord[]>([]);
  const [isCourtPickerOpen, setIsCourtPickerOpen] = useState(false);
  const [addForm, setAddForm] = useState({ eventTypeCode: "", eventDate: new Date().toISOString().slice(0, 10), eventTime: "", title: "", description: "", prosecutorId: "", staffId: "", reason: "", recommendationCode: "", caseResolutionId: null as number | null, chargesForFiling: [emptyResolutionCharge()], chargesForDismissal: [emptyResolutionCharge()], approvalActions: [emptyApprovalAction()], courtFilingDecisionId: "", courtId: null as number | null, courtName: "", courtBranch: "", chargeFiled: "", informationCount: "", criminalCaseNo: "" });
  const [editForm, setEditForm] = useState({ eventDate: "", title: "", description: "", editReason: "" });
  const [voidReason, setVoidReason] = useState("");
  const [voidConfirmed, setVoidConfirmed] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    let isActive = true;

    getCaseAssignments(caseId).then((result) => {
      if (isActive && !result.error) {
        setAssignments(result.data);
      }
    });

    return () => {
      isActive = false;
    };
  }, [caseId, events]);

  const openAddDialog = async () => {
    setActionError(null);
    setEventTypesError(null);
    setCaseResolutions([]);
    setCourtFilingDecisions([]);
    setAddForm({ eventTypeCode: addableEventTypes(eventTypes)[0]?.code ?? "", eventDate: new Date().toISOString().slice(0, 10), eventTime: "", title: "", description: "", prosecutorId: "", staffId: "", reason: "", recommendationCode: "", caseResolutionId: null, chargesForFiling: [emptyResolutionCharge()], chargesForDismissal: [emptyResolutionCharge()], approvalActions: [emptyApprovalAction()], courtFilingDecisionId: "", courtId: null as number | null, courtName: "", courtBranch: "", chargeFiled: "", informationCount: "", criminalCaseNo: "" });
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

    if (prosecutors.length === 0) {
      const result = await getProsecutors(250);
      if (!result.error) setProsecutors(result.data);
    }

    if (staffMembers.length === 0) {
      const result = await getStaff(250);
      if (!result.error) setStaffMembers(result.data);
    }

    if (caseViolations.length === 0) {
      const result = await getCaseManagedViolations(caseId);
      if (!result.error) setCaseViolations(result.data);
    }

    if (violations.length === 0) {
      const result = await getViolations(250);
      if (!result.error) setViolations(result.data);
    }

    const resolutionsResult = await getCaseResolutionsWithActions(caseId);
    if (!resolutionsResult.error) {
      setCaseResolutions(resolutionsResult.data);
    }

    const assignmentResult = await getCaseAssignments(caseId);
    if (!assignmentResult.error) setAssignments(assignmentResult.data);

    const courtFilingDecisionsResult = await getAvailableCourtFilingDecisions(caseId);
    if (!courtFilingDecisionsResult.error) setCourtFilingDecisions(courtFilingDecisionsResult.data);

    if (courtOptions.length === 0) {
      const courtsResult = await getCourts();
      if (!courtsResult.error) setCourtOptions(courtsResult.data);
    }
  };

  useEffect(() => {
    if (addForm.eventTypeCode !== "COURT_FILING" || courtFilingDecisions.length !== 1 || addForm.courtFilingDecisionId) {
      return;
    }

    const [decision] = courtFilingDecisions;
    setAddForm((form) => ({
      ...form,
      courtFilingDecisionId: String(decision.id),
      chargeFiled: decision.charge_text,
    }));
  }, [addForm.courtFilingDecisionId, addForm.eventTypeCode, courtFilingDecisions]);

  const handleAddSave = async () => {
    const isAssignment = addForm.eventTypeCode === "CASE_ASSIGNMENT";
    const isReassignment = addForm.eventTypeCode === "CASE_REASSIGNMENT";
    const isResolved = addForm.eventTypeCode === "CASE_RESOLVED";
    const isDecisionApproved = addForm.eventTypeCode === "CASE_DECISION_APPROVED";
    const isCourtFiling = addForm.eventTypeCode === "COURT_FILING";
    if (!addForm.eventTypeCode || !addForm.eventDate) return;
    if ((isAssignment || isReassignment) && !addForm.prosecutorId) return;
    if (isReassignment && !addForm.reason.trim()) return;
    if (isResolved && !addForm.recommendationCode) return;
    if (isDecisionApproved && (!addForm.prosecutorId || !addForm.caseResolutionId || !addForm.approvalActions.some((action) => action.chargeText.trim()))) return;
    if (isCourtFiling && (!addForm.courtFilingDecisionId || !addForm.courtName.trim() || !addForm.chargeFiled.trim())) return;
    if (isReassignment && currentAssignment?.prosecutor_id === Number(addForm.prosecutorId)) {
      setActionError("The selected prosecutor is already assigned to this case.");
      return;
    }
    if (!isAssignment && !isReassignment && !isResolved && !isDecisionApproved && !isCourtFiling && !addForm.title.trim()) return;
    setIsSaving(true);
    setActionError(null);
    const result = isAssignment
      ? await recordCaseAssignmentEvent({
        caseId,
        prosecutorId: Number(addForm.prosecutorId),
        assignmentDate: addForm.eventDate,
        assignmentTime: addForm.eventTime || null,
        staffId: addForm.staffId ? Number(addForm.staffId) : null,
        remarks: addForm.description,
      })
      : isReassignment
        ? await recordCaseReassignmentEvent({
          caseId,
          prosecutorId: Number(addForm.prosecutorId),
          reassignmentDate: addForm.eventDate,
          reassignmentTime: addForm.eventTime || null,
          staffId: addForm.staffId ? Number(addForm.staffId) : null,
          reason: addForm.reason,
          remarks: addForm.description,
        })
        : isResolved
          ? await recordCaseResolvedEvent({
            caseId,
            recommendationCode: addForm.recommendationCode as "CASE_FOR_FILING" | "CASE_DISMISSAL" | "MIXED_RESULT",
            dateResolved: addForm.eventDate,
            timeResolved: addForm.eventTime || null,
            remarks: addForm.description,
            chargesForFiling: addForm.chargesForFiling,
            chargesForDismissal: addForm.chargesForDismissal,
          })
          : isDecisionApproved
            ? await recordCaseDecisionApprovedEvent({
              caseId,
              caseResolutionId: Number(addForm.caseResolutionId),
              approvedByProsecutorId: Number(addForm.prosecutorId),
              dateApproved: addForm.eventDate,
              timeApproved: addForm.eventTime || null,
              approvalActions: addForm.approvalActions,
              remarks: addForm.description,
            })
            : isCourtFiling
              ? await recordCourtFilingEvent({
                caseId,
                caseResolutionApprovalActionId: Number(addForm.courtFilingDecisionId),
                courtId: addForm.courtId,
                courtName: addForm.courtName,
                courtBranch: addForm.courtBranch,
                chargeFiled: addForm.chargeFiled,
                dateFiled: addForm.eventDate,
                timeFiled: addForm.eventTime || null,
                informationCount: addForm.informationCount ? Number(addForm.informationCount) : null,
                criminalCaseNo: addForm.criminalCaseNo,
                remarks: addForm.description,
              })
          : await createCaseEvent({
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
    if (isReassignment) {
      onUpdateStatus?.();
    }
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
    const shouldPromptStatusUpdate = isAssignmentEvent(voidingEvent);
    setVoidingEvent(null);
    await onChanged?.();
    if (shouldPromptStatusUpdate) {
      onUpdateStatus?.();
    }
  };

  const isAddingAssignment = addForm.eventTypeCode === "CASE_ASSIGNMENT";
  const isAddingReassignment = addForm.eventTypeCode === "CASE_REASSIGNMENT";
  const isAddingResolved = addForm.eventTypeCode === "CASE_RESOLVED";
  const isAddingDecisionApproved = addForm.eventTypeCode === "CASE_DECISION_APPROVED";
  const isAddingCourtFiling = addForm.eventTypeCode === "COURT_FILING";
  const approvingProsecutors = prosecutors.filter((prosecutor) => {
    const position = prosecutor as { position_code?: string | null; position_group_type?: string | null };
    return position.position_group_type === "PROSECUTOR" && ["CHIEF_PROSECUTOR", "DEPUTY_PROSECUTOR"].includes(String(position.position_code ?? ""));
  });
  const showChargesForFiling = addForm.recommendationCode === "CASE_FOR_FILING" || addForm.recommendationCode === "MIXED_RESULT";
  const showChargesForDismissal = addForm.recommendationCode === "CASE_DISMISSAL" || addForm.recommendationCode === "MIXED_RESULT";
  const isAddingAssignmentLike = isAddingAssignment || isAddingReassignment;
  const currentAssignment = assignments.find((assignment) => !assignment.unassigned_at && ("is_voided" in assignment ? assignment.is_voided === false : true)) ?? null;
  const selectedEventTypeLabel = eventTypes.find((eventType) => eventType.code === addForm.eventTypeCode)?.display_label ?? "";
  const selectedApprovalResolution = caseResolutions.find((resolution) => resolution.id === addForm.caseResolutionId) ?? null;
  const filteredCourts = courtOptions.filter((court) => {
    const searchText = addForm.courtName.trim().toLowerCase();
    if (!searchText) return true;
    return [court.name, court.code, court.court_type].filter(Boolean).some((value) => String(value).toLowerCase().includes(searchText));
  }).slice(0, 25);
  const hasExactCourtMatch = courtOptions.some((court) => court.name.trim().toLowerCase() === addForm.courtName.trim().toLowerCase());
  const formatRecommendationLabel = (code: string) => code === "CASE_FOR_FILING" ? "Case for Filing" : code === "CASE_DISMISSAL" ? "Case Dismissal" : code === "MIXED_RESULT" ? "Mixed Result" : code;
  const approvalActionsFromResolution = (resolution: CaseResolutionWithActionsRecord): CaseResolutionApprovalActionInput[] => resolution.charge_actions.length > 0
    ? resolution.charge_actions.map((action) => ({
      chargeText: action.charge_text,
      caseViolationId: action.case_violation_id,
      violationId: action.violation_id,
      sourceResolutionChargeActionId: action.id,
      decisionCode: action.action_code,
    }))
    : [emptyApprovalAction()];

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
                    const assignmentDetails = isAssignmentEvent(event)
                      ? assignments.find((assignment) =>
                        (("case_event_id" in assignment && Number(assignment.case_event_id) === Number(event.case_event_id)) ||
                        Number(assignment.id) === Number(event.source_id)),
                      ) ?? null
                      : null;
                    const detailItems = timelineDetailItems(event, assignmentDetails);
                    const subtitle = timelineSubtitle(event, petitionDetails);

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
                                {subtitle ? (
                                  <p className="line-clamp-2 text-xs text-muted-foreground">
                                    {subtitle}
                                  </p>
                                ) : null}
                              </div>
                            </div>
                          </AccordionTrigger>
                          <AccordionContent className="space-y-3 pb-3">
                            {event.is_voided ? (
                              <div className="rounded-md border border-destructive/30 bg-destructive/5 p-3 text-sm">
                                <p className="font-medium text-destructive">VOIDED</p>
                                <p className="text-muted-foreground">Reason: {event.void_reason ?? "—"}</p>
                                <p className="text-muted-foreground">Voided: {formatDate(event.voided_at)} by {event.voided_by_email ?? "—"}</p>
                              </div>
                            ) : null}
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
                            {!event.is_voided ? (
                              <div className="flex gap-2 border-t pt-3">
                                <Button type="button" variant="outline" size="sm" onClick={() => openEditDialog(event)}>Edit</Button>
                                <Button type="button" variant="destructive" size="sm" onClick={() => openVoidDialog(event)}>Void</Button>
                              </div>
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
        <DialogContent className="grid max-h-[calc(100vh-2rem)] grid-rows-[auto_minmax(0,1fr)_auto] gap-3 p-5 sm:max-w-xl">
          <DialogHeader className="gap-1">
            <DialogTitle>Add event</DialogTitle>
            <DialogDescription>Add a new activity to this case timeline.</DialogDescription>
          </DialogHeader>
          <div className="min-h-0 space-y-3 overflow-y-auto pr-1">
            {eventTypesError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{eventTypesError}</p> : null}
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            <div className="space-y-2">
              <Label htmlFor="add-event-type">Event Type</Label>
              <select id="add-event-type" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.eventTypeCode} onChange={(e) => setAddForm((form) => ({ ...form, eventTypeCode: e.target.value, title: e.target.value === "CASE_ASSIGNMENT" ? "Case Assignment" : e.target.value === "CASE_REASSIGNMENT" ? "Case Reassignment" : e.target.value === "CASE_RESOLVED" ? "Case Resolved" : e.target.value === "CASE_DECISION_APPROVED" ? "Case Decision Approved" : e.target.value === "COURT_FILING" ? "Court Filing" : form.title }))}>
                {eventTypes.map((eventType) => <option key={eventType.code} value={eventType.code}>{eventType.display_label}</option>)}
              </select>
            </div>
            {isAddingAssignment ? (
              <div className="rounded-md border border-blue-200 bg-blue-50 p-3 text-sm text-blue-900 dark:border-blue-900/60 dark:bg-blue-950/30 dark:text-blue-100">
                Assigning this case to a prosecutor will automatically change the case status to Pending.
              </div>
            ) : null}
            {isAddingReassignment ? (
              <div className="rounded-md border bg-muted/40 p-3 text-sm">
                <p className="mb-2 font-medium">Current assignment</p>
                <div className="grid gap-3 sm:grid-cols-2">
                  <OptionalDetailItem label="Current Prosecutor" value={currentAssignment?.prosecutors?.short_name ?? currentAssignment?.prosecutors?.full_name} />
                  <OptionalDetailItem label="Current Staff" value={currentAssignment?.staff?.short_name ?? currentAssignment?.staff?.full_name} />
                </div>
                {!currentAssignment ? <p className="text-muted-foreground">No active assignment found.</p> : null}
              </div>
            ) : null}
            {isAddingAssignmentLike ? (
              <>
                <div className="space-y-2"><Label htmlFor="add-assigned-prosecutor">{isAddingReassignment ? "New Prosecutor" : "Assigned Prosecutor"}</Label><select id="add-assigned-prosecutor" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.prosecutorId} onChange={(e) => setAddForm((form) => ({ ...form, prosecutorId: e.target.value }))}><option value="">Select prosecutor</option>{prosecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.short_name ?? prosecutor.full_name}</option>)}</select></div>
                <div className="grid gap-4 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="add-assignment-date">{isAddingReassignment ? "Reassignment Date" : "Assignment Date"}</Label><Input id="add-assignment-date" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div><div className="space-y-2"><Label htmlFor="add-assignment-time">{isAddingReassignment ? "Reassignment Time" : "Assignment Time"}</Label><Input id="add-assignment-time" type="time" value={addForm.eventTime} onChange={(e) => setAddForm((form) => ({ ...form, eventTime: e.target.value }))} /></div></div>
                <div className="space-y-2"><Label htmlFor="add-assigned-staff">{isAddingReassignment ? "New Staff" : "Assigned Staff"}</Label><select id="add-assigned-staff" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.staffId} onChange={(e) => setAddForm((form) => ({ ...form, staffId: e.target.value }))}><option value="">No staff selected</option>{staffMembers.map((staff) => <option key={staff.id} value={staff.id}>{staff.short_name ?? staff.full_name}</option>)}</select></div>
                {isAddingReassignment ? <div className="space-y-2"><Label htmlFor="add-reassignment-reason">Reason</Label><Textarea id="add-reassignment-reason" required value={addForm.reason} onChange={(e) => setAddForm((form) => ({ ...form, reason: e.target.value }))} /></div> : null}
                <div className="space-y-2"><Label htmlFor="add-assignment-remarks">Remarks</Label><Textarea id="add-assignment-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingResolved ? (
              <>
                <div className="space-y-2"><Label htmlFor="add-resolution-recommendation">Recommendation</Label><select id="add-resolution-recommendation" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.recommendationCode} onChange={(e) => setAddForm((form) => ({ ...form, recommendationCode: e.target.value }))}><option value="">Select recommendation</option><option value="CASE_FOR_FILING">Case for Filing</option><option value="CASE_DISMISSAL">Case Dismissal</option><option value="MIXED_RESULT">Mixed Result</option></select></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-date-resolved">Date Resolved</Label><Input id="add-date-resolved" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div><div className="space-y-1"><Label htmlFor="add-time-resolved">Time Resolved</Label><Input id="add-time-resolved" type="time" value={addForm.eventTime} onChange={(e) => setAddForm((form) => ({ ...form, eventTime: e.target.value }))} /></div></div>
                {showChargesForFiling ? <ChargeEntries title="Charges for Filing" charges={addForm.chargesForFiling} caseViolations={caseViolations} violations={violations} onChange={(charges) => setAddForm((form) => ({ ...form, chargesForFiling: charges }))} /> : null}
                {showChargesForDismissal ? <ChargeEntries title="Charges for Dismissal" charges={addForm.chargesForDismissal} caseViolations={caseViolations} violations={violations} onChange={(charges) => setAddForm((form) => ({ ...form, chargesForDismissal: charges }))} /> : null}
                <div className="space-y-1"><Label htmlFor="add-resolution-remarks">Remarks</Label><Textarea id="add-resolution-remarks" className="min-h-20" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingDecisionApproved ? (
              <>
                {caseResolutions.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100">No active unapproved case resolution available to approve.</div> : null}
                <div className="space-y-2"><Label htmlFor="add-approval-resolution">Resolution to Approve</Label><select id="add-approval-resolution" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.caseResolutionId ?? ""} onChange={(e) => { const resolutionId = e.target.value ? Number(e.target.value) : null; const resolution = caseResolutions.find((item) => item.id === resolutionId) ?? null; setAddForm((form) => ({ ...form, caseResolutionId: resolutionId, approvalActions: resolution ? approvalActionsFromResolution(resolution) : [emptyApprovalAction()] })); }}><option value="">Select resolution</option>{caseResolutions.map((resolution) => <option key={resolution.id} value={resolution.id}>{formatRecommendationLabel(resolution.recommendation_code)} • {formatDate(resolution.date_resolved)} • Resolution #{resolution.id}</option>)}</select>{selectedApprovalResolution ? <p className="text-xs text-muted-foreground">Loaded {selectedApprovalResolution.charge_actions.length} recommended action{selectedApprovalResolution.charge_actions.length === 1 ? "" : "s"} from the selected resolution.</p> : null}</div>
                <div className="space-y-2"><Label htmlFor="add-approved-by">Approved By</Label><select id="add-approved-by" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.prosecutorId} onChange={(e) => setAddForm((form) => ({ ...form, prosecutorId: e.target.value }))}><option value="">Select approving prosecutor</option>{approvingProsecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.short_name ?? prosecutor.full_name}</option>)}</select>{approvingProsecutors.length === 0 ? <p className="text-xs text-muted-foreground">No active Chief Prosecutor or Deputy Prosecutor records found.</p> : null}</div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-date-approved">Date Approved</Label><Input id="add-date-approved" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div><div className="space-y-1"><Label htmlFor="add-time-approved">Time Approved</Label><Input id="add-time-approved" type="time" value={addForm.eventTime} onChange={(e) => setAddForm((form) => ({ ...form, eventTime: e.target.value }))} /></div></div>
                <ApprovalDecisionEntries actions={addForm.approvalActions} onChange={(approvalActions) => setAddForm((form) => ({ ...form, approvalActions }))} />
                <div className="space-y-1"><Label htmlFor="add-approval-remarks">Remarks</Label><Textarea id="add-approval-remarks" className="min-h-20" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingCourtFiling ? (
              <>
                {courtFilingDecisions.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100">No approved filing decision available for court filing.</div> : null}
                <div className="space-y-2"><Label htmlFor="add-court-filing-decision">Approved Filing Decision</Label><select id="add-court-filing-decision" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.courtFilingDecisionId} onChange={(e) => { const decision = courtFilingDecisions.find((item) => item.id === Number(e.target.value)); setAddForm((form) => ({ ...form, courtFilingDecisionId: e.target.value, chargeFiled: decision?.charge_text ?? form.chargeFiled })); }}><option value="">Select approved filing decision</option>{courtFilingDecisions.map((decision) => <option key={decision.id} value={decision.id}>{decision.charge_text} • Approved {formatDate(decision.date_approved)}</option>)}</select></div>
                <div className="space-y-2"><Label htmlFor="add-court">Court</Label><div className="flex rounded-md shadow-sm"><Input id="add-court" value={addForm.courtName} className="rounded-r-none" placeholder="Search or type new court" onFocus={() => setIsCourtPickerOpen(true)} onChange={(e) => { setIsCourtPickerOpen(true); setAddForm((form) => ({ ...form, courtName: e.target.value, courtId: null })); }} /><Button type="button" variant="outline" className="rounded-l-none border-l-0 px-3" aria-label="Show courts" onClick={() => setIsCourtPickerOpen((open) => !open)}>▼</Button></div>{isCourtPickerOpen ? <div className="max-h-44 overflow-y-auto rounded-md border bg-popover p-1 shadow-md">{filteredCourts.length === 0 ? <p className="px-2 py-1 text-xs text-muted-foreground">No matching courts. The typed name will be added as a new court.</p> : null}{filteredCourts.map((court) => <button key={court.id} type="button" className="block w-full rounded-sm px-2 py-1 text-left text-sm hover:bg-accent hover:text-accent-foreground" onClick={() => { setAddForm((form) => ({ ...form, courtId: Number(court.id), courtName: court.name })); setIsCourtPickerOpen(false); }}>{court.name}{court.court_type ? <span className="text-muted-foreground"> • {court.court_type}</span> : null}</button>)}{addForm.courtName.trim() && !hasExactCourtMatch ? <button type="button" className="block w-full rounded-sm px-2 py-1 text-left text-sm font-medium text-primary hover:bg-accent hover:text-accent-foreground" onClick={() => setIsCourtPickerOpen(false)}>Use “{addForm.courtName.trim()}” as new court</button> : null}</div> : null}</div>
                <div className="space-y-2"><Label htmlFor="add-court-branch">Court Branch</Label><Input id="add-court-branch" value={addForm.courtBranch} onChange={(e) => setAddForm((form) => ({ ...form, courtBranch: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="add-charge-filed">Charge Filed</Label><Input id="add-charge-filed" value={addForm.chargeFiled} onChange={(e) => setAddForm((form) => ({ ...form, chargeFiled: e.target.value }))} /></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-date-filed">Date Filed</Label><Input id="add-date-filed" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div><div className="space-y-1"><Label htmlFor="add-time-filed">Time Filed</Label><Input id="add-time-filed" type="time" value={addForm.eventTime} onChange={(e) => setAddForm((form) => ({ ...form, eventTime: e.target.value }))} /></div></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-information-count">Information Count</Label><Input id="add-information-count" type="number" min="0" value={addForm.informationCount} onChange={(e) => setAddForm((form) => ({ ...form, informationCount: e.target.value }))} /></div><div className="space-y-1"><Label htmlFor="add-criminal-case-no">Criminal Case No.</Label><Input id="add-criminal-case-no" value={addForm.criminalCaseNo} onChange={(e) => setAddForm((form) => ({ ...form, criminalCaseNo: e.target.value }))} /></div></div>
                <div className="space-y-2"><Label htmlFor="add-court-filing-remarks">Remarks</Label><Textarea id="add-court-filing-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : (
              <>
                <div className="space-y-2"><Label htmlFor="add-event-date">Event Date</Label><Input id="add-event-date" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="add-event-title">Title</Label><Input id="add-event-title" value={addForm.title} placeholder={selectedEventTypeLabel || undefined} onChange={(e) => setAddForm((form) => ({ ...form, title: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="add-event-description">Description / Remarks</Label><Textarea id="add-event-description" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            )}
          </div>
          <DialogFooter className="border-t pt-3">
            <Button type="button" variant="outline" onClick={() => setIsAddDialogOpen(false)}>Cancel</Button>
            <Button type="button" onClick={handleAddSave} disabled={isSaving || !addForm.eventTypeCode || !addForm.eventDate || (isAddingAssignmentLike ? !addForm.prosecutorId || (isAddingReassignment && !addForm.reason.trim()) : isAddingResolved ? !addForm.recommendationCode : isAddingDecisionApproved ? !addForm.prosecutorId || !addForm.caseResolutionId || !addForm.approvalActions.some((action) => action.chargeText.trim()) : isAddingCourtFiling ? !addForm.courtFilingDecisionId || !addForm.courtName.trim() || !addForm.chargeFiled.trim() : !addForm.title.trim())}>{isSaving ? "Saving..." : isAddingReassignment ? "Confirm Reassignment" : isAddingAssignment ? "Confirm Assignment" : isAddingResolved ? "Resolve Case" : isAddingDecisionApproved ? "Approve Decision" : isAddingCourtFiling ? "Record Court Filing" : "Add event"}</Button>
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
