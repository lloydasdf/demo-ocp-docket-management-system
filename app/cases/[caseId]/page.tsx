"use client";

import type React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ExternalLink } from "lucide-react";

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
import {
  getCaseAttachmentsIndex,
  getCaseCompactById,
  getCaseCourtDetails,
  getCaseDetailsById,
  getCaseMotions,
  getCaseParticipants,
  getCasePetitionsForReview,
  getCaseTimelineEvents,
  type CaseCourtRecord,
  type CaseDetailsRecord,
  type CaseMotionRecord,
  type CaseParticipantRecord,
  type CasePetitionForReviewRecord,
  type CaseTimelineEventRecord,
} from "@/lib/supabase/queries";
import type {
  TableRow as SupabaseTableRow,
  ViewRow,
} from "@/lib/supabase/types";

type CaseDetailsState = {
  compact: ViewRow<"v_cases_display"> | null;
  details: CaseDetailsRecord | null;
  participants: CaseParticipantRecord[];
  timeline: CaseTimelineEventRecord[];
  courts: CaseCourtRecord[];
  motions: CaseMotionRecord[];
  petitionsForReview: CasePetitionForReviewRecord[];
  attachments: SupabaseTableRow<"case_attachment_index">[];
  warnings: string[];
};
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

function firstDisplayValue(...values: (string | number | null | undefined)[]) {
  return values.find((value) => value !== null && value !== undefined && String(value).trim() !== "");
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
  const age = attributes?.age_text ?? attributes?.age_years;
  const gender = attributes?.gender_text ?? attributes?.gender_normalized;
  const parts = [
    age ? `Age at case: ${age}` : null,
    gender ?? null,
  ].filter((part): part is string => Boolean(part));

  return parts.join(" • ");
}

function caseSpecificFlags(participant: CaseParticipantRecord) {
  const attributes = participant.case_participant_attributes;
  const flags = [
    attributes?.is_minor_at_case ? "Minor" : null,
    attributes?.is_senior_at_case ? "Senior" : null,
    attributes?.is_pwd_at_case ? "PWD" : null,
  ].filter((flag): flag is string => Boolean(flag));

  return flags.length > 0 ? flags.join(", ") : null;
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
  return formatAddress(preferredAddress?.addresses ?? null);
}


function SectionEmpty({ children = "No records yet." }: { children?: string }) {
  return (
    <p className="rounded-md border border-dashed p-4 text-sm text-muted-foreground">
      {children}
    </p>
  );
}

function hasDetailValue(value: React.ReactNode) {
  return value !== null && value !== undefined && value !== "" && value !== "—";
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

  if (event.event_type_code === "CASE_RAFFLED") {
    return [
      { label: "Prosecutor", value: event.prosecutor_short_name },
      { label: "Date", value: formatDate(event.event_date) },
      { label: "Remarks", value: eventRemarks(event) },
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
        attachments,
        timeline,
        courts,
        motions,
        petitionsForReview,
      ] = await Promise.all([
        getCaseCompactById(caseId),
        getCaseDetailsById(caseId),
        getCaseParticipants(caseId),
        getCaseAttachmentsIndex(caseId),
        getCaseTimelineEvents(caseId),
        getCaseCourtDetails(caseId),
        getCaseMotions(caseId),
        getCasePetitionsForReview(caseId),
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
        attachments,
        timeline,
        courts,
        motions,
        petitionsForReview,
      ]
        .map((result) => result.error?.message)
        .filter((message): message is string => Boolean(message));

      setData({
        compact: compact.data,
        details: details.data,
        participants: participants.data ?? [],
        attachments: attachments.data ?? [],
        timeline: timeline.data ?? [],
        courts: courts.data ?? [],
        motions: motions.data ?? [],
        petitionsForReview: petitionsForReview.data ?? [],
        warnings,
      });
      setIsLoading(false);
    }

    loadCase();

    return () => {
      isMounted = false;
    };
  }, [caseId]);



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


  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto p-3 pt-16 md:p-8">
        <div className="flex w-full max-w-[824px] flex-col gap-4 md:gap-6">
          {isLoading ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Loading case details...
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
                          {data.details.current_status?.display_label ??
                            data.details.current_status?.code ??
                            data.details.current_status_raw ??
                            "—"}
                        </Badge>
                      }
                    />
                    <OptionalDetailItem
                      label="Status date"
                      value={formatDate(data.details.current_status_date ?? data.compact.current_status_date)}
                    />
                    <OptionalDetailItem
                      label="Status approved date"
                      value={firstDisplayValue(data.details.status_approved_date_raw, formatDate(data.details.status_approved_date))}
                    />
                    <OptionalDetailItem
                      label="Status remarks"
                      value={data.details.current_status_remarks}
                    />
                    <OptionalDetailItem
                      label="Classification"
                      value={
                        data.details.case_classifications?.display_label ??
                        data.details.case_classifications?.name ??
                        data.details.case_classifications?.code
                      }
                    />
                  </div>
                </CardHeader>
              </Card>

              <div className="space-y-6">
                <Card>
                  <CardHeader className="p-4 sm:p-6">
                    <CardTitle>Parties</CardTitle>
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
                                    {formatPersonDemographics(participant) ? (
                                      <p className="text-sm text-muted-foreground">
                                        {formatPersonDemographics(participant)}
                                      </p>
                                    ) : null}
                                  </div>
                                </div>
                                <Separator className="my-3" />
                                <div className="grid gap-2 text-sm sm:grid-cols-2">
                                  <DetailItem label="Role" value={role} />
                                  <OptionalDetailItem
                                    label="Birthdate"
                                    value={
                                      participant.persons?.birth_date
                                        ? formatDate(participant.persons.birth_date)
                                        : null
                                    }
                                  />
                                  <OptionalDetailItem
                                    label="Address"
                                    value={primaryAddress(participant)}
                                  />
                                  <OptionalDetailItem
                                    label="Case flags"
                                    value={caseSpecificFlags(participant)}
                                  />
                                  <OptionalDetailItem
                                    label="Remarks"
                                    value={participant.remarks}
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
                    <CardTitle>Timeline</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {timelineGroupedByDate.length === 0 ? (
                      <SectionEmpty>No timeline events found.</SectionEmpty>
                    ) : (
                      <div className="space-y-4">
                        {timelineGroupedByDate.map(([dateLabel, events]) => (
                          <div key={dateLabel}>
                            <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                              {dateLabel}
                            </p>
                            <Accordion
                              type="single"
                              collapsible
                              className="relative ml-2 space-y-3 border-l border-border pl-6"
                            >
                              {events.map((event) => {
                                const courtDetails = eventCourtDetails(event, data.courts);
                                const motionDetails = eventMotionDetails(event, data.motions);
                                const petitionDetails = eventPetitionForReviewDetails(
                                  event,
                                  data.petitionsForReview,
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
                                            </p>
                                            <p className="line-clamp-2 text-xs text-muted-foreground">
                                              {timelineSubtitle(event, petitionDetails)}
                                            </p>
                                          </div>
                                        </div>
                                      </AccordionTrigger>
                                      <AccordionContent className="space-y-3 pb-3">
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
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle>Attachments</CardTitle>
                    <CardDescription>
                      Google Drive folder and indexed file records, when available.
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
            </>
          )}
        </div>
      </main>
    </div>
  );
}
