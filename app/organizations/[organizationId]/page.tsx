"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ExternalLink } from "lucide-react";

import { Sidebar } from "@/components/sidebar";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import {
  getCaseCompactsByIds,
  getCaseParticipantsForOrganization,
  getOrganizationDetailsById,
  type CaseParticipantRecord,
  type CasesDisplayRecord,
  type OrganizationDetailsRecord,
} from "@/lib/supabase/queries";

type OrganizationDetailsState = {
  organization: OrganizationDetailsRecord | null;
  participants: CaseParticipantRecord[];
  cases: CasesDisplayRecord[];
  warnings: string[];
};

function displayValue(value: string | number | null | undefined) {
  return value === null || value === undefined || value === "" ? "—" : String(value);
}

function hasDisplayValue(value: string | number | boolean | null | undefined) {
  return value !== null && value !== undefined && value !== "";
}

function formatDate(value: string | null | undefined) {
  if (!value) return "—";
  const parsedDate = new Date(value);
  return Number.isNaN(parsedDate.getTime()) ? value : parsedDate.toLocaleDateString();
}

function aliasesFor(organization: OrganizationDetailsRecord | null) {
  const aliases = organization?.organization_aliases;
  return Array.isArray(aliases)
    ? aliases
        .map((alias) => (typeof alias === "object" && alias && "alias_name" in alias ? String(alias.alias_name) : null))
        .filter((alias): alias is string => Boolean(alias))
    : [];
}

function roleLabel(participant: CaseParticipantRecord) {
  return participant.participant_roles?.display_label ?? participant.participant_roles?.code ?? "Party";
}

function formatOrganizationDetails(details: unknown) {
  if (
    !details ||
    typeof details !== "object" ||
    Array.isArray(details) ||
    Object.keys(details as Record<string, unknown>).length === 0
  ) {
    return null;
  }

  return Object.entries(details as Record<string, unknown>)
    .map(
      ([key, value]) =>
        `${key}: ${typeof value === "object" ? JSON.stringify(value) : String(value)}`,
    )
    .join("; ");
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

export default function OrganizationDetailsPage() {
  const params = useParams<{ organizationId: string }>();
  const organizationId = Number.parseInt(params.organizationId, 10);
  const [state, setState] = useState<OrganizationDetailsState>({ organization: null, participants: [], cases: [], warnings: [] });
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function loadOrganization() {
      if (!Number.isFinite(organizationId)) {
        setErrorMessage("Invalid organization identifier.");
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setErrorMessage(null);

      const warnings: string[] = [];
      const [organizationResult, participantsResult] = await Promise.all([
        getOrganizationDetailsById(organizationId),
        getCaseParticipantsForOrganization(organizationId),
      ]);

      if (!isMounted) return;

      if (organizationResult.error) {
        setErrorMessage(organizationResult.error.message);
        setIsLoading(false);
        return;
      }

      if (participantsResult.error) warnings.push(participantsResult.error.message);

      const participants = participantsResult.data ?? [];
      const caseIds = Array.from(new Set(participants.map((participant) => participant.case_id).filter((caseId): caseId is number => Number.isFinite(caseId))));
      const casesResult = await getCaseCompactsByIds(caseIds);

      if (!isMounted) return;
      if (casesResult.error) warnings.push(casesResult.error.message);

      setState({ organization: organizationResult.data ?? null, participants, cases: casesResult.data ?? [], warnings });
      setIsLoading(false);
    }

    void loadOrganization();
    return () => { isMounted = false; };
  }, [organizationId]);

  const rolesByCaseId = useMemo(() => {
    const grouped = new Map<number, string[]>();

    for (const participant of state.participants) {
      grouped.set(participant.case_id, [
        ...(grouped.get(participant.case_id) ?? []),
        roleLabel(participant),
      ]);
    }

    return grouped;
  }, [state.participants]);
  const aliases = aliasesFor(state.organization);
  const organizationDetails = [
    { label: "Contact person", value: state.organization?.contact_person },
    { label: "Phone", value: state.organization?.contact_number },
    { label: "Email", value: state.organization?.email },
    { label: "Organization details", value: formatOrganizationDetails(state.organization?.details_jsonb) },
  ].filter((detail) => hasDisplayValue(detail.value));

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto p-3 pt-16 md:p-8">
        <div className="flex w-full max-w-[960px] flex-col gap-4 md:gap-6">
          {isLoading ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Loading organization details...
              </CardContent>
            </Card>
          ) : errorMessage ? (
            <Alert variant="destructive">
              <AlertTitle>Unable to load organization details</AlertTitle>
              <AlertDescription>{errorMessage}</AlertDescription>
            </Alert>
          ) : !state.organization ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Organization not found.
              </CardContent>
            </Card>
          ) : (
            <>
              {state.warnings.length > 0 ? (
                <Alert>
                  <AlertTitle>Some related sections could not be loaded</AlertTitle>
                  <AlertDescription>{state.warnings.join(" ")}</AlertDescription>
                </Alert>
              ) : null}

              <Card>
                <CardHeader className="gap-4 p-4 sm:p-6">
                  <div className="min-w-0">
                    <CardTitle className="text-2xl font-bold sm:text-3xl">
                      {state.organization.organization_name}
                    </CardTitle>
                  </div>

                  {organizationDetails.length > 0 ? (
                    <div className="grid gap-3 border-t pt-4 sm:grid-cols-2 lg:grid-cols-3">
                      {organizationDetails.map((detail) => (
                        <DetailItem
                          key={detail.label}
                          label={detail.label}
                          value={displayValue(detail.value as string | number)}
                        />
                      ))}
                    </div>
                  ) : null}

                  {aliases.length > 0 ? (
                    <div className="border-t pt-4">
                      <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                        Aliases
                      </p>
                      <div className="flex flex-wrap gap-2">
                        {aliases.map((alias) => (
                          <Badge key={alias} variant="outline">
                            {alias}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  ) : null}
                </CardHeader>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Associated cases</CardTitle>
                  <CardDescription>
                    Cases connected to this organization. Select a case to open the case details page.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  {state.cases.length === 0 ? (
                    <SectionEmpty>No associated cases found.</SectionEmpty>
                  ) : (
                    state.cases.map((caseRecord) => (
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
                              Status: {caseRecord.current_case_status_label ?? caseRecord.current_status_label ?? caseRecord.current_status_code ?? "—"} | Stage: {caseRecord.current_case_stage_label ?? "—"}
                            </p>
                          </div>
                          <ExternalLink className="mt-1 h-4 w-4 shrink-0 text-muted-foreground" />
                        </div>
                        <Separator className="my-3" />
                        <div className="grid gap-3 text-sm sm:grid-cols-3">
                          <DetailItem
                            label="Role"
                            value={
                              (rolesByCaseId.get(caseRecord.id ?? 0) ?? []).join(", ") ||
                              "—"
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
            </>
          )}
        </div>
      </main>
    </div>
  );
}
