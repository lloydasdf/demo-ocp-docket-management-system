/**
 * DUPLICATE CHECKING COMPONENT
 * 
 * Shows "Possible Existing Records" whenever user adds a person or searches a docket.
 * Helps prevent duplicate entry and suggests linking to existing records.
 * 
 * Uses dummy data for demonstration. Backend will perform actual duplicate detection.
 */

'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { AlertCircle, CheckCircle, Link2 } from 'lucide-react';

export interface PossibleDuplicate {
  id: string;
  type: 'person' | 'docket';
  displayName: string;
  confidence: number; // 0-100%
  matchReasons: string[];
  details?: {
    aliases?: string[];
    address?: string;
    status?: string;
    relatedDockets?: number;
  };
}

interface DuplicateCheckerProps {
  possibleDuplicates: PossibleDuplicate[];
  onLinkExisting?: (id: string) => void;
  onCreateNew?: () => void;
  onView?: (id: string) => void;
  itemName: string;
}

export function DuplicateChecker({
  possibleDuplicates,
  onLinkExisting,
  onCreateNew,
  onView,
  itemName
}: DuplicateCheckerProps) {
  if (possibleDuplicates.length === 0) {
    return (
      <Card className="border-green-200 bg-green-50">
        <CardContent className="pt-6">
          <div className="flex items-center gap-3">
            <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0" />
            <div>
              <p className="font-semibold text-green-900">No Similar Records Found</p>
              <p className="text-sm text-green-800">Safe to create new {itemName} record.</p>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  const highConfidence = possibleDuplicates.filter(d => d.confidence >= 80);
  const mediumConfidence = possibleDuplicates.filter(d => d.confidence >= 50 && d.confidence < 80);
  const lowConfidence = possibleDuplicates.filter(d => d.confidence < 50);

  return (
    <div className="space-y-4">
      {/* WARNING ALERT */}
      <Alert className="border-amber-500/50 bg-amber-500/5">
        <AlertCircle className="h-4 w-4 text-amber-600" />
        <AlertDescription className="text-amber-900">
          <strong>Possible Existing Records Found:</strong> Please review below. 
          Linking to existing records prevents duplicates and keeps data accurate.
        </AlertDescription>
      </Alert>

      {/* HIGH CONFIDENCE MATCHES */}
      {highConfidence.length > 0 && (
        <Card className="border-red-300 bg-red-50">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <span className="w-2 h-2 bg-red-500 rounded-full" />
              Likely Match ({highConfidence.length})
            </CardTitle>
            <CardDescription>Very similar records - strongly recommend review</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {highConfidence.map((dup) => (
              <DuplicateRecord
                key={dup.id}
                duplicate={dup}
                onLink={() => onLinkExisting?.(dup.id)}
                onView={() => onView?.(dup.id)}
              />
            ))}
          </CardContent>
        </Card>
      )}

      {/* MEDIUM CONFIDENCE MATCHES */}
      {mediumConfidence.length > 0 && (
        <Card className="border-amber-300 bg-amber-50">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <span className="w-2 h-2 bg-amber-500 rounded-full" />
              Possible Match ({mediumConfidence.length})
            </CardTitle>
            <CardDescription>Similar records - review before proceeding</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {mediumConfidence.map((dup) => (
              <DuplicateRecord
                key={dup.id}
                duplicate={dup}
                onLink={() => onLinkExisting?.(dup.id)}
                onView={() => onView?.(dup.id)}
              />
            ))}
          </CardContent>
        </Card>
      )}

      {/* LOW CONFIDENCE MATCHES */}
      {lowConfidence.length > 0 && (
        <Card className="border-gray-300 bg-gray-50">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <span className="w-2 h-2 bg-gray-500 rounded-full" />
              Low Confidence ({lowConfidence.length})
            </CardTitle>
            <CardDescription>Weak similarities - probably not related</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {lowConfidence.map((dup) => (
              <DuplicateRecord
                key={dup.id}
                duplicate={dup}
                onLink={() => onLinkExisting?.(dup.id)}
                onView={() => onView?.(dup.id)}
              />
            ))}
          </CardContent>
        </Card>
      )}

      {/* DECISION HELPER */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Decision Helper</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          <div className="p-3 bg-blue-50 border border-blue-200 rounded">
            <p className="font-semibold text-blue-900 mb-1">This person/docket already exists?</p>
            <p className="text-blue-800">Click "Link Existing" to connect to that record instead of creating a duplicate.</p>
          </div>
          <div className="p-3 bg-green-50 border border-green-200 rounded">
            <p className="font-semibold text-green-900 mb-1">This is a new person/docket?</p>
            <p className="text-green-800">Click "Create New Record" below to proceed with creating a new entry.</p>
          </div>
        </CardContent>
      </Card>

      {/* CREATE NEW BUTTON */}
      {onCreateNew && (
        <Button onClick={onCreateNew} variant="outline" className="w-full">
          Create New {itemName} Record
        </Button>
      )}
    </div>
  );
}

/**
 * Individual duplicate record display
 */
function DuplicateRecord({
  duplicate,
  onLink,
  onView
}: {
  duplicate: PossibleDuplicate;
  onLink?: () => void;
  onView?: () => void;
}) {
  const getConfidenceColor = (conf: number) => {
    if (conf >= 80) return 'bg-red-100 text-red-800';
    if (conf >= 50) return 'bg-amber-100 text-amber-800';
    return 'bg-gray-100 text-gray-800';
  };

  const getConfidenceLabel = (conf: number) => {
    if (conf >= 80) return 'High Match';
    if (conf >= 50) return 'Possible Match';
    return 'Low Match';
  };

  return (
    <div className="p-4 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors">
      <div className="flex items-start justify-between gap-4 mb-3">
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <p className="font-semibold">{duplicate.displayName}</p>
            <Badge className={getConfidenceColor(duplicate.confidence)}>
              {getConfidenceLabel(duplicate.confidence)} ({duplicate.confidence}%)
            </Badge>
          </div>
          <div className="space-y-1">
            {duplicate.matchReasons.map((reason, i) => (
              <p key={i} className="text-xs text-muted-foreground flex items-center gap-2">
                <span className="w-1 h-1 bg-muted-foreground rounded-full" />
                {reason}
              </p>
            ))}
          </div>

          {/* Additional details if provided */}
          {duplicate.details && (
            <div className="mt-3 pt-3 border-t border-gray-200 space-y-1">
              {duplicate.details.aliases && (
                <p className="text-xs">
                  <span className="text-muted-foreground">Aliases:</span> {duplicate.details.aliases.join(', ')}
                </p>
              )}
              {duplicate.details.address && (
                <p className="text-xs">
                  <span className="text-muted-foreground">Address:</span> {duplicate.details.address}
                </p>
              )}
              {duplicate.details.status && (
                <p className="text-xs">
                  <span className="text-muted-foreground">Status:</span> {duplicate.details.status}
                </p>
              )}
              {duplicate.details.relatedDockets && (
                <p className="text-xs">
                  <span className="text-muted-foreground">Related Dockets:</span> {duplicate.details.relatedDockets}
                </p>
              )}
            </div>
          )}
        </div>
      </div>

      {/* ACTION BUTTONS */}
      <div className="flex gap-2">
        {onLink && (
          <Button
            size="sm"
            onClick={onLink}
            className="flex items-center gap-1"
          >
            <Link2 className="w-4 h-4" />
            Link Existing
          </Button>
        )}
        {onView && (
          <Button
            size="sm"
            variant="outline"
            onClick={onView}
          >
            View Full Record
          </Button>
        )}
      </div>
    </div>
  );
}
