'use client';

import { useState, useMemo } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { Badge } from '@/components/ui/badge';
import {
  CheckCircle,
  Search as SearchIcon,
  AlertCircle,
  Zap,
  Users,
  FileText,
} from 'lucide-react';

interface SearchResult {
  id: string;
  docketNumber: string;
  caseNumber: string;
  respondentName: string;
  respondentAliases: string[];
  status: string;
  lastUpdated: string;
  confidenceScore: number;
  matchDetails: string;
  matchType: 'exact' | 'alias' | 'similar';
  casesCount: number;
}

// Fuzzy search with multiple matching strategies
function calculateFuzzyMatch(search: string, text: string): number {
  const s = search.toLowerCase().trim();
  const t = text.toLowerCase();

  if (t === s) return 1; // Exact match
  if (t.includes(s)) return 0.95; // Substring match

  let score = 0;
  let textIndex = 0;

  for (let i = 0; i < s.length && textIndex < t.length; i++) {
    const charIndex = t.indexOf(s[i], textIndex);
    if (charIndex >= 0) {
      score += 1 / (charIndex - textIndex + 1);
      textIndex = charIndex + 1;
    }
  }

  return score > 0 ? Math.min(score / s.length, 0.99) : 0;
}

export default function ClearanceSearch() {
  const [searchQuery, setSearchQuery] = useState('');
  const [verifiedResults, setVerifiedResults] = useState<SearchResult[]>([]);
  const [showVerificationPanel, setShowVerificationPanel] = useState(false);
  const [selectedResult, setSelectedResult] = useState<SearchResult | null>(null);
  const [verificationNotes, setVerificationNotes] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Perform comprehensive fuzzy search with multiple result types
  const searchResults = useMemo(() => {
    if (!searchQuery.trim()) return [];

    const results: SearchResult[] = [];
    const resultMap = new Map<string, SearchResult>();

    dockets.forEach((docket) => {
      docket.cases.forEach((caseDetail) => {
        caseDetail.respondents.forEach((respondent) => {
          const fullName = `${respondent.firstName} ${respondent.middleName} ${respondent.lastName}`.trim();
          let maxScore = 0;
          let matchDetails = '';
          let matchType: 'exact' | 'alias' | 'similar' = 'similar';

          // Search in full name
          const nameScore = calculateFuzzyMatch(searchQuery, fullName);
          if (nameScore > maxScore) {
            maxScore = nameScore;
            matchDetails = `Name: ${fullName}`;
            matchType = nameScore === 1 ? 'exact' : 'similar';
          }

          // Search in aliases
          respondent.aliases.forEach((alias) => {
            const aliasScore = calculateFuzzyMatch(searchQuery, alias);
            if (aliasScore > maxScore) {
              maxScore = aliasScore;
              matchDetails = `Alias: ${alias}`;
              matchType = aliasScore === 1 ? 'exact' : 'alias';
            }
          });

          if (maxScore > 0.4) {
            const resultKey = `${respondent.id}`;
            const existingResult = resultMap.get(resultKey);

            if (existingResult) {
              // Update if we found a better match, or add to case count
              if (maxScore > existingResult.confidenceScore) {
                existingResult.confidenceScore = Math.round(maxScore * 100);
                existingResult.matchDetails = matchDetails;
                existingResult.matchType = matchType;
              }
              existingResult.casesCount += 1;
            } else {
              const newResult: SearchResult = {
                id: `${docket.id}-${caseDetail.id}-${respondent.id}`,
                docketNumber: docket.docketNumber,
                caseNumber: caseDetail.caseNumber,
                respondentName: fullName,
                respondentAliases: respondent.aliases,
                status: caseDetail.status,
                lastUpdated: caseDetail.statusHistory[caseDetail.statusHistory.length - 1].date,
                confidenceScore: Math.round(maxScore * 100),
                matchDetails,
                matchType,
                casesCount: 1,
              };
              resultMap.set(resultKey, newResult);
            }
          }
        });
      });
    });

    // Convert to array and sort by confidence
    return Array.from(resultMap.values()).sort((a, b) => b.confidenceScore - a.confidenceScore);
  }, [searchQuery]);

  // Group results by confidence level
  const groupedResults = useMemo(() => {
    const groups: Record<string, SearchResult[]> = {
      Exact: [],
      High: [],
      Medium: [],
    };

    searchResults.forEach((result) => {
      if (result.matchType === 'exact') {
        groups.Exact.push(result);
      } else if (result.confidenceScore >= 80) {
        groups.High.push(result);
      } else if (result.confidenceScore >= 60) {
        groups.Medium.push(result);
      }
    });

    return groups;
  }, [searchResults]);

  const handleVerifyResult = (result: SearchResult) => {
    setSelectedResult(result);
    setShowVerificationPanel(true);
  };

  const handleConfirmVerification = () => {
    if (!selectedResult) return;

    setVerifiedResults([...verifiedResults, selectedResult]);
    setSuccessMessage(`Record verified: ${selectedResult.respondentName}`);
    setShowVerificationPanel(false);
    setSelectedResult(null);
    setVerificationNotes('');
    setTimeout(() => setSuccessMessage(''), 4000);
  };

  const handleRemoveVerified = (id: string) => {
    setVerifiedResults(verifiedResults.filter((r) => r.id !== id));
  };

  const totalExactMatches = groupedResults.Exact.length;
  const totalHighMatches = groupedResults.High.length;
  const totalMediumMatches = groupedResults.Medium.length;
  const hasResults = searchQuery.trim() && searchResults.length > 0;

  return (
    <div className="p-8 bg-gradient-to-br from-slate-50 to-slate-100 min-h-screen">
      <div className="max-w-6xl mx-auto space-y-6">
        {/* Header Section */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="p-2 bg-primary rounded-lg">
              <SearchIcon className="w-6 h-6 text-white" />
            </div>
            <h1 className="text-4xl font-bold text-slate-900">Clearance Record Search</h1>
          </div>
          <p className="text-lg text-slate-600 ml-11">
            Advanced search system with fuzzy matching to locate individuals by name, aliases, and similar variations across all docket records.
          </p>
        </div>

        {/* Success Message */}
        {successMessage && (
          <div className="bg-emerald-50 border-l-4 border-emerald-500 rounded-lg p-4 flex items-center gap-3 shadow-sm">
            <CheckCircle className="w-6 h-6 text-emerald-600 flex-shrink-0" />
            <div>
              <p className="font-semibold text-emerald-900">{successMessage}</p>
            </div>
          </div>
        )}

        {/* Search Form */}
        <Card className="border-slate-200 shadow-md">
          <CardHeader className="bg-slate-50 border-b border-slate-200">
            <CardTitle className="flex items-center gap-2">
              <Zap className="w-5 h-5 text-amber-500" />
              Search Records
            </CardTitle>
            <CardDescription>
              Enter any name, alias, or partial name to search across all records
            </CardDescription>
          </CardHeader>
          <CardContent className="p-6">
            <div className="space-y-4">
              <div>
                <Label htmlFor="search-query" className="text-base font-semibold text-slate-900">
                  Name or Alias
                </Label>
                <div className="relative mt-2">
                  <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
                  <Input
                    id="search-query"
                    placeholder="e.g., 'Carlos Santos', 'Carlito', 'CR Santos'..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-12 h-12 text-base border-slate-300 focus:border-primary focus:ring-primary"
                  />
                </div>
                <div className="mt-3 grid grid-cols-3 gap-4 text-sm">
                  <div className="bg-blue-50 p-3 rounded border border-blue-200">
                    <div className="font-semibold text-blue-900">Exact Matches</div>
                    <div className="text-2xl font-bold text-blue-600">{totalExactMatches}</div>
                  </div>
                  <div className="bg-green-50 p-3 rounded border border-green-200">
                    <div className="font-semibold text-green-900">High Confidence</div>
                    <div className="text-2xl font-bold text-green-600">{totalHighMatches}</div>
                  </div>
                  <div className="bg-amber-50 p-3 rounded border border-amber-200">
                    <div className="font-semibold text-amber-900">Medium Confidence</div>
                    <div className="text-2xl font-bold text-amber-600">{totalMediumMatches}</div>
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Search Results */}
        {hasResults && (
          <div className="space-y-6">
            {/* Exact Matches */}
            {groupedResults.Exact.length > 0 && (
              <Card className="border-2 border-blue-300 shadow-lg bg-gradient-to-r from-blue-50 to-blue-100/50">
                <CardHeader className="pb-3">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Badge className="bg-blue-600 text-lg px-3 py-1">EXACT MATCH</Badge>
                      <span className="text-sm font-semibold text-slate-600">
                        {groupedResults.Exact.length} record{groupedResults.Exact.length === 1 ? '' : 's'}
                      </span>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  {groupedResults.Exact.map((result) => (
                    <div
                      key={result.id}
                      className="p-4 bg-white border-2 border-blue-300 rounded-lg hover:shadow-md transition-shadow"
                    >
                      <div className="flex items-start justify-between mb-3">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-1">
                            <p className="font-bold text-lg text-slate-900">{result.respondentName}</p>
                            <Badge className="bg-blue-600">100%</Badge>
                          </div>
                          <p className="text-sm text-slate-600">
                            Docket: <span className="font-mono font-semibold">{result.docketNumber}</span> |
                            Case: <span className="font-mono font-semibold">{result.caseNumber}</span>
                          </p>
                        </div>
                      </div>

                      <div className="grid grid-cols-4 gap-3 mb-3 text-sm">
                        <div className="bg-slate-50 p-2 rounded">
                          <div className="text-xs text-slate-600">Status</div>
                          <StatusBadge status={result.status as any} size="sm" />
                        </div>
                        <div className="bg-slate-50 p-2 rounded">
                          <div className="text-xs text-slate-600">Related Cases</div>
                          <div className="font-bold text-slate-900 flex items-center gap-1">
                            <FileText className="w-4 h-4" />
                            {result.casesCount}
                          </div>
                        </div>
                        <div className="bg-slate-50 p-2 rounded">
                          <div className="text-xs text-slate-600">Aliases</div>
                          <div className="font-bold text-slate-900 flex items-center gap-1">
                            <Users className="w-4 h-4" />
                            {result.respondentAliases.length}
                          </div>
                        </div>
                        <div className="bg-slate-50 p-2 rounded">
                          <div className="text-xs text-slate-600">Last Updated</div>
                          <div className="font-mono text-xs font-semibold text-slate-900">{result.lastUpdated}</div>
                        </div>
                      </div>

                      {result.respondentAliases.length > 0 && (
                        <div className="mb-3 p-2 bg-blue-50 border border-blue-200 rounded text-sm">
                          <div className="text-xs font-semibold text-blue-900 mb-1">Aliases on File:</div>
                          <div className="flex flex-wrap gap-1">
                            {result.respondentAliases.slice(0, 4).map((alias, i) => (
                              <Badge key={i} variant="outline" className="text-xs bg-white">
                                {alias}
                              </Badge>
                            ))}
                            {result.respondentAliases.length > 4 && (
                              <Badge variant="outline" className="text-xs bg-white">
                                +{result.respondentAliases.length - 4} more
                              </Badge>
                            )}
                          </div>
                        </div>
                      )}

                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          onClick={() => handleVerifyResult(result)}
                          className="flex-1 bg-blue-600 hover:bg-blue-700"
                        >
                          <CheckCircle className="w-4 h-4 mr-2" />
                          Verify Record
                        </Button>
                        <Button size="sm" variant="outline" className="flex-1">
                          View Details
                        </Button>
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}

            {/* High Confidence Matches */}
            {groupedResults.High.length > 0 && (
              <Card className="border-2 border-green-300 shadow-lg bg-gradient-to-r from-green-50 to-green-100/50">
                <CardHeader className="pb-3">
                  <div className="flex items-center gap-2">
                    <Badge className="bg-green-600 text-lg px-3 py-1">HIGH CONFIDENCE</Badge>
                    <span className="text-sm font-semibold text-slate-600">
                      {groupedResults.High.length} record{groupedResults.High.length === 1 ? '' : 's'} (80%+)
                    </span>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  {groupedResults.High.map((result) => (
                    <div
                      key={result.id}
                      className="p-4 bg-white border border-green-200 rounded-lg hover:shadow-md transition-shadow"
                    >
                      <div className="flex items-start justify-between mb-2">
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <p className="font-semibold text-slate-900">{result.respondentName}</p>
                            <Badge className="bg-green-600">{result.confidenceScore}%</Badge>
                          </div>
                          <p className="text-xs text-slate-600">
                            {result.docketNumber} | {result.caseNumber}
                          </p>
                        </div>
                        <StatusBadge status={result.status as any} size="sm" />
                      </div>
                      <p className="text-sm text-slate-600 mb-2">{result.matchDetails}</p>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          onClick={() => handleVerifyResult(result)}
                          className="bg-green-600 hover:bg-green-700"
                        >
                          Verify
                        </Button>
                        <Button size="sm" variant="outline">
                          View
                        </Button>
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}

            {/* Medium Confidence Matches */}
            {groupedResults.Medium.length > 0 && (
              <Card className="border-2 border-amber-300 shadow-lg bg-gradient-to-r from-amber-50 to-amber-100/50">
                <CardHeader className="pb-3">
                  <div className="flex items-center gap-2">
                    <Badge className="bg-amber-600 text-lg px-3 py-1">MEDIUM CONFIDENCE</Badge>
                    <span className="text-sm font-semibold text-slate-600">
                      {groupedResults.Medium.length} record{groupedResults.Medium.length === 1 ? '' : 's'} (60-79%)
                    </span>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  {groupedResults.Medium.map((result) => (
                    <div key={result.id} className="p-4 bg-white border border-amber-200 rounded-lg hover:shadow-sm transition-shadow">
                      <div className="flex items-start justify-between mb-2">
                        <div>
                          <p className="font-semibold text-sm text-slate-900">{result.respondentName}</p>
                          <p className="text-xs text-slate-600">
                            {result.docketNumber} | {result.caseNumber}
                          </p>
                        </div>
                        <Badge className="bg-amber-600">{result.confidenceScore}%</Badge>
                      </div>
                      <p className="text-xs text-slate-600 mb-2">{result.matchDetails}</p>
                      <Button size="sm" variant="outline" onClick={() => handleVerifyResult(result)}>
                        Review
                      </Button>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}
          </div>
        )}

        {/* No Results Message */}
        {searchQuery && !hasResults && (
          <Card className="border-amber-300 bg-amber-50">
            <CardContent className="flex items-center gap-3 py-6">
              <AlertCircle className="w-6 h-6 text-amber-600 flex-shrink-0" />
              <div>
                <p className="font-semibold text-amber-900">No records found</p>
                <p className="text-sm text-amber-700">
                  No matches found for &quot;{searchQuery}&quot;. Try a different name or alias.
                </p>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Verification Panel */}
        {showVerificationPanel && selectedResult && (
          <Card className="border-2 border-slate-400 shadow-xl bg-gradient-to-br from-slate-50 to-slate-100">
            <CardHeader className="bg-slate-900 text-white">
              <CardTitle className="flex items-center gap-2">
                <CheckCircle className="w-5 h-5" />
                Record Verification Form
              </CardTitle>
            </CardHeader>
            <CardContent className="p-6 space-y-6">
              {/* Record Summary */}
              <div className="grid grid-cols-2 gap-4 p-4 bg-white border border-slate-300 rounded-lg">
                <div>
                  <div className="text-xs font-semibold text-slate-600 mb-1">SUBJECT NAME</div>
                  <p className="font-bold text-lg text-slate-900">{selectedResult.respondentName}</p>
                </div>
                <div>
                  <div className="text-xs font-semibold text-slate-600 mb-1">CONFIDENCE</div>
                  <p className="font-bold text-lg text-slate-900">{selectedResult.confidenceScore}%</p>
                </div>
                <div>
                  <div className="text-xs font-semibold text-slate-600 mb-1">DOCKET NUMBER</div>
                  <p className="font-mono text-sm font-semibold text-slate-900">{selectedResult.docketNumber}</p>
                </div>
                <div>
                  <div className="text-xs font-semibold text-slate-600 mb-1">CASE STATUS</div>
                  <StatusBadge status={selectedResult.status as any} size="sm" />
                </div>
              </div>

              {/* Verification Notes */}
              <div>
                <Label htmlFor="verification-notes" className="text-base font-semibold text-slate-900">
                  Verification Notes
                </Label>
                <Textarea
                  id="verification-notes"
                  placeholder="Document any relevant findings, confirmations, or additional information about this record..."
                  value={verificationNotes}
                  onChange={(e) => setVerificationNotes(e.target.value)}
                  rows={4}
                  className="mt-2 border-slate-300 focus:border-primary focus:ring-primary"
                />
                <p className="text-xs text-slate-600 mt-1">
                  Verification will be recorded in the system log for audit purposes.
                </p>
              </div>

              {/* Action Buttons */}
              <div className="grid grid-cols-2 gap-3">
                <Button
                  onClick={handleConfirmVerification}
                  className="h-11 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                >
                  <CheckCircle className="w-5 h-5 mr-2" />
                  Confirm & Record
                </Button>
                <Button
                  onClick={() => {
                    setShowVerificationPanel(false);
                    setSelectedResult(null);
                    setVerificationNotes('');
                  }}
                  variant="outline"
                  className="h-11 font-semibold"
                >
                  Cancel
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Verified Results Summary */}
        {verifiedResults.length > 0 && (
          <Card className="border-emerald-300 shadow-lg bg-gradient-to-r from-emerald-50 to-emerald-100/50">
            <CardHeader className="bg-emerald-900 text-white">
              <CardTitle className="flex items-center gap-2">
                <CheckCircle className="w-5 h-5" />
                Verification Record
              </CardTitle>
              <CardDescription className="text-emerald-100">
                {verifiedResults.length} record{verifiedResults.length === 1 ? '' : 's'} verified in this session
              </CardDescription>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-3">
                {verifiedResults.map((result) => (
                  <div
                    key={result.id}
                    className="p-4 bg-white border-l-4 border-emerald-500 rounded flex items-start justify-between hover:shadow-md transition-shadow"
                  >
                    <div>
                      <p className="font-semibold text-slate-900">{result.respondentName}</p>
                      <p className="text-sm text-slate-600 mt-1">
                        <span className="font-mono">{result.docketNumber}</span> •{' '}
                        <span className="font-mono">{result.caseNumber}</span> • Confidence:{' '}
                        <span className="font-bold">{result.confidenceScore}%</span>
                      </p>
                    </div>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => handleRemoveVerified(result.id)}
                      className="text-slate-500 hover:text-destructive"
                    >
                      Remove
                    </Button>
                  </div>
                ))}
              </div>
              <div className="mt-4 pt-4 border-t border-slate-200 text-sm text-slate-600 text-center">
                <p>
                  Records verified at <span className="font-mono">{new Date().toLocaleTimeString()}</span>
                </p>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
