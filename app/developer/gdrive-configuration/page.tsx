'use client';

import { useCallback, useEffect, useState } from 'react';
import { CheckCircle2, HardDrive, Loader2, Pencil, Plus, RefreshCw, Trash2, XCircle } from 'lucide-react';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';

type EnvironmentRow = { name: string; configured: boolean; maskedValue: string; source: string };
type DiagnosticFolder = { id: string; name: string; webViewLink: string | null };
type Status = { environment: EnvironmentRow[]; connection: { status: string; rootName?: string; message?: string } };

async function developerRequest(path = '', init?: RequestInit) {
  const supabase = await getSupabaseBrowserClient();
  const { data } = await supabase.auth.getSession();
  const token = data.session?.access_token;
  if (!token) throw new Error('Your session has expired.');
  const response = await fetch(`/api/developer/gdrive${path}`, {
    ...init,
    headers: { 'content-type': 'application/json', Authorization: `Bearer ${token}`, ...(init?.headers ?? {}) },
  });
  const body = await response.json() as { data?: unknown; error?: { message?: string } };
  if (!response.ok || !body.data) throw new Error(body.error?.message ?? 'Google Drive diagnostic request failed.');
  return body.data;
}

export default function GoogleDriveConfigurationPage() {
  const [status, setStatus] = useState<Status | null>(null);
  const [folder, setFolder] = useState<DiagnosticFolder | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [action, setAction] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setIsLoading(true); setError(null);
    try { setStatus(await developerRequest() as Status); }
    catch (loadError) { setError(loadError instanceof Error ? loadError.message : 'Unable to load configuration.'); }
    finally { setIsLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);

  async function runFolderAction(kind: 'create' | 'rename' | 'delete') {
    setAction(kind); setError(null);
    try {
      if (kind === 'create') {
        const data = await developerRequest('', { method: 'POST' }) as { folder: DiagnosticFolder };
        setFolder(data.folder);
      } else if (kind === 'rename' && folder) {
        const data = await developerRequest('', { method: 'PATCH', body: JSON.stringify({ folderId: folder.id }) }) as { folder: DiagnosticFolder };
        setFolder(data.folder);
      } else if (kind === 'delete' && folder) {
        await developerRequest(`?folderId=${encodeURIComponent(folder.id)}`, { method: 'DELETE' });
        setFolder(null);
      }
    } catch (actionError) { setError(actionError instanceof Error ? actionError.message : 'Diagnostic action failed.'); }
    finally { setAction(null); }
  }

  return (
    <RoleRouteGuard route="/developer/gdrive-configuration">
      <div className="flex min-h-screen bg-background"><Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto p-6 lg:p-10">
          <div className="mx-auto max-w-5xl space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div><h1 className="flex items-center gap-2 text-3xl font-bold"><HardDrive className="h-8 w-8" /> GDrive Configuration</h1><p className="mt-1 text-muted-foreground">Developer-only server configuration and connection diagnostics.</p></div>
              <Button variant="outline" onClick={() => void load()} disabled={isLoading}><RefreshCw className={`mr-2 h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />Test connection</Button>
            </div>
            <Alert><AlertTitle>Secrets remain server-only</AlertTitle><AlertDescription>Configuration presence is read from the running server&apos;s process environment, but values are never sent to the browser. OAuth secrets cannot be viewed or edited here; update <code>.env.local</code> and restart Next.js to change them.</AlertDescription></Alert>
            {error ? <Alert variant="destructive"><XCircle className="h-4 w-4" /><AlertTitle>Diagnostic failed</AlertTitle><AlertDescription>{error}</AlertDescription></Alert> : null}
            <Card><CardHeader><CardTitle>Environment variables</CardTitle><CardDescription>The exact variable names, source, and configuration presence currently read by the server.</CardDescription></CardHeader><CardContent>
              {isLoading && !status ? <div className="flex items-center gap-2 text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" />Reading server configuration…</div> : <Table><TableHeader><TableRow><TableHead>Variable</TableHead><TableHead>Source</TableHead><TableHead>Status</TableHead><TableHead>Masked value</TableHead></TableRow></TableHeader><TableBody>{status?.environment.map((item) => <TableRow key={item.name}><TableCell className="font-mono text-xs">{item.name}</TableCell><TableCell>{item.source}</TableCell><TableCell><Badge variant={item.configured ? 'default' : 'destructive'}>{item.configured ? 'Configured' : 'Missing'}</Badge></TableCell><TableCell className="font-mono">{item.maskedValue || '—'}</TableCell></TableRow>)}</TableBody></Table>}
            </CardContent></Card>
            <Card><CardHeader><CardTitle>Connection</CardTitle><CardDescription>OAuth and configured root-folder read test.</CardDescription></CardHeader><CardContent>{status?.connection.status === 'CONNECTED' ? <div className="flex items-center gap-2 text-green-700"><CheckCircle2 className="h-5 w-5" /><span>Connected to root folder <strong>{status.connection.rootName}</strong>.</span></div> : <div className="flex items-center gap-2 text-destructive"><XCircle className="h-5 w-5" /><span>{status?.connection.message ?? 'Not tested.'}</span></div>}</CardContent></Card>
            <Card><CardHeader><CardTitle>Drive CRUD diagnostic</CardTitle><CardDescription>Create, read, rename, and trash a protected diagnostic folder directly under the configured root. Only folders created here with the diagnostic prefix can be changed.</CardDescription></CardHeader><CardContent className="space-y-4">
              {!folder ? <Button onClick={() => void runFolderAction('create')} disabled={Boolean(action) || status?.connection.status !== 'CONNECTED'}><Plus className="mr-2 h-4 w-4" />{action === 'create' ? 'Creating…' : 'Create test folder'}</Button> : <><div className="rounded-md border p-4"><p className="text-sm text-muted-foreground">Current diagnostic folder</p><p className="font-mono text-sm">{folder.name}</p>{folder.webViewLink ? <a className="text-sm text-primary underline" href={folder.webViewLink} target="_blank" rel="noreferrer">Open in Google Drive</a> : null}</div><div className="flex gap-2"><Button variant="outline" onClick={() => void runFolderAction('rename')} disabled={Boolean(action)}><Pencil className="mr-2 h-4 w-4" />{action === 'rename' ? 'Renaming…' : 'Rename test folder'}</Button><Button variant="destructive" onClick={() => void runFolderAction('delete')} disabled={Boolean(action)}><Trash2 className="mr-2 h-4 w-4" />{action === 'delete' ? 'Deleting…' : 'Trash test folder'}</Button></div></>}
            </CardContent></Card>
          </div>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
