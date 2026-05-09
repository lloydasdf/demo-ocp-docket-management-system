'use client';

import { useState } from 'react';
import { AlertCircle, CheckCircle2, Database, Loader2 } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { verifySupabaseConnection } from '@/lib/supabase/queries';
import type { SupabaseQueryError } from '@/lib/supabase/types';

type ConnectionState =
  | { status: 'idle' }
  | { status: 'checking' }
  | { status: 'connected'; checkedTable: string; rowCount: number; checkedAt: string }
  | { status: 'error'; error: SupabaseQueryError };

export function SupabaseConnectionCheck() {
  const [connection, setConnection] = useState<ConnectionState>({ status: 'idle' });

  async function handleVerifyConnection() {
    setConnection({ status: 'checking' });

    const result = await verifySupabaseConnection();

    if (result.error) {
      setConnection({ status: 'error', error: result.error });
      return;
    }

    setConnection({
      status: 'connected',
      checkedTable: result.data.checkedTable,
      rowCount: result.data.rowCount,
      checkedAt: result.data.checkedAt,
    });
  }

  return (
    <Card className="border-dashed">
      <CardHeader className="pb-3">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <CardTitle className="flex items-center gap-2 text-base">
              <Database className="h-4 w-4" />
              Supabase Connection Check
            </CardTitle>
            <CardDescription>
              Temporary verification helper. Remove this card after the database connection is confirmed.
            </CardDescription>
          </div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={handleVerifyConnection}
            disabled={connection.status === 'checking'}
          >
            {connection.status === 'checking' ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Checking
              </>
            ) : (
              'Verify Supabase'
            )}
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {connection.status === 'idle' && (
          <p className="text-sm text-muted-foreground">
            Click the button to run a read-only query against the typed docket_types lookup table.
          </p>
        )}

        {connection.status === 'checking' && (
          <p className="text-sm text-muted-foreground">Attempting a read-only Supabase query...</p>
        )}

        {connection.status === 'connected' && (
          <div className="flex flex-col gap-2 text-sm sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-2 text-green-700">
              <CheckCircle2 className="h-4 w-4" />
              Connected to Supabase via {connection.checkedTable}.
            </div>
            <Badge variant="outline">
              {connection.rowCount} row{connection.rowCount === 1 ? '' : 's'} sampled at{' '}
              {new Date(connection.checkedAt).toLocaleTimeString()}
            </Badge>
          </div>
        )}

        {connection.status === 'error' && (
          <div className="space-y-2 text-sm text-destructive">
            <div className="flex items-center gap-2 font-medium">
              <AlertCircle className="h-4 w-4" />
              Supabase check failed
            </div>
            <p>{connection.error.message}</p>
            {connection.error.hint && <p className="text-xs">Hint: {connection.error.hint}</p>}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
