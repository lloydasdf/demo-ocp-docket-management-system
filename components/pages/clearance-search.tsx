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
import { CheckCircle, Search as SearchIcon } from 'lucide-react';

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
}

// Simple fuzzy search algorithm
function calculateFuzzyMatch(search: string, text: string): number {
  const s = search.toLowerCase();
  const t = text.toLowerCase();

  if (t === s) return 1;
  if (t.includes(s)) return 0.9;

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
  const [searchType, setSearchType] = useState<'name' | 'alias' | 'all'>('all');
  const [verifiedResults, setVerifiedResults] = useState<SearchResult[]>([]);
  const [showVerificationPanel, setShowVerificationPanel] = useState(false);
  const [selectedResult, setSelectedResult] = useState<SearchResult | null>(null);
  const [verificationNotes, setVerificationNotes] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Perform fuzzy search
  const searchResults = useMemo(() => {
    if (!searchQuery.trim()) return [];

    const results: SearchResult[] = [];

    dockets.forEach((docket) => {
      docket.cases.forEach((caseDetail) => {
        // Search in respondents
        caseDetail.respondents.forEach((respondent) => {
          let maxScore = 0;
          let matchDetails = '';

          // Search in full name
          const fullName = `${respondent.firstName} ${respondent.middleName} ${respondent.lastName}`.trim();
          const nameScore = calculateFuzzyMatch(searchQuery, fullName);
          if (nameScore > maxScore) {
            maxScore = nameScore;
            matchDetails = `Name match: ${fullName}`;
          }

          // Search in aliases
          respondent.aliases.forEach((alias) => {
            const aliasScore = calculateFuzzyMatch(searchQuery, alias);
            if (aliasScore > maxScore) {
              maxScore = aliasScore;
              matchDetails = `Alias match: ${alias}`;
            }
          });

          if (maxScore > 0.4) {
            results.push({
              id: `${docket.id}-${caseDetail.id}-${respondent.id}`,
              docketNumber: docket.docketNumber,
              caseNumber: caseDetail.caseNumber,
              respondentName: fullName,
              respondentAliases: respondent.aliases,
              status: caseDetail.status,
              lastUpdated: caseDetail.statusHistory[caseDetail.statusHistory.length - 1].date,
              confidenceScore: Math.round(maxScore * 100),
              matchDetails,
            });
          }
        });
      });
    });

    // Sort by confidence score
    return results.sort((a, b) => b.confidenceScore - a.confidenceScore);
  }, [searchQuery, searchType]);

  // Group results by confidence
  const groupedResults = useMemo(() => {
    const groups: Record<string, SearchResult[]> = {
      High: [],
      Medium: [],
      Low: [],
    };

    searchResults.forEach((result) => {
      if (result.confidenceScore >= 80) {
        groups.High.push(result);
      } else if (result.confidenceScore >= 60) {
        groups.Medium.push(result);
      } else {
        groups.Low.push(result);
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
    setSuccessMessage('Result verified and recorded');
    setShowVerificationPanel(false);
    setSelectedResult(null);
    setVerificationNotes('');
    setTimeout(() => setSuccessMessage(''), 3000);
  };

  const handleRemoveVerified = (id: string) => {
    setVerifiedResults(verifiedResults.filter((r) => r.id !== id));
  };

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Clearance Search</h1>
        <p className="text-muted-foreground mt-1">
          Advanced search with fuzzy matching to find records by name and aliases
        </p>
      </div>

      {/* Success Message */}
      {successMessage && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded flex items-center gap-2">
          <CheckCircle className="w-5 h-5" />
          {successMessage}
        </div>
      )}

      {/* Search Form */}
      <Card>
        <CardHeader>
          <CardTitle>Search Records</CardTitle>
          <CardDescription>Enter a name or alias to search across all dockets</CardDescription>
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
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10 text-lg"
              />
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              Supports partial matches and aliases. Confidence score indicates match quality.
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Search Results */}
      {searchQuery && (
        <div className="space-y-6">
          {/* High Confidence */}
          {groupedResults.High.length > 0 && (
            <Card className="border-green-200 bg-green-50/50">
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg flex items-center gap-2">
                    <Badge className="bg-green-600">High Confidence</Badge>
                    {groupedResults.High.length} result{groupedResults.High.length === 1 ? '' : 's'}
                  </CardTitle>
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                {groupedResults.High.map((result) => (
                  <div
                    key={result.id}
                    className="p-4 bg-white border border-green-200 rounded-lg hover:bg-green-50/30 transition-colors"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <p className="font-semibold text-lg">{result.respondentName}</p>
                        <p className="text-xs text-muted-foreground">
                          Case: {result.caseNumber} | Docket: {result.docketNumber}
                        </p>
                      </div>
                      <div className="text-right flex flex-col items-end gap-2">
                        <Badge className="bg-green-600 font-bold text-white">
                          {result.confidenceScore}%
                        </Badge>
                      </div>
                    </div>
                    <p className="text-sm text-muted-foreground mb-2">{result.matchDetails}</p>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <StatusBadge status={result.status as any} size="sm" />
                        {result.respondentAliases.length > 0 && (
                          <Badge variant="outline" className="text-xs">
                            {result.respondentAliases.length} alias{result.respondentAliases.length === 1 ? '' : 'es'}
                          </Badge>
                        )}
                      </div>
                      <Button
                        size="sm"
                        onClick={() => handleVerifyResult(result)}
                        className="bg-green-600 hover:bg-green-700"
                      >
                        Verify
                      </Button>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          )}

          {/* Medium Confidence */}
          {groupedResults.Medium.length > 0 && (
            <Card className="border-yellow-200 bg-yellow-50/50">
              <CardHeader className="pb-3">
                <CardTitle className="text-lg flex items-center gap-2">
                  <Badge className="bg-yellow-600">Medium Confidence</Badge>
                  {groupedResults.Medium.length} result{groupedResults.Medium.length === 1 ? '' : 's'}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                {groupedResults.Medium.map((result) => (
                  <div
                    key={result.id}
                    className="p-4 bg-white border border-yellow-200 rounded-lg hover:bg-yellow-50/30 transition-colors"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <p className="font-semibold">{result.respondentName}</p>
                        <p className="text-xs text-muted-foreground">
                          Case: {result.caseNumber} | Docket: {result.docketNumber}
                        </p>
                      </div>
                      <Badge className="bg-yellow-600 font-bold text-white">{result.confidenceScore}%</Badge>
                    </div>
                    <p className="text-sm text-muted-foreground mb-2">{result.matchDetails}</p>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <StatusBadge status={result.status as any} size="sm" />
                      </div>
                      <Button size="sm" variant="outline" onClick={() => handleVerifyResult(result)}>
                        Review
                      </Button>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          )}

          {/* Low Confidence */}
          {groupedResults.Low.length > 0 && (
            <Card className="border-gray-200 bg-gray-50/50">
              <CardHeader className="pb-3">
                <CardTitle className="text-lg flex items-center gap-2">
                  <Badge className="bg-gray-600">Low Confidence</Badge>
                  {groupedResults.Low.length} result{groupedResults.Low.length === 1 ? '' : 's'}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                {groupedResults.Low.map((result) => (
                  <div
                    key={result.id}
                    className="p-4 bg-white border border-gray-200 rounded-lg hover:bg-gray-50/30 transition-colors"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <p className="font-semibold text-sm">{result.respondentName}</p>
                        <p className="text-xs text-muted-foreground">
                          Case: {result.caseNumber} | Docket: {result.docketNumber}
                        </p>
                      </div>
                      <Badge className="bg-gray-600 font-bold text-white">{result.confidenceScore}%</Badge>
                    </div>
                    <p className="text-sm text-muted-foreground mb-2">{result.matchDetails}</p>
                  </div>
                ))}
              </CardContent>
            </Card>
          )}

          {searchResults.length === 0 && (
            <Card>
              <CardContent className="text-center py-8">
                <p className="text-muted-foreground">No records found matching "{searchQuery}"</p>
              </CardContent>
            </Card>
          )}
        </div>
      )}

      {/* Verification Panel */}
      {showVerificationPanel && selectedResult && (
        <Card className="border-blue-200 bg-blue-50/50">
          <CardHeader>
            <CardTitle>Manual Verification</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="p-4 bg-white border border-border rounded">
              <p className="font-semibold text-lg mb-1">{selectedResult.respondentName}</p>
              <p className="text-sm text-muted-foreground mb-3">
                Case: {selectedResult.caseNumber} | Docket: {selectedResult.docketNumber}
              </p>
              <StatusBadge status={selectedResult.status as any} size="sm" />
            </div>

            <div>
              <Label htmlFor="verification-notes">Verification Notes</Label>
              <Textarea
                id="verification-notes"
                placeholder="Add any notes about this verification..."
                value={verificationNotes}
                onChange={(e) => setVerificationNotes(e.target.value)}
                rows={3}
                className="mt-1"
              />
            </div>

            <div className="flex gap-2">
              <Button onClick={handleConfirmVerification} className="flex-1 bg-green-600 hover:bg-green-700">
                Confirm & Record
              </Button>
              <Button
                onClick={() => {
                  setShowVerificationPanel(false);
                  setSelectedResult(null);
                  setVerificationNotes('');
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

      {/* Verified Results */}
      {verifiedResults.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Verified Results</CardTitle>
            <CardDescription>{verifiedResults.length} record{verifiedResults.length === 1 ? '' : 's'} verified</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {verifiedResults.map((result) => (
              <div key={result.id} className="p-4 bg-green-50 border border-green-200 rounded-lg flex items-start justify-between">
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
