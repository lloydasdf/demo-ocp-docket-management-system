/**
 * AUDIT TRAIL & ACTIVITY LOG COMPONENT
 * 
 * Shows who did what, when, for all operations.
 * Provides transparency and accountability for government records.
 * 
 * Currently a UI placeholder - ready for backend integration.
 */

'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  FileText,
  Edit2,
  Lock,
  User,
  Clock,
  Eye,
  CheckCircle2,
  AlertCircle,
  Share2,
  Download
} from 'lucide-react';

export interface AuditEntry {
  id: string;
  timestamp: string;
  action: string;
  actionType: 'create' | 'update' | 'view' | 'verify' | 'export' | 'search';
  entityType: string;
  entityId: string;
  performedBy: string;
  performedByRole?: string;
  changes?: Record<string, { before: string; after: string }>;
  notes?: string;
  status?: 'success' | 'failed';
}

interface AuditTrailProps {
  entityType: string;
  entityId: string;
  entries: AuditEntry[];
  createdBy?: string;
  createdAt?: string;
  lastModifiedBy?: string;
  lastModifiedAt?: string;
  reviewedBy?: string;
  reviewedAt?: string;
  showHeader?: boolean;
}

export function AuditTrail({
  entityType,
  entityId,
  entries,
  createdBy,
  createdAt,
  lastModifiedBy,
  lastModifiedAt,
  reviewedBy,
  reviewedAt,
  showHeader = true
}: AuditTrailProps) {
  const getActionIcon = (actionType: AuditEntry['actionType']) => {
    const iconProps = { className: 'w-4 h-4' };
    switch (actionType) {
      case 'create':
        return <FileText {...iconProps} className="w-4 h-4 text-green-600" />;
      case 'update':
        return <Edit2 {...iconProps} className="w-4 h-4 text-blue-600" />;
      case 'view':
        return <Eye {...iconProps} className="w-4 h-4 text-gray-600" />;
      case 'verify':
        return <CheckCircle2 {...iconProps} className="w-4 h-4 text-green-600" />;
      case 'export':
        return <Download {...iconProps} className="w-4 h-4 text-purple-600" />;
      case 'search':
        return <AlertCircle {...iconProps} className="w-4 h-4 text-amber-600" />;
      default:
        return <FileText {...iconProps} />;
    }
  };

  const getActionColor = (actionType: AuditEntry['actionType']) => {
    switch (actionType) {
      case 'create':
        return 'bg-green-50 border-green-200';
      case 'update':
        return 'bg-blue-50 border-blue-200';
      case 'view':
        return 'bg-gray-50 border-gray-200';
      case 'verify':
        return 'bg-green-50 border-green-200';
      case 'export':
        return 'bg-purple-50 border-purple-200';
      case 'search':
        return 'bg-amber-50 border-amber-200';
      default:
        return 'bg-gray-50 border-gray-200';
    }
  };

  return (
    <div className="space-y-4">
      {/* METADATA SUMMARY */}
      {showHeader && (createdBy || lastModifiedBy || reviewedBy) && (
        <Card className="bg-slate-50 border-slate-200">
          <CardContent className="pt-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {createdBy && createdAt && (
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Created</p>
                  <p className="font-semibold text-sm">{createdBy}</p>
                  <p className="text-xs text-muted-foreground mt-1">
                    {new Date(createdAt).toLocaleDateString()} {new Date(createdAt).toLocaleTimeString()}
                  </p>
                </div>
              )}

              {lastModifiedBy && lastModifiedAt && (
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Last Modified</p>
                  <p className="font-semibold text-sm">{lastModifiedBy}</p>
                  <p className="text-xs text-muted-foreground mt-1">
                    {new Date(lastModifiedAt).toLocaleDateString()} {new Date(lastModifiedAt).toLocaleTimeString()}
                  </p>
                </div>
              )}

              {reviewedBy && reviewedAt && (
                <div>
                  <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Reviewed</p>
                  <p className="font-semibold text-sm">{reviewedBy}</p>
                  <p className="text-xs text-muted-foreground mt-1">
                    {new Date(reviewedAt).toLocaleDateString()} {new Date(reviewedAt).toLocaleTimeString()}
                  </p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* ACTIVITY LOG */}
      {entries.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <Clock className="w-4 h-4" />
              Activity Log
            </CardTitle>
            <CardDescription>{entries.length} action(s) recorded</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {entries.map((entry) => (
                <div key={entry.id} className={`p-4 border rounded-lg ${getActionColor(entry.actionType)}`}>
                  <div className="flex items-start justify-between gap-4 mb-2">
                    <div className="flex items-start gap-3 flex-1">
                      <div className="mt-1">{getActionIcon(entry.actionType)}</div>
                      <div className="flex-1">
                        <p className="font-semibold text-sm">{entry.action}</p>
                        <p className="text-xs text-muted-foreground mt-1">
                          <span className="flex items-center gap-1">
                            <User className="w-3 h-3" />
                            {entry.performedBy}
                            {entry.performedByRole && ` (${entry.performedByRole})`}
                          </span>
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-muted-foreground">
                        {new Date(entry.timestamp).toLocaleDateString()}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {new Date(entry.timestamp).toLocaleTimeString()}
                      </p>
                      {entry.status && (
                        <Badge
                          variant={entry.status === 'success' ? 'default' : 'destructive'}
                          className="mt-1"
                        >
                          {entry.status}
                        </Badge>
                      )}
                    </div>
                  </div>

                  {/* CHANGES SUMMARY */}
                  {entry.changes && Object.keys(entry.changes).length > 0 && (
                    <div className="mt-3 p-2 bg-white/50 rounded border border-gray-300 text-xs space-y-1">
                      {Object.entries(entry.changes).map(([field, change]) => (
                        <div key={field} className="flex gap-2">
                          <span className="font-mono text-muted-foreground min-w-fit">{field}:</span>
                          <span className="line-through text-red-600">{change.before}</span>
                          <span className="text-green-600">→ {change.after}</span>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* NOTES */}
                  {entry.notes && (
                    <p className="text-xs text-muted-foreground mt-2 italic">
                      Note: {entry.notes}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {entries.length === 0 && (
        <Card>
          <CardContent className="pt-6">
            <p className="text-center text-muted-foreground text-sm">No activity logged yet</p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

/**
 * EMBEDDED AUDIT INFO COMPONENT
 * 
 * Smaller version to show at top of page/card
 * Shows essential metadata without full activity log
 */
interface EmbeddedAuditInfoProps {
  createdBy?: string;
  createdAt?: string;
  lastModifiedBy?: string;
  lastModifiedAt?: string;
  compact?: boolean;
}

export function EmbeddedAuditInfo({
  createdBy,
  createdAt,
  lastModifiedBy,
  lastModifiedAt,
  compact = false
}: EmbeddedAuditInfoProps) {
  if (compact) {
    return (
      <div className="text-xs text-muted-foreground space-y-1">
        {createdBy && createdAt && (
          <p>
            <span className="font-medium">Created:</span> {createdBy} on {new Date(createdAt).toLocaleDateString()}
          </p>
        )}
        {lastModifiedBy && lastModifiedAt && (
          <p>
            <span className="font-medium">Modified:</span> {lastModifiedBy} on {new Date(lastModifiedAt).toLocaleDateString()}
          </p>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-wrap gap-4 text-xs">
      {createdBy && createdAt && (
        <div className="flex items-center gap-2">
          <Lock className="w-4 h-4 text-muted-foreground" />
          <span>
            <span className="text-muted-foreground">Created by</span> <span className="font-medium">{createdBy}</span>
            <br />
            <span className="text-muted-foreground">{new Date(createdAt).toLocaleDateString()}</span>
          </span>
        </div>
      )}
      {lastModifiedBy && lastModifiedAt && (
        <div className="flex items-center gap-2">
          <Edit2 className="w-4 h-4 text-muted-foreground" />
          <span>
            <span className="text-muted-foreground">Modified by</span> <span className="font-medium">{lastModifiedBy}</span>
            <br />
            <span className="text-muted-foreground">{new Date(lastModifiedAt).toLocaleDateString()}</span>
          </span>
        </div>
      )}
    </div>
  );
}
