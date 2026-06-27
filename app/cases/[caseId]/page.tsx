"use client";

import type React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ExternalLink } from "lucide-react";

import { CaseTimeline } from "@/components/case-timeline";
import { Sidebar } from "@/components/sidebar";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
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
  getCaseCourtDetails,
  getCaseDetailsPageById,
  getCaseMotions,
  getCaseParticipants,
  getCasePetitionsForReview,
  getCaseTimelineEvents,
  type CaseCourtRecord,
  type CaseDetailsPageViewRecord,
  type CaseMotionRecord,
  type CaseParticipantRecord,
  type CasePetitionForReviewRecord,
  type CaseTimelineEventRecord,
} from "@/lib/supabase/queries";
import type { TableRow as SupabaseTableRow } from "@/lib/supabase/types";


type CaseAddressRecord = {
  id?: number | null;
  address_type_label?: string | null;
  is_primary?: boolean | null;
  remarks?: string | null;
  addresses?: {
    line1: string | null;
    line2: string | null;
    barangay: string | null;
    city: string | null;
    province: string | null;
    region: string | null;
    zip_code: string | null;
    country: string | null;
  } | null;
};

type CaseDetailsState = {
  compact: CaseDetailsPageViewRecord | null;
  details: CaseDetailsPageViewRecord | null;
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

function participantName(participant: CaseParticipantRecord) {
  return participant.persons?.full_name ?? participant.organizations?.organization_name ?? participant.display_name_snapshot ?? "Unnamed participant";
}

function formatOrganizationDetails(details: unknown) {
  if (!details || typeof details !== "object" || Array.isArray(details) || Object.keys(details as Record<string, unknown>).length === 0) return null;
  return Object.entries(details as Record<string, unknown>)
    .map(([key, value]) => `${key}: ${typeof value === "object" ? JSON.stringify(value) : String(value)}`)
    .join("; ");
}

function participantAliases(participant: CaseParticipantRecord) {
  const aliases = participant.participant_kind === "ORGANIZATION" ? participant.organizations?.organization_aliases : participant.persons?.person_aliases;
  if (!Array.isArray(aliases)) return null;
  const names = aliases.map((alias) => typeof alias === "object" && alias && "alias_name" in alias ? String(alias.alias_name) : null).filter(Boolean);
  return names.length ? names.join(", ") : null;
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

function caseAddresses(details: CaseDetailsPageViewRecord | null): CaseAddressRecord[] {
  return Array.isArray(details?.case_addresses) ? (details.case_addresses as CaseAddressRecord[]) : [];
}

function formatCaseAddress(address: CaseAddressRecord) {
  return formatAddress(address.addresses ?? null);
}

function classificationLabel(details: CaseDetailsPageViewRecord) {
  return (
    details.case_classifications?.display_label ??
    details.case_classifications?.name ??
    details.case_classifications?.code ??
    null
  );
}

function placeOfCommission(details: CaseDetailsPageViewRecord | null) {
  const addresses = caseAddresses(details);

  if (addresses.length === 0) {
    return null;
  }

  return (
    <div className="space-y-2">
      {addresses.map((address) => {
        const addressText = formatCaseAddress(address) ?? "Unnamed address";

        return (
          <div key={address.id ?? addressText} className="min-w-0 space-y-1">
            <p className="break-words">{addressText}</p>
            {address.remarks ? (
              <p className="break-words text-xs font-normal text-muted-foreground">
                {address.remarks}
              </p>
            ) : null}
          </div>
        );
      })}
    </div>
  );
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

function DetailItem({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="min-w-0 space-y-1">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </p>
      <div className="min-w-0 break-words text-sm font-medium text-foreground">
        {value}
      </div>
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
        caseDetailsPage,
        participants,
        attachments,
        timeline,
        courts,
        motions,
        petitionsForReview,
      ] = await Promise.all([
        getCaseDetailsPageById(caseId),
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

      const criticalError = caseDetailsPage.error;

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
        compact: caseDetailsPage.data,
        details: caseDetailsPage.data,
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
                    <div className="flex min-w-0 flex-wrap items-center gap-3">
                      <CardTitle className="text-2xl sm:text-3xl">
                        {data.compact.docket_display_number ??
                          displayValue(data.details.docket_number)}
                      </CardTitle>
                      {classificationLabel(data.details) ? (
                        <Badge
                          variant="outline"
                          className="border-blue-200 bg-blue-50 text-blue-700"
                        >
                          {classificationLabel(data.details)}
                        </Badge>
                      ) : null}
                    </div>
                    <CardDescription className="mt-3 text-sm text-foreground sm:text-base">
                      {data.compact.violations ?? "No violation recorded"}
                    </CardDescription>
                  </div>

                  <div className="grid gap-6 border-t pt-4 md:grid-cols-[minmax(0,1fr)_minmax(14rem,18rem)] md:gap-x-12">
                    <div className="space-y-4">
                      <OptionalDetailItem
                        label="Place of commission"
                        value={placeOfCommission(data.details)}
                      />
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
                    </div>

                    <div className="space-y-4">
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
                        value={formatDate(
                          data.details.current_status_date ??
                            data.compact.current_status_date,
                        )}
                      />
                      <OptionalDetailItem
                        label="Status approved date"
                        value={firstDisplayValue(
                          data.details.status_approved_date_raw,
                          formatDate(data.details.status_approved_date),
                        )}
                      />
                      <OptionalDetailItem
                        label="Status remarks"
                        value={data.details.current_status_remarks}
                      />
                    </div>
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
                                        {participantName(participant)}
                                      </Link>
                                    ) : (
                                      <p className="font-medium">
                                        {participantName(participant)}
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
                                    label="Organization contact"
                                    value={participant.organizations?.contact_person ?? participant.organizations?.contact_number ?? participant.organizations?.email}
                                  />
                                  <OptionalDetailItem
                                    label="Birthdate"
                                    value={
                                      participant.persons?.birth_date
                                        ? formatDate(participant.persons.birth_date)
                                        : null
                                    }
                                  />
                                  <OptionalDetailItem
                                    label="Organization details"
                                    value={formatOrganizationDetails(participant.organizations?.details_jsonb)}
                                  />
                                  <OptionalDetailItem
                                    label="Aliases"
                                    value={participantAliases(participant)}
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

                <CaseTimeline
                  courts={data.courts}
                  events={data.timeline}
                  motions={data.motions}
                  petitionsForReview={data.petitionsForReview}
                />

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
