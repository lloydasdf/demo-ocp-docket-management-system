"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  AlertCircle,
  Database,
  Info,
  ListFilter,
  Search as SearchIcon,
} from "lucide-react";

import { StatusBadge } from "@/components/status-badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import {
  type ClearanceSearchResult,
  searchClearancePhoneticMatches,
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

const phoneticConfidenceGroups = {
  High: {
    cardClass: "border-slate-200 bg-slate-50/50",
    itemClass: "border-slate-200 hover:bg-slate-50/50",
    badgeClass: "bg-slate-500",
  },
  Medium: {
    cardClass: "border-slate-200 bg-slate-50/40",
    itemClass: "border-slate-200 hover:bg-slate-50/40",
    badgeClass: "bg-slate-400",
  },
  Low: {
    cardClass: "border-gray-200 bg-gray-50/40",
    itemClass: "border-gray-200 hover:bg-gray-50/40",
    badgeClass: "bg-gray-500",
  },
} satisfies Record<
  keyof typeof confidenceGroups,
  { cardClass: string; itemClass: string; badgeClass: string }
>;

function getSearchTokens(query: string) {
  return query.trim().split(/\s+/).filter(Boolean);
}

function hasMultipleNameTokens(name: string) {
  return getSearchTokens(name).length > 1;
}

type ParticipantRoleFilter = "respondents" | "complainants" | "both";

interface ClearanceSearchPreferences {
  searchQuery: string;
  participantRoleFilter: ParticipantRoleFilter;
  isExpandedSearchEnabled: boolean;
  searchResults: ClearanceSearchResult[];
  possibleMatchResults: ClearanceSearchResult[];
  hasSearchedPossibleMatches: boolean;
  phoneticMatchResults: ClearanceSearchResult[];
  hasSearchedPhoneticMatches: boolean;
}

const CLEARANCE_SEARCH_PREFERENCES_STORAGE_KEY =
  "ocp-clearance-search-preferences";

function isParticipantRoleFilter(value: unknown): value is ParticipantRoleFilter {
  return value === "respondents" || value === "complainants" || value === "both";
}

function parseStoredClearanceSearchPreferences(value: string | null) {
  if (!value) {
    return null;
  }

  try {
    return JSON.parse(value) as Partial<ClearanceSearchPreferences>;
  } catch {
    return null;
  }
}

function getRoleLabel(result: ClearanceSearchResult) {
  return result.roleLabel.toLowerCase();
}

function isRespondentResult(result: ClearanceSearchResult) {
  return getRoleLabel(result).includes("respondent");
}

function isComplainantResult(result: ClearanceSearchResult) {
  return getRoleLabel(result).includes("complainant");
}

function filterResultsByParticipantRole(
  results: ClearanceSearchResult[],
  roleFilter: ParticipantRoleFilter,
) {
  return results.filter((result) => {
    if (roleFilter === "respondents") {
      return isRespondentResult(result);
    }

    if (roleFilter === "complainants") {
      return isComplainantResult(result);
    }

    return isRespondentResult(result) || isComplainantResult(result);
  });
}

function getResultNameKey(result: ClearanceSearchResult) {
  return result.respondentName.trim().toLowerCase().replace(/\s+/g, " ");
}

function getResultNameKeys(results: ClearanceSearchResult[]) {
  return new Set(results.map(getResultNameKey).filter(Boolean));
}

function excludeResultsByName(
  results: ClearanceSearchResult[],
  excludedNameKeys: Set<string>,
) {
  return results.filter(
    (result) => !excludedNameKeys.has(getResultNameKey(result)),
  );
}

function getRoleFilterSummary(roleFilter: ParticipantRoleFilter) {
  if (roleFilter === "respondents") {
    return "respondent";
  }

  if (roleFilter === "complainants") {
    return "complainant";
  }

  return "complainant or respondent";
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
  confidenceTone?: "standard" | "phonetic";
}

function ResultGroup({
  label,
  results,
  confidenceTone = "standard",
}: ResultGroupProps) {
  if (results.length === 0) {
    return null;
  }

  const config =
    confidenceTone === "phonetic"
      ? phoneticConfidenceGroups[label]
      : confidenceGroups[label];

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
              href={result.participantKind === "ORGANIZATION" && result.organizationId ? `/organizations/${result.organizationId}` : `/persons/${result.personId}`}
              className={`block p-4 bg-white border rounded-lg transition-colors ${config.itemClass} focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2`}
            >
              <div className="flex items-start justify-between gap-4 mb-2">
                <div className="flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-semibold text-lg">
                      {result.respondentName}
                      {result.participantKind === "PERSON" && result.age ? (
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
                    {matchDetails ? (
                      <Tooltip>
                        <TooltipTrigger asChild>
                          <span
                            className="inline-flex h-6 w-6 items-center justify-center rounded-full border bg-background text-muted-foreground"
                            aria-label="Show match details"
                            tabIndex={0}
                          >
                            <Info className="h-3.5 w-3.5" />
                          </span>
                        </TooltipTrigger>
                        <TooltipContent className="max-w-xs text-left">
                          {matchDetails}
                        </TooltipContent>
                      </Tooltip>
                    ) : null}
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
                  View {result.participantKind === "ORGANIZATION" ? "organization" : "person"} details
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
  const [isExpandedSearchEnabled, setIsExpandedSearchEnabled] = useState(true);
  const [participantRoleFilter, setParticipantRoleFilter] =
    useState<ParticipantRoleFilter>("respondents");
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
  const [phoneticMatchResults, setPhoneticMatchResults] = useState<
    ClearanceSearchResult[]
  >([]);
  const [isSearchingPhoneticMatches, setIsSearchingPhoneticMatches] =
    useState(false);
  const [phoneticMatchError, setPhoneticMatchError] = useState<string | null>(
    null,
  );
  const [hasSearchedPhoneticMatches, setHasSearchedPhoneticMatches] =
    useState(false);
  const [hasLoadedStoredSearchPreferences, setHasLoadedStoredSearchPreferences] =
    useState(false);
  const possibleMatchSearchIdRef = useRef(0);
  const lastSearchedQueryRef = useRef("");

  useEffect(() => {
    const preferences = parseStoredClearanceSearchPreferences(
      window.localStorage.getItem(CLEARANCE_SEARCH_PREFERENCES_STORAGE_KEY),
    );

    if (preferences) {
      if (typeof preferences.searchQuery === "string") {
        lastSearchedQueryRef.current = preferences.searchQuery.trim();
        setSearchQuery(preferences.searchQuery);
      }

      if (isParticipantRoleFilter(preferences.participantRoleFilter)) {
        setParticipantRoleFilter(preferences.participantRoleFilter);
      }

      if (typeof preferences.isExpandedSearchEnabled === "boolean") {
        setIsExpandedSearchEnabled(preferences.isExpandedSearchEnabled);
      }

      if (Array.isArray(preferences.searchResults)) {
        setSearchResults(preferences.searchResults);
      }

      if (Array.isArray(preferences.possibleMatchResults)) {
        setPossibleMatchResults(preferences.possibleMatchResults);
      }

      if (typeof preferences.hasSearchedPossibleMatches === "boolean") {
        setHasSearchedPossibleMatches(preferences.hasSearchedPossibleMatches);
      }

      if (Array.isArray(preferences.phoneticMatchResults)) {
        setPhoneticMatchResults(preferences.phoneticMatchResults);
      }

      if (typeof preferences.hasSearchedPhoneticMatches === "boolean") {
        setHasSearchedPhoneticMatches(preferences.hasSearchedPhoneticMatches);
      }
    }

    setHasLoadedStoredSearchPreferences(true);
  }, []);

  useEffect(() => {
    if (!hasLoadedStoredSearchPreferences) {
      return;
    }

    const preferences: ClearanceSearchPreferences = {
      searchQuery,
      participantRoleFilter,
      isExpandedSearchEnabled,
      searchResults,
      possibleMatchResults,
      hasSearchedPossibleMatches,
      phoneticMatchResults,
      hasSearchedPhoneticMatches,
    };

    window.localStorage.setItem(
      CLEARANCE_SEARCH_PREFERENCES_STORAGE_KEY,
      JSON.stringify(preferences),
    );
  }, [
    hasLoadedStoredSearchPreferences,
    hasSearchedPhoneticMatches,
    hasSearchedPossibleMatches,
    isExpandedSearchEnabled,
    participantRoleFilter,
    phoneticMatchResults,
    possibleMatchResults,
    searchQuery,
    searchResults,
  ]);

  useEffect(() => {
    if (!hasLoadedStoredSearchPreferences) {
      return;
    }

    const trimmedQuery = searchQuery.trim();

    if (trimmedQuery === lastSearchedQueryRef.current) {
      return;
    }

    lastSearchedQueryRef.current = trimmedQuery;

    const searchId = possibleMatchSearchIdRef.current + 1;
    possibleMatchSearchIdRef.current = searchId;
    setPossibleMatchResults([]);
    setPossibleMatchError(null);
    setHasSearchedPossibleMatches(false);
    setIsSearchingPossibleMatches(false);
    setPhoneticMatchResults([]);
    setPhoneticMatchError(null);
    setHasSearchedPhoneticMatches(false);
    setIsSearchingPhoneticMatches(false);

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
        searchType: "all",
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

      if (!isExpandedSearchEnabled) {
        return;
      }

      setIsSearchingPossibleMatches(true);

      const possibleResult = await searchClearancePossibleMatches({
        query: trimmedQuery,
        searchType: "all",
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

      const shouldSearchPhoneticMatches =
        getSearchTokens(trimmedQuery).length > 1;

      if (!shouldSearchPhoneticMatches) {
        return;
      }

      setIsSearchingPhoneticMatches(true);

      const phoneticResult = await searchClearancePhoneticMatches({
        query: trimmedQuery,
        searchType: "all",
        limit: 50,
      });

      if (!isCurrent || possibleMatchSearchIdRef.current !== searchId) {
        return;
      }

      if (phoneticResult.error) {
        setPhoneticMatchResults([]);
        setPhoneticMatchError(phoneticResult.error.message);
      } else {
        setPhoneticMatchResults(
          phoneticResult.data.filter((result) =>
            hasMultipleNameTokens(result.respondentName),
          ),
        );
        setPhoneticMatchError(null);
      }

      setHasSearchedPhoneticMatches(true);
      setIsSearchingPhoneticMatches(false);
    }, 300);

    return () => {
      isCurrent = false;
      window.clearTimeout(timer);
    };
  }, [hasLoadedStoredSearchPreferences, searchQuery]);

  async function handleExpandPossibleMatches() {
    const trimmedQuery = searchQuery.trim();

    if (!trimmedQuery) {
      return;
    }

    const searchId = possibleMatchSearchIdRef.current;
    setPossibleMatchResults([]);
    setPossibleMatchError(null);
    setHasSearchedPossibleMatches(false);
    setPhoneticMatchResults([]);
    setPhoneticMatchError(null);
    setHasSearchedPhoneticMatches(false);
    setIsSearchingPhoneticMatches(false);
    setIsSearchingPossibleMatches(true);

    const possibleResult = await searchClearancePossibleMatches({
      query: trimmedQuery,
      searchType: "all",
      limit: 50,
    });

    if (possibleMatchSearchIdRef.current !== searchId) {
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
  }

  async function handleExpandPhoneticMatches() {
    const trimmedQuery = searchQuery.trim();

    if (!trimmedQuery || getSearchTokens(trimmedQuery).length <= 1) {
      return;
    }

    const searchId = possibleMatchSearchIdRef.current;
    setPhoneticMatchResults([]);
    setPhoneticMatchError(null);
    setHasSearchedPhoneticMatches(false);
    setIsSearchingPhoneticMatches(true);

    const phoneticResult = await searchClearancePhoneticMatches({
      query: trimmedQuery,
      searchType: "all",
      limit: 50,
    });

    if (possibleMatchSearchIdRef.current !== searchId) {
      return;
    }

    if (phoneticResult.error) {
      setPhoneticMatchResults([]);
      setPhoneticMatchError(phoneticResult.error.message);
    } else {
      setPhoneticMatchResults(
        phoneticResult.data.filter((result) =>
          hasMultipleNameTokens(result.respondentName),
        ),
      );
      setPhoneticMatchError(null);
    }

    setHasSearchedPhoneticMatches(true);
    setIsSearchingPhoneticMatches(false);
  }

  const filteredSearchResults = useMemo(
    () => filterResultsByParticipantRole(searchResults, participantRoleFilter),
    [participantRoleFilter, searchResults],
  );
  const filteredPossibleMatchResults = useMemo(() => {
    const roleFilteredResults = filterResultsByParticipantRole(
      possibleMatchResults,
      participantRoleFilter,
    );

    return excludeResultsByName(
      roleFilteredResults,
      getResultNameKeys(filteredSearchResults),
    );
  }, [filteredSearchResults, participantRoleFilter, possibleMatchResults]);
  const filteredPhoneticMatchResults = useMemo(() => {
    const roleFilteredResults = filterResultsByParticipantRole(
      phoneticMatchResults,
      participantRoleFilter,
    );
    const previouslyShownNameKeys = new Set([
      ...getResultNameKeys(filteredSearchResults),
      ...getResultNameKeys(filteredPossibleMatchResults),
    ]);

    return excludeResultsByName(roleFilteredResults, previouslyShownNameKeys);
  }, [
    filteredPossibleMatchResults,
    filteredSearchResults,
    participantRoleFilter,
    phoneticMatchResults,
  ]);
  const groupedResults = useMemo(
    () => groupResults(filteredSearchResults),
    [filteredSearchResults],
  );
  const groupedPossibleMatchResults = useMemo(
    () => groupResults(filteredPossibleMatchResults),
    [filteredPossibleMatchResults],
  );
  const groupedPhoneticMatchResults = useMemo(
    () => groupResults(filteredPhoneticMatchResults),
    [filteredPhoneticMatchResults],
  );
  const roleFilterSummary = getRoleFilterSummary(participantRoleFilter);
  const trimmedSearchQuery = searchQuery.trim();
  const canRunPhoneticSearch = getSearchTokens(trimmedSearchQuery).length > 1;
  const shouldShowPossibleMatches =
    !isSearching &&
    !searchError &&
    (isSearchingPossibleMatches ||
      hasSearchedPossibleMatches ||
      Boolean(possibleMatchError) ||
      possibleMatchResults.length > 0);
  const shouldShowPhoneticMatches =
    !isSearching &&
    !searchError &&
    canRunPhoneticSearch &&
    (isSearchingPhoneticMatches ||
      hasSearchedPhoneticMatches ||
      Boolean(phoneticMatchError) ||
      phoneticMatchResults.length > 0);
  const shouldShowManualPossibleButton =
    !isExpandedSearchEnabled &&
    !isSearching &&
    !searchError &&
    !isSearchingPossibleMatches &&
    !hasSearchedPossibleMatches &&
    !possibleMatchError &&
    possibleMatchResults.length === 0;
  const shouldShowManualPhoneticButton =
    !isExpandedSearchEnabled &&
    !isSearching &&
    !searchError &&
    canRunPhoneticSearch &&
    hasSearchedPossibleMatches &&
    !possibleMatchError &&
    !isSearchingPossibleMatches &&
    !isSearchingPhoneticMatches &&
    !hasSearchedPhoneticMatches &&
    !phoneticMatchError &&
    phoneticMatchResults.length === 0;

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

      <Card className="sticky top-0 z-20 border-x-0 border-t-0 rounded-none bg-background/95 shadow-sm backdrop-blur supports-[backdrop-filter]:bg-background/80 md:rounded-lg md:border-x md:border-t">
        <CardContent className="space-y-2 py-3 md:py-4">
          <div>
            <Label htmlFor="search-query">Search Query</Label>
            <div className="relative mt-1">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                id="search-query"
                placeholder="Enter name or alias..."
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                className="pl-10 pr-12 text-lg"
              />
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="absolute right-1 top-1/2 -translate-y-1/2"
                    aria-label={`Filter results by role: ${roleFilterSummary}`}
                  >
                    <ListFilter className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuLabel>Results filter</DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <DropdownMenuRadioGroup
                    value={participantRoleFilter}
                    onValueChange={(value) =>
                      setParticipantRoleFilter(value as ParticipantRoleFilter)
                    }
                  >
                    <DropdownMenuRadioItem value="respondents">
                      Respondents only
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value="complainants">
                      Complainants only
                    </DropdownMenuRadioItem>
                    <DropdownMenuRadioItem value="both">
                      Both
                    </DropdownMenuRadioItem>
                  </DropdownMenuRadioGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <Switch
              id="expanded-search"
              checked={isExpandedSearchEnabled}
              onCheckedChange={setIsExpandedSearchEnabled}
              aria-label="Toggle automatic possible and phonetic matches"
            />
            <Label
              htmlFor="expanded-search"
              className="cursor-pointer font-medium leading-none"
            >
              Automatic possible and phonetic matches
            </Label>
            <Badge variant="outline" className="h-5 px-2 text-[11px]">
              {isExpandedSearchEnabled ? "On" : "Off"}
            </Badge>
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
              This means the app reached PostgreSQL, but the database does not yet
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

              {filteredSearchResults.length === 0 && (
                <Card>
                  <CardContent className="text-center py-8">
                    <p className="text-muted-foreground">
                      No exact live {roleFilterSummary} records found matching
                      &quot;{searchQuery}&quot;
                    </p>
                  </CardContent>
                </Card>
              )}

              {shouldShowManualPossibleButton && (
                <Card>
                  <CardContent className="flex flex-col gap-3 py-5 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="font-medium">Need a broader review?</p>
                      <p className="text-sm text-muted-foreground">
                        Expand search to load possible typo and spelling matches.
                      </p>
                    </div>
                    <Button type="button" onClick={handleExpandPossibleMatches}>
                      Expand search
                    </Button>
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
                          expanding search<br />
                          finding possible matches for typo error
                        </p>
                      </CardContent>
                    </Card>
                  )}

                  {filteredPossibleMatchResults.length > 0 ? (
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
                            No possible {roleFilterSummary} matches found for
                            &quot;{searchQuery}&quot;
                          </p>
                        </CardContent>
                      </Card>
                    )
                  )}
                </section>
              )}

              {shouldShowManualPhoneticButton && (
                <Card>
                  <CardContent className="flex flex-col gap-3 py-5 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="font-medium">Continue with sound-alike names?</p>
                      <p className="text-sm text-muted-foreground">
                        Expand search to load phonetic matches after possible matches.
                      </p>
                    </div>
                    <Button type="button" onClick={handleExpandPhoneticMatches}>
                      Expand search
                    </Button>
                  </CardContent>
                </Card>
              )}

              {shouldShowPhoneticMatches && (
                <section className="space-y-4">
                  <div>
                    <h2 className="text-2xl font-semibold">
                      Sound-alike Matches — broad manual review required
                    </h2>
                    <p className="text-sm text-muted-foreground">
                      These are phonetic/sound-alike results only. Verify
                      carefully before making a clearance decision.
                    </p>
                  </div>

                  {phoneticMatchError && (
                    <Alert variant="destructive">
                      <AlertCircle className="h-4 w-4" />
                      <AlertTitle>Unable to run sound-alike search</AlertTitle>
                      <AlertDescription>{phoneticMatchError}</AlertDescription>
                    </Alert>
                  )}

                  {isSearchingPhoneticMatches && (
                    <Card>
                      <CardContent className="text-center py-8">
                        <p className="text-muted-foreground">
                          expanding search<br />
                          looking for possible sound alike names
                        </p>
                      </CardContent>
                    </Card>
                  )}

                  {filteredPhoneticMatchResults.length > 0 ? (
                    <>
                      <ResultGroup
                        label="High"
                        results={groupedPhoneticMatchResults.High}
                        confidenceTone="phonetic"
                      />
                      <ResultGroup
                        label="Medium"
                        results={groupedPhoneticMatchResults.Medium}
                        confidenceTone="phonetic"
                      />
                      <ResultGroup
                        label="Low"
                        results={groupedPhoneticMatchResults.Low}
                        confidenceTone="phonetic"
                      />
                    </>
                  ) : (
                    hasSearchedPhoneticMatches &&
                    !phoneticMatchError && (
                      <Card>
                        <CardContent className="text-center py-8">
                          <p className="text-muted-foreground">
                            No sound-alike {roleFilterSummary} matches found for
                            &quot;{searchQuery}&quot;
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
