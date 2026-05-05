/**
 * DOCKET FINAL REVIEW & CONFIRMATION
 * 
 * Shown before official docket creation.
 * Ensures staff review all information and confirms before saving.
 * 
 * NOTE: This component does NOT auto-save. Staff must explicitly click "Confirm and Save Official Docket".
 */

'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { StatusBadge } from '@/components/status-badge';
import { AlertTriangle, ArrowLeft, Save, CheckCircle, AlertCircle } from 'lucide-react';
import { useState } from 'react';

interface DocketReviewData {
  docketNumber: string;
  dateReceived: string;
  complainants: Array<{ name: string; aliases: string[] }>;
  respondents: Array<{ name: string; aliases: string[]; age?: string; dateOfBirth?: string }>;
  addresses: Array<{ street: string; barangay: string; municipality: string }>;
  violations: Array<{ statute: string; description: string; placeOfCommission: string }>;
  prosecutorAssignment?: string;
  attachments: Array<{ name: string; type: string }>;
  missingRequiredFields: string[];
  possibleDuplicatePersons: Array<{ name: string; similarity: number }>;
  possibleDuplicateDockets: Array<{ docketNumber: string; similarity: number }>;
}

interface DocketFinalReviewProps {
  data: DocketReviewData;
  onConfirm: () => void;
  onBackToEdit: () => void;
  onSaveAsDraft: () => void;
}

export function DocketFinalReview({
  data,
  onConfirm,
  onBackToEdit,
  onSaveAsDraft
}: DocketFinalReviewProps) {
  const [reviewNotes, setReviewNotes] = useState('');
  const [agreed, setAgreed] = useState(false);

  const hasMissingRequired = data.missingRequiredFields.length > 0;
  const canConfirm = !hasMissingRequired && agreed;

  return (
    <div className="space-y-6">
      {/* WARNING - Missing Required Fields */}
      {hasMissingRequired && (
        <Alert className="border-destructive/50 bg-destructive/5">
          <AlertTriangle className="h-4 w-4 text-destructive" />
          <AlertDescription className="text-destructive">
            <strong>Missing Required Fields:</strong> {data.missingRequiredFields.join(', ')}
            <br />
            <span className="text-sm">Cannot save official docket until all required fields are completed.</span>
          </AlertDescription>
        </Alert>
      )}

      {/* DUPLICATE WARNINGS */}
      {(data.possibleDuplicatePersons.length > 0 || data.possibleDuplicateDockets.length > 0) && (
        <Alert className="border-amber-500/50 bg-amber-500/5">
          <AlertCircle className="h-4 w-4 text-amber-600" />
          <AlertDescription className="text-amber-900">
            <strong>Possible Duplicate Records Found:</strong> Please review below before confirming.
          </AlertDescription>
        </Alert>
      )}

      {/* MAIN REVIEW SECTION */}
      <Card className="border-2 border-primary/20">
        <CardHeader className="pb-3">
          <CardTitle>Review Docket Information</CardTitle>
          <CardDescription>Verify all information is correct before creating official record</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          
          {/* DOCKET INFO */}
          <section className="space-y-4">
            <h3 className="font-semibold text-lg flex items-center gap-2">
              <span className="w-2 h-2 bg-primary rounded-full" />
              Docket Information
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 bg-muted/30 rounded-lg border border-border">
              <div>
                <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Docket Number</p>
                <p className="font-mono font-semibold text-lg">{data.docketNumber}</p>
              </div>
              <div>
                <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Date Received</p>
                <p className="font-semibold">{new Date(data.dateReceived).toLocaleDateString()}</p>
              </div>
            </div>
          </section>

          {/* PARTIES */}
          <section className="space-y-4">
            <h3 className="font-semibold text-lg flex items-center gap-2">
              <span className="w-2 h-2 bg-primary rounded-full" />
              Parties Involved
            </h3>
            <div className="space-y-4">
              {/* Complainants */}
              <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
                <p className="text-sm font-semibold text-green-900 mb-2">Complainants ({data.complainants.length})</p>
                <div className="space-y-2">
                  {data.complainants.map((c, i) => (
                    <div key={i} className="text-sm">
                      <p className="font-medium">{c.name}</p>
                      {c.aliases.length > 0 && (
                        <p className="text-xs text-muted-foreground">Aliases: {c.aliases.join(', ')}</p>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Respondents */}
              <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
                <p className="text-sm font-semibold text-red-900 mb-2">Respondents ({data.respondents.length})</p>
                <div className="space-y-2">
                  {data.respondents.map((r, i) => (
                    <div key={i} className="text-sm">
                      <p className="font-medium">{r.name}</p>
                      {r.aliases.length > 0 && (
                        <p className="text-xs text-muted-foreground">Aliases: {r.aliases.join(', ')}</p>
                      )}
                      {(r.age || r.dateOfBirth) && (
                        <p className="text-xs text-muted-foreground">
                          {r.dateOfBirth ? `DOB: ${r.dateOfBirth}` : `Age: ${r.age}`}
                        </p>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </section>

          {/* ADDRESSES */}
          <section className="space-y-4">
            <h3 className="font-semibold text-lg flex items-center gap-2">
              <span className="w-2 h-2 bg-primary rounded-full" />
              Addresses ({data.addresses.length})
            </h3>
            <div className="space-y-2">
              {data.addresses.map((addr, i) => (
                <div key={i} className="p-3 border border-border rounded-lg text-sm">
                  <p className="font-medium">{addr.street}</p>
                  <p className="text-xs text-muted-foreground">
                    {addr.barangay}, {addr.municipality}
                  </p>
                </div>
              ))}
            </div>
          </section>

          {/* VIOLATIONS */}
          <section className="space-y-4">
            <h3 className="font-semibold text-lg flex items-center gap-2">
              <span className="w-2 h-2 bg-primary rounded-full" />
              Violations ({data.violations.length})
            </h3>
            <div className="space-y-2">
              {data.violations.map((v, i) => (
                <div key={i} className="p-3 border border-border rounded-lg text-sm">
                  <p className="font-mono font-semibold text-primary">{v.statute}</p>
                  <p className="font-medium">{v.description}</p>
                  <p className="text-xs text-muted-foreground mt-1">Place: {v.placeOfCommission}</p>
                </div>
              ))}
            </div>
          </section>

          {/* PROSECUTOR & ATTACHMENTS */}
          <section className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 bg-muted/30 rounded-lg border border-border">
            <div>
              <p className="text-xs text-muted-foreground uppercase tracking-wider mb-2">Assigned Prosecutor</p>
              <p className="font-semibold">{data.prosecutorAssignment || 'Not Yet Assigned'}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground uppercase tracking-wider mb-2">Attachments</p>
              <p className="font-semibold">{data.attachments.length} file(s) attached</p>
            </div>
          </section>

          {/* POSSIBLE DUPLICATES */}
          {(data.possibleDuplicatePersons.length > 0 || data.possibleDuplicateDockets.length > 0) && (
            <section className="space-y-4">
              <h3 className="font-semibold text-lg flex items-center gap-2">
                <span className="w-2 h-2 bg-amber-500 rounded-full" />
                Possible Existing Records
              </h3>

              {data.possibleDuplicatePersons.length > 0 && (
                <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
                  <p className="text-sm font-semibold text-amber-900 mb-3">Similar Persons in System</p>
                  <div className="space-y-2">
                    {data.possibleDuplicatePersons.map((dup, i) => (
                      <div key={i} className="flex items-center justify-between text-sm p-2 bg-white rounded border border-amber-100">
                        <span>{dup.name}</span>
                        <Badge variant="outline">{dup.similarity}% match</Badge>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {data.possibleDuplicateDockets.length > 0 && (
                <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
                  <p className="text-sm font-semibold text-amber-900 mb-3">Similar Dockets in System</p>
                  <div className="space-y-2">
                    {data.possibleDuplicateDockets.map((dup, i) => (
                      <div key={i} className="flex items-center justify-between text-sm p-2 bg-white rounded border border-amber-100">
                        <span className="font-mono">{dup.docketNumber}</span>
                        <Badge variant="outline">{dup.similarity}% match</Badge>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </section>
          )}
        </CardContent>
      </Card>

      {/* STAFF REVIEW NOTES */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Staff Review Notes (Optional)</CardTitle>
          <CardDescription>Document any issues or special notes for audit trail</CardDescription>
        </CardHeader>
        <CardContent>
          <Textarea
            placeholder="E.g., 'Verified aliases with complainant', 'Missing prosecutor assignment - will assign separately', etc."
            value={reviewNotes}
            onChange={(e) => setReviewNotes(e.target.value)}
            className="min-h-24"
          />
          <p className="text-xs text-muted-foreground mt-2">
            Notes will be saved with docket audit trail for future reference.
          </p>
        </CardContent>
      </Card>

      {/* CONFIRMATION CHECKBOX */}
      <Card className="border-blue-200 bg-blue-50">
        <CardContent className="pt-6">
          <div className="flex items-start gap-3">
            <input
              type="checkbox"
              id="confirm-check"
              checked={agreed}
              onChange={(e) => setAgreed(e.target.checked)}
              className="mt-1"
              disabled={hasMissingRequired}
            />
            <label htmlFor="confirm-check" className="text-sm cursor-pointer flex-1">
              <span className="font-semibold">I have reviewed all information above.</span>
              <br />
              <span className="text-muted-foreground">
                I confirm this information is accurate and complete. This will create an official docket record that cannot be easily deleted.
              </span>
            </label>
          </div>
        </CardContent>
      </Card>

      {/* ACTIONS */}
      <div className="flex flex-col sm:flex-row gap-3 justify-between">
        <div className="flex gap-3">
          <Button variant="outline" onClick={onBackToEdit} className="flex items-center gap-2">
            <ArrowLeft className="w-4 h-4" />
            Back to Edit
          </Button>
          <Button variant="ghost" onClick={onSaveAsDraft} className="flex items-center gap-2">
            <Save className="w-4 h-4" />
            Save as Draft
          </Button>
        </div>
        <Button
          onClick={onConfirm}
          disabled={!canConfirm}
          className="flex items-center gap-2 bg-green-600 hover:bg-green-700"
        >
          <CheckCircle className="w-4 h-4" />
          Confirm and Save Official Docket
        </Button>
      </div>

      {/* HELP TEXT */}
      <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg text-sm">
        <p className="font-semibold text-blue-900 mb-2">How to Use</p>
        <ul className="text-blue-800 space-y-1 text-xs">
          <li>• <strong>Back to Edit</strong>: Make changes and return to review</li>
          <li>• <strong>Save as Draft</strong>: Temporarily save (can resume later)</li>
          <li>• <strong>Confirm:</strong> Create official docket record (becomes permanent)</li>
          <li>• All actions are logged for audit trail and staff accountability</li>
        </ul>
      </div>
    </div>
  );
}
