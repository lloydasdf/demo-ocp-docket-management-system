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

export default function OrganizationDetailsPage() {
  const params = useParams<{ organizationId: string }>();
  const organizationId = Number(params.organizationId);
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

  const casesById = useMemo(() => new Map(state.cases.map((caseRow) => [caseRow.id, caseRow])), [state.cases]);
  const aliases = aliasesFor(state.organization);

  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <main className="p-6 lg:pl-72">
        <div className="mx-auto max-w-5xl space-y-6">
          <div>
            <Link href="/clearance-search" className="text-sm font-medium text-primary hover:underline">← Back to clearance search</Link>
            <h1 className="mt-2 text-3xl font-bold">Organization Profile</h1>
          </div>

          {errorMessage ? <Alert variant="destructive"><AlertTitle>Unable to load organization</AlertTitle><AlertDescription>{errorMessage}</AlertDescription></Alert> : null}
          {state.warnings.map((warning) => <Alert key={warning}><AlertTitle>Partial data warning</AlertTitle><AlertDescription>{warning}</AlertDescription></Alert>)}

          <Card>
            <CardHeader>
              <CardTitle>{isLoading ? "Loading…" : displayValue(state.organization?.organization_name)}</CardTitle>
              <CardDescription>Organization identity, contact details, aliases, and linked case participation.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 md:grid-cols-3">
                <div><p className="text-xs uppercase text-muted-foreground">Contact person</p><p className="font-medium">{displayValue(state.organization?.contact_person)}</p></div>
                <div><p className="text-xs uppercase text-muted-foreground">Phone</p><p className="font-medium">{displayValue(state.organization?.contact_number)}</p></div>
                <div><p className="text-xs uppercase text-muted-foreground">Email</p><p className="font-medium">{displayValue(state.organization?.email)}</p></div>
              </div>
              <Separator />
              <div className="flex flex-wrap gap-2">
                {aliases.length > 0 ? aliases.map((alias) => <Badge key={alias} variant="outline">{alias}</Badge>) : <span className="text-sm text-muted-foreground">No active aliases recorded.</span>}
              </div>
              <p className="text-xs text-muted-foreground">Created {formatDate(state.organization?.created_at)} · Updated {formatDate(state.organization?.updated_at)}</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Linked Cases</CardTitle><CardDescription>{state.participants.length} case participant record{state.participants.length === 1 ? "" : "s"}</CardDescription></CardHeader>
            <CardContent className="space-y-3">
              {state.participants.length === 0 && !isLoading ? <p className="text-sm text-muted-foreground">No linked cases found.</p> : null}
              {state.participants.map((participant) => {
                const caseRow = casesById.get(participant.case_id);
                return (
                  <Link key={participant.id} href={`/cases/${participant.case_id}`} className="flex items-center justify-between rounded-lg border p-4 transition-colors hover:bg-muted/40">
                    <div>
                      <p className="font-semibold">{caseRow?.docket_display_number ?? `Case #${participant.case_id}`}</p>
                      <p className="text-sm text-muted-foreground">Role: {roleLabel(participant)}</p>
                    </div>
                    <ExternalLink className="h-4 w-4 text-muted-foreground" />
                  </Link>
                );
              })}
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}
