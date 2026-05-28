"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { AlertCircle, Database, Search as SearchIcon } from "lucide-react";

import { StatusBadge } from "@/components/status-badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  type ClearanceSearchResult,
  searchClearanceRecords,
} from "@/lib/supabase/queries";

const confidenceGroups = {
  High: {
    min: 90,
    cardClass: "border-green-200 bg-green-50/50",
    itemClass: "border-green-200 hover:bg-green-50/30",
    badgeClass: "bg-green-600",
  },
  Medium: {
    min: 70,
    cardClass: "border-yellow-200 bg-yellow-50/50",
    itemClass: "border-yellow-200 hover:bg-yellow-50/30",
    badgeClass: "bg-yellow-600",
  },
  Low: {
    min: 0,
    cardClass: "border-gray-200 bg-gray-50/50",
    itemClass: "border-gray-200 hover:bg-gray-50/30",
    badgeClass: "bg-gray-600",
  },
} as const;

function normalizeStatusForBadge(status: string) {
  const normalized = status.toLowerCase();

  if (normalized.includes("file")) return "Filed";
  if (normalized.includes("dismiss")) return "Dismissed";
  if (normalized.includes("resolv") || normalized.includes("close"))
    return "Resolved";
  if (normalized.includes("rfi") || normalized.includes("information"))
    return "RFI";

  return "Pending";
}


function visibleMatchDetails(matchDetails: string) {
  return matchDetails.toLowerCase().startsWith("phonetic token match:")
    ? null
    : matchDetails;
}

function groupResults(results: ClearanceSearchResult[]) {
  return results.reduce<
    Record<keyof typeof confidenceGroups, ClearanceSearchResult[]>
  >(
    (groups, result) => {
      if (result.confidenceScore >= confidenceGroups.High.min) {
        groups.High.push(result);
      } else if (result.confidenceScore >= confidenceGroups.Medium.min) {
        groups.Medium.push(result);
      } else {
        groups.Low.push(result);
      }

      return groups;
    },
    { High: [], Medium: [], Low: [] },
  );
}

interface ResultGroupProps {
  label: keyof typeof confidenceGroups;
  results: ClearanceSearchResult[];
}

function ResultGroup({ label, results }: ResultGroupProps) {
  if (results.length === 0) {
    return null;
  }

  const config = confidenceGroups[label];

  return (
    <Card className={config.cardClass}>
      <CardHeader className="pb-3">
        <CardTitle className="text-lg flex items-center gap-2">
          <Badge className={config.badgeClass}>{label} Confidence</Badge>
          {results.length} result{results.length === 1 ? "" : "s"}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {results.map((result) => {
          const matchDetails = visibleMatchDetails(result.matchDetails);

          return (
            <Link
              key={result.id}
              href={`/persons/${result.personId}`}
              className={`block p-4 bg-white border rounded-lg transition-colors ${config.itemClass} focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2`}
            >
              <div className="flex items-start justify-between gap-4 mb-2">
                <div className="flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-semibold text-lg">
                      {result.respondentName}
                      {result.age ? (
                        <span className="ml-2 text-base font-medium text-muted-foreground">
                          {result.age}
                        </span>
                      ) : null}
                    </p>
                    <Badge variant="outline" className="text-xs">
                      {result.roleLabel}
                    </Badge>
                    <Badge variant="secondary" className="text-xs capitalize">
                      {result.matchType}
                    </Badge>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    Violations: {result.violations || "—"} | Docket:{" "}
                    {result.docketNumber} | Status: {result.status || "—"}
                  </p>
                </div>
                <Badge className={`${config.badgeClass} font-bold text-white`}>
                  {result.confidenceScore}%
                </Badge>
              </div>
              {matchDetails ? (
                <p className="mb-3 text-sm text-muted-foreground">
                  {matchDetails}
                </p>
              ) : null}
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex flex-wrap items-center gap-2">
                  <StatusBadge
                    status={normalizeStatusForBadge(result.status) as any}
                    size="sm"
                  />
                  {result.respondentAliases.length > 0 && (
                    <Badge variant="outline" className="text-xs">
                      Aliases: {result.respondentAliases.slice(0, 3).join(", ")}
                      {result.respondentAliases.length > 3 ? "…" : ""}
                    </Badge>
                  )}
                </div>
                <span className="text-sm font-medium text-primary">
                  View person details
                </span>
              </div>
            </Link>
          );
        })}
      </CardContent>
    </Card>
  );
}

export default function ClearanceSearch() {
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<ClearanceSearchResult[]>(
    [],
  );
  const [isSearching, setIsSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);

  useEffect(() => {
    const trimmedQuery = searchQuery.trim();

    if (!trimmedQuery) {
      setSearchResults([]);
      setSearchError(null);
      setIsSearching(false);
      return;
    }

    let isCurrent = true;
    setIsSearching(true);

    const timer = window.setTimeout(async () => {
      const result = await searchClearanceRecords({
        query: trimmedQuery,
        searchType: "all",
        limit: 50,
      });

      if (!isCurrent) {
        return;
      }

      if (result.error) {
        setSearchResults([]);
        setSearchError(result.error.message);
      } else {
        setSearchResults(result.data);
        setSearchError(null);
      }

      setIsSearching(false);
    }, 300);

    return () => {
      isCurrent = false;
      window.clearTimeout(timer);
    };
  }, [searchQuery]);

  const groupedResults = useMemo(
    () => groupResults(searchResults),
    [searchResults],
  );

  return (
    <div className="p-8 space-y-6">
      <div>
        <div className="flex items-center gap-3">
          <h1 className="text-3xl font-bold text-foreground">
            Clearance Search
          </h1>
          <Badge variant="secondary" className="gap-1">
            <Database className="h-3.5 w-3.5" />
            Live PostgreSQL
          </Badge>
        </div>
      </div>

      <Card>
        <CardContent className="space-y-4 pt-6">
          <div>
            <Label htmlFor="search-query">Search Query</Label>
            <div className="relative mt-1">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                id="search-query"
                placeholder="Enter name or alias..."
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                className="pl-10 text-lg"
              />
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              Exact full-name matches rank highest. Prefix, alias, fuzzy,
              phonetic, and B/V sound-alike matches are included, but
              single-token surname or phonetic matches stay in review ranges.
            </p>
          </div>
        </CardContent>
      </Card>

      {searchError && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Unable to run live clearance search</AlertTitle>
          <AlertDescription className="space-y-2">
            <p>{searchError}</p>
            <p>
              This means the app reached Supabase, but Supabase does not yet
              have the <code>search_clearance_records</code> RPC that powers the
              live fuzzy search. Apply
              <code>
                {" "}
                supabase/migrations/20260512000000_clearance_search_person_details.sql
              </code>
              , which enables pg_trgm/fuzzystrmatch and creates that function.
            </p>
          </AlertDescription>
        </Alert>
      )}

      {searchQuery.trim() && (
        <div className="space-y-6">
          {isSearching && (
            <Card>
              <CardContent className="text-center py-8">
                <p className="text-muted-foreground">
                  Searching live PostgreSQL records…
                </p>
              </CardContent>
            </Card>
          )}

          {!isSearching && !searchError && (
            <>
              <ResultGroup label="High" results={groupedResults.High} />
              <ResultGroup label="Medium" results={groupedResults.Medium} />
              <ResultGroup label="Low" results={groupedResults.Low} />

              {searchResults.length === 0 && (
                <Card>
                  <CardContent className="text-center py-8">
                    <p className="text-muted-foreground">
                      No live records found matching &quot;{searchQuery}&quot;
                    </p>
                  </CardContent>
                </Card>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
