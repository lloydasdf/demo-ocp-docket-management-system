"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  type ClearanceSearchResult,
  type ClearanceSearchType,
  searchClearancePossibleMatches,
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
          const matchDetails = result.matchDetails;

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
                  <StatusBadge status={result.status} size="sm" />
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
  const [searchType, setSearchType] = useState<ClearanceSearchType>("all");
  const [searchResults, setSearchResults] = useState<ClearanceSearchResult[]>(
    [],
  );
  const [isSearching, setIsSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [possibleMatchResults, setPossibleMatchResults] = useState<
    ClearanceSearchResult[]
  >([]);
  const [isSearchingPossibleMatches, setIsSearchingPossibleMatches] =
    useState(false);
  const [possibleMatchError, setPossibleMatchError] = useState<string | null>(
    null,
  );
  const [hasSearchedPossibleMatches, setHasSearchedPossibleMatches] =
    useState(false);
  const possibleMatchSearchIdRef = useRef(0);

  useEffect(() => {
    const trimmedQuery = searchQuery.trim();

    const searchId = possibleMatchSearchIdRef.current + 1;
    possibleMatchSearchIdRef.current = searchId;
    setPossibleMatchResults([]);
    setPossibleMatchError(null);
    setHasSearchedPossibleMatches(false);
    setIsSearchingPossibleMatches(false);

    if (!trimmedQuery) {
      setSearchResults([]);
      setSearchError(null);
      setIsSearching(false);
      return;
    }

    let isCurrent = true;
    setIsSearching(true);

    const timer = window.setTimeout(async () => {
      const exactResult = await searchClearanceRecords({
        query: trimmedQuery,
        searchType,
        limit: 50,
      });

      if (!isCurrent || possibleMatchSearchIdRef.current !== searchId) {
        return;
      }

      if (exactResult.error) {
        setSearchResults([]);
        setSearchError(exactResult.error.message);
        setIsSearching(false);
        return;
      }

      setSearchResults(exactResult.data);
      setSearchError(null);
      setIsSearching(false);
      setIsSearchingPossibleMatches(true);

      const possibleResult = await searchClearancePossibleMatches({
        query: trimmedQuery,
        searchType,
        limit: 50,
      });

      if (!isCurrent || possibleMatchSearchIdRef.current !== searchId) {
        return;
      }

      if (possibleResult.error) {
        setPossibleMatchResults([]);
        setPossibleMatchError(possibleResult.error.message);
      } else {
        setPossibleMatchResults(possibleResult.data);
        setPossibleMatchError(null);
      }

      setHasSearchedPossibleMatches(true);
      setIsSearchingPossibleMatches(false);
    }, 300);

    return () => {
      isCurrent = false;
      window.clearTimeout(timer);
    };
  }, [searchQuery, searchType]);

  const groupedResults = useMemo(
    () => groupResults(searchResults),
    [searchResults],
  );
  const groupedPossibleMatchResults = useMemo(
    () => groupResults(possibleMatchResults),
    [possibleMatchResults],
  );
  const trimmedSearchQuery = searchQuery.trim();
  const shouldShowPossibleMatches =
    !isSearching &&
    !searchError &&
    (isSearchingPossibleMatches ||
      hasSearchedPossibleMatches ||
      Boolean(possibleMatchError) ||
      possibleMatchResults.length > 0);

  return (
    <div className="p-8 space-y-6">
      <div>
        <div className="flex items-center gap-3">
          <h1 className="text-3xl font-bold text-foreground">
            Clearance Search
          </h1>
          <Badge variant="secondary" className="gap-1">
            <Database className="h-3.5 w-3.5" />
            Live Supabase
          </Badge>
        </div>
      </div>

      <Card>
        <CardContent className="space-y-4 pt-6">
          <div className="grid gap-4 md:grid-cols-[1fr_220px]">
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
            </div>
            <div>
              <Label htmlFor="search-type">Search Mode</Label>
              <Select
                value={searchType}
                onValueChange={(value) =>
                  setSearchType(value as ClearanceSearchType)
                }
              >
                <SelectTrigger id="search-type" className="mt-1">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Names + aliases</SelectItem>
                  <SelectItem value="name">Name only</SelectItem>
                  <SelectItem value="alias">Alias only</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <p className="text-xs text-muted-foreground">
            Searches exact normalized names first, then automatically reviews
            possible spelling variants and misspelled names separately.
          </p>
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
              live exact normalized clearance search. Install the Phase 1
              clearance search RPC, then refresh this page.
            </p>
          </AlertDescription>
        </Alert>
      )}

      {trimmedSearchQuery && (
        <div className="space-y-6">
          {isSearching && (
            <Card>
              <CardContent className="text-center py-8">
                <p className="text-muted-foreground">
                  Searching live Supabase records…
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
                      No exact live records found matching &quot;{searchQuery}&quot;
                    </p>
                  </CardContent>
                </Card>
              )}

              {shouldShowPossibleMatches && (
                <section className="space-y-4">
                  <div>
                    <h2 className="text-2xl font-semibold">
                      Possible Matches — manual review required
                    </h2>
                    <p className="text-sm text-muted-foreground">
                      These results are separate from exact matches and require
                      manual review before clearance decisions.
                    </p>
                  </div>

                  {possibleMatchError && (
                    <Alert variant="destructive">
                      <AlertCircle className="h-4 w-4" />
                      <AlertTitle>Unable to run possible-match search</AlertTitle>
                      <AlertDescription>{possibleMatchError}</AlertDescription>
                    </Alert>
                  )}

                  {isSearchingPossibleMatches && (
                    <Card>
                      <CardContent className="text-center py-8">
                        <p className="text-muted-foreground">
                          Searching possible misspelled names…
                        </p>
                      </CardContent>
                    </Card>
                  )}

                  {possibleMatchResults.length > 0 ? (
                    <>
                      <ResultGroup
                        label="High"
                        results={groupedPossibleMatchResults.High}
                      />
                      <ResultGroup
                        label="Medium"
                        results={groupedPossibleMatchResults.Medium}
                      />
                      <ResultGroup
                        label="Low"
                        results={groupedPossibleMatchResults.Low}
                      />
                    </>
                  ) : (
                    hasSearchedPossibleMatches &&
                    !possibleMatchError && (
                      <Card>
                        <CardContent className="text-center py-8">
                          <p className="text-muted-foreground">
                            No possible matches found for &quot;{searchQuery}&quot;
                          </p>
                        </CardContent>
                      </Card>
                    )
                  )}
                </section>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
