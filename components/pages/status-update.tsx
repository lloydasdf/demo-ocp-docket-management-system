'use client';

import { useState, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getCaseStatusHistory, getCaseById } from '@/lib/supabase-queries';
import { Timeline, TimelineItem } from '@/components/ui/timeline';
import { StatusBadge } from '@/components/status-badge';
import { AlertTriangle, Clock } from 'lucide-react';

export default function StatusUpdate() {
  const searchParams = useSearchParams();
  const caseId = searchParams.get('caseId');

  const [caseData, setCaseData] = useState<any>(null);
  const [history, setHistory] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!caseId) {
      setError('No case ID provided');
      setLoading(false);
      return;
    }

    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);

        const [caseDetails, statusHistory] = await Promise.all([
          getCaseById(caseId),
          getCaseStatusHistory(caseId),
        ]);

        setCaseData(caseDetails);
        setHistory(statusHistory);
      } catch (err) {
        console.error('[v0] Error loading status history:', err);
        setError('Failed to load status history');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, [caseId]);

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <Spinner className="w-12 h-12 mx-auto mb-4" />
          <p className="text-muted-foreground">Loading status history...</p>
        </div>
      </div>
    );
  }

  if (error || !caseData) {
    return (
      <div className="p-8">
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription>{error || 'Case not found'}</AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Case Status History</h1>
        <p className="text-muted-foreground mt-1">{caseData.case_number}</p>
      </div>

      {/* Current Status */}
      <Card>
        <CardHeader>
          <CardTitle>Current Status</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-between">
            <div>
              <StatusBadge status={caseData.status} />
              <p className="text-sm text-muted-foreground mt-2">Last updated: {new Date(caseData.updated_at).toLocaleDateString()}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Status Timeline */}
      <Card>
        <CardHeader>
          <CardTitle>Status Timeline</CardTitle>
          <CardDescription>{history.length} status update{history.length !== 1 ? 's' : ''}</CardDescription>
        </CardHeader>
        <CardContent>
          {history.length === 0 ? (
            <p className="text-muted-foreground text-center py-8">No status updates recorded</p>
          ) : (
            <div className="space-y-4">
              {history.map((entry, index) => (
                <div key={entry.id} className="pb-6 border-b last:border-b-0 last:pb-0">
                  <div className="flex gap-4">
                    <div className="flex flex-col items-center">
                      <div className="w-4 h-4 rounded-full bg-primary" />
                      {index !== history.length - 1 && (
                        <div className="w-0.5 h-12 bg-border mt-2" />
                      )}
                    </div>
                    <div className="flex-1 pt-1">
                      <div className="flex items-center gap-2 mb-1">
                        <StatusBadge status={entry.status} size="sm" />
                        <span className="text-sm text-muted-foreground">
                          {new Date(entry.updated_at).toLocaleDateString()} at{' '}
                          {new Date(entry.updated_at).toLocaleTimeString([], {
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </span>
                      </div>
                      <p className="text-sm">
                        Updated by <span className="font-medium">{entry.app_users?.full_name}</span>
                      </p>
                      {entry.notes && (
                        <p className="text-sm mt-2 p-2 bg-muted rounded">{entry.notes}</p>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Read-Only Notice */}
      <Alert>
        <Clock className="h-4 w-4" />
        <AlertDescription>
          Status history is read-only. Updates are made through the New Docket Entry workflow.
        </AlertDescription>
      </Alert>
    </div>
  );
}
