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
  recordCustomCaseEvent,
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
  recordMotionReceivedEvent,
  recordMotionResolvedEvent,
  getMotionResolutionRecommendations,
  addMotionResolutionRecommendation,
  recordMotionDecisionApprovedEvent,
  getMotionResolutionApprovalCandidates,
  getMotionDecisionCaseStatusOptions,
  getMotionDecisionCaseStageOptions,
  type MotionResolutionRecommendationRecord,
  type MotionResolutionApprovalCandidateRecord,
  type CaseStatusOptionRecord,
  type CaseStageOptionRecord,
  type CourtStatusUpdateCandidateRecord,
  getCourtStatusUpdateCandidates,
  updateCourtFilingStatusDetails,
  recordPetitionForReviewEvent,
  recordPetitionForReviewUpdate,
  editCaseEvent,
  getCaseEventTypes,
  voidCaseEvent,
} from "@/lib/supabase/queries";
import { formatManilaClock, getManilaDateTimeInputValues } from "@/lib/philippine-time";
import type { TableRow } from "@/lib/supabase/types";

export type CaseTimelineProps = {
  caseId: number;
  events: CaseTimelineEventRecord[];
  courts?: CaseCourtRecord[];
  motions?: CaseMotionRecord[];
  petitionsForReview?: CasePetitionForReviewRecord[];
  onChanged?: () => void | Promise<void>;
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

type MotionDetailRow = { detail: string; value: string };
type CourtStatusRow = { court_status: string; status_date: string };
type CriminalCaseNumberRow = { criminal_case_no: string };


function MotionDetailsEditor({ rows, onChange }: { rows: MotionDetailRow[]; onChange: (rows: MotionDetailRow[]) => void }) {
  const normalizedRows = rows.length ? rows : [{ detail: "", value: "" }];
  return (
    <div className="space-y-2">
      <Label>Additional Details</Label>
      <div className="space-y-2">
        {normalizedRows.map((row, index) => (
          <div key={index} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]">
            <Input placeholder="Detail" value={row.detail} onChange={(e) => onChange(normalizedRows.map((item, itemIndex) => itemIndex === index ? { ...item, detail: e.target.value } : item))} />
            <Input placeholder="Value" value={row.value} onChange={(e) => onChange(normalizedRows.map((item, itemIndex) => itemIndex === index ? { ...item, value: e.target.value } : item))} />
            <Button type="button" variant="outline" size="sm" onClick={() => onChange(normalizedRows.length === 1 ? [{ detail: "", value: "" }] : normalizedRows.filter((_, itemIndex) => itemIndex !== index))}>Remove</Button>
          </div>
        ))}
      </div>
      <Button type="button" variant="outline" size="sm" onClick={() => onChange([...normalizedRows, { detail: "", value: "" }])}>Add Detail</Button>
    </div>
  );
}

function motionFiledByLabel(code: string | null | undefined) {
  return code === "COMPLAINANT" ? "Complainant" : code === "RESPONDENT" ? "Respondent" : code;
}

function motionWorkflowEventDetails(event: CaseTimelineEventRecord) {
  if (!["MOTION_RECEIVED", "MOTION_RESOLVED", "MOTION_DECISION_APPROVED"].includes(event.event_type_code ?? "")) return null;
  const details = event.details_jsonb && typeof event.details_jsonb === "object" ? event.details_jsonb as Record<string, unknown> : {};
  return [
    { label: "Motion Title", value: stringDetail(details.motion_title) ?? event.title },
    { label: "Filed By", value: stringDetail(details.filed_by_label) ?? motionFiledByLabel(stringDetail(details.filed_by_code)) },
    { label: "Assigned Prosecutor", value: stringDetail(details.assigned_prosecutor_name) },
    event.event_type_code === "MOTION_DECISION_APPROVED"
      ? { label: "Original Recommendation", value: stringDetail(details.original_recommendation_label) ?? stringDetail(details.original_recommendation_code) }
      : event.event_type_code === "MOTION_RESOLVED"
        ? { label: "Recommendation", value: stringDetail(details.recommendation_label) ?? stringDetail(details.recommendation_code) }
        : { label: "Date Filed", value: formatDate(stringDetail(details.date_filed) ?? event.event_date) },
    ...(event.event_type_code === "MOTION_DECISION_APPROVED" ? [
      { label: "Decision Approved", value: stringDetail(details.approved_decision_label) ?? stringDetail(details.approved_decision_code) },
      { label: "Approved By", value: stringDetail(details.approved_by_name) },
      { label: "Date Approved", value: formatDate(stringDetail(details.date_approved) ?? event.event_date) },
      { label: "Time Approved", value: formatTime(stringDetail(details.time_approved) ?? event.event_time) },
      { label: "Update Case Status", value: details.updates_case_status === true ? "Yes" : "No" },
      { label: "Selected Case Status", value: details.updates_case_status === true ? stringDetail(details.selected_case_status_label) : null },
      { label: "Selected Case Stage", value: details.updates_case_status === true ? stringDetail(details.selected_case_stage_label) : null },
    ] : [
      { label: event.event_type_code === "MOTION_RESOLVED" ? "Date Resolved" : "Time Filed", value: event.event_type_code === "MOTION_RESOLVED" ? formatDate(stringDetail(details.date_resolved) ?? event.event_date) : formatTime(stringDetail(details.time_filed) ?? event.event_time) },
      ...(event.event_type_code === "MOTION_RESOLVED" ? [{ label: "Time Resolved", value: formatTime(stringDetail(details.time_resolved) ?? event.event_time) }] : []),
    ]),
    { label: "Remarks", value: stringDetail(details.remarks) ?? event.description },
  ];
}

function normalizeDetailRows(value: unknown): MotionDetailRow[] {
  if (!Array.isArray(value)) return [];
  return value.map((row) => {
    const item = row && typeof row === "object" ? row as Record<string, unknown> : {};
    return { detail: String(item.detail ?? "").trim(), value: String(item.value ?? "").trim() };
  }).filter((row) => row.detail || row.value);
}

function motionReceivedAdditionalDetails(event: CaseTimelineEventRecord): MotionDetailRow[] {
  if (event.event_type_code !== "MOTION_RECEIVED" || !event.details_jsonb || typeof event.details_jsonb !== "object") return [];
  return normalizeDetailRows((event.details_jsonb as Record<string, unknown>).details);
}

function customEventAdditionalDetails(event: CaseTimelineEventRecord): MotionDetailRow[] {
  if (event.event_type_code !== "CUSTOM_EVENT" || !event.details_jsonb || typeof event.details_jsonb !== "object") return [];
  return normalizeDetailRows((event.details_jsonb as Record<string, unknown>).additional_details);
}

function AdditionalDetailsRows({ rows }: { rows: MotionDetailRow[] }) {
  if (rows.length === 0) return null;
  return <div className="rounded-md border bg-background p-3"><p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Additional Details</p><div className="space-y-1 text-sm">{rows.map((detail, index) => <p key={index}><span className="font-medium">{detail.detail || "Detail"}:</span> {detail.value || "—"}</p>)}</div></div>;
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
  const criminalCaseNumbers = Array.isArray(details.criminal_case_numbers)
    ? details.criminal_case_numbers.map((row) => stringDetail((row as Record<string, unknown>).criminal_case_no)).filter(Boolean).join("; ")
    : stringDetail(details.criminal_case_no);
  const courtStatuses = Array.isArray(details.court_statuses)
    ? details.court_statuses.map((row) => {
      const item = row as Record<string, unknown>;
      return `${stringDetail(item.court_status) ?? ""} — ${formatDate(stringDetail(item.status_date))}`.trim();
    }).filter(Boolean).join("; ")
    : stringDetail(details.court_status);
  const additionalDetails = Array.isArray(details.additional_details)
    ? details.additional_details.map((row) => {
      const item = row as Record<string, unknown>;
      return `${stringDetail(item.detail) ?? ""}: ${stringDetail(item.value) ?? ""}`.trim();
    }).filter(Boolean).join("; ")
    : null;
  return [
    { label: "Approved Filing Decision", value: stringDetail(details.approved_filing_decision_label) ?? stringDetail(details.approved_filing_decision) },
    { label: "Court", value: stringDetail(details.court) ?? event.court_name },
    { label: "Court Branch", value: stringDetail(details.court_branch) },
    { label: "Charge Filed", value: stringDetail(details.charge_filed) },
    { label: "Date Filed", value: formatDate(stringDetail(details.date_filed) ?? event.event_date) },
    { label: "Time Filed", value: formatTime(stringDetail(details.time_filed) ?? event.event_time) },
    { label: "Criminal Case Numbers", value: criminalCaseNumbers },
    { label: "Court Status History", value: courtStatuses },
    { label: "Information Count", value: stringDetail(details.information_count) },
    { label: "Additional Details", value: additionalDetails },
    { label: "Remarks", value: stringDetail(details.court_status_update_remarks) ?? stringDetail(details.remarks) },
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

  if (event.event_type_code === "CASE_REASSIGNMENT") {
    return [
      { label: "Previous prosecutor", value: stringDetail(details.previous_prosecutor_name) },
      { label: "New prosecutor", value: stringDetail(details.new_prosecutor_name) ?? event.prosecutor_short_name },
      { label: "Reassignment date", value: formatDate(event.event_date) },
      { label: "Reassignment time", value: formatTime(event.event_time) },
      { label: "Assigned staff", value: stringDetail(details.staff_name) ?? event.staff_short_name },
      { label: "Stage", value: event.case_stage_label ?? stringDetail(details.automatic_case_stage) },
      { label: "Reason", value: stringDetail(details.reason) },
      { label: "Remarks", value: stringDetail(details.remarks) },
    ];
  }

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

function caseStatusUpdatedEventDetails(event: CaseTimelineEventRecord) {
  if (event.event_type_code !== "CASE_STATUS_UPDATED") return null;
  const details = event.details_jsonb && typeof event.details_jsonb === "object" ? event.details_jsonb as Record<string, unknown> : {};
  return [
    { label: "Previous Case Status", value: stringDetail(details.previous_case_status_label) ?? stringDetail(details.previous_case_status_id) },
    { label: "New Case Status", value: stringDetail(details.selected_case_status_label) ?? event.case_status_label ?? event.status_label },
    { label: "Previous Case Stage", value: stringDetail(details.previous_case_stage_label) ?? stringDetail(details.previous_case_stage_id) },
    { label: "New Case Stage", value: stringDetail(details.selected_case_stage_label) ?? event.case_stage_label },
    { label: "Status Date", value: formatDate(stringDetail(details.status_date) ?? event.event_date) },
    { label: "Remarks", value: stringDetail(details.remarks) ?? event.description },
    { label: "Reason for Edit", value: stringDetail(details.reason) },
  ];
}

function customEventDetails(event: CaseTimelineEventRecord) {
  if (event.event_type_code !== "CUSTOM_EVENT") return null;
  const details = event.details_jsonb && typeof event.details_jsonb === "object" ? event.details_jsonb as Record<string, unknown> : {};
  const updatesCaseStatus = details.updates_case_status === true || String(details.updates_case_status).toLowerCase() === "true";
  return [
    { label: "Event Title", value: stringDetail(details.title) ?? event.title },
    { label: "Event Date", value: formatDate(stringDetail(details.event_date) ?? event.event_date) },
    { label: "Event Time", value: formatTime(stringDetail(details.event_time) ?? event.event_time) },
    { label: "Remarks", value: stringDetail(details.remarks) ?? event.description },
    { label: "Case Status", value: updatesCaseStatus ? stringDetail(details.selected_case_status_label) ?? event.case_status_label ?? event.status_label ?? stringDetail(details.selected_case_status_code) : null },
    { label: "Case Stage", value: updatesCaseStatus ? stringDetail(details.selected_case_stage_label) ?? event.case_stage_label ?? stringDetail(details.selected_case_stage_code) : null },
  ];
}

function timelineDetailItems(event: CaseTimelineEventRecord, assignment?: CaseAssignmentRecord | null) {
  if (isPetitionForReviewEvent(event)) {
    return [];
  }

  if (event.event_type_code === "CASE_RECEIVED") {
    return [{ label: "Date", value: formatDate(event.event_date) }];
  }

  const motionWorkflowDetails = motionWorkflowEventDetails(event);
  if (motionWorkflowDetails) {
    return motionWorkflowDetails;
  }

  const caseStatusUpdatedDetails = caseStatusUpdatedEventDetails(event);
  if (caseStatusUpdatedDetails) {
    return caseStatusUpdatedDetails;
  }

  const customDetails = customEventDetails(event);
  if (customDetails) {
    return customDetails;
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
    { label: "Stage", value: event.case_stage_label ?? event.status_label },
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
    : event.event_type_code === "CASE_RESOLVED" || event.event_type_code === "CASE_DECISION_APPROVED" || event.event_type_code === "COURT_FILING" || event.event_type_code === "MOTION_RECEIVED" || event.event_type_code === "MOTION_RESOLVED" || event.event_type_code === "MOTION_DECISION_APPROVED" || event.event_type_code === "CASE_STATUS_UPDATED" || event.event_type_code === "CUSTOM_EVENT"
      ? new Set(Object.keys(event.details_jsonb as Record<string, unknown>))
      : eventSourceTable(event) === "case_assignments"
      ? new Set(Object.keys(event.details_jsonb as Record<string, unknown>))
      : isMotionForReconsideration(event)
        ? new Set(["status", "status_label", "case_status", "case_status_label", "case_stage", "case_stage_label", "prosecutor", "prosecutor_short_name", "court", "court_name"])
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
    { label: "Assigned Prosecutor", value: petition.assigned_prosecutor_name ?? petition.handling_prosecutor_text },
    { label: "Filed By", value: petition.filed_by ?? motionFiledByLabel(petition.filed_by_code) },
    { label: "Status", value: petition.petition_status },
    { label: "Date Filed", value: formatOptionalDate(petition.date_filed ?? petition.date_received, petition.date_received_raw) },
    { label: "Time Filed", value: formatTime(petition.time_filed) },
    { label: "Status Date", value: formatDate(petition.status_date) },
    { label: "Date Resolved", value: formatOptionalDate(petition.date_resolved, petition.date_resolved_raw) },
    { label: "Date Approved", value: formatOptionalDate(petition.date_approved, petition.date_approved_raw) },
    { label: "Additional Details", value: (petition.additional_details_jsonb ?? []).map((row) => `${row.detail}: ${row.value}`).join("; ") },
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
        <OptionalDetailItem label="Assigned Prosecutor" value={motion.assigned_prosecutor_name} />
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



// Edit Activity is temporarily disabled pending further refinement of the event-specific edit workflow.
// Keep the edit code/RPC/forms in place, but do not expose an Edit action from the timeline UI.
const EDIT_WORKFLOW_TEMPORARILY_DISABLED = true;

const SUPPORTED_EVENT_EDIT_TYPES = new Set([
  "CASE_ASSIGNMENT",
  "CASE_REASSIGNMENT",
  "CASE_RESOLVED",
  "CASE_DECISION_APPROVED",
  "COURT_FILING",
  "MOTION_RECEIVED",
  "MOTION_RESOLVED",
  "MOTION_DECISION_APPROVED",
  "PETITION_FOR_REVIEW",
  "CASE_STATUS_UPDATED",
  "CUSTOM_EVENT",
]);

const EVENT_EDIT_TITLES: Record<string, string> = {
  CASE_ASSIGNMENT: "Edit Case Assignment",
  CASE_REASSIGNMENT: "Edit Case Reassignment",
  CASE_RESOLVED: "Edit Case Resolved",
  CASE_DECISION_APPROVED: "Edit Case Decision Approved",
  COURT_FILING: "Edit Court Filing",
  MOTION_RECEIVED: "Edit Motion Received",
  MOTION_RESOLVED: "Edit Motion Resolved",
  MOTION_DECISION_APPROVED: "Edit Motion Decision Approved",
  PETITION_FOR_REVIEW: "Edit Petition for Review",
  CASE_STATUS_UPDATED: "Edit Case Status Updated",
  CUSTOM_EVENT: "Edit Custom Event",
};

function editDialogTitle(event: CaseTimelineEventRecord | null) {
  if (!event) return "Edit activity";
  return EVENT_EDIT_TITLES[event.event_type_code ?? ""] ?? "Edit Legacy Activity";
}

function EditNotice() {
  return <p className="rounded-md border bg-muted/40 p-3 text-xs text-muted-foreground">Use Edit only to correct stored information. To change a legal decision or workflow outcome, void this activity and record the correct event.</p>;
}

function ReadOnlyActivityDetails({ event }: { event: CaseTimelineEventRecord | null }) {
  if (!event) return null;
  const details = event.details_jsonb && typeof event.details_jsonb === "object" ? event.details_jsonb as Record<string, unknown> : {};
  const rows = [
    { label: "Event Type", value: event.event_type_label ?? event.event_type_code },
    ...(event.event_type_code === "CASE_ASSIGNMENT" ? [
      { label: "Assigned Prosecutor", value: stringDetail(details.new_prosecutor_name) ?? event.prosecutor_short_name },
      { label: "Assigned Staff", value: stringDetail(details.staff_name) ?? event.staff_short_name },
      { label: "Automatic Case Status", value: event.case_status_label ?? event.status_label ?? stringDetail(details.case_status_label) },
      { label: "Automatic Case Stage", value: event.case_stage_label ?? stringDetail(details.case_stage_label) ?? stringDetail(details.automatic_case_stage) },
    ] : []),
    ...(event.event_type_code === "CASE_REASSIGNMENT" ? [
      { label: "Previous Prosecutor", value: stringDetail(details.previous_prosecutor_name) },
      { label: "New Assigned Prosecutor", value: stringDetail(details.new_prosecutor_name) ?? event.prosecutor_short_name },
      { label: "Assigned Staff", value: stringDetail(details.staff_name) ?? event.staff_short_name },
      { label: "Previous Assignment ID", value: stringDetail(details.previous_assignment_id) },
      { label: "Automatic Case Status", value: event.case_status_label ?? event.status_label ?? stringDetail(details.case_status_label) },
      { label: "Automatic Case Stage", value: event.case_stage_label ?? stringDetail(details.case_stage_label) ?? stringDetail(details.automatic_case_stage) },
    ] : []),
    ...(event.event_type_code === "CASE_RESOLVED" ? [
      { label: "Linked Assignment / Prosecutor", value: stringDetail(details.assigned_prosecutor_name) ?? event.prosecutor_short_name },
      { label: "Recommendation", value: stringDetail(details.recommendation_label) ?? stringDetail(details.recommendation_code) },
      { label: "Resulting Case Status", value: event.case_status_label ?? event.status_label },
      { label: "Resulting Case Stage", value: event.case_stage_label },
    ] : []),
    ...(event.event_type_code === "CASE_DECISION_APPROVED" ? [
      { label: "Linked Case Resolution", value: stringDetail(details.case_resolution_id) },
      { label: "Approved Decision", value: stringDetail(details.final_status_label) ?? stringDetail(details.final_status_code) },
      { label: "Filing/Dismissal Charge Actions", value: stringDetail(details.approval_actions_summary) ?? stringDetail(details.actions_summary) },
      { label: "Resulting Case Status", value: event.case_status_label ?? event.status_label },
      { label: "Resulting Case Stage", value: event.case_stage_label },
    ] : []),
    ...(event.event_type_code === "COURT_FILING" ? [
      { label: "Linked Approval Action", value: stringDetail(details.case_resolution_approval_action_id) ?? stringDetail(details.approved_filing_decision_label) },
      { label: "Charge Filed", value: stringDetail(details.charge_filed) },
      { label: "Criminal Case Numbers", value: stringDetail(details.criminal_case_numbers) ?? stringDetail(details.criminal_case_no) },
      { label: "Court Status History", value: stringDetail(details.court_status) ?? stringDetail(details.court_statuses) },
    ] : []),
    ...(event.event_type_code === "MOTION_RECEIVED" ? [
      { label: "Linked Case", value: event.docket_display_number ?? event.case_id },
      { label: "Automatic Stage", value: event.case_stage_label },
    ] : []),
    ...(event.event_type_code === "MOTION_RESOLVED" ? [
      { label: "Linked Motion", value: stringDetail(details.motion_title) ?? stringDetail(details.motion_id) },
      { label: "Recommendation / Decision", value: stringDetail(details.recommendation_label) ?? stringDetail(details.recommendation_code) },
      { label: "Automatic Stage", value: event.case_stage_label },
    ] : []),
    ...(event.event_type_code === "MOTION_DECISION_APPROVED" ? [
      { label: "Linked Motion Resolution", value: stringDetail(details.motion_resolution_id) },
      { label: "Approved Decision", value: stringDetail(details.approved_decision_label) ?? stringDetail(details.approved_decision_code) },
      { label: "Update Case Status", value: details.updates_case_status === true ? "Yes" : "No" },
      { label: "Selected Case Status", value: stringDetail(details.selected_case_status_label) },
      { label: "Selected Case Stage", value: stringDetail(details.selected_case_stage_label) },
    ] : []),
    ...(event.event_type_code === "PETITION_FOR_REVIEW" ? [
      { label: "Linked Update History Count", value: stringDetail(details.update_history_count) ?? "—" },
      { label: "Automatic State", value: `${event.case_status_label ?? "PENDING"} / ${event.case_stage_label ?? "PENDING_PETREV"}` },
    ] : []),
    ...(event.event_type_code === "CASE_STATUS_UPDATED" ? [
      { label: "Previous Case Status", value: stringDetail(details.previous_case_status_label) },
      { label: "New Case Status", value: stringDetail(details.selected_case_status_label) ?? event.case_status_label },
      { label: "Previous Case Stage", value: stringDetail(details.previous_case_stage_label) },
      { label: "New Case Stage", value: stringDetail(details.selected_case_stage_label) ?? event.case_stage_label },
    ] : []),
  ].filter((row) => hasDetailValue(row.value));

  return (
    <div className="space-y-3 rounded-md border bg-muted/20 p-3">
      <div>
        <p className="text-sm font-medium">Activity Details — Read Only</p>
        <p className="text-xs text-muted-foreground">Read-only fields define this activity’s legal or workflow history. To change them, void this activity and record the correct event.</p>
      </div>
      <div className="grid gap-2 sm:grid-cols-2">
        {rows.map((row) => <div key={row.label} className="rounded-md border bg-background p-2"><p className="text-xs text-muted-foreground">{row.label}</p><p className="text-sm font-medium">{row.value}</p></div>)}
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
  "PETITION_FOR_REVIEW_UPDATE",
  "CUSTOM_EVENT",
]);

function addableEventTypes(eventTypes: CaseEventTypeReference[]) {
  const priority = new Map([
    ["COURT_FILING", 140],
    ["COURT_STATUS_UPDATE", 145],
    ["MOTION_RECEIVED", 150],
    ["MOTION_DECISION_APPROVED", 160],
    ["PETITION_FOR_REVIEW", 170],
    ["PETITION_FOR_REVIEW_UPDATE", 171],
  ]);
  return eventTypes
    .filter((eventType) => ADD_EVENT_TYPE_CODES.has(eventType.code))
    .sort((left, right) => (priority.get(left.code) ?? left.sort_order) - (priority.get(right.code) ?? right.sort_order) || left.display_label.localeCompare(right.display_label));
}

export function CaseTimeline({
  caseId,
  courts = [],
  events,
  motions = [],
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
  const [courtStatusCandidates, setCourtStatusCandidates] = useState<CourtStatusUpdateCandidateRecord[]>([]);
  const [courtStatusStep, setCourtStatusStep] = useState(1);
  const [courtStatusForm, setCourtStatusForm] = useState({ courtFilingId: "", criminalCaseNumbers: [{ criminal_case_no: "" }] as CriminalCaseNumberRow[], courtStatuses: [{ court_status: "", status_date: "" }] as CourtStatusRow[], informationCount: "", additionalDetails: [] as MotionDetailRow[], remarks: "" });
  const [motionRecommendations, setMotionRecommendations] = useState<MotionResolutionRecommendationRecord[]>([]);
  const [motionResolutionApprovalCandidates, setMotionResolutionApprovalCandidates] = useState<MotionResolutionApprovalCandidateRecord[]>([]);
  const [caseStatusOptions, setCaseStatusOptions] = useState<CaseStatusOptionRecord[]>([]);
  const [caseStageOptions, setCaseStageOptions] = useState<CaseStageOptionRecord[]>([]);
  const [isRecommendationDialogOpen, setIsRecommendationDialogOpen] = useState(false);
  const [recommendationLabel, setRecommendationLabel] = useState("");
  const [isCourtPickerOpen, setIsCourtPickerOpen] = useState(false);
  const initialManilaDateTime = getManilaDateTimeInputValues();
  const [addForm, setAddForm] = useState({ eventTypeCode: "", eventDate: initialManilaDateTime.date, eventTime: initialManilaDateTime.time, title: "", description: "", prosecutorId: "", staffId: "", reason: "", recommendationCode: "", caseResolutionId: null as number | null, chargesForFiling: [emptyResolutionCharge()], chargesForDismissal: [emptyResolutionCharge()], approvalActions: [emptyApprovalAction()], courtFilingDecisionId: "", courtId: null as number | null, courtName: "", courtBranch: "", chargeFiled: "", informationCount: "", criminalCaseNo: "", motionTitle: "", filedByCode: "", assignedProsecutorId: "", motionResolveMotionId: "", motionRecommendationId: "", motionDecisionStep: 1, motionApprovalResolutionId: "", motionApprovalDecisionId: "", motionApprovedByProsecutorId: "", motionUpdateCaseStatus: "", motionSelectedCaseStatusId: "", motionSelectedCaseStageId: "", motionDetails: [] as MotionDetailRow[], petitionStatus: "", petitionUpdateStep: 1, petitionUpdatePetitionId: "", petitionUpdateCaseStatus: "", petitionSelectedCaseStatusId: "", petitionSelectedCaseStageId: "", petitionDetails: [] as MotionDetailRow[], customStep: 1, customUpdateCaseStatus: "", customSelectedCaseStatusId: "", customSelectedCaseStageId: "", customDetails: [] as MotionDetailRow[] });
  const [manilaNow, setManilaNow] = useState(() => new Date());
  const [isAddDateTimeDirty, setIsAddDateTimeDirty] = useState(false);
  const [editForm, setEditForm] = useState({ eventDate: "", eventTime: "", title: "", description: "", editReason: "", prosecutorId: "", staffId: "", assignedProsecutorId: "", filedByCode: "", petitionStatus: "", courtName: "", courtBranch: "", chargeFiled: "", informationCount: "", criminalCaseNo: "", approvedByProsecutorId: "", motionTitle: "", additionalDetails: [] as MotionDetailRow[] });
  const [voidReason, setVoidReason] = useState("");
  const [voidConfirmed, setVoidConfirmed] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);


  useEffect(() => {
    if (!isAddDialogOpen) return;

    const tick = () => {
      const now = new Date();
      setManilaNow(now);
      if (!isAddDateTimeDirty) {
        const current = getManilaDateTimeInputValues(now);
        setAddForm((form) => ({ ...form, eventDate: current.date, eventTime: current.time }));
      }
    };

    tick();
    const intervalId = window.setInterval(tick, 1000);
    return () => window.clearInterval(intervalId);
  }, [isAddDateTimeDirty, isAddDialogOpen]);

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
    setCourtStatusCandidates([]);
    setCourtStatusStep(1);
    setCourtStatusForm({ courtFilingId: "", criminalCaseNumbers: [{ criminal_case_no: "" }], courtStatuses: [{ court_status: "", status_date: "" }], informationCount: "", additionalDetails: [], remarks: "" });
    setMotionResolutionApprovalCandidates([]);
    setRecommendationLabel("");
    const currentManilaDateTime = getManilaDateTimeInputValues();
    setManilaNow(new Date());
    setIsAddDateTimeDirty(false);
    setAddForm({ eventTypeCode: addableEventTypes(eventTypes)[0]?.code ?? "", eventDate: currentManilaDateTime.date, eventTime: currentManilaDateTime.time, title: "", description: "", prosecutorId: "", staffId: "", reason: "", recommendationCode: "", caseResolutionId: null, chargesForFiling: [emptyResolutionCharge()], chargesForDismissal: [emptyResolutionCharge()], approvalActions: [emptyApprovalAction()], courtFilingDecisionId: "", courtId: null as number | null, courtName: "", courtBranch: "", chargeFiled: "", informationCount: "", criminalCaseNo: "", motionTitle: "", filedByCode: "", assignedProsecutorId: "", motionResolveMotionId: "", motionRecommendationId: "", motionDecisionStep: 1, motionApprovalResolutionId: "", motionApprovalDecisionId: "", motionApprovedByProsecutorId: "", motionUpdateCaseStatus: "", motionSelectedCaseStatusId: "", motionSelectedCaseStageId: "", motionDetails: [] as MotionDetailRow[], petitionStatus: "", petitionUpdateStep: 1, petitionUpdatePetitionId: "", petitionUpdateCaseStatus: "", petitionSelectedCaseStatusId: "", petitionSelectedCaseStageId: "", petitionDetails: [] as MotionDetailRow[], customStep: 1, customUpdateCaseStatus: "", customSelectedCaseStatusId: "", customSelectedCaseStageId: "", customDetails: [] as MotionDetailRow[] });
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

    const courtStatusCandidatesResult = await getCourtStatusUpdateCandidates(caseId);
    if (!courtStatusCandidatesResult.error) {
      setCourtStatusCandidates(courtStatusCandidatesResult.data);
      if (courtStatusCandidatesResult.data.length === 1) {
        const filing = courtStatusCandidatesResult.data[0];
        setCourtStatusForm({
          courtFilingId: String(filing.id),
          criminalCaseNumbers: filing.criminal_case_numbers.length ? filing.criminal_case_numbers.map((row) => ({ criminal_case_no: row.criminal_case_no })) : filing.criminal_case_no ? [{ criminal_case_no: filing.criminal_case_no }] : [{ criminal_case_no: "" }],
          courtStatuses: filing.court_statuses.length ? filing.court_statuses.map((row) => ({ court_status: row.court_status, status_date: row.status_date })) : [{ court_status: "", status_date: "" }],
          informationCount: filing.information_count === null || filing.information_count === undefined ? "" : String(filing.information_count),
          additionalDetails: filing.additional_details_jsonb.length ? filing.additional_details_jsonb : [],
          remarks: filing.court_status_update_remarks ?? "",
        });
      }
    }

    if (courtOptions.length === 0) {
      const courtsResult = await getCourts();
      if (!courtsResult.error) setCourtOptions(courtsResult.data);
    }

    const motionRecommendationsResult = await getMotionResolutionRecommendations();
    if (!motionRecommendationsResult.error) setMotionRecommendations(motionRecommendationsResult.data);

    const motionResolutionApprovalCandidatesResult = await getMotionResolutionApprovalCandidates(caseId);
    if (!motionResolutionApprovalCandidatesResult.error) setMotionResolutionApprovalCandidates(motionResolutionApprovalCandidatesResult.data);

    const statusOptionsResult = await getMotionDecisionCaseStatusOptions();
    if (!statusOptionsResult.error) setCaseStatusOptions(statusOptionsResult.data);

    const stageOptionsResult = await getMotionDecisionCaseStageOptions();
    if (!stageOptionsResult.error) setCaseStageOptions(stageOptionsResult.data);
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
    const isCourtStatusUpdate = addForm.eventTypeCode === "COURT_STATUS_UPDATE";
    const isMotionReceived = addForm.eventTypeCode === "MOTION_RECEIVED";
    const isMotionResolved = addForm.eventTypeCode === "MOTION_RESOLVED";
    const isMotionDecisionApproved = addForm.eventTypeCode === "MOTION_DECISION_APPROVED";
    const isCustomEvent = addForm.eventTypeCode === "CUSTOM_EVENT";
    if (!addForm.eventTypeCode || !addForm.eventDate) return;
    if ((isAssignment || isReassignment) && !addForm.prosecutorId) return;
    if (isReassignment && !addForm.reason.trim()) return;
    if (isResolved && !addForm.recommendationCode) return;
    if (isDecisionApproved && (!addForm.prosecutorId || !addForm.caseResolutionId || !addForm.approvalActions.some((action) => action.chargeText.trim()))) return;
    if (isCourtFiling && (!addForm.courtFilingDecisionId || !addForm.courtName.trim() || !addForm.chargeFiled.trim())) return;
    if (isCourtStatusUpdate && (!courtStatusForm.courtFilingId || courtStatusStep !== 3)) return;
    if (isMotionReceived && (!addForm.motionTitle.trim() || !addForm.filedByCode)) return;
    if (isMotionResolved && (!addForm.motionResolveMotionId || !addForm.motionRecommendationId)) return;
    if (isMotionDecisionApproved && (addForm.motionDecisionStep !== 5 || !addForm.motionApprovalResolutionId || !addForm.motionApprovalDecisionId || !addForm.motionApprovedByProsecutorId || !addForm.eventDate || !addForm.motionUpdateCaseStatus || (addForm.motionUpdateCaseStatus === "YES" && (!addForm.motionSelectedCaseStatusId || !addForm.motionSelectedCaseStageId)))) return;
    if (isCustomEvent && (addForm.customStep !== 3 || !addForm.title.trim() || !addForm.eventDate || !addForm.eventTime || !addForm.customUpdateCaseStatus || (addForm.customUpdateCaseStatus === "YES" && (!addForm.customSelectedCaseStatusId || !addForm.customSelectedCaseStageId)))) return;
    if (isReassignment && currentAssignment?.prosecutor_id === Number(addForm.prosecutorId)) {
      setActionError("The selected prosecutor is already assigned to this case.");
      return;
    }
    if (!isAssignment && !isReassignment && !isResolved && !isDecisionApproved && !isCourtFiling && !isCourtStatusUpdate && !isMotionReceived && !isMotionResolved && !isMotionDecisionApproved && !isCustomEvent && !addForm.title.trim()) return;
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
              : isCourtStatusUpdate
                ? await updateCourtFilingStatusDetails({
                  caseId,
                  courtFilingId: Number(courtStatusForm.courtFilingId),
                  criminalCaseNumbers: courtStatusForm.criminalCaseNumbers,
                  courtStatuses: courtStatusForm.courtStatuses,
                  informationCount: courtStatusForm.informationCount ? Number(courtStatusForm.informationCount) : null,
                  additionalDetails: courtStatusForm.additionalDetails,
                  remarks: courtStatusForm.remarks,
                })
                : isMotionReceived
                ? await recordMotionReceivedEvent({
                  caseId,
                  motionTitle: addForm.motionTitle,
                  filedByCode: addForm.filedByCode as "COMPLAINANT" | "RESPONDENT",
                  dateFiled: addForm.eventDate,
                  timeFiled: addForm.eventTime || null,
                  details: addForm.motionDetails,
                  assignedProsecutorId: addForm.assignedProsecutorId ? Number(addForm.assignedProsecutorId) : null,
                  remarks: addForm.description,
                })
                : isMotionResolved
                  ? await recordMotionResolvedEvent({
                    caseId,
                    caseMotionId: Number(addForm.motionResolveMotionId),
                    recommendationId: Number(addForm.motionRecommendationId),
                    dateResolved: addForm.eventDate,
                    timeResolved: addForm.eventTime || null,
                    remarks: addForm.description,
                  })
                  : isMotionDecisionApproved
                    ? await recordMotionDecisionApprovedEvent({
                      caseId,
                      motionResolutionId: Number(addForm.motionApprovalResolutionId),
                      approvedDecisionRecommendationId: Number(addForm.motionApprovalDecisionId),
                      approvedByProsecutorId: Number(addForm.motionApprovedByProsecutorId),
                      dateApproved: addForm.eventDate,
                      timeApproved: addForm.eventTime || null,
                      updateCaseStatus: addForm.motionUpdateCaseStatus === "YES",
                      selectedCaseStatusId: addForm.motionSelectedCaseStatusId ? Number(addForm.motionSelectedCaseStatusId) : null,
                      selectedCaseStageId: addForm.motionSelectedCaseStageId ? Number(addForm.motionSelectedCaseStageId) : null,
                      remarks: addForm.description,
                    })
                    : addForm.eventTypeCode === "PETITION_FOR_REVIEW"
                      ? await recordPetitionForReviewEvent({
                        caseId,
                        filedByCode: addForm.filedByCode as "COMPLAINANT" | "RESPONDENT",
                        dateFiled: addForm.eventDate,
                        timeFiled: addForm.eventTime || null,
                        petitionStatus: addForm.petitionStatus,
                        additionalDetails: addForm.petitionDetails,
                        assignedProsecutorId: addForm.assignedProsecutorId ? Number(addForm.assignedProsecutorId) : null,
                        remarks: addForm.description,
                      })
                      : addForm.eventTypeCode === "PETITION_FOR_REVIEW_UPDATE"
                        ? await recordPetitionForReviewUpdate({
                          caseId,
                          petitionForReviewId: Number(addForm.petitionUpdatePetitionId),
                          petitionStatus: addForm.petitionStatus,
                          statusDate: addForm.eventDate,
                          remarks: addForm.description,
                          additionalDetails: addForm.petitionDetails,
                          updateCaseStatus: addForm.petitionUpdateCaseStatus === "YES",
                          selectedCaseStatusId: addForm.petitionSelectedCaseStatusId ? Number(addForm.petitionSelectedCaseStatusId) : null,
                          selectedCaseStageId: addForm.petitionSelectedCaseStageId ? Number(addForm.petitionSelectedCaseStageId) : null,
                        })
          : await recordCustomCaseEvent({
        caseId,
        title: addForm.title,
        eventDate: addForm.eventDate,
        eventTime: addForm.eventTime,
        remarks: addForm.description,
        additionalDetails: addForm.customDetails,
        updateCaseStatus: addForm.customUpdateCaseStatus === "YES",
        selectedCaseStatusId: addForm.customSelectedCaseStatusId ? Number(addForm.customSelectedCaseStatusId) : null,
        selectedCaseStageId: addForm.customSelectedCaseStageId ? Number(addForm.customSelectedCaseStageId) : null,
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

  const openEditDialog = async (event: CaseTimelineEventRecord) => {
    if (event.is_voided) return;
    setActionError(null);
    if (prosecutors.length === 0) {
      const result = await getProsecutors(250);
      if (!result.error) setProsecutors(result.data);
    }
    if (staffMembers.length === 0) {
      const result = await getStaff(250);
      if (!result.error) setStaffMembers(result.data);
    }
    const details = event.details_jsonb && typeof event.details_jsonb === "object" ? event.details_jsonb as Record<string, unknown> : {};
    const sourceMotion = motions.find((motion) => sourceIdMatches(event, motion.id));
    const sourcePetition = petitionsForReview.find((petition) => sourceIdMatches(event, petition.id));
    setEditingEvent(event);
    setEditForm({
      eventDate: toDateInputValue(sourceMotion?.date_filed ?? sourcePetition?.date_filed ?? stringDetail(details.date_filed) ?? stringDetail(details.date_resolved) ?? stringDetail(details.date_approved) ?? stringDetail(details.status_date) ?? event.event_date),
      eventTime: sourceMotion?.time_filed ?? sourcePetition?.time_filed ?? stringDetail(details.time_filed) ?? stringDetail(details.time_resolved) ?? stringDetail(details.time_approved) ?? event.event_time ?? "",
      title: stringDetail(details.motion_title) ?? sourceMotion?.motion_title ?? event.title ?? "",
      description: sourceMotion?.remarks ?? sourcePetition?.remarks ?? stringDetail(details.remarks) ?? event.description ?? "",
      editReason: "",
      prosecutorId: String(details.prosecutor_id ?? details.assigned_prosecutor_id ?? ""),
      staffId: String(details.staff_id ?? ""),
      assignedProsecutorId: String(sourceMotion?.assigned_prosecutor_id ?? sourcePetition?.assigned_prosecutor_id ?? details.assigned_prosecutor_id ?? details.approved_by_prosecutor_id ?? details.approved_by_id ?? ""),
      filedByCode: sourceMotion?.filed_by_code ?? sourcePetition?.filed_by_code ?? stringDetail(details.filed_by_code) ?? "",
      petitionStatus: sourcePetition?.petition_status ?? stringDetail(details.petition_status) ?? "",
      courtName: stringDetail(details.court_name) ?? "",
      courtBranch: stringDetail(details.court_branch) ?? "",
      chargeFiled: stringDetail(details.charge_filed) ?? "",
      informationCount: String(details.information_count ?? ""),
      criminalCaseNo: stringDetail(details.criminal_case_no) ?? "",
      approvedByProsecutorId: String(details.approved_by_prosecutor_id ?? details.approved_by_id ?? ""),
      motionTitle: sourceMotion?.motion_title ?? stringDetail(details.motion_title) ?? event.title ?? "",
      additionalDetails: Array.isArray(sourceMotion?.details_jsonb) ? sourceMotion.details_jsonb.map((row) => ({ detail: String((row as Record<string, unknown>)?.detail ?? ""), value: String((row as Record<string, unknown>)?.value ?? "") })) : sourcePetition?.additional_details_jsonb ? sourcePetition.additional_details_jsonb : Array.isArray(details.additional_details) ? details.additional_details.map((row) => ({ detail: String((row as Record<string, unknown>)?.detail ?? ""), value: String((row as Record<string, unknown>)?.value ?? "") })) : Array.isArray(details.details) ? details.details.map((row) => ({ detail: String((row as Record<string, unknown>)?.detail ?? ""), value: String((row as Record<string, unknown>)?.value ?? "") })) : [],
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
    if (!editingEvent || !editForm.eventDate || !editForm.editReason.trim()) return;
    const code = editingEvent.event_type_code ?? "LEGACY_EVENT";
    const isCustomOrLegacy = code === "CUSTOM_EVENT" || !SUPPORTED_EVENT_EDIT_TYPES.has(code);
    if (isCustomOrLegacy && !editForm.title.trim()) return;
    setIsSaving(true);
    setActionError(null);
    const result = await editCaseEvent({
      caseEventId: editingEvent.case_event_id,
      eventTypeCode: code,
      values: {
        event_date: editForm.eventDate,
        event_time: editForm.eventTime || null,
        title: editForm.title,
        description: editForm.description,
        remarks: editForm.description,
        ...(["CASE_ASSIGNMENT", "CASE_REASSIGNMENT", "CASE_RESOLVED"].includes(code) ? {} : { prosecutor_id: editForm.prosecutorId ? Number(editForm.prosecutorId) : null }),
        ...(["CASE_ASSIGNMENT", "CASE_REASSIGNMENT"].includes(code) ? {} : { staff_id: editForm.staffId ? Number(editForm.staffId) : null }),
        ...(["CASE_ASSIGNMENT", "CASE_REASSIGNMENT"].includes(code) ? {} : { assigned_prosecutor_id: editForm.assignedProsecutorId ? Number(editForm.assignedProsecutorId) : null }),
        approved_by_prosecutor_id: editForm.approvedByProsecutorId ? Number(editForm.approvedByProsecutorId) : null,
        filed_by_code: editForm.filedByCode || null,
        petition_status: editForm.petitionStatus,
        court_name: editForm.courtName,
        court_branch: editForm.courtBranch,
        charge_filed: editForm.chargeFiled,
        information_count: editForm.informationCount ? Number(editForm.informationCount) : null,
        motion_title: editForm.motionTitle,
        details: editForm.additionalDetails,
      },
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
    const shouldRefreshMotionApprovalCandidates = voidingEvent.event_type_code === "MOTION_DECISION_APPROVED";
    setVoidingEvent(null);
    await onChanged?.();
    if (shouldRefreshMotionApprovalCandidates) {
      const candidatesResult = await getMotionResolutionApprovalCandidates(caseId);
      if (!candidatesResult.error) setMotionResolutionApprovalCandidates(candidatesResult.data);
    }
    if (shouldPromptStatusUpdate) {
      onUpdateStatus?.();
    }
  };

  const isAddingAssignment = addForm.eventTypeCode === "CASE_ASSIGNMENT";
  const isAddingReassignment = addForm.eventTypeCode === "CASE_REASSIGNMENT";
  const isAddingResolved = addForm.eventTypeCode === "CASE_RESOLVED";
  const isAddingDecisionApproved = addForm.eventTypeCode === "CASE_DECISION_APPROVED";
  const isAddingCourtFiling = addForm.eventTypeCode === "COURT_FILING";
  const isAddingCourtStatusUpdate = addForm.eventTypeCode === "COURT_STATUS_UPDATE";
  const selectedCourtStatusFiling = courtStatusCandidates.find((filing) => String(filing.id) === courtStatusForm.courtFilingId) ?? null;
  const loadCourtStatusFiling = (filingId: string) => {
    const filing = courtStatusCandidates.find((item) => String(item.id) === filingId);
    setCourtStatusForm({
      courtFilingId: filingId,
      criminalCaseNumbers: filing?.criminal_case_numbers.length ? filing.criminal_case_numbers.map((row) => ({ criminal_case_no: row.criminal_case_no })) : filing?.criminal_case_no ? [{ criminal_case_no: filing.criminal_case_no }] : [{ criminal_case_no: "" }],
      courtStatuses: filing?.court_statuses.length ? filing.court_statuses.map((row) => ({ court_status: row.court_status, status_date: row.status_date })) : [{ court_status: "", status_date: "" }],
      informationCount: filing?.information_count === null || filing?.information_count === undefined ? "" : String(filing.information_count),
      additionalDetails: filing?.additional_details_jsonb.length ? filing.additional_details_jsonb : [],
      remarks: filing?.court_status_update_remarks ?? "",
    });
  };

  const isAddingPetitionForReview = addForm.eventTypeCode === "PETITION_FOR_REVIEW";
  const isAddingPetitionForReviewUpdate = addForm.eventTypeCode === "PETITION_FOR_REVIEW_UPDATE";
  const activePetitionsForReview = petitionsForReview.filter((petition) => !petition.is_voided);
  const selectedPetitionForReview = activePetitionsForReview.find((petition) => Number(petition.id) === Number(addForm.petitionUpdatePetitionId)) ?? null;
  const selectedPetitionStatus = caseStatusOptions.find((status) => Number(status.id) === Number(addForm.petitionSelectedCaseStatusId)) ?? null;
  const selectedPetitionStage = caseStageOptions.find((stage) => Number(stage.id) === Number(addForm.petitionSelectedCaseStageId)) ?? null;
  const isAddingMotionReceived = addForm.eventTypeCode === "MOTION_RECEIVED";
  const isAddingMotionResolved = addForm.eventTypeCode === "MOTION_RESOLVED";
  const isAddingMotionDecisionApproved = addForm.eventTypeCode === "MOTION_DECISION_APPROVED";
  const isAddingCustomEvent = addForm.eventTypeCode === "CUSTOM_EVENT";
  const approvingProsecutors = prosecutors.filter((prosecutor) => {
    const position = prosecutor as { position_code?: string | null; position_group_type?: string | null };
    return position.position_group_type === "PROSECUTOR" && ["CHIEF_PROSECUTOR", "DEPUTY_PROSECUTOR"].includes(String(position.position_code ?? ""));
  });
  const showChargesForFiling = addForm.recommendationCode === "CASE_FOR_FILING" || addForm.recommendationCode === "MIXED_RESULT";
  const showChargesForDismissal = addForm.recommendationCode === "CASE_DISMISSAL" || addForm.recommendationCode === "MIXED_RESULT";
  const isAddingAssignmentLike = isAddingAssignment || isAddingReassignment;
  const activeAssignments = assignments.filter((assignment) => !assignment.unassigned_at && ("is_voided" in assignment ? assignment.is_voided === false : true));
  const currentAssignment = [...activeAssignments].sort((left, right) => {
    const leftTime = left.assigned_at ? new Date(left.assigned_at).getTime() : 0;
    const rightTime = right.assigned_at ? new Date(right.assigned_at).getTime() : 0;
    return rightTime - leftTime || Number(right.id) - Number(left.id);
  })[0] ?? null;
  const eligibleMotions = motions.filter((motion) => !motion.is_voided && motion.case_event_id && !motion.active_motion_resolution_id);
  const eligibleMotionResolutionApprovals = motionResolutionApprovalCandidates.filter((resolution) => !resolution.active_motion_decision_approval_id);
  const selectedMotionApprovalResolution = eligibleMotionResolutionApprovals.find((resolution) => Number(resolution.id) === Number(addForm.motionApprovalResolutionId)) ?? null;
  const selectedMotionApprovalDecision = motionRecommendations.find((recommendation) => Number(recommendation.id) === Number(addForm.motionApprovalDecisionId)) ?? null;
  const selectedMotionApprover = approvingProsecutors.find((prosecutor) => Number(prosecutor.id) === Number(addForm.motionApprovedByProsecutorId)) ?? null;
  const selectedMotionStatus = caseStatusOptions.find((status) => Number(status.id) === Number(addForm.motionSelectedCaseStatusId)) ?? null;
  const selectedMotionStage = caseStageOptions.find((stage) => Number(stage.id) === Number(addForm.motionSelectedCaseStageId)) ?? null;
  const selectedCustomStatus = caseStatusOptions.find((status) => Number(status.id) === Number(addForm.customSelectedCaseStatusId)) ?? null;
  const selectedCustomStage = caseStageOptions.find((stage) => Number(stage.id) === Number(addForm.customSelectedCaseStageId)) ?? null;
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

  useEffect(() => {
    if ((addForm.eventTypeCode !== "MOTION_RECEIVED" && addForm.eventTypeCode !== "PETITION_FOR_REVIEW") || addForm.assignedProsecutorId || !currentAssignment?.prosecutor_id) return;
    setAddForm((form) => ({ ...form, assignedProsecutorId: String(currentAssignment.prosecutor_id) }));
  }, [addForm.assignedProsecutorId, addForm.eventTypeCode, currentAssignment?.prosecutor_id]);

  useEffect(() => {
    if (addForm.eventTypeCode !== "PETITION_FOR_REVIEW_UPDATE" || addForm.petitionUpdatePetitionId || activePetitionsForReview.length !== 1) return;
    const petition = activePetitionsForReview[0];
    setAddForm((form) => ({ ...form, petitionUpdatePetitionId: String(petition.id), petitionStatus: petition.petition_status ?? "", eventDate: toDateInputValue(petition.status_date ?? petition.date_filed ?? petition.date_received), description: petition.remarks ?? "", petitionDetails: petition.additional_details_jsonb ?? [] }));
  }, [addForm.eventTypeCode, addForm.petitionUpdatePetitionId, activePetitionsForReview]);

  useEffect(() => {
    if (addForm.eventTypeCode !== "MOTION_RESOLVED" || addForm.motionResolveMotionId || eligibleMotions.length !== 1) return;
    setAddForm((form) => ({ ...form, motionResolveMotionId: String(eligibleMotions[0].id) }));
  }, [addForm.eventTypeCode, addForm.motionResolveMotionId, eligibleMotions]);

  useEffect(() => {
    if (addForm.eventTypeCode !== "MOTION_DECISION_APPROVED" || addForm.motionApprovalResolutionId || eligibleMotionResolutionApprovals.length !== 1) return;
    setAddForm((form) => ({ ...form, motionApprovalResolutionId: String(eligibleMotionResolutionApprovals[0].id) }));
  }, [addForm.eventTypeCode, addForm.motionApprovalResolutionId, eligibleMotionResolutionApprovals]);

  const handleAddRecommendationSave = async () => {
    if (!recommendationLabel.trim()) return;
    setIsSaving(true);
    setActionError(null);
    const result = await addMotionResolutionRecommendation({ displayLabel: recommendationLabel });
    setIsSaving(false);
    if (result.error) {
      setActionError(result.error.message);
      return;
    }
    const recommendationsResult = await getMotionResolutionRecommendations();
    if (!recommendationsResult.error) setMotionRecommendations(recommendationsResult.data);
    setAddForm((form) => form.eventTypeCode === "MOTION_DECISION_APPROVED" ? { ...form, motionApprovalDecisionId: String(result.data) } : { ...form, motionRecommendationId: String(result.data) });
    setIsRecommendationDialogOpen(false);
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
                            <AdditionalDetailsRows rows={motionReceivedAdditionalDetails(event)} />
                            <AdditionalDetailsRows rows={customEventAdditionalDetails(event)} />
                            {motionDetails ? <MotionEventDetails motion={motionDetails} /> : null}
                            {petitionDetails ? (
                              <PetitionForReviewEventDetails petition={petitionDetails} />
                            ) : null}
                            {!event.is_voided ? (
                              <div className="flex gap-2 border-t pt-3">
                                {!EDIT_WORKFLOW_TEMPORARILY_DISABLED ? <Button type="button" variant="outline" size="sm" onClick={() => openEditDialog(event)}>Edit</Button> : null}
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
          <Button type="button" onClick={openAddDialog}>Add Event</Button>
        </div>
      </CardContent>

      <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
        <DialogContent className="grid max-h-[calc(100vh-2rem)] grid-rows-[auto_minmax(0,1fr)_auto] gap-3 p-5 sm:max-w-xl">
          <DialogHeader className="gap-1">
            <DialogTitle>Add event</DialogTitle>
            <DialogDescription>Add a new activity to this case timeline.</DialogDescription>
            <p className="text-xs text-muted-foreground">Current Philippine time: {formatManilaClock(manilaNow)}</p>
          </DialogHeader>
          <div className="min-h-0 space-y-3 overflow-y-auto pr-1">
            {eventTypesError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{eventTypesError}</p> : null}
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            {isAddingMotionDecisionApproved && addForm.motionDecisionStep === 3 ? null : (
              <div className="space-y-2">
                <Label htmlFor="add-event-type">Event Type</Label>
                <select id="add-event-type" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.eventTypeCode} onChange={(e) => setAddForm((form) => ({ ...form, eventTypeCode: e.target.value, title: e.target.value === "CASE_ASSIGNMENT" ? "Case Assignment" : e.target.value === "CASE_REASSIGNMENT" ? "Case Reassignment" : e.target.value === "CASE_RESOLVED" ? "Case Resolved" : e.target.value === "CASE_DECISION_APPROVED" ? "Case Decision Approved" : e.target.value === "COURT_FILING" ? "Court Filing" : e.target.value === "COURT_STATUS_UPDATE" ? "Court Status Update" : e.target.value === "MOTION_RECEIVED" ? "Motion Received" : e.target.value === "MOTION_RESOLVED" ? "Motion Resolved" : e.target.value === "MOTION_DECISION_APPROVED" ? "Motion Decision Approved" : e.target.value === "PETITION_FOR_REVIEW" ? "Petition for Review" : e.target.value === "PETITION_FOR_REVIEW_UPDATE" ? "Petition for Review Update" : form.title }))}>
                  {eventTypes.map((eventType) => <option key={eventType.code} value={eventType.code}>{eventType.display_label}</option>)}
                </select>
              </div>
            )}
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
                <div className="grid gap-4 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="add-assignment-date">{isAddingReassignment ? "Reassignment Date" : "Assignment Date"}</Label><Input id="add-assignment-date" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-2"><Label htmlFor="add-assignment-time">{isAddingReassignment ? "Reassignment Time" : "Assignment Time"}</Label><Input id="add-assignment-time" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
                <div className="space-y-2"><Label htmlFor="add-assigned-staff">{isAddingReassignment ? "New Staff" : "Assigned Staff"}</Label><select id="add-assigned-staff" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.staffId} onChange={(e) => setAddForm((form) => ({ ...form, staffId: e.target.value }))}><option value="">No staff selected</option>{staffMembers.map((staff) => <option key={staff.id} value={staff.id}>{staff.short_name ?? staff.full_name}</option>)}</select></div>
                {isAddingReassignment ? <div className="space-y-2"><Label htmlFor="add-reassignment-reason">Reason</Label><Textarea id="add-reassignment-reason" required value={addForm.reason} onChange={(e) => setAddForm((form) => ({ ...form, reason: e.target.value }))} /></div> : null}
                <div className="space-y-2"><Label htmlFor="add-assignment-remarks">Remarks</Label><Textarea id="add-assignment-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingResolved ? (
              <>
                <div className="space-y-2"><Label htmlFor="add-resolution-recommendation">Recommendation</Label><select id="add-resolution-recommendation" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.recommendationCode} onChange={(e) => setAddForm((form) => ({ ...form, recommendationCode: e.target.value }))}><option value="">Select recommendation</option><option value="CASE_FOR_FILING">Case for Filing</option><option value="CASE_DISMISSAL">Case Dismissal</option><option value="MIXED_RESULT">Mixed Result</option></select></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-date-resolved">Date Resolved</Label><Input id="add-date-resolved" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-1"><Label htmlFor="add-time-resolved">Time Resolved</Label><Input id="add-time-resolved" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
                {showChargesForFiling ? <ChargeEntries title="Charges for Filing" charges={addForm.chargesForFiling} caseViolations={caseViolations} violations={violations} onChange={(charges) => setAddForm((form) => ({ ...form, chargesForFiling: charges }))} /> : null}
                {showChargesForDismissal ? <ChargeEntries title="Charges for Dismissal" charges={addForm.chargesForDismissal} caseViolations={caseViolations} violations={violations} onChange={(charges) => setAddForm((form) => ({ ...form, chargesForDismissal: charges }))} /> : null}
                <div className="space-y-1"><Label htmlFor="add-resolution-remarks">Remarks</Label><Textarea id="add-resolution-remarks" className="min-h-20" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingDecisionApproved ? (
              <>
                {caseResolutions.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100">No active unapproved case resolution available to approve.</div> : null}
                <div className="space-y-2"><Label htmlFor="add-approval-resolution">Resolution to Approve</Label><select id="add-approval-resolution" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.caseResolutionId ?? ""} onChange={(e) => { const resolutionId = e.target.value ? Number(e.target.value) : null; const resolution = caseResolutions.find((item) => item.id === resolutionId) ?? null; setAddForm((form) => ({ ...form, caseResolutionId: resolutionId, approvalActions: resolution ? approvalActionsFromResolution(resolution) : [emptyApprovalAction()] })); }}><option value="">Select resolution</option>{caseResolutions.map((resolution) => <option key={resolution.id} value={resolution.id}>{formatRecommendationLabel(resolution.recommendation_code)} • {formatDate(resolution.date_resolved)} • Resolution #{resolution.id}</option>)}</select>{selectedApprovalResolution ? <p className="text-xs text-muted-foreground">Loaded {selectedApprovalResolution.charge_actions.length} recommended action{selectedApprovalResolution.charge_actions.length === 1 ? "" : "s"} from the selected resolution.</p> : null}</div>
                <div className="space-y-2"><Label htmlFor="add-approved-by">Approved By</Label><select id="add-approved-by" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.prosecutorId} onChange={(e) => setAddForm((form) => ({ ...form, prosecutorId: e.target.value }))}><option value="">Select approving prosecutor</option>{approvingProsecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.short_name ?? prosecutor.full_name}</option>)}</select>{approvingProsecutors.length === 0 ? <p className="text-xs text-muted-foreground">No active Chief Prosecutor or Deputy Prosecutor records found.</p> : null}</div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-date-approved">Date Approved</Label><Input id="add-date-approved" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-1"><Label htmlFor="add-time-approved">Time Approved</Label><Input id="add-time-approved" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
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
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-date-filed">Date Filed</Label><Input id="add-date-filed" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-1"><Label htmlFor="add-time-filed">Time Filed</Label><Input id="add-time-filed" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-information-count">Information Count</Label><Input id="add-information-count" type="number" min="0" value={addForm.informationCount} onChange={(e) => setAddForm((form) => ({ ...form, informationCount: e.target.value }))} /></div><div className="space-y-1"><Label htmlFor="add-criminal-case-no">Criminal Case No.</Label><Input id="add-criminal-case-no" value={addForm.criminalCaseNo} onChange={(e) => setAddForm((form) => ({ ...form, criminalCaseNo: e.target.value }))} /></div></div>
                <div className="space-y-2"><Label htmlFor="add-court-filing-remarks">Remarks</Label><Textarea id="add-court-filing-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingCourtStatusUpdate ? (
              <>
                {courtStatusStep === 1 ? <>
                  {courtStatusCandidates.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100">No active Court Filing is available for update.</div> : null}
                  <div className="space-y-2"><Label htmlFor="court-status-filing">Court Filing</Label><select id="court-status-filing" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={courtStatusForm.courtFilingId} onChange={(e) => loadCourtStatusFiling(e.target.value)}><option value="">Select Court Filing</option>{courtStatusCandidates.map((filing) => <option key={filing.id} value={filing.id}>{filing.charge_filed} • {filing.court_name}{filing.court_branch ? ` Branch ${filing.court_branch}` : ""} • {formatDate(filing.date_filed)}{filing.criminal_case_no ? ` • ${filing.criminal_case_no}` : ""}</option>)}</select></div>
                  <div className="flex justify-end"><Button type="button" onClick={() => setCourtStatusStep(2)} disabled={!courtStatusForm.courtFilingId}>Next</Button></div>
                </> : null}
                {courtStatusStep === 2 && selectedCourtStatusFiling ? <>
                  <div className="rounded-md border bg-muted/40 p-3"><p className="mb-2 text-sm font-medium">Selected Court Filing</p><div className="grid gap-3 sm:grid-cols-2"><OptionalDetailItem label="Approved Filing Decision" value={selectedCourtStatusFiling.approved_filing_decision} /><OptionalDetailItem label="Court" value={selectedCourtStatusFiling.court_name} /><OptionalDetailItem label="Court Branch" value={selectedCourtStatusFiling.court_branch} /><OptionalDetailItem label="Charge Filed" value={selectedCourtStatusFiling.charge_filed} /><OptionalDetailItem label="Date Filed" value={formatDate(selectedCourtStatusFiling.date_filed)} /><OptionalDetailItem label="Time Filed" value={formatTime(selectedCourtStatusFiling.time_filed)} /></div></div>
                  <div className="space-y-2"><div className="flex items-center justify-between gap-2"><Label>Criminal Case Numbers</Label><Button type="button" variant="outline" size="sm" onClick={() => setCourtStatusForm((form) => ({ ...form, criminalCaseNumbers: [...form.criminalCaseNumbers, { criminal_case_no: "" }] }))}>Add Criminal Case Number</Button></div>{courtStatusForm.criminalCaseNumbers.map((row, index) => <div key={index} className="grid gap-2 sm:grid-cols-[1fr_auto]"><Input placeholder="Criminal Case Number" value={row.criminal_case_no} onChange={(e) => setCourtStatusForm((form) => ({ ...form, criminalCaseNumbers: form.criminalCaseNumbers.map((item, itemIndex) => itemIndex === index ? { criminal_case_no: e.target.value } : item) }))} /><Button type="button" variant="outline" size="sm" onClick={() => setCourtStatusForm((form) => ({ ...form, criminalCaseNumbers: form.criminalCaseNumbers.length === 1 ? [{ criminal_case_no: "" }] : form.criminalCaseNumbers.filter((_, itemIndex) => itemIndex !== index) }))}>Remove</Button></div>)}</div>
                  <div className="space-y-2"><div className="flex items-center justify-between gap-2"><Label>Court Statuses</Label><Button type="button" variant="outline" size="sm" onClick={() => setCourtStatusForm((form) => ({ ...form, courtStatuses: [...form.courtStatuses, { court_status: "", status_date: "" }] }))}>Add Court Status</Button></div>{courtStatusForm.courtStatuses.map((row, index) => <div key={index} className="grid gap-2 sm:grid-cols-[1fr_12rem_auto]"><Input placeholder="Court Status" value={row.court_status} onChange={(e) => setCourtStatusForm((form) => ({ ...form, courtStatuses: form.courtStatuses.map((item, itemIndex) => itemIndex === index ? { ...item, court_status: e.target.value } : item) }))} /><Input type="date" value={row.status_date} onChange={(e) => setCourtStatusForm((form) => ({ ...form, courtStatuses: form.courtStatuses.map((item, itemIndex) => itemIndex === index ? { ...item, status_date: e.target.value } : item) }))} /><Button type="button" variant="outline" size="sm" onClick={() => setCourtStatusForm((form) => ({ ...form, courtStatuses: form.courtStatuses.length === 1 ? [{ court_status: "", status_date: "" }] : form.courtStatuses.filter((_, itemIndex) => itemIndex !== index) }))}>Remove</Button></div>)}</div>
                  <div className="space-y-2"><Label htmlFor="court-status-information-count">Information Count</Label><Input id="court-status-information-count" type="number" min="0" value={courtStatusForm.informationCount} onChange={(e) => setCourtStatusForm((form) => ({ ...form, informationCount: e.target.value }))} /></div>
                  <div className="space-y-2"><div className="flex items-center justify-between gap-2"><Label>Additional Details</Label><Button type="button" variant="outline" size="sm" onClick={() => setCourtStatusForm((form) => ({ ...form, additionalDetails: [...form.additionalDetails, { detail: "", value: "" }] }))}>Add Detail</Button></div>{courtStatusForm.additionalDetails.map((row, index) => <div key={index} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]"><Input placeholder="Detail" value={row.detail} onChange={(e) => setCourtStatusForm((form) => ({ ...form, additionalDetails: form.additionalDetails.map((item, itemIndex) => itemIndex === index ? { ...item, detail: e.target.value } : item) }))} /><Input placeholder="Value" value={row.value} onChange={(e) => setCourtStatusForm((form) => ({ ...form, additionalDetails: form.additionalDetails.map((item, itemIndex) => itemIndex === index ? { ...item, value: e.target.value } : item) }))} /><Button type="button" variant="outline" size="sm" onClick={() => setCourtStatusForm((form) => ({ ...form, additionalDetails: form.additionalDetails.filter((_, itemIndex) => itemIndex !== index) }))}>Remove</Button></div>)}</div>
                  <div className="space-y-2"><Label htmlFor="court-status-remarks">Remarks</Label><Textarea id="court-status-remarks" value={courtStatusForm.remarks} onChange={(e) => setCourtStatusForm((form) => ({ ...form, remarks: e.target.value }))} /></div>
                  <div className="flex justify-between"><Button type="button" variant="outline" onClick={() => setCourtStatusStep(1)}>Back</Button><Button type="button" onClick={() => setCourtStatusStep(3)} disabled={courtStatusForm.informationCount !== "" && Number(courtStatusForm.informationCount) < 0}>Next</Button></div>
                </> : null}
                {courtStatusStep === 3 && selectedCourtStatusFiling ? <>
                  <div className="rounded-md border bg-background p-3"><p className="mb-2 text-sm font-medium">Review</p><div className="grid gap-3 sm:grid-cols-2"><OptionalDetailItem label="Selected Court Filing" value={`${selectedCourtStatusFiling.charge_filed} • ${selectedCourtStatusFiling.court_name}`} /><OptionalDetailItem label="Approved Filing Decision" value={selectedCourtStatusFiling.approved_filing_decision} /><OptionalDetailItem label="Court" value={selectedCourtStatusFiling.court_name} /><OptionalDetailItem label="Court Branch" value={selectedCourtStatusFiling.court_branch} /><OptionalDetailItem label="Charge Filed" value={selectedCourtStatusFiling.charge_filed} /><OptionalDetailItem label="Date Filed" value={formatDate(selectedCourtStatusFiling.date_filed)} /><OptionalDetailItem label="Time Filed" value={formatTime(selectedCourtStatusFiling.time_filed)} /><OptionalDetailItem label="Criminal Case Numbers" value={courtStatusForm.criminalCaseNumbers.map((row) => row.criminal_case_no.trim()).filter(Boolean).join("; ")} /><OptionalDetailItem label="Court Statuses" value={courtStatusForm.courtStatuses.filter((row) => row.court_status.trim() || row.status_date).map((row) => `${row.court_status.trim()} — ${formatDate(row.status_date)}`).join("; ")} /><OptionalDetailItem label="Information Count" value={courtStatusForm.informationCount} /><OptionalDetailItem label="Additional Details" value={courtStatusForm.additionalDetails.filter((row) => row.detail.trim() || row.value.trim()).map((row) => `${row.detail.trim()}: ${row.value.trim()}`).join("; ")} /><OptionalDetailItem label="Remarks" value={courtStatusForm.remarks} /></div></div>
                  <div className="flex justify-start"><Button type="button" variant="outline" onClick={() => setCourtStatusStep(2)}>Back</Button></div>
                </> : null}
              </>
            ) : isAddingMotionReceived ? (
              <>
                <div className="space-y-2"><Label htmlFor="add-motion-title">Motion Title</Label><Input id="add-motion-title" value={addForm.motionTitle} onChange={(e) => setAddForm((form) => ({ ...form, motionTitle: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="add-motion-filed-by">Filed By</Label><select id="add-motion-filed-by" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.filedByCode} onChange={(e) => setAddForm((form) => ({ ...form, filedByCode: e.target.value }))}><option value="">Select filer</option><option value="COMPLAINANT">Complainant</option><option value="RESPONDENT">Respondent</option></select></div>
                <div className="space-y-2"><Label htmlFor="add-motion-assigned-prosecutor">Assigned Prosecutor</Label><select id="add-motion-assigned-prosecutor" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.assignedProsecutorId} onChange={(e) => setAddForm((form) => ({ ...form, assignedProsecutorId: e.target.value }))}><option value="">No prosecutor selected</option>{prosecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.short_name ?? prosecutor.full_name}</option>)}</select></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-motion-date-filed">Date Filed</Label><Input id="add-motion-date-filed" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-1"><Label htmlFor="add-motion-time-filed">Time Filed</Label><Input id="add-motion-time-filed" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
                <div className="space-y-2"><div className="flex items-center justify-between gap-2"><Label>Additional Details</Label><Button type="button" variant="outline" size="sm" onClick={() => setAddForm((form) => ({ ...form, motionDetails: [...form.motionDetails, { detail: "", value: "" }] }))}>Add Detail</Button></div>{addForm.motionDetails.map((row, index) => <div key={index} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]"><Input placeholder="Detail" value={row.detail} onChange={(e) => setAddForm((form) => ({ ...form, motionDetails: form.motionDetails.map((item, itemIndex) => itemIndex === index ? { ...item, detail: e.target.value } : item) }))} /><Input placeholder="Value" value={row.value} onChange={(e) => setAddForm((form) => ({ ...form, motionDetails: form.motionDetails.map((item, itemIndex) => itemIndex === index ? { ...item, value: e.target.value } : item) }))} /><Button type="button" variant="outline" size="sm" onClick={() => setAddForm((form) => ({ ...form, motionDetails: form.motionDetails.filter((_, itemIndex) => itemIndex !== index) }))}>Remove</Button></div>)}</div>
                <div className="space-y-2"><Label htmlFor="add-motion-remarks">Remarks</Label><Textarea id="add-motion-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingMotionResolved ? (
              <>
                {eligibleMotions.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100">No pending motion is available for resolution.</div> : null}
                <div className="space-y-2"><Label htmlFor="add-motion-to-resolve">Motion</Label><select id="add-motion-to-resolve" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionResolveMotionId} onChange={(e) => setAddForm((form) => ({ ...form, motionResolveMotionId: e.target.value }))}><option value="">Select motion</option>{eligibleMotions.map((motion) => <option key={motion.id} value={motion.id}>{motion.motion_title ?? motion.motion_name} • {motionFiledByLabel(motion.filed_by_code) ?? motion.filed_by ?? "—"} • {formatDate(motion.date_filed ?? motion.date_received)}</option>)}</select></div>
                <div className="space-y-2"><Label htmlFor="add-motion-recommendation">Recommendation</Label><select id="add-motion-recommendation" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionRecommendationId} onChange={(e) => { if (e.target.value === "__add__") { setRecommendationLabel(""); setIsRecommendationDialogOpen(true); return; } setAddForm((form) => ({ ...form, motionRecommendationId: e.target.value })); }}><option value="">Select recommendation</option>{motionRecommendations.map((recommendation) => <option key={recommendation.id} value={recommendation.id}>{recommendation.display_label}</option>)}<option value="__add__">+ Add Recommendation</option></select></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-motion-date-resolved">Date Resolved</Label><Input id="add-motion-date-resolved" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-1"><Label htmlFor="add-motion-time-resolved">Time Resolved</Label><Input id="add-motion-time-resolved" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
                <div className="space-y-2"><Label htmlFor="add-motion-resolution-remarks">Remarks</Label><Textarea id="add-motion-resolution-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingMotionDecisionApproved ? (
              <>
                <div className="rounded-md border bg-muted/30 p-3 text-sm font-medium">Step {addForm.motionDecisionStep} of 5</div>
                {addForm.motionDecisionStep === 1 ? <>
                  {eligibleMotionResolutionApprovals.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-900/60 dark:bg-amber-950/30 dark:text-amber-100">No motion resolution is available for approval.</div> : null}
                  <div className="space-y-2"><Label htmlFor="motion-approval-resolution">Motion Resolution</Label><select id="motion-approval-resolution" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionApprovalResolutionId} onChange={(e) => setAddForm((form) => ({ ...form, motionApprovalResolutionId: e.target.value }))}><option value="">Select motion resolution</option>{eligibleMotionResolutionApprovals.map((resolution) => <option key={resolution.id} value={resolution.id}>{resolution.motion_title ?? "Motion"} • {motionFiledByLabel(resolution.filed_by_code) ?? resolution.filed_by ?? "—"} • {resolution.recommendation_label ?? resolution.recommendation_code ?? "—"} • {formatDate(resolution.date_resolved)}</option>)}</select></div>
                  <div className="space-y-2"><Label htmlFor="motion-approved-decision">Decision Approved</Label><select id="motion-approved-decision" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionApprovalDecisionId} onChange={(e) => { if (e.target.value === "__add__") { setRecommendationLabel(""); setIsRecommendationDialogOpen(true); return; } setAddForm((form) => ({ ...form, motionApprovalDecisionId: e.target.value })); }}><option value="">Select decision</option>{motionRecommendations.map((recommendation) => <option key={recommendation.id} value={recommendation.id}>{recommendation.display_label}</option>)}<option value="__add__">+ Add Recommendation</option></select></div>
                  <div className="space-y-2"><Label htmlFor="motion-approval-remarks">Remarks</Label><Textarea id="motion-approval-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
                  <div className="flex justify-end"><Button type="button" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: 2 }))} disabled={!addForm.motionApprovalResolutionId || !addForm.motionApprovalDecisionId}>Next</Button></div>
                </> : null}
                {addForm.motionDecisionStep === 2 ? <>
                  <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="motion-approved-by">Who Approved</Label><select id="motion-approved-by" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionApprovedByProsecutorId} onChange={(e) => setAddForm((form) => ({ ...form, motionApprovedByProsecutorId: e.target.value }))}><option value="">Select approving prosecutor</option>{approvingProsecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.short_name ?? prosecutor.full_name}</option>)}</select></div><div className="space-y-2"><Label htmlFor="motion-date-approved">Date Approved</Label><Input id="motion-date-approved" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div></div>
                  <div className="space-y-2"><Label htmlFor="motion-time-approved">Time Approved</Label><Input id="motion-time-approved" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div>
                  <div className="flex justify-between"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: 1 }))}>Back</Button><Button type="button" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: 3 }))} disabled={!addForm.motionApprovedByProsecutorId || !addForm.eventDate}>Next</Button></div>
                </> : null}
                {addForm.motionDecisionStep === 3 ? <>
                  <p className="text-sm font-medium">Update Case Status?</p>
                  <div className="grid gap-2 sm:grid-cols-2"><Button type="button" variant={addForm.motionUpdateCaseStatus === "YES" ? "default" : "outline"} onClick={() => setAddForm((form) => ({ ...form, motionUpdateCaseStatus: "YES", motionDecisionStep: 4 }))}>Yes</Button><Button type="button" variant={addForm.motionUpdateCaseStatus === "NO" ? "default" : "outline"} onClick={() => setAddForm((form) => ({ ...form, motionUpdateCaseStatus: "NO", motionDecisionStep: 5, motionSelectedCaseStatusId: "", motionSelectedCaseStageId: "" }))}>No</Button></div>
                  <div className="flex justify-start"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: 2 }))}>Back</Button></div>
                </> : null}
                {addForm.motionDecisionStep === 4 ? <>
                  <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="motion-selected-status">Case Status</Label><select id="motion-selected-status" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionSelectedCaseStatusId} onChange={(e) => setAddForm((form) => ({ ...form, motionSelectedCaseStatusId: e.target.value }))}><option value="">Select status</option>{caseStatusOptions.map((status) => <option key={status.id} value={status.id}>{status.display_label}</option>)}</select></div><div className="space-y-2"><Label htmlFor="motion-selected-stage">Case Stage</Label><select id="motion-selected-stage" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.motionSelectedCaseStageId} onChange={(e) => setAddForm((form) => ({ ...form, motionSelectedCaseStageId: e.target.value }))}><option value="">Select stage</option>{caseStageOptions.map((stage) => <option key={stage.id} value={stage.id}>{stage.display_label}</option>)}</select></div></div>
                  <div className="flex justify-between"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: 3 }))}>Back</Button><Button type="button" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: 5 }))} disabled={!addForm.motionSelectedCaseStatusId || !addForm.motionSelectedCaseStageId}>Next</Button></div>
                </> : null}
                {addForm.motionDecisionStep === 5 ? <>
                  <div className="rounded-md border bg-background p-3"><p className="mb-2 text-sm font-medium">Review</p><div className="grid gap-3 sm:grid-cols-2"><OptionalDetailItem label="Motion Title" value={selectedMotionApprovalResolution?.motion_title} /><OptionalDetailItem label="Filed By" value={motionFiledByLabel(selectedMotionApprovalResolution?.filed_by_code) ?? selectedMotionApprovalResolution?.filed_by} /><OptionalDetailItem label="Assigned Prosecutor" value={selectedMotionApprovalResolution?.assigned_prosecutor_name} /><OptionalDetailItem label="Original Motion Resolution recommendation" value={selectedMotionApprovalResolution?.recommendation_label} /><OptionalDetailItem label="Decision Approved" value={selectedMotionApprovalDecision?.display_label} /><OptionalDetailItem label="Who Approved" value={selectedMotionApprover?.short_name ?? selectedMotionApprover?.full_name} /><OptionalDetailItem label="Date Approved" value={formatDate(addForm.eventDate)} /><OptionalDetailItem label="Time Approved" value={formatTime(addForm.eventTime)} /><OptionalDetailItem label="Update Case Status" value={addForm.motionUpdateCaseStatus === "YES" ? "Yes" : "No"} /><OptionalDetailItem label="Selected Case Status" value={addForm.motionUpdateCaseStatus === "YES" ? selectedMotionStatus?.display_label : null} /><OptionalDetailItem label="Selected Case Stage" value={addForm.motionUpdateCaseStatus === "YES" ? selectedMotionStage?.display_label : null} /><OptionalDetailItem label="Remarks" value={addForm.description} /></div></div>
                  <div className="flex justify-start"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, motionDecisionStep: form.motionUpdateCaseStatus === "YES" ? 4 : 3 }))}>Back</Button></div>
                </> : null}
              </>
            ) : isAddingPetitionForReview ? (
              <>
                <div className="space-y-2"><Label htmlFor="add-petition-filed-by">Filed By</Label><select id="add-petition-filed-by" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.filedByCode} onChange={(e) => setAddForm((form) => ({ ...form, filedByCode: e.target.value }))}><option value="">Select filer</option><option value="COMPLAINANT">Complainant</option><option value="RESPONDENT">Respondent</option></select></div>
                <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-1"><Label htmlFor="add-petition-date-filed">Date Filed</Label><Input id="add-petition-date-filed" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-1"><Label htmlFor="add-petition-time-filed">Time Filed</Label><Input id="add-petition-time-filed" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div>
                <div className="space-y-2"><Label htmlFor="add-petition-status">Status <span className="text-muted-foreground">(Optional)</span></Label><Input id="add-petition-status" value={addForm.petitionStatus} onChange={(e) => setAddForm((form) => ({ ...form, petitionStatus: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="add-petition-assigned-prosecutor">Assigned Prosecutor</Label><select id="add-petition-assigned-prosecutor" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.assignedProsecutorId} onChange={(e) => setAddForm((form) => ({ ...form, assignedProsecutorId: e.target.value }))}><option value="">No prosecutor selected</option>{prosecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.short_name ?? prosecutor.full_name}</option>)}</select></div>
                <div className="space-y-2"><div className="flex items-center justify-between gap-2"><Label>Additional Details</Label><Button type="button" variant="outline" size="sm" onClick={() => setAddForm((form) => ({ ...form, petitionDetails: [...form.petitionDetails, { detail: "", value: "" }] }))}>Add Detail</Button></div>{addForm.petitionDetails.map((row, index) => <div key={index} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]"><Input placeholder="Detail" value={row.detail} onChange={(e) => setAddForm((form) => ({ ...form, petitionDetails: form.petitionDetails.map((item, itemIndex) => itemIndex === index ? { ...item, detail: e.target.value } : item) }))} /><Input placeholder="Value" value={row.value} onChange={(e) => setAddForm((form) => ({ ...form, petitionDetails: form.petitionDetails.map((item, itemIndex) => itemIndex === index ? { ...item, value: e.target.value } : item) }))} /><Button type="button" variant="outline" size="sm" onClick={() => setAddForm((form) => ({ ...form, petitionDetails: form.petitionDetails.filter((_, itemIndex) => itemIndex !== index) }))}>Remove</Button></div>)}</div>
                <div className="space-y-2"><Label htmlFor="add-petition-remarks">Remarks</Label><Textarea id="add-petition-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            ) : isAddingPetitionForReviewUpdate ? (
              <>
                <div className="rounded-md border bg-muted/30 p-3 text-sm font-medium">Step {addForm.petitionUpdateStep} of 3</div>
                {addForm.petitionUpdateStep === 1 ? <><div className="space-y-2"><Label htmlFor="petition-update-petition">Petition for Review</Label><select id="petition-update-petition" className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.petitionUpdatePetitionId} onChange={(e) => { const petition = activePetitionsForReview.find((item) => String(item.id) === e.target.value); setAddForm((form) => ({ ...form, petitionUpdatePetitionId: e.target.value, petitionStatus: petition?.petition_status ?? "", eventDate: toDateInputValue(petition?.status_date ?? petition?.date_filed ?? petition?.date_received), description: petition?.remarks ?? "", petitionDetails: petition?.additional_details_jsonb ?? [] })); }}><option value="">Select petition</option>{activePetitionsForReview.map((petition) => <option key={petition.id} value={petition.id}>{petition.filed_by ?? motionFiledByLabel(petition.filed_by_code)} • {formatDate(petition.date_filed ?? petition.date_received)} • {petition.petition_status ?? "—"}</option>)}</select></div>{activePetitionsForReview.length === 0 ? <div className="rounded-md border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900">No active Petition for Review is available for update.</div> : null}<div className="flex justify-end"><Button type="button" onClick={() => setAddForm((form) => ({ ...form, petitionUpdateStep: 2 }))} disabled={!addForm.petitionUpdatePetitionId}>Next</Button></div></> : null}
                {addForm.petitionUpdateStep === 2 ? <><div className="rounded-md border bg-background p-3"><p className="mb-2 text-sm font-medium">Original Petition Details</p><div className="grid gap-3 sm:grid-cols-2"><OptionalDetailItem label="Filed By" value={selectedPetitionForReview?.filed_by ?? motionFiledByLabel(selectedPetitionForReview?.filed_by_code)} /><OptionalDetailItem label="Date Filed" value={formatDate(selectedPetitionForReview?.date_filed ?? selectedPetitionForReview?.date_received)} /><OptionalDetailItem label="Time Filed" value={formatTime(selectedPetitionForReview?.time_filed)} /><OptionalDetailItem label="Assigned Prosecutor" value={selectedPetitionForReview?.assigned_prosecutor_name ?? selectedPetitionForReview?.handling_prosecutor_text} /></div></div><div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="petition-update-status">Petition Status</Label><Input id="petition-update-status" value={addForm.petitionStatus} onChange={(e) => setAddForm((form) => ({ ...form, petitionStatus: e.target.value }))} /></div><div className="space-y-2"><Label htmlFor="petition-update-date">Status Date</Label><Input id="petition-update-date" type="date" value={addForm.eventDate} onChange={(e) => setAddForm((form) => ({ ...form, eventDate: e.target.value }))} /></div></div><div className="space-y-2"><div className="flex items-center justify-between gap-2"><Label>Additional Details</Label><Button type="button" variant="outline" size="sm" onClick={() => setAddForm((form) => ({ ...form, petitionDetails: [...form.petitionDetails, { detail: "", value: "" }] }))}>Add Detail</Button></div>{addForm.petitionDetails.map((row, index) => <div key={index} className="grid gap-2 sm:grid-cols-[1fr_1fr_auto]"><Input placeholder="Detail" value={row.detail} onChange={(e) => setAddForm((form) => ({ ...form, petitionDetails: form.petitionDetails.map((item, itemIndex) => itemIndex === index ? { ...item, detail: e.target.value } : item) }))} /><Input placeholder="Value" value={row.value} onChange={(e) => setAddForm((form) => ({ ...form, petitionDetails: form.petitionDetails.map((item, itemIndex) => itemIndex === index ? { ...item, value: e.target.value } : item) }))} /><Button type="button" variant="outline" size="sm" onClick={() => setAddForm((form) => ({ ...form, petitionDetails: form.petitionDetails.filter((_, itemIndex) => itemIndex !== index) }))}>Remove</Button></div>)}</div><div className="space-y-2"><Label htmlFor="petition-update-remarks">Remarks</Label><Textarea id="petition-update-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div><p className="text-sm font-medium">Update Case Status?</p><div className="grid gap-2 sm:grid-cols-2"><Button type="button" variant={addForm.petitionUpdateCaseStatus === "YES" ? "default" : "outline"} onClick={() => setAddForm((form) => ({ ...form, petitionUpdateCaseStatus: "YES" }))}>Yes</Button><Button type="button" variant={addForm.petitionUpdateCaseStatus === "NO" ? "default" : "outline"} onClick={() => setAddForm((form) => ({ ...form, petitionUpdateCaseStatus: "NO", petitionSelectedCaseStatusId: "", petitionSelectedCaseStageId: "" }))}>No</Button></div>{addForm.petitionUpdateCaseStatus === "YES" ? <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label>Case Status</Label><select className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.petitionSelectedCaseStatusId} onChange={(e) => setAddForm((form) => ({ ...form, petitionSelectedCaseStatusId: e.target.value }))}><option value="">Select status</option>{caseStatusOptions.map((status) => <option key={status.id} value={status.id}>{status.display_label}</option>)}</select></div><div className="space-y-2"><Label>Case Stage</Label><select className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.petitionSelectedCaseStageId} onChange={(e) => setAddForm((form) => ({ ...form, petitionSelectedCaseStageId: e.target.value }))}><option value="">Select stage</option>{caseStageOptions.map((stage) => <option key={stage.id} value={stage.id}>{stage.display_label}</option>)}</select></div></div> : null}<div className="flex justify-between"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, petitionUpdateStep: 1 }))}>Back</Button><Button type="button" onClick={() => setAddForm((form) => ({ ...form, petitionUpdateStep: 3 }))} disabled={!addForm.petitionStatus.trim() || !addForm.eventDate || !addForm.petitionUpdateCaseStatus || (addForm.petitionUpdateCaseStatus === "YES" && (!addForm.petitionSelectedCaseStatusId || !addForm.petitionSelectedCaseStageId))}>Next</Button></div></> : null}
                {addForm.petitionUpdateStep === 3 ? <><div className="rounded-md border bg-background p-3"><p className="mb-2 text-sm font-medium">Review</p><div className="grid gap-3 sm:grid-cols-2"><OptionalDetailItem label="Petition" value={selectedPetitionForReview ? `${selectedPetitionForReview.filed_by ?? motionFiledByLabel(selectedPetitionForReview.filed_by_code)} • ${formatDate(selectedPetitionForReview.date_filed ?? selectedPetitionForReview.date_received)}` : null} /><OptionalDetailItem label="Petition Status" value={addForm.petitionStatus} /><OptionalDetailItem label="Status Date" value={formatDate(addForm.eventDate)} /><OptionalDetailItem label="Additional Details" value={addForm.petitionDetails.filter((row) => row.detail.trim() || row.value.trim()).map((row) => `${row.detail.trim()}: ${row.value.trim()}`).join("; ")} /><OptionalDetailItem label="Update Case Status" value={addForm.petitionUpdateCaseStatus === "YES" ? "Yes" : "No"} /><OptionalDetailItem label="Selected Case Status" value={addForm.petitionUpdateCaseStatus === "YES" ? selectedPetitionStatus?.display_label : null} /><OptionalDetailItem label="Selected Case Stage" value={addForm.petitionUpdateCaseStatus === "YES" ? selectedPetitionStage?.display_label : null} /><OptionalDetailItem label="Remarks" value={addForm.description} /></div></div><div className="flex justify-start"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, petitionUpdateStep: 2 }))}>Back</Button></div></> : null}
              </>
            ) : isAddingCustomEvent ? (
              <>
                <div className="rounded-md border bg-muted/30 p-3 text-sm font-medium">Step {addForm.customStep} of 3</div>
                {addForm.customStep === 1 ? <><div className="space-y-2"><Label htmlFor="custom-title">Event Title</Label><Input id="custom-title" value={addForm.title} onChange={(e) => setAddForm((form) => ({ ...form, title: e.target.value }))} /></div><div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="custom-date">Event Date</Label><Input id="custom-date" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div><div className="space-y-2"><Label htmlFor="custom-time">Event Time</Label><Input id="custom-time" type="time" step="1" value={addForm.eventTime} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventTime: e.target.value })); }} /></div></div><MotionDetailsEditor rows={addForm.customDetails} onChange={(rows) => setAddForm((form) => ({ ...form, customDetails: rows }))} /><div className="space-y-2"><Label htmlFor="custom-remarks">Remarks</Label><Textarea id="custom-remarks" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div><div className="flex justify-end"><Button type="button" onClick={() => setAddForm((form) => ({ ...form, customStep: 2 }))} disabled={!addForm.title.trim() || !addForm.eventDate || !addForm.eventTime}>Next</Button></div></> : null}
                {addForm.customStep === 2 ? <><p className="text-sm font-medium">Update Case Status?</p><div className="grid gap-2 sm:grid-cols-2"><Button type="button" variant={addForm.customUpdateCaseStatus === "YES" ? "default" : "outline"} onClick={() => setAddForm((form) => ({ ...form, customUpdateCaseStatus: "YES" }))}>Yes</Button><Button type="button" variant={addForm.customUpdateCaseStatus === "NO" ? "default" : "outline"} onClick={() => setAddForm((form) => ({ ...form, customUpdateCaseStatus: "NO", customSelectedCaseStatusId: "", customSelectedCaseStageId: "" }))}>No</Button></div>{addForm.customUpdateCaseStatus === "YES" ? <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label>Case Status</Label><select className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.customSelectedCaseStatusId} onChange={(e) => setAddForm((form) => ({ ...form, customSelectedCaseStatusId: e.target.value }))}><option value="">Select status</option>{caseStatusOptions.map((status) => <option key={status.id} value={status.id}>{status.display_label}</option>)}</select></div><div className="space-y-2"><Label>Case Stage</Label><select className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={addForm.customSelectedCaseStageId} onChange={(e) => setAddForm((form) => ({ ...form, customSelectedCaseStageId: e.target.value }))}><option value="">Select stage</option>{caseStageOptions.map((stage) => <option key={stage.id} value={stage.id}>{stage.display_label}</option>)}</select></div></div> : null}<div className="flex justify-between"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, customStep: 1 }))}>Back</Button><Button type="button" onClick={() => setAddForm((form) => ({ ...form, customStep: 3 }))} disabled={!addForm.customUpdateCaseStatus || (addForm.customUpdateCaseStatus === "YES" && (!addForm.customSelectedCaseStatusId || !addForm.customSelectedCaseStageId))}>Next</Button></div></> : null}
                {addForm.customStep === 3 ? <><div className="rounded-md border bg-background p-3"><p className="mb-2 text-sm font-medium">Review</p><div className="grid gap-3 sm:grid-cols-2"><OptionalDetailItem label="Event Title" value={addForm.title} /><OptionalDetailItem label="Event Date" value={formatDate(addForm.eventDate)} /><OptionalDetailItem label="Event Time" value={formatTime(addForm.eventTime)} /><OptionalDetailItem label="Additional Details" value={addForm.customDetails.filter((row) => row.detail.trim() || row.value.trim()).map((row) => `${row.detail.trim()}: ${row.value.trim()}`).join("; ")} /><OptionalDetailItem label="Remarks" value={addForm.description} /><OptionalDetailItem label="Update Case Status" value={addForm.customUpdateCaseStatus === "YES" ? "Yes" : "No"} /><OptionalDetailItem label="Selected Case Status" value={addForm.customUpdateCaseStatus === "YES" ? selectedCustomStatus?.display_label : null} /><OptionalDetailItem label="Selected Case Stage" value={addForm.customUpdateCaseStatus === "YES" ? selectedCustomStage?.display_label : null} /></div></div><div className="flex justify-start"><Button type="button" variant="outline" onClick={() => setAddForm((form) => ({ ...form, customStep: 2 }))}>Back</Button></div></> : null}
              </>
            ) : (
              <>
                <div className="space-y-2"><Label htmlFor="add-event-date">Event Date</Label><Input id="add-event-date" type="date" value={addForm.eventDate} onChange={(e) => { setIsAddDateTimeDirty(true); setAddForm((form) => ({ ...form, eventDate: e.target.value })); }} /></div>
                <div className="space-y-2"><Label htmlFor="add-event-title">Title</Label><Input id="add-event-title" value={addForm.title} placeholder={selectedEventTypeLabel || undefined} onChange={(e) => setAddForm((form) => ({ ...form, title: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="add-event-description">Description / Remarks</Label><Textarea id="add-event-description" value={addForm.description} onChange={(e) => setAddForm((form) => ({ ...form, description: e.target.value }))} /></div>
              </>
            )}
          </div>
          <DialogFooter className="border-t pt-3">
            <Button type="button" variant="outline" onClick={() => setIsAddDialogOpen(false)}>Cancel</Button>
            <Button type="button" onClick={handleAddSave} disabled={isSaving || !addForm.eventTypeCode || !addForm.eventDate || (isAddingAssignmentLike ? !addForm.prosecutorId || (isAddingReassignment && !addForm.reason.trim()) : isAddingResolved ? !addForm.recommendationCode : isAddingDecisionApproved ? !addForm.prosecutorId || !addForm.caseResolutionId || !addForm.approvalActions.some((action) => action.chargeText.trim()) : isAddingCourtFiling ? !addForm.courtFilingDecisionId || !addForm.courtName.trim() || !addForm.chargeFiled.trim() : isAddingCourtStatusUpdate ? !courtStatusForm.courtFilingId || courtStatusStep !== 3 : isAddingMotionReceived ? !addForm.motionTitle.trim() || !addForm.filedByCode : isAddingMotionResolved ? !addForm.motionResolveMotionId || !addForm.motionRecommendationId : isAddingMotionDecisionApproved ? addForm.motionDecisionStep !== 5 || !addForm.motionApprovalResolutionId || !addForm.motionApprovalDecisionId || !addForm.motionApprovedByProsecutorId || !addForm.motionUpdateCaseStatus || (addForm.motionUpdateCaseStatus === "YES" && (!addForm.motionSelectedCaseStatusId || !addForm.motionSelectedCaseStageId)) : isAddingPetitionForReview ? !addForm.filedByCode : isAddingPetitionForReviewUpdate ? addForm.petitionUpdateStep !== 3 || !addForm.petitionUpdatePetitionId || !addForm.petitionStatus.trim() || !addForm.petitionUpdateCaseStatus || (addForm.petitionUpdateCaseStatus === "YES" && (!addForm.petitionSelectedCaseStatusId || !addForm.petitionSelectedCaseStageId)) : isAddingCustomEvent ? addForm.customStep !== 3 || !addForm.title.trim() || !addForm.eventTime || !addForm.customUpdateCaseStatus || (addForm.customUpdateCaseStatus === "YES" && (!addForm.customSelectedCaseStatusId || !addForm.customSelectedCaseStageId)) : !addForm.title.trim())}>{isSaving ? "Saving..." : isAddingReassignment ? "Confirm Reassignment" : isAddingAssignment ? "Confirm Assignment" : isAddingResolved ? "Resolve Case" : isAddingDecisionApproved ? "Approve Decision" : isAddingCourtFiling ? "Record Court Filing" : isAddingCourtStatusUpdate ? "Save Court Status Update" : isAddingMotionReceived ? "Record Motion Received" : isAddingMotionResolved ? "Record Motion Resolved" : isAddingMotionDecisionApproved ? "Save Motion Decision Approval" : isAddingPetitionForReview ? "Record Petition for Review" : isAddingPetitionForReviewUpdate ? "Save Petition Update" : isAddingCustomEvent ? "Save Custom Event" : "Add event"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={isRecommendationDialogOpen} onOpenChange={setIsRecommendationDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add recommendation</DialogTitle>
            <DialogDescription>Add a Motion Resolution recommendation option.</DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            <div className="space-y-2"><Label htmlFor="motion-recommendation-label">Recommendation Label</Label><Input id="motion-recommendation-label" value={recommendationLabel} onChange={(e) => setRecommendationLabel(e.target.value)} /></div>
            <p className="text-xs text-muted-foreground">The recommendation code will be generated automatically.</p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setIsRecommendationDialogOpen(false)}>Cancel</Button>
            <Button type="button" onClick={handleAddRecommendationSave} disabled={isSaving || !recommendationLabel.trim()}>{isSaving ? "Saving..." : "Save Recommendation"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <Dialog open={Boolean(editingEvent)} onOpenChange={(open) => !open && setEditingEvent(null)}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>{editDialogTitle(editingEvent)}</DialogTitle>
            <DialogDescription>Correct stored timeline information without changing the event type, source record, or legal/workflow decision.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            {actionError ? <p className="rounded-md border border-destructive/30 bg-destructive/5 p-2 text-sm text-destructive">{actionError}</p> : null}
            <EditNotice />
            <ReadOnlyActivityDetails event={editingEvent} />
            <div className="space-y-2">
              <p className="text-sm font-medium">Editable Corrections</p>
            </div>
            {(() => {
              const code = editingEvent?.event_type_code ?? "";
              const isAssignment = code === "CASE_ASSIGNMENT" || code === "CASE_REASSIGNMENT";
              const isResolution = code === "CASE_RESOLVED";
              const isApproval = code === "CASE_DECISION_APPROVED" || code === "MOTION_DECISION_APPROVED";
              const isCourtFiling = code === "COURT_FILING";
              const isMotionReceived = code === "MOTION_RECEIVED";
              const isMotionResolved = code === "MOTION_RESOLVED";
              const isPetition = code === "PETITION_FOR_REVIEW";
              const isStatus = code === "CASE_STATUS_UPDATED";
              const isCustomOrLegacy = code === "CUSTOM_EVENT" || !SUPPORTED_EVENT_EDIT_TYPES.has(code);
              return <>
                <div className="grid gap-3 sm:grid-cols-2">
                  <div className="space-y-2"><Label htmlFor="edit-date">{isStatus ? "Status Date" : isResolution ? "Resolution Date" : isApproval ? "Approval Date" : isCourtFiling || isMotionReceived || isPetition ? "Date Filed" : isMotionResolved ? "Date Resolved" : isAssignment && code === "CASE_REASSIGNMENT" ? "Reassignment Date" : "Event Date"}</Label><Input id="edit-date" type="date" value={editForm.eventDate} onChange={(e) => setEditForm((form) => ({ ...form, eventDate: e.target.value }))} /></div>
                  <div className="space-y-2"><Label htmlFor="edit-time">{isStatus ? "Event Time" : isResolution ? "Resolution Time" : isApproval ? "Approval Time" : isCourtFiling || isMotionReceived || isPetition ? "Time Filed" : isMotionResolved ? "Time Resolved" : "Event Time"}</Label><Input id="edit-time" type="time" value={editForm.eventTime} onChange={(e) => setEditForm((form) => ({ ...form, eventTime: e.target.value }))} /></div>
                </div>
                {isApproval ? <div className="space-y-2"><Label htmlFor="edit-approved-by">Who Approved</Label><select id="edit-approved-by" className="w-full rounded-md border bg-background px-3 py-2 text-sm" value={editForm.approvedByProsecutorId} onChange={(e) => setEditForm((form) => ({ ...form, approvedByProsecutorId: e.target.value }))}><option value="">Select prosecutor</option>{prosecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.full_name}</option>)}</select></div> : null}
                {isMotionReceived ? <><div className="space-y-2"><Label htmlFor="edit-motion-title">Motion Title</Label><Input id="edit-motion-title" value={editForm.motionTitle} onChange={(e) => setEditForm((form) => ({ ...form, motionTitle: e.target.value }))} /></div><div className="space-y-2"><Label htmlFor="edit-filed-by">Filed By</Label><select id="edit-filed-by" className="w-full rounded-md border bg-background px-3 py-2 text-sm" value={editForm.filedByCode} onChange={(e) => setEditForm((form) => ({ ...form, filedByCode: e.target.value }))}><option value="">Select filer</option><option value="COMPLAINANT">Complainant</option><option value="RESPONDENT">Respondent</option></select></div><div className="space-y-2"><Label htmlFor="edit-motion-prosecutor">Assigned Prosecutor</Label><select id="edit-motion-prosecutor" className="w-full rounded-md border bg-background px-3 py-2 text-sm" value={editForm.assignedProsecutorId} onChange={(e) => setEditForm((form) => ({ ...form, assignedProsecutorId: e.target.value }))}><option value="">No assigned prosecutor</option>{prosecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.full_name}</option>)}</select></div></> : null}
                {isPetition ? <><div className="space-y-2"><Label htmlFor="edit-petition-filed-by">Filed By</Label><select id="edit-petition-filed-by" className="w-full rounded-md border bg-background px-3 py-2 text-sm" value={editForm.filedByCode} onChange={(e) => setEditForm((form) => ({ ...form, filedByCode: e.target.value }))}><option value="">Select filer</option><option value="COMPLAINANT">Complainant</option><option value="RESPONDENT">Respondent</option></select></div><div className="space-y-2"><Label htmlFor="edit-petition-status">Petition Status</Label><Input id="edit-petition-status" value={editForm.petitionStatus} onChange={(e) => setEditForm((form) => ({ ...form, petitionStatus: e.target.value }))} /></div><div className="space-y-2"><Label htmlFor="edit-petition-prosecutor">Assigned Prosecutor</Label><select id="edit-petition-prosecutor" className="w-full rounded-md border bg-background px-3 py-2 text-sm" value={editForm.assignedProsecutorId} onChange={(e) => setEditForm((form) => ({ ...form, assignedProsecutorId: e.target.value }))}><option value="">No assigned prosecutor</option>{prosecutors.map((prosecutor) => <option key={prosecutor.id} value={prosecutor.id}>{prosecutor.full_name}</option>)}</select></div></> : null}
                {isCourtFiling ? <div className="grid gap-3 sm:grid-cols-2"><div className="space-y-2"><Label htmlFor="edit-court-name">Court</Label><Input id="edit-court-name" value={editForm.courtName} onChange={(e) => setEditForm((form) => ({ ...form, courtName: e.target.value }))} /></div><div className="space-y-2"><Label htmlFor="edit-court-branch">Branch</Label><Input id="edit-court-branch" value={editForm.courtBranch} onChange={(e) => setEditForm((form) => ({ ...form, courtBranch: e.target.value }))} /></div><div className="space-y-2"><Label htmlFor="edit-info-count">Information Count</Label><Input id="edit-info-count" type="number" min="0" value={editForm.informationCount} onChange={(e) => setEditForm((form) => ({ ...form, informationCount: e.target.value }))} /></div><div className="rounded-md border border-dashed p-3 text-xs text-muted-foreground">Criminal Case Numbers are read-only here. Use Court Status Update to correct normalized criminal case number history.</div></div> : null}
                {isCustomOrLegacy ? <div className="space-y-2"><Label htmlFor="edit-title">{code === "CUSTOM_EVENT" ? "Title" : "Legacy Title"}</Label><Input id="edit-title" value={editForm.title} disabled={code !== "CUSTOM_EVENT"} onChange={(e) => setEditForm((form) => ({ ...form, title: e.target.value }))} /></div> : null}
                {(isMotionReceived || isPetition || code === "CUSTOM_EVENT") ? <MotionDetailsEditor rows={editForm.additionalDetails} onChange={(rows) => setEditForm((form) => ({ ...form, additionalDetails: rows }))} /> : null}
                <div className="space-y-2"><Label htmlFor="edit-description">{isCustomOrLegacy ? "Description / Remarks" : "Remarks"}</Label><Textarea id="edit-description" value={editForm.description} onChange={(e) => setEditForm((form) => ({ ...form, description: e.target.value }))} /></div>
                <div className="space-y-2"><Label htmlFor="edit-reason">Reason for Edit</Label><Textarea id="edit-reason" required value={editForm.editReason} onChange={(e) => setEditForm((form) => ({ ...form, editReason: e.target.value }))} /></div>
              </>;
            })()}
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setEditingEvent(null)}>Cancel</Button>
            <Button type="button" onClick={handleEditSave} disabled={isSaving || !editForm.eventDate || !editForm.editReason.trim()}>{isSaving ? "Saving..." : "Save Corrections"}</Button>
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
