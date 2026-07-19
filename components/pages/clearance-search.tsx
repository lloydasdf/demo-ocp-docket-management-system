"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  AlertCircle,
  Database,
  ListFilter,
  Search as SearchIcon,
} from "lucide-react";

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
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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

function isInactiveClearanceResult(result: ClearanceSearchResult) {
  return result.resultGroup === "inactive" || result.isVoided;
}

function activeClearanceResults(results: ClearanceSearchResult[]) {
  return results.filter((result) => result.resultGroup !== "inactive" && !result.isVoided);
}

function inactiveClearanceResults(results: ClearanceSearchResult[]) {
  return results.filter(isInactiveClearanceResult);
}

function getSnapshotValue(snapshot: unknown, key: "person" | "organization" | "attributes") {
  return typeof snapshot === "object" && snapshot && !Array.isArray(snapshot) && key in snapshot ? (snapshot as Record<string, unknown>)[key] : null;
}

function formatCorrectionDate(value: string | null) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

function getInactiveBadgeLabel(result: ClearanceSearchResult) {
  if (result.isCorrected) return "Corrected";
  if (result.isVoided) return "Voided";
  return "Inactive";
}

function getCorrectedPersonName(result: ClearanceSearchResult) {
  const person = getSnapshotValue(result.newSnapshotJson, "person");
  if (typeof person === "object" && person && !Array.isArray(person)) {
    const fullName = (person as Record<string, unknown>).full_name;
    if (typeof fullName === "string" && fullName.trim()) return fullName;
  }

  const organization = getSnapshotValue(result.newSnapshotJson, "organization");
  if (typeof organization === "object" && organization && !Array.isArray(organization)) {
    const organizationName = (organization as Record<string, unknown>).organization_name;
    if (typeof organizationName === "string" && organizationName.trim()) return organizationName;
  }

  return result.activePersonId ? `Person #${result.activePersonId}` : "—";
}

function getResultEntityKey(result: ClearanceSearchResult) {
  const entityId = result.participantKind === "ORGANIZATION"
    ? result.organizationId
    : result.activePersonId ?? result.personId;

  return entityId === null ? `case-${result.caseId}` : `${result.participantKind}-${entityId}`;
}

function getResultEntityKeys(results: ClearanceSearchResult[]) {
  return new Set(results.map(getResultEntityKey));
}

function excludeResultsByEntity(
  results: ClearanceSearchResult[],
  excludedEntityKeys: Set<string>,
) {
  return results.filter(
    (result) => !excludedEntityKeys.has(getResultEntityKey(result)),
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

interface EntitySearchResult extends ClearanceSearchResult {
  cases: ClearanceSearchResult[];
}

function groupResultsByEntity(results: ClearanceSearchResult[]) {
  const entities = new Map<string, EntitySearchResult>();

  for (const result of results) {
    const entityKey = getResultEntityKey(result);
    const existing = entities.get(entityKey);

    if (!existing) {
      entities.set(entityKey, { ...result, cases: [result] });
      continue;
    }

    existing.cases.push(result);
    existing.respondentAliases = Array.from(
      new Set([...existing.respondentAliases, ...result.respondentAliases]),
    );

    if (result.confidenceScore > existing.confidenceScore) {
      Object.assign(existing, result, {
        cases: existing.cases,
        respondentAliases: existing.respondentAliases,
      });
    }
  }

  return Array.from(entities.values()).sort(
    (a, b) => b.confidenceScore - a.confidenceScore || a.respondentName.localeCompare(b.respondentName),
  );
}

function getDistinctDockets(result: EntitySearchResult) {
  return Array.from(
    new Map(result.cases.map((caseResult) => [caseResult.caseId, caseResult])).values(),
  );
}

function groupResults(results: ClearanceSearchResult[]) {
  return groupResultsByEntity(results).reduce<
    Record<keyof typeof confidenceGroups, EntitySearchResult[]>
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
  results: EntitySearchResult[];
  confidenceTone?: "standard" | "phonetic";
  onInactiveSelect?: (result: ClearanceSearchResult) => void;
}

function ResultGroup({
  label,
  results,
  confidenceTone = "standard",
  onInactiveSelect,
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
          {results.length} entit{results.length === 1 ? "y" : "ies"}
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {results.map((result) => {
          const dockets = getDistinctDockets(result);
          const isInactive = isInactiveClearanceResult(result);
          const cardClassName = `block p-4 bg-white border rounded-lg transition-colors ${config.itemClass} focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2`;
          const content = (
            <>
              <p className="mb-3 text-lg font-semibold">{result.respondentName}</p>
              <div className="mb-3 rounded-md border bg-muted/30 p-2.5 text-sm">
                <p className="mb-1 font-medium text-foreground">Associated dockets</p>
                <ul className="space-y-1 text-muted-foreground">
                  {dockets.map((caseResult) => (
                    <li key={caseResult.caseId}>{caseResult.docketNumber}</li>
                  ))}
                </ul>
              </div>
              <span className="text-sm font-medium text-primary">View person details</span>
            </>
          );

          if (isInactive) {
            return (
              <button
                key={result.id}
                type="button"
                onClick={() => onInactiveSelect?.(result)}
                className={`${cardClassName} w-full text-left`}
              >
                {content}
              </button>
            );
          }

          return (
            <Link
              key={result.id}
              href={result.participantKind === "ORGANIZATION" && result.organizationId ? `/organizations/${result.organizationId}` : `/persons/${result.personId}`}
              className={cardClassName}
            >
              {content}
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
  const [selectedInactiveResult, setSelectedInactiveResult] =
    useState<ClearanceSearchResult | null>(null);
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

    return excludeResultsByEntity(
      roleFilteredResults,
      getResultEntityKeys(filteredSearchResults),
    );
  }, [filteredSearchResults, participantRoleFilter, possibleMatchResults]);
  const filteredPhoneticMatchResults = useMemo(() => {
    const roleFilteredResults = filterResultsByParticipantRole(
      phoneticMatchResults,
      participantRoleFilter,
    );
    const previouslyShownEntityKeys = new Set([
      ...getResultEntityKeys(filteredSearchResults),
      ...getResultEntityKeys(filteredPossibleMatchResults),
    ]);

    return excludeResultsByEntity(roleFilteredResults, previouslyShownEntityKeys);
  }, [
    filteredPossibleMatchResults,
    filteredSearchResults,
    participantRoleFilter,
    phoneticMatchResults,
  ]);
  const activeSearchResults = useMemo(() => activeClearanceResults(filteredSearchResults), [filteredSearchResults]);
  const inactiveSearchResults = useMemo(() => inactiveClearanceResults(filteredSearchResults), [filteredSearchResults]);
  const activePossibleMatchResults = useMemo(() => activeClearanceResults(filteredPossibleMatchResults), [filteredPossibleMatchResults]);
  const inactivePossibleMatchResults = useMemo(() => inactiveClearanceResults(filteredPossibleMatchResults), [filteredPossibleMatchResults]);
  const activePhoneticMatchResults = useMemo(() => activeClearanceResults(filteredPhoneticMatchResults), [filteredPhoneticMatchResults]);
  const inactivePhoneticMatchResults = useMemo(() => inactiveClearanceResults(filteredPhoneticMatchResults), [filteredPhoneticMatchResults]);
  const groupedResults = useMemo(
    () => groupResults(activeSearchResults),
    [activeSearchResults],
  );
  const groupedInactiveResults = useMemo(
    () => groupResults(inactiveSearchResults),
    [inactiveSearchResults],
  );
  const groupedPossibleMatchResults = useMemo(
    () => groupResults(activePossibleMatchResults),
    [activePossibleMatchResults],
  );
  const groupedInactivePossibleMatchResults = useMemo(
    () => groupResults(inactivePossibleMatchResults),
    [inactivePossibleMatchResults],
  );
  const groupedPhoneticMatchResults = useMemo(
    () => groupResults(activePhoneticMatchResults),
    [activePhoneticMatchResults],
  );
  const groupedInactivePhoneticMatchResults = useMemo(
    () => groupResults(inactivePhoneticMatchResults),
    [inactivePhoneticMatchResults],
  );
  const hasInactiveMatches = inactiveSearchResults.length > 0 || inactivePossibleMatchResults.length > 0 || inactivePhoneticMatchResults.length > 0;
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
    <div className="mx-auto w-full max-w-[900px] space-y-6 p-8">
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
              <div className={hasInactiveMatches ? "grid gap-6 lg:grid-cols-2" : "space-y-6"}>
                <section className="space-y-6">
                  {hasInactiveMatches ? <h2 className="text-2xl font-semibold">Active / Official Matches</h2> : null}
                  <ResultGroup label="High" results={groupedResults.High} />
                  <ResultGroup label="Medium" results={groupedResults.Medium} />
                  <ResultGroup label="Low" results={groupedResults.Low} />
                </section>
                {hasInactiveMatches ? (
                  <section className="space-y-6">
                    <h2 className="text-2xl font-semibold">Voided / Corrected / Inactive Matches</h2>
                    <ResultGroup label="High" results={groupedInactiveResults.High} onInactiveSelect={setSelectedInactiveResult} />
                    <ResultGroup label="Medium" results={groupedInactiveResults.Medium} onInactiveSelect={setSelectedInactiveResult} />
                    <ResultGroup label="Low" results={groupedInactiveResults.Low} onInactiveSelect={setSelectedInactiveResult} />
                  </section>
                ) : null}
              </div>

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
                    <div className={inactivePossibleMatchResults.length ? "grid gap-6 lg:grid-cols-2" : "space-y-6"}>
                      <section className="space-y-6">
                        {inactivePossibleMatchResults.length ? <h3 className="text-xl font-semibold">Active / Official Matches</h3> : null}
                        <ResultGroup label="High" results={groupedPossibleMatchResults.High} />
                        <ResultGroup label="Medium" results={groupedPossibleMatchResults.Medium} />
                        <ResultGroup label="Low" results={groupedPossibleMatchResults.Low} />
                      </section>
                      {inactivePossibleMatchResults.length ? (
                        <section className="space-y-6">
                          <h3 className="text-xl font-semibold">Voided / Corrected / Inactive Matches</h3>
                          <ResultGroup label="High" results={groupedInactivePossibleMatchResults.High} onInactiveSelect={setSelectedInactiveResult} />
                          <ResultGroup label="Medium" results={groupedInactivePossibleMatchResults.Medium} onInactiveSelect={setSelectedInactiveResult} />
                          <ResultGroup label="Low" results={groupedInactivePossibleMatchResults.Low} onInactiveSelect={setSelectedInactiveResult} />
                        </section>
                      ) : null}
                    </div>
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
                    <div className={inactivePhoneticMatchResults.length ? "grid gap-6 lg:grid-cols-2" : "space-y-6"}>
                      <section className="space-y-6">
                        {inactivePhoneticMatchResults.length ? <h3 className="text-xl font-semibold">Active / Official Matches</h3> : null}
                        <ResultGroup label="High" results={groupedPhoneticMatchResults.High} confidenceTone="phonetic" />
                        <ResultGroup label="Medium" results={groupedPhoneticMatchResults.Medium} confidenceTone="phonetic" />
                        <ResultGroup label="Low" results={groupedPhoneticMatchResults.Low} confidenceTone="phonetic" />
                      </section>
                      {inactivePhoneticMatchResults.length ? (
                        <section className="space-y-6">
                          <h3 className="text-xl font-semibold">Voided / Corrected / Inactive Matches</h3>
                          <ResultGroup label="High" results={groupedInactivePhoneticMatchResults.High} confidenceTone="phonetic" onInactiveSelect={setSelectedInactiveResult} />
                          <ResultGroup label="Medium" results={groupedInactivePhoneticMatchResults.Medium} confidenceTone="phonetic" onInactiveSelect={setSelectedInactiveResult} />
                          <ResultGroup label="Low" results={groupedInactivePhoneticMatchResults.Low} confidenceTone="phonetic" onInactiveSelect={setSelectedInactiveResult} />
                        </section>
                      ) : null}
                    </div>
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

      <Dialog open={Boolean(selectedInactiveResult)} onOpenChange={(open) => !open && setSelectedInactiveResult(null)}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-4xl">
          <DialogHeader>
            <DialogTitle>Inactive / Corrected Match Details</DialogTitle>
            <DialogDescription>Old voided details are shown here only for correction-history review.</DialogDescription>
          </DialogHeader>
          {selectedInactiveResult ? (
            <div className="space-y-4 text-sm">
              <div className="flex flex-wrap items-center gap-2">
                <Badge variant="destructive">{getInactiveBadgeLabel(selectedInactiveResult)}</Badge>
                <Badge variant="outline">Docket: {selectedInactiveResult.docketNumber}</Badge>
                <Badge variant="outline">{selectedInactiveResult.roleLabel}</Badge>
              </div>
              <div className="grid gap-3 md:grid-cols-2">
                <div className="rounded-lg border p-3">
                  <p className="font-medium">Old person details</p>
                  <pre className="mt-2 overflow-auto rounded-md bg-muted p-2 text-xs">
                    {JSON.stringify(getSnapshotValue(selectedInactiveResult.oldSnapshotJson, "person") ?? getSnapshotValue(selectedInactiveResult.oldSnapshotJson, "organization") ?? { full_name: selectedInactiveResult.respondentName, person_id: selectedInactiveResult.personId, organization_id: selectedInactiveResult.organizationId }, null, 2)}
                  </pre>
                </div>
                <div className="rounded-lg border p-3">
                  <p className="font-medium">New corrected person details</p>
                  <pre className="mt-2 overflow-auto rounded-md bg-muted p-2 text-xs">
                    {JSON.stringify(getSnapshotValue(selectedInactiveResult.newSnapshotJson, "person") ?? getSnapshotValue(selectedInactiveResult.newSnapshotJson, "organization") ?? { active_person_id: selectedInactiveResult.activePersonId }, null, 2)}
                  </pre>
                </div>
                <div className="rounded-lg border p-3">
                  <p className="font-medium">Old attributes</p>
                  <pre className="mt-2 overflow-auto rounded-md bg-muted p-2 text-xs">
                    {JSON.stringify(getSnapshotValue(selectedInactiveResult.oldSnapshotJson, "attributes"), null, 2)}
                  </pre>
                </div>
                <div className="rounded-lg border p-3">
                  <p className="font-medium">New attributes</p>
                  <pre className="mt-2 overflow-auto rounded-md bg-muted p-2 text-xs">
                    {JSON.stringify(getSnapshotValue(selectedInactiveResult.newSnapshotJson, "attributes"), null, 2)}
                  </pre>
                </div>
              </div>
              <div className="rounded-lg border p-3">
                <p><span className="font-medium">Correction reason:</span> {selectedInactiveResult.correctionReason ?? "—"}</p>
                <p><span className="font-medium">Corrected by:</span> {selectedInactiveResult.correctedBy ?? "—"}</p>
                <p><span className="font-medium">Corrected date/time:</span> {formatCorrectionDate(selectedInactiveResult.correctedAt)}</p>
              </div>
            </div>
          ) : null}
          <DialogFooter>
            <Button type="button" onClick={() => setSelectedInactiveResult(null)}>Close</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
