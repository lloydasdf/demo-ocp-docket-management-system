/**
 * SYSTEM STATUS COMPONENT
 * 
 * Shows local server status, sync status, backup status, and offline readiness.
 * Designed for local-first operation with future cloud sync capability.
 * 
 * Currently shows placeholder UI. Backend will populate with real status.
 */

'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import {
  Server,
  Wifi,
  WifiOff,
  Clock,
  HardDrive,
  CheckCircle2,
  AlertCircle,
  Database,
  CloudSync,
  Save
} from 'lucide-react';
import { useEffect, useState } from 'react';

interface SystemStatusData {
  mode: 'local' | 'cloud_sync';
  localServerConnected: boolean;
  lastBackup?: string;
  pendingSyncCount: number;
  offlineReady: boolean;
  version: string;
}

export function SystemStatus() {
  const [status, setStatus] = useState<SystemStatusData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // TODO: Replace with backend call
    // import { getSystemStatus } from '@/lib/backend';
    // getSystemStatus().then(setStatus);

    // Dummy data for now
    const dummyStatus: SystemStatusData = {
      mode: 'local',
      localServerConnected: true,
      lastBackup: new Date(Date.now() - 3600000).toISOString(),
      pendingSyncCount: 0,
      offlineReady: true,
      version: '1.0.0-local'
    };

    setStatus(dummyStatus);
    setLoading(false);
  }, []);

  if (loading || !status) {
    return (
      <Card>
        <CardContent className="pt-6">
          <p className="text-muted-foreground">Loading system status...</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      {/* MAIN STATUS CARD */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-lg flex items-center gap-2">
                <Server className="w-5 h-5" />
                System Status
              </CardTitle>
              <CardDescription>Local docket management system</CardDescription>
            </div>
            <Badge variant={status.localServerConnected ? 'default' : 'destructive'} className="text-xs">
              {status.mode === 'local' ? 'Local Mode' : 'Cloud Sync Mode'}
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* LOCAL SERVER STATUS */}
            <div className="p-4 border border-border rounded-lg">
              <div className="flex items-center justify-between mb-2">
                <p className="font-semibold flex items-center gap-2">
                  {status.localServerConnected ? (
                    <Wifi className="w-4 h-4 text-green-600" />
                  ) : (
                    <WifiOff className="w-4 h-4 text-red-600" />
                  )}
                  Local Server
                </p>
                {status.localServerConnected ? (
                  <Badge variant="outline" className="bg-green-50 text-green-700 border-green-200">
                    Connected
                  </Badge>
                ) : (
                  <Badge variant="destructive">Disconnected</Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground">
                {status.localServerConnected
                  ? 'Connected to local PostgreSQL database'
                  : 'Unable to reach local server'}
              </p>
            </div>

            {/* OFFLINE READINESS */}
            <div className="p-4 border border-border rounded-lg">
              <div className="flex items-center justify-between mb-2">
                <p className="font-semibold flex items-center gap-2">
                  <Database className="w-4 h-4 text-blue-600" />
                  Offline Ready
                </p>
                {status.offlineReady ? (
                  <Badge variant="outline" className="bg-blue-50 text-blue-700 border-blue-200">
                    Yes
                  </Badge>
                ) : (
                  <Badge variant="outline" className="bg-gray-100 text-gray-700">
                    No
                  </Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground">
                {status.offlineReady
                  ? 'Can operate without internet connection'
                  : 'Internet connection required'}
              </p>
            </div>

            {/* LAST BACKUP */}
            <div className="p-4 border border-border rounded-lg">
              <div className="flex items-center justify-between mb-2">
                <p className="font-semibold flex items-center gap-2">
                  <Save className="w-4 h-4 text-amber-600" />
                  Last Backup
                </p>
              </div>
              {status.lastBackup ? (
                <p className="text-xs text-muted-foreground">
                  {new Date(status.lastBackup).toLocaleDateString()}{' '}
                  {new Date(status.lastBackup).toLocaleTimeString()}
                </p>
              ) : (
                <p className="text-xs text-muted-foreground">Never backed up</p>
              )}
            </div>

            {/* PENDING SYNC */}
            <div className="p-4 border border-border rounded-lg">
              <div className="flex items-center justify-between mb-2">
                <p className="font-semibold flex items-center gap-2">
                  <CloudSync className="w-4 h-4 text-purple-600" />
                  Pending Sync
                </p>
                <Badge variant={status.pendingSyncCount > 0 ? 'outline' : 'outline'}>
                  {status.pendingSyncCount}
                </Badge>
              </div>
              <p className="text-xs text-muted-foreground">
                {status.pendingSyncCount === 0
                  ? 'All data synced'
                  : `${status.pendingSyncCount} change(s) pending`}
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* LOCAL-FIRST NOTICE */}
      <Alert className="bg-blue-50 border-blue-200">
        <Server className="h-4 w-4 text-blue-600" />
        <AlertDescription className="text-blue-900">
          <strong>Local-First Mode:</strong> This system operates on a local server in your office.
          Data is stored locally for security and offline operation. Cloud sync/backup can be enabled later.
        </AlertDescription>
      </Alert>

      {/* INFORMATION CARDS */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* VERSION INFO */}
        <Card className="bg-slate-50 border-slate-200">
          <CardContent className="pt-6">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Version</p>
            <p className="font-mono font-semibold text-sm">{status.version}</p>
          </CardContent>
        </Card>

        {/* DATABASE INFO */}
        <Card className="bg-slate-50 border-slate-200">
          <CardContent className="pt-6">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">Database</p>
            <p className="font-semibold text-sm">PostgreSQL (Local)</p>
          </CardContent>
        </Card>

        {/* API INFO */}
        <Card className="bg-slate-50 border-slate-200">
          <CardContent className="pt-6">
            <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">API</p>
            <p className="font-semibold text-sm">Local REST API</p>
          </CardContent>
        </Card>
      </div>

      {/* SYSTEM MAINTENANCE SECTION */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">System Maintenance</CardTitle>
          <CardDescription>Administrative actions (local server only)</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex gap-2 flex-wrap">
            <Button variant="outline" size="sm" disabled>
              Create Local Backup
            </Button>
            <Button variant="outline" size="sm" disabled>
              Restore from Backup
            </Button>
            <Button variant="outline" size="sm" disabled>
              View Database Logs
            </Button>
            <Button variant="outline" size="sm" disabled>
              System Diagnostics
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            Buttons disabled in demo mode. Backend integration will enable full maintenance features.
          </p>
        </CardContent>
      </Card>

      {/* HELP TEXT */}
      <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg text-sm">
        <p className="font-semibold text-blue-900 mb-2">Local-First Architecture</p>
        <ul className="text-blue-800 space-y-1 text-xs">
          <li>• <strong>Local Storage:</strong> All data stays on office server - no cloud dependency</li>
          <li>• <strong>Offline Operation:</strong> Works without internet, syncs when available</li>
          <li>• <strong>Data Security:</strong> Complete control over sensitive government records</li>
          <li>• <strong>Future Ready:</strong> Can add cloud backup and sync later without changes</li>
        </ul>
      </div>
    </div>
  );
}
