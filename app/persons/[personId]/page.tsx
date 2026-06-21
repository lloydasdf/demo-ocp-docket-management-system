"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ExternalLink } from "lucide-react";

import { Sidebar } from "@/components/sidebar";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import {
  getCaseCompactsByIds,
  getCaseParticipantsForPerson,
  getPersonDetailsById,
  type CaseParticipantRecord,
  type CasesDisplayRecord,
  type PersonDetailsRecord,
} from "@/lib/supabase/queries";

type PersonDetailsState = {
  person: PersonDetailsRecord | null;
  participants: CaseParticipantRecord[];
  cases: CasesDisplayRecord[];
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

function displayValue(value: string | number | null | undefined) {
  return value === null || value === undefined || value === ""
    ? "—"
    : String(value);
}

function hasDisplayValue(value: string | number | boolean | null | undefined) {
  return value !== null && value !== undefined && value !== "";
}

function booleanDisplay(value: boolean | null | undefined) {
  if (value === null || value === undefined) {
    return null;
  }

  return value ? "Yes" : "No";
}

function formatAddress(
  address: NonNullable<
    NonNullable<PersonDetailsRecord["person_addresses"]>[number]["addresses"]
  >,
) {
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

function primaryPersonAddress(person: PersonDetailsRecord) {
  const addresses = person.person_addresses ?? [];
  const preferredAddress =
    addresses.find((address) => address.is_primary) ?? addresses[0];

  return preferredAddress?.addresses
    ? formatAddress(preferredAddress.addresses)
    : null;
}

function roleLabel(participant: CaseParticipantRecord) {
  return (
    participant.participant_roles?.display_label ??
    participant.participant_roles?.code ??
    "Party"
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

function SectionEmpty({ children = "No records yet." }: { children?: string }) {
  return (
    <p className="rounded-md border border-dashed p-4 text-sm text-muted-foreground">
      {children}
    </p>
  );
}

export default function PersonDetailsPage() {
  const params = useParams<{ personId: string }>();
  const personId = Number.parseInt(params.personId, 10);
  const [data, setData] = useState<PersonDetailsState | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function loadPerson() {
      if (!Number.isFinite(personId)) {
        setErrorMessage("Invalid person id.");
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setErrorMessage(null);

      const [person, participants] = await Promise.all([
        getPersonDetailsById(personId),
        getCaseParticipantsForPerson(personId),
      ]);

      const caseIds = (participants.data ?? []).map(
        (participant) => participant.case_id,
      );
      const cases = await getCaseCompactsByIds(caseIds);

      if (!isMounted) {
        return;
      }

      if (person.error) {
        setErrorMessage(person.error.message);
        setData(null);
        setIsLoading(false);
        return;
      }

      const warnings = [
        participants.error?.message,
        cases.error?.message,
      ].filter((message): message is string => Boolean(message));

      setData({
        person: person.data,
        participants: participants.data ?? [],
        cases: cases.data ?? [],
        warnings,
      });
      setIsLoading(false);
    }

    loadPerson();

    return () => {
      isMounted = false;
    };
  }, [personId]);

  const rolesByCaseId = useMemo(() => {
    const grouped = new Map<number, string[]>();

    for (const participant of data?.participants ?? []) {
      grouped.set(participant.case_id, [
        ...(grouped.get(participant.case_id) ?? []),
        roleLabel(participant),
      ]);
    }

    return grouped;
  }, [data?.participants]);

  const participantAttributes = data?.participants.find(
    (participant) => participant.case_participant_attributes,
  )?.case_participant_attributes;

  const personDetails = [
    { label: "Age", value: participantAttributes?.age_text ?? participantAttributes?.age_years },
    { label: "Gender", value: participantAttributes?.gender_text ?? participantAttributes?.gender_normalized },
    { label: "Address", value: data?.person ? primaryPersonAddress(data.person) : null },
    { label: "Minor", value: booleanDisplay(participantAttributes?.is_minor_at_case) },
    { label: "Senior citizen", value: booleanDisplay(participantAttributes?.is_senior_at_case) },
    { label: "PWD", value: booleanDisplay(participantAttributes?.is_pwd_at_case) },
  ].filter((detail) => hasDisplayValue(detail.value));

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto p-3 pt-16 md:p-8">
        <div className="flex w-full max-w-[960px] flex-col gap-4 md:gap-6">
          {isLoading ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Loading person details...
              </CardContent>
            </Card>
          ) : errorMessage ? (
            <Alert variant="destructive">
              <AlertTitle>Unable to load person details</AlertTitle>
              <AlertDescription>{errorMessage}</AlertDescription>
            </Alert>
          ) : !data?.person ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Person not found.
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
                <CardHeader className="gap-4 p-4 sm:p-6">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-3">
                      <CardTitle className="text-2xl sm:text-3xl">
                        {data.person.full_name}
                      </CardTitle>
                    </div>
                  </div>

                  {personDetails.length > 0 ? (
                    <div className="grid gap-3 border-t pt-4 sm:grid-cols-2 lg:grid-cols-3">
                      {personDetails.map((detail) => (
                        <DetailItem
                          key={detail.label}
                          label={detail.label}
                          value={displayValue(detail.value as string | number)}
                        />
                      ))}
                    </div>
                  ) : null}

                  <div className="border-t pt-4">
                    <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                      Aliases
                    </p>
                    {(data.person.person_aliases ?? []).length === 0 ? (
                      <p className="text-sm text-muted-foreground">No aliases recorded.</p>
                    ) : (
                      <div className="flex flex-wrap gap-2">
                        {(data.person.person_aliases ?? []).map((alias) => (
                          <Badge
                            key={`${alias.alias_name}-${alias.alias_type}`}
                            variant={alias.is_active ? "outline" : "secondary"}
                          >
                            {alias.alias_name}{" "}
                            {alias.alias_type ? `(${alias.alias_type})` : null}
                          </Badge>
                        ))}
                      </div>
                    )}
                  </div>
                </CardHeader>
              </Card>

              <div className="grid gap-6">
                <Card>
                  <CardHeader>
                    <CardTitle>Associated cases</CardTitle>
                    <CardDescription>
                      Cases connected to this person. Select a case to open the
                      case details page.
                    </CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    {data.cases.length === 0 ? (
                      <SectionEmpty>No associated cases found.</SectionEmpty>
                    ) : (
                      data.cases.map((caseRecord) => (
                        <Link
                          key={caseRecord.id}
                          href={`/cases/${caseRecord.id}`}
                          className="block rounded-lg border p-4 transition-colors hover:bg-muted/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
                        >
                          <div className="flex items-start justify-between gap-4">
                            <div className="min-w-0">
                              <p className="font-semibold">
                                {caseRecord.docket_display_number ??
                                  `Case #${caseRecord.id}`}
                              </p>
                              <p className="mt-1 text-sm text-muted-foreground">
                                Violations: {caseRecord.violations ?? "—"} |
                                Status:{" "}
                                {caseRecord.current_status_label ??
                                  caseRecord.current_status_code ??
                                  "—"}
                              </p>
                            </div>
                            <ExternalLink className="mt-1 h-4 w-4 shrink-0 text-muted-foreground" />
                          </div>
                          <Separator className="my-3" />
                          <div className="grid gap-3 text-sm sm:grid-cols-3">
                            <DetailItem
                              label="Role"
                              value={
                                (
                                  rolesByCaseId.get(caseRecord.id ?? 0) ?? []
                                ).join(", ") || "—"
                              }
                            />
                            <DetailItem
                              label="Date received"
                              value={formatDate(caseRecord.date_received)}
                            />
                            <DetailItem
                              label="Assigned prosecutor"
                              value={
                                caseRecord.prosecutor_full_name ??
                                caseRecord.prosecutor_short_name ??
                                "—"
                              }
                            />
                          </div>
                        </Link>
                      ))
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
