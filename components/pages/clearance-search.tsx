"use client";

import { useEffect, useMemo, useState } from "react";
import {
  AlertCircle,
  CheckCircle,
  Database,
  Search as SearchIcon,
} from "lucide-react";

import { StatusBadge } from "@/components/status-badge";
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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  type ClearanceSearchResult,
  type ClearanceSearchType,
  searchClearanceRecords,
} from "@/lib/supabase/queries";

const confidenceGroups = {
  High: {
    min: 80,
    cardClass: "border-green-200 bg-green-50/50",
    itemClass: "border-green-200 hover:bg-green-50/30",
    badgeClass: "bg-green-600",
  },
  Medium: {
    min: 60,
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

function formatDate(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "Unknown";
  }

  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
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
  onVerify: (result: ClearanceSearchResult) => void;
}

function ResultGroup({ label, results, onVerify }: ResultGroupProps) {
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
        {results.map((result) => (
          <div
            key={result.id}
            className={`p-4 bg-white border rounded-lg transition-colors ${config.itemClass}`}
          >
            <div className="flex items-start justify-between gap-4 mb-2">
              <div className="flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="font-semibold text-lg">
                    {result.respondentName}
                  </p>
                  <Badge variant="outline" className="text-xs">
                    {result.roleLabel}
                  </Badge>
                  <Badge variant="secondary" className="text-xs capitalize">
                    {result.matchType}
                  </Badge>
                </div>
                <p className="text-xs text-muted-foreground">
                  Case: {result.caseNumber} | Docket: {result.docketNumber} |
                  Updated: {formatDate(result.lastUpdated)}
                </p>
              </div>
              <Badge className={`${config.badgeClass} font-bold text-white`}>
                {result.confidenceScore}%
              </Badge>
            </div>
            <p className="text-sm text-muted-foreground mb-3">
              {result.matchDetails}
            </p>
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
              <Button
                size="sm"
                variant={label === "High" ? "default" : "outline"}
                onClick={() => onVerify(result)}
                className={
                  label === "High"
                    ? "bg-green-600 hover:bg-green-700"
                    : undefined
                }
              >
                {label === "High" ? "Verify" : "Review"}
              </Button>
            </div>
          </div>
        ))}
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
  const [verifiedResults, setVerifiedResults] = useState<
    ClearanceSearchResult[]
  >([]);
  const [showVerificationPanel, setShowVerificationPanel] = useState(false);
  const [selectedResult, setSelectedResult] =
    useState<ClearanceSearchResult | null>(null);
  const [verificationNotes, setVerificationNotes] = useState("");
  const [successMessage, setSuccessMessage] = useState("");

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
        searchType,
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
  }, [searchQuery, searchType]);

  const groupedResults = useMemo(
    () => groupResults(searchResults),
    [searchResults],
  );

  const handleVerifyResult = (result: ClearanceSearchResult) => {
    setSelectedResult(result);
    setShowVerificationPanel(true);
  };

  const handleConfirmVerification = () => {
    if (!selectedResult) return;

    setVerifiedResults((current) => {
      if (current.some((result) => result.id === selectedResult.id)) {
        return current;
      }

      return [...current, selectedResult];
    });
    setSuccessMessage("Result verified and recorded for this session");
    setShowVerificationPanel(false);
    setSelectedResult(null);
    setVerificationNotes("");
    setTimeout(() => setSuccessMessage(""), 3000);
  };

  const handleRemoveVerified = (id: string) => {
    setVerifiedResults(verifiedResults.filter((result) => result.id !== id));
  };

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
        <p className="text-muted-foreground mt-1">
          Searches live Supabase PostgreSQL records using pg_trgm similarity,
          alias matching, and phonetic fuzzy matching.
        </p>
      </div>

      {successMessage && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded flex items-center gap-2">
          <CheckCircle className="w-5 h-5" />
          {successMessage}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Search Records</CardTitle>
          <CardDescription>
            Enter a name or alias to search respondent and participant records
            across all live dockets.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
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
              The database ranks exact, alias, trigram-similar, and phonetic
              matches. Confidence score indicates match quality.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            {(["all", "name", "alias"] as const).map((type) => (
              <Button
                key={type}
                type="button"
                variant={searchType === type ? "default" : "outline"}
                size="sm"
                onClick={() => setSearchType(type)}
                className="capitalize"
              >
                {type === "all" ? "Names + aliases" : `${type} only`}
              </Button>
            ))}
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
              have the <code>search_clearance_records</code> RPC that powers
              the live fuzzy search. Apply
              <code> supabase/migrations/20260511000000_clearance_search.sql</code>,
              which enables pg_trgm/fuzzystrmatch and creates that function.
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
              <ResultGroup
                label="High"
                results={groupedResults.High}
                onVerify={handleVerifyResult}
              />
              <ResultGroup
                label="Medium"
                results={groupedResults.Medium}
                onVerify={handleVerifyResult}
              />
              <ResultGroup
                label="Low"
                results={groupedResults.Low}
                onVerify={handleVerifyResult}
              />

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

      {showVerificationPanel && selectedResult && (
        <Card className="border-blue-200 bg-blue-50/50">
          <CardHeader>
            <CardTitle>Manual Verification</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="p-4 bg-white border border-border rounded">
              <p className="font-semibold text-lg mb-1">
                {selectedResult.respondentName}
              </p>
              <p className="text-sm text-muted-foreground mb-3">
                Case: {selectedResult.caseNumber} | Docket:{" "}
                {selectedResult.docketNumber} | Match:{" "}
                {selectedResult.confidenceScore}%
              </p>
              <StatusBadge
                status={normalizeStatusForBadge(selectedResult.status) as any}
                size="sm"
              />
            </div>

            <div>
              <Label htmlFor="verification-notes">Verification Notes</Label>
              <Textarea
                id="verification-notes"
                placeholder="Add any notes about this verification..."
                value={verificationNotes}
                onChange={(event) => setVerificationNotes(event.target.value)}
                rows={3}
                className="mt-1"
              />
            </div>

            <div className="flex gap-2">
              <Button
                onClick={handleConfirmVerification}
                className="flex-1 bg-green-600 hover:bg-green-700"
              >
                Confirm & Record
              </Button>
              <Button
                onClick={() => {
                  setShowVerificationPanel(false);
                  setSelectedResult(null);
                  setVerificationNotes("");
                }}
                variant="outline"
                className="flex-1"
              >
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {verifiedResults.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Verified Results</CardTitle>
            <CardDescription>
              {verifiedResults.length} record
              {verifiedResults.length === 1 ? "" : "s"} verified in this review
              session
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {verifiedResults.map((result) => (
              <div
                key={result.id}
                className="p-4 bg-green-50 border border-green-200 rounded-lg flex items-start justify-between"
              >
                <div>
                  <p className="font-semibold">{result.respondentName}</p>
                  <p className="text-sm text-muted-foreground">
                    Case: {result.caseNumber} | {result.matchDetails}
                  </p>
                </div>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => handleRemoveVerified(result.id)}
                  className="text-destructive"
                >
                  Remove
                </Button>
              </div>
            ))}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
