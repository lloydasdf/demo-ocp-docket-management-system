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
import { DocketFolderGeneration } from '@/components/docket-folder-generation';

type EnvironmentRow = { name: string; configured: boolean; maskedValue: string; source: string };
type DriveItem = { id: string; name: string; mimeType: string | null; webViewLink: string | null };
type DiagnosticFolder = { id: string; name: string; webViewLink: string | null };
type Status = { environment: EnvironmentRow[]; connection: { status: string; account?: { emailAddress: string; displayName: string | null }; rootName?: string; maskedRootId?: string; currentFolder?: { id: string; name: string; isRoot: boolean }; rootContents?: DriveItem[]; message?: string; stage?: string; code?: string; description?: string; suggestion?: string } };

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
  const [uploadedFile, setUploadedFile] = useState<DriveItem | null>(null);
  const [folderStack, setFolderStack] = useState<Array<{ id: string; name: string }>>([]);
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

  async function listRootContents(folderId?: string) {
    setAction('list'); setError(null);
    try { setStatus(await developerRequest(folderId ? `?folderId=${encodeURIComponent(folderId)}` : '?listRoot=1') as Status); }
    catch (listError) { setError(listError instanceof Error ? listError.message : 'Unable to list root folder.'); }
    finally { setAction(null); }
  }

  async function createManagedFolder() {
    const name = window.prompt('New folder name');
    const parentId = status?.connection.currentFolder?.id;
    if (!name || !parentId) return;
    setAction('create-managed'); setError(null);
    try { await developerRequest('', { method: 'POST', body: JSON.stringify({ action: 'createFolder', parentId, name }) }); await listRootContents(parentId); }
    catch (createError) { setError(createError instanceof Error ? createError.message : 'Unable to create folder.'); }
    finally { setAction(null); }
  }

  async function renameManagedItem(item: DriveItem) {
    const name = window.prompt('New name', item.name);
    if (!name) return;
    setAction(`rename-${item.id}`); setError(null);
    try { await developerRequest('', { method: 'PATCH', body: JSON.stringify({ itemId: item.id, name }) }); await listRootContents(status?.connection.currentFolder?.id); }
    catch (renameError) { setError(renameError instanceof Error ? renameError.message : 'Unable to rename item.'); }
    finally { setAction(null); }
  }

  async function deleteManagedItem(item: DriveItem) {
    if (!window.confirm(`Move “${item.name}” to Google Drive trash?`)) return;
    setAction(`delete-${item.id}`); setError(null);
    try { await developerRequest(`?itemId=${encodeURIComponent(item.id)}`, { method: 'DELETE' }); await listRootContents(status?.connection.currentFolder?.id); }
    catch (deleteError) { setError(deleteError instanceof Error ? deleteError.message : 'Unable to trash item.'); }
    finally { setAction(null); }
  }

  async function uploadManagedFile(file: File) {
    const parentId = status?.connection.currentFolder?.id;
    if (!parentId) return;
    setAction('upload-managed'); setError(null);
    try {
      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getSession();
      if (!data.session?.access_token) throw new Error('Your session has expired.');
      const form = new FormData(); form.set('parentId', parentId); form.set('file', file);
      const response = await fetch('/api/developer/gdrive', { method: 'POST', headers: { Authorization: `Bearer ${data.session.access_token}` }, body: form });
      const body = await response.json() as { error?: { message?: string } };
      if (!response.ok) throw new Error(body.error?.message ?? 'Upload failed.');
      await listRootContents(parentId);
    } catch (uploadError) { setError(uploadError instanceof Error ? uploadError.message : 'Unable to upload file.'); }
    finally { setAction(null); }
  }

  async function testUpload() {
    if (!folder) return;
    setAction('upload'); setError(null);
    try {
      const data = await developerRequest('', { method: 'POST', body: JSON.stringify({ action: 'upload', folderId: folder.id }) }) as { file: DriveItem };
      setUploadedFile(data.file);
    } catch (uploadError) { setError(uploadError instanceof Error ? uploadError.message : 'Upload diagnostic failed.'); }
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
            <Card><CardHeader><CardTitle>Connection</CardTitle><CardDescription>OAuth and configured root-folder read test.</CardDescription></CardHeader><CardContent>{status?.connection.status === 'CONNECTED' ? <div className="space-y-3"><div className="flex items-center gap-2 text-green-700"><CheckCircle2 className="h-5 w-5" /><span>Connected successfully.</span></div><dl className="grid gap-1 text-sm sm:grid-cols-[10rem_1fr]"><dt className="font-medium">Google account</dt><dd>{status.connection.account?.emailAddress}</dd><dt className="font-medium">Root folder</dt><dd>{status.connection.rootName}</dd><dt className="font-medium">Masked root ID</dt><dd><code>{status.connection.maskedRootId}</code></dd></dl></div> : <div className="space-y-3"><div className="flex items-start gap-2 text-destructive"><XCircle className="mt-0.5 h-5 w-5 shrink-0" /><span>{status?.connection.message ?? 'Not tested.'}</span></div>{status?.connection.stage ? <div className="rounded-md bg-muted p-3 text-sm"><p><strong>Failed stage:</strong> {status.connection.stage}</p>{status.connection.code ? <p className="mt-1"><strong>Sanitized error:</strong> <code>{status.connection.code}</code></p> : null}{status.connection.description ? <p className="mt-1"><strong>Sanitized error_description (development only):</strong> {status.connection.description}</p> : null}{status.connection.suggestion ? <p className="mt-1"><strong>Recommended action:</strong> {status.connection.suggestion}</p> : null}</div> : null}</div>}</CardContent></Card>
            {status?.connection.status === 'CONNECTED' ? <Card><CardHeader><CardTitle>Drive file manager</CardTitle><CardDescription>Browse and manage all files and folders below the configured root. The root itself cannot be renamed or deleted.</CardDescription></CardHeader><CardContent className="space-y-4"><div className="flex flex-wrap gap-2"><Button variant="outline" onClick={() => { setFolderStack([]); void listRootContents(); }} disabled={Boolean(action)}><RefreshCw className={`mr-2 h-4 w-4 ${action === 'list' ? 'animate-spin' : ''}`} />Open root</Button>{folderStack.length ? <Button variant="outline" onClick={() => { const parent = folderStack[folderStack.length - 1]; setFolderStack((items) => items.slice(0, -1)); void listRootContents(parent.id); }}>Back</Button> : null}{status.connection.currentFolder ? <><Button onClick={() => void createManagedFolder()} disabled={Boolean(action)}><Plus className="mr-2 h-4 w-4" />New folder</Button><Button variant="outline" asChild><label className="cursor-pointer"><Plus className="mr-2 h-4 w-4" />Upload file<input className="sr-only" type="file" onChange={(event) => { const file = event.target.files?.[0]; if (file) void uploadManagedFile(file); event.target.value = ''; }} /></label></Button></> : null}</div>{status.connection.currentFolder ? <p className="text-sm"><strong>Current folder:</strong> {status.connection.currentFolder.name}</p> : null}{status.connection.rootContents ? status.connection.rootContents.length ? <Table><TableHeader><TableRow><TableHead>Name</TableHead><TableHead>Type</TableHead><TableHead className="text-right">Actions</TableHead></TableRow></TableHeader><TableBody>{status.connection.rootContents.map((item) => { const isFolder = item.mimeType === 'application/vnd.google-apps.folder'; return <TableRow key={item.id}><TableCell>{isFolder ? <button className="font-medium text-primary underline" onClick={() => { const current = status.connection.currentFolder; if (current) setFolderStack((items) => [...items, { id: current.id, name: current.name }]); void listRootContents(item.id); }}>{item.name}</button> : item.webViewLink ? <a className="text-primary underline" href={item.webViewLink} target="_blank" rel="noreferrer">{item.name}</a> : item.name}</TableCell><TableCell>{isFolder ? 'Folder' : item.mimeType || 'File'}</TableCell><TableCell><div className="flex justify-end gap-2"><Button size="sm" variant="outline" onClick={() => void renameManagedItem(item)} disabled={Boolean(action)}><Pencil className="h-4 w-4" /></Button><Button size="sm" variant="destructive" onClick={() => void deleteManagedItem(item)} disabled={Boolean(action)}><Trash2 className="h-4 w-4" /></Button></div></TableCell></TableRow>; })}</TableBody></Table> : <p className="text-sm text-muted-foreground">This folder is empty.</p> : null}</CardContent></Card> : null}
            {status?.connection.status === 'CONNECTED' ? <DocketFolderGeneration /> : null}
            <Card><CardHeader><CardTitle>Troubleshooting checklist</CardTitle><CardDescription>Complete these checks in order, then restart the server and test again.</CardDescription></CardHeader><CardContent><ol className="list-decimal space-y-2 pl-5 text-sm"><li>Confirm the Google Drive API is enabled in the Google Cloud project that owns the OAuth client.</li><li>Confirm the client ID and client secret are from the same <strong>Web application</strong> OAuth client.</li><li>Generate the refresh token with that exact client and a Drive scope; for OAuth Playground, enable <strong>Use your own OAuth credentials</strong>.</li><li>Ensure the configured root folder ID is only the ID from the Drive URL—not the full URL—and the authorizing Google account can edit it.</li><li>After changing <code>.env.local</code>, fully stop and restart <code>npm run dev</code>. Environment files are not reliably reloaded into the running server.</li></ol><p className="mt-4 text-sm text-muted-foreground">A <code>400 invalid_grant</code> occurs before Drive folder access is tested. The usual fix is to issue a fresh refresh token using the same client ID and secret currently configured.</p></CardContent></Card>
            <Card><CardHeader><CardTitle>Drive CRUD diagnostic</CardTitle><CardDescription>Create, read, rename, and trash a protected diagnostic folder directly under the configured root. Only folders created here with the diagnostic prefix can be changed.</CardDescription></CardHeader><CardContent className="space-y-4">
              {!folder ? <Button onClick={() => void runFolderAction('create')} disabled={Boolean(action) || status?.connection.status !== 'CONNECTED'}><Plus className="mr-2 h-4 w-4" />{action === 'create' ? 'Creating…' : 'Create test folder'}</Button> : <><div className="rounded-md border p-4"><p className="text-sm text-muted-foreground">Current diagnostic folder</p><p className="font-mono text-sm">{folder.name}</p>{folder.webViewLink ? <a className="text-sm text-primary underline" href={folder.webViewLink} target="_blank" rel="noreferrer">Open in Google Drive</a> : null}</div><div className="flex flex-wrap gap-2"><Button variant="outline" onClick={() => void testUpload()} disabled={Boolean(action)}><Plus className="mr-2 h-4 w-4" />{action === 'upload' ? 'Uploading…' : 'Upload test text file'}</Button><Button variant="outline" onClick={() => void runFolderAction('rename')} disabled={Boolean(action)}><Pencil className="mr-2 h-4 w-4" />{action === 'rename' ? 'Renaming…' : 'Rename test folder'}</Button><Button variant="destructive" onClick={() => void runFolderAction('delete')} disabled={Boolean(action)}><Trash2 className="mr-2 h-4 w-4" />{action === 'delete' ? 'Deleting…' : 'Trash test folder'}</Button></div>{uploadedFile ? <Alert><CheckCircle2 className="h-4 w-4" /><AlertTitle>Upload succeeded</AlertTitle><AlertDescription>{uploadedFile.webViewLink ? <a className="underline" href={uploadedFile.webViewLink} target="_blank" rel="noreferrer">{uploadedFile.name}</a> : uploadedFile.name} was created in the diagnostic folder.</AlertDescription></Alert> : null}</>}
            </CardContent></Card>
          </div>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
