/**
 * CLEARANCE SEARCH STAFF REVIEW WORKFLOW
 * 
 * Provides structured review process for clearance searches.
 * Captures staff decisions with proper wording (no "criminal record" language).
 * 
 * Uses careful terminology:
 * - "matched docket record" not "criminal record found"
 * - "possible match" for uncertain results
 * - "requires manual verification" for supervisor review
 */

'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { CheckCircle2, AlertCircle, FileText, Clock } from 'lucide-react';
import { useState } from 'react';

interface SearchMatch {
  docketNumber: string;
  respondentName: string;
  matchType: 'exact' | 'alias' | 'variant' | 'fuzzy' | 'phonetic';
  confidence: number;
  caseStatus: string;
}

interface ClearanceReviewWorkflowProps {
  searchQuery: string;
  searchDate: string;
  matches: SearchMatch[];
  onConfirm: (decision: ReviewDecision) => void;
  onGenerateDraft: (decision: ReviewDecision) => void;
}

export interface ReviewDecision {
  decision: 'no_match' | 'possible_match' | 'matched_record';
  notes: string;
  supervisorReviewRequired: boolean;
  reviewedBy: string;
  reviewDate: string;
}

export function ClearanceReviewWorkflow({
  searchQuery,
  searchDate,
  matches,
  onConfirm,
  onGenerateDraft
}: ClearanceReviewWorkflowProps) {
  const [decision, setDecision] = useState<'no_match' | 'possible_match' | 'matched_record'>('no_match');
  const [notes, setNotes] = useState('');
  const [reviewedBy, setReviewedBy] = useState('');
  const [supervisorRequired, setSupervisorRequired] = useState(false);

  const hasExactMatches = matches.some(m => m.matchType === 'exact');
  const hasHighConfidenceMatches = matches.some(m => m.confidence >= 0.85);

  const handleConfirm = () => {
    const reviewDecision: ReviewDecision = {
      decision,
      notes,
      supervisorReviewRequired: supervisorRequired || decision === 'matched_record',
      reviewedBy,
      reviewDate: new Date().toISOString()
    };
    onConfirm(reviewDecision);
  };

  const handleGenerateDraft = () => {
    const reviewDecision: ReviewDecision = {
      decision,
      notes,
      supervisorReviewRequired: supervisorRequired || decision === 'matched_record',
      reviewedBy,
      reviewDate: new Date().toISOString()
    };
    onGenerateDraft(reviewDecision);
  };

  return (
    <div className="space-y-6">
      {/* SEARCH SUMMARY */}
      <Card className="border-primary/20">
        <CardHeader className="pb-3">
          <CardTitle className="text-lg">Clearance Search Summary</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 bg-muted/30 rounded-lg border border-border">
              <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Search Query</p>
              <p className="font-mono font-semibold text-lg">{searchQuery}</p>
            </div>
            <div className="p-4 bg-muted/30 rounded-lg border border-border">
              <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Search Date</p>
              <p className="font-semibold">{new Date(searchDate).toLocaleDateString()}</p>
            </div>
            <div className="p-4 bg-muted/30 rounded-lg border border-border">
              <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Total Matches</p>
              <p className="font-semibold text-lg">{matches.length} record(s)</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* MATCHES REVIEW */}
      {matches.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Possible Matches Reviewed</CardTitle>
            <CardDescription>Staff confirms review of the following records</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {matches.map((match, i) => (
                <div
                  key={i}
                  className="p-4 border border-border rounded-lg hover:border-primary/50 transition-colors"
                >
                  <div className="flex items-start justify-between gap-4 mb-2">
                    <div>
                      <p className="font-mono font-semibold text-primary">{match.docketNumber}</p>
                      <p className="font-medium">{match.respondentName}</p>
                    </div>
                    <div className="text-right">
                      <Badge variant="outline" className="mb-1 block">
                        {(match.confidence * 100).toFixed(0)}% confidence
                      </Badge>
                      <Badge variant="secondary" className="text-xs">
                        {match.matchType === 'exact' && 'Exact Match'}
                        {match.matchType === 'alias' && 'Alias Match'}
                        {match.matchType === 'variant' && 'Name Variant'}
                        {match.matchType === 'fuzzy' && 'Similar Name'}
                        {match.matchType === 'phonetic' && 'Sound-alike Name'}
                      </Badge>
                    </div>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    Case Status: {match.caseStatus}
                  </p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* DECISION SELECTION */}
      <Card className="border-2 border-primary/20">
        <CardHeader>
          <CardTitle className="text-base">Staff Review Decision</CardTitle>
          <CardDescription>Select the appropriate decision based on search results and review</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <RadioGroup value={decision} onValueChange={(v) => setDecision(v as any)}>
            {/* OPTION 1: No Match */}
            <div className="p-4 border border-border rounded-lg hover:border-primary/50 cursor-pointer transition-colors">
              <div className="flex items-start gap-3">
                <RadioGroupItem value="no_match" id="no_match" className="mt-1" />
                <label htmlFor="no_match" className="flex-1 cursor-pointer">
                  <p className="font-semibold flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-green-600" />
                    No Matching Docket Record Found
                  </p>
                  <p className="text-sm text-muted-foreground mt-1">
                    Search query did not match any existing docket records in the system. Clearance is confirmed.
                  </p>
                </label>
              </div>
            </div>

            {/* OPTION 2: Possible Match */}
            <div className="p-4 border border-border rounded-lg hover:border-primary/50 cursor-pointer transition-colors">
              <div className="flex items-start gap-3">
                <RadioGroupItem value="possible_match" id="possible_match" className="mt-1" />
                <label htmlFor="possible_match" className="flex-1 cursor-pointer">
                  <p className="font-semibold flex items-center gap-2">
                    <AlertCircle className="w-4 h-4 text-amber-600" />
                    Possible Match, Requires Manual Verification
                  </p>
                  <p className="text-sm text-muted-foreground mt-1">
                    Some records show similarities (similar names, aliases, addresses) but are not certain matches.
                    Supervisor must review and verify before clearance is granted.
                  </p>
                </label>
              </div>
            </div>

            {/* OPTION 3: Matched Record */}
            <div className="p-4 border border-border rounded-lg hover:border-primary/50 cursor-pointer transition-colors">
              <div className="flex items-start gap-3">
                <RadioGroupItem value="matched_record" id="matched_record" className="mt-1" />
                <label htmlFor="matched_record" className="flex-1 cursor-pointer">
                  <p className="font-semibold flex items-center gap-2">
                    <FileText className="w-4 h-4 text-blue-600" />
                    Matched Docket Record for Staff Review
                  </p>
                  <p className="text-sm text-muted-foreground mt-1">
                    Search confirmed a matching docket record. Related cases and documents are available for review.
                    Supervisor review is required before clearance determination.
                  </p>
                </label>
              </div>
            </div>
          </RadioGroup>
        </CardContent>
      </Card>

      {/* SUPERVISOR REVIEW CHECKBOX */}
      {decision !== 'no_match' && (
        <Card className="bg-amber-50 border-amber-200">
          <CardContent className="pt-6">
            <div className="flex items-start gap-3">
              <input
                type="checkbox"
                id="supervisor-check"
                checked={supervisorRequired}
                onChange={(e) => setSupervisorRequired(e.target.checked)}
                className="mt-1"
              />
              <label htmlFor="supervisor-check" className="flex-1 cursor-pointer">
                <p className="font-semibold text-amber-900">
                  Flag for Supervisor Review
                </p>
                <p className="text-sm text-amber-800 mt-1">
                  Mark this search if it requires additional supervisor verification before final clearance decision.
                </p>
              </label>
            </div>
          </CardContent>
        </Card>
      )}

      {/* STAFF REVIEW NOTES */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Staff Review Notes</CardTitle>
          <CardDescription>Document any special observations or concerns</CardDescription>
        </CardHeader>
        <CardContent>
          <Textarea
            placeholder="E.g., 'Verified name matches but different age range', 'Aliases appear to match multiple persons', 'Recommend supervisor verification before clearance', etc."
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className="min-h-20"
          />
        </CardContent>
      </Card>

      {/* STAFF INFORMATION */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Review Information</CardTitle>
          <CardDescription>Who performed this review</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="reviewed-by">Reviewed By (Officer ID or Name)</Label>
            <input
              id="reviewed-by"
              type="text"
              placeholder="Officer Name or ID"
              value={reviewedBy}
              onChange={(e) => setReviewedBy(e.target.value)}
              className="mt-2 w-full px-3 py-2 border border-input rounded-md text-sm"
            />
          </div>
          <div className="p-3 bg-muted/30 rounded-lg border border-border">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Review Date</p>
            <p className="font-semibold flex items-center gap-2">
              <Clock className="w-4 h-4" />
              {new Date().toLocaleDateString()} at {new Date().toLocaleTimeString()}
            </p>
          </div>
        </CardContent>
      </Card>

      {/* IMPORTANT NOTE */}
      <Alert className="bg-blue-50 border-blue-200">
        <AlertCircle className="h-4 w-4 text-blue-600" />
        <AlertDescription className="text-blue-900">
          <strong>Important:</strong> This review is recorded in the system audit trail. 
          Clearance determinations are official records and require accuracy and staff accountability.
        </AlertDescription>
      </Alert>

      {/* ACTIONS */}
      <div className="flex flex-col sm:flex-row gap-3 justify-between">
        <Button
          variant="outline"
          onClick={handleGenerateDraft}
          className="flex items-center gap-2"
        >
          <FileText className="w-4 h-4" />
          Generate Clearance Draft
        </Button>
        <Button
          onClick={handleConfirm}
          disabled={!reviewedBy.trim()}
          className="flex items-center gap-2 bg-green-600 hover:bg-green-700"
        >
          <CheckCircle2 className="w-4 h-4" />
          Confirm Review Decision
        </Button>
      </div>

      {/* HELP TEXT */}
      <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg text-sm">
        <p className="font-semibold text-blue-900 mb-2">Wording Guide</p>
        <ul className="text-blue-800 space-y-1 text-xs">
          <li>✓ Use: "matched docket record," "possible match," "requires verification"</li>
          <li>✗ Avoid: "criminal record found," "arrest record," "guilty of"</li>
          <li>• All reviews are logged for audit trail and staff accountability</li>
          <li>• Supervisor review is automatic for non-clearance decisions</li>
        </ul>
      </div>
    </div>
  );
}
