"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { ArrowLeft, CheckCircle2, FolderPlus, Loader2, RefreshCw, Upload, UploadCloud } from "lucide-react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { AttachmentWorkspace, type PreviewFile } from "@/components/drive-preview";
import type { OnlyOfficeSession } from "@/components/drive-preview/onlyoffice-editor";
import { DriveUploadManager, type UploadItem } from "@/components/drive-upload-manager";

type DriveFile = PreviewFile;

type DriveState = {
  files: DriveFile[];
  scannedAt: string;
  folder: { id: string; name: string; webViewLink: string | null };
  currentFolder: { id: string; name: string; webViewLink: string | null };
};

async function authenticatedRequest(caseId: number, path: string, method = "GET") {
  const supabase = await getSupabaseBrowserClient();
  const { data } = await supabase.auth.getSession();
  if (!data.session?.access_token) throw new Error("Your session has expired.");
  const response = await fetch(`/api/cases/${caseId}/drive/${path}`, {
    method,
    headers: { Authorization: `Bearer ${data.session.access_token}` },
    cache: "no-store",
  });
  const body = await response.json() as { data?: DriveState & { drive?: { status: string } }; error?: { message?: string; canCreate?: boolean } };
  return { response, body };
}

export function CaseDriveAttachments({ caseId, docketYear, docketType, docketNumber, onPreviewChange }: { caseId: number; docketYear: number | null; docketType: string | null; docketNumber: string | null; onPreviewChange?: (active: boolean, widthPercent?: number) => void }) {
  const [drive, setDrive] = useState<DriveState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [canCreate, setCanCreate] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [creating, setCreating] = useState(false);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const [folderStack, setFolderStack] = useState<Array<{ id: string; name: string }>>([]);
  const [folderCreated, setFolderCreated] = useState(false);
  const [uploads, setUploads] = useState<UploadItem[]>([]);
  const [dragging, setDragging] = useState(false);
  const [managingFolderId, setManagingFolderId] = useState<string | null>(null);
  const [creatingChildFolder, setCreatingChildFolder] = useState(false);
  const [managingFileId, setManagingFileId] = useState<string | null>(null);
  const [canShareFiles, setCanShareFiles] = useState(false);
  const uploadRequests = useRef(new Map<string, XMLHttpRequest>());
  const uploadInput = useRef<HTMLInputElement>(null);
  const uploadDismissTimers = useRef(new Set<ReturnType<typeof setTimeout>>());
  const loadSequence = useRef(0);
  const currentFolderId = useRef<string | null>(null);

  useEffect(() => () => { uploadRequests.current.forEach((request) => request.abort()); uploadDismissTimers.current.forEach(clearTimeout); }, []);
  useEffect(() => { setCanShareFiles(typeof navigator !== "undefined" && typeof navigator.share === "function" && typeof navigator.canShare === "function"); }, []);

  const load = useCallback(async (folderId?: string, background = false) => {
    const sequence = ++loadSequence.current;
    if (background) setRefreshing(true); else setLoading(true);
    setError(null); setFolderCreated(false);
    try {
      const { response, body } = await authenticatedRequest(caseId, folderId ? `files?folderId=${encodeURIComponent(folderId)}` : "files");
      if (!response.ok || !body.data) {
        setCanCreate(Boolean(body.error?.canCreate));
        throw new Error(body.error?.message ?? "Unable to read Google Drive attachments.");
      }
      if (sequence === loadSequence.current) { setDrive(body.data); currentFolderId.current = body.data.currentFolder.id; setCanCreate(false); }
    } catch (loadError) { if (sequence === loadSequence.current) setError(loadError instanceof Error ? loadError.message : "Unable to read Google Drive attachments."); }
    finally { if (sequence === loadSequence.current) { if (background) setRefreshing(false); else setLoading(false); } }
  }, [caseId]);

  useEffect(() => { void load(); }, [load]);

  async function createFolder() {
    setCreating(true); setError(null);
    try {
      const { response, body } = await authenticatedRequest(caseId, "retry", "POST");
      if (!response.ok || body.data?.drive?.status !== "READY") throw new Error(body.error?.message ?? "Google Drive folder creation failed.");
      // A newly provisioned docket folder is empty by definition. Avoid an
      // immediate redundant Drive listing; Refresh remains available on demand.
      setCanCreate(false);
      setDrive(null);
      setFolderStack([]);
      setFolderCreated(true);
    } catch (createError) { setError(createError instanceof Error ? createError.message : "Google Drive folder creation failed."); }
    finally { setCreating(false); }
  }

  async function fetchFileBlob(file: DriveFile) {
      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getSession();
      if (!data.session?.access_token) throw new Error("Your session has expired.");
      const response = await fetch(`/api/cases/${caseId}/drive/files/${encodeURIComponent(file.id)}/download`, { headers: { Authorization: `Bearer ${data.session.access_token}` } });
      if (!response.ok) {
        const body = await response.json().catch(() => null) as { error?: { message?: string } } | null;
        throw new Error(body?.error?.message ?? "Unable to download the file.");
      }
      return { blob: await response.blob(), disposition: response.headers.get("content-disposition") ?? "" };
  }

  async function loadPreviewBlob(file: DriveFile) {
    return (await fetchFileBlob(file)).blob;
  }

  async function startDocumentEdit(file: DriveFile): Promise<OnlyOfficeSession> {
    const supabase = await getSupabaseBrowserClient();
    const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) throw new Error("Your session has expired.");
    const response = await fetch(`/api/cases/${caseId}/drive/edit/start`, { method: "POST", headers: { "content-type": "application/json", Authorization: `Bearer ${data.session.access_token}` }, body: JSON.stringify({ fileId: file.id }) });
    const body = await response.json() as { data?: OnlyOfficeSession; error?: { message?: string } };
    if (!response.ok || !body.data) throw new Error(body.error?.message ?? "Unable to start the document editor.");
    return body.data;
  }

  async function checkDocumentEditStatus(sessionId: string) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) throw new Error("Your session has expired.");
    const response = await fetch(`/api/cases/${caseId}/drive/edit/${sessionId}/status`, { headers: { Authorization: `Bearer ${data.session.access_token}` }, cache: "no-store" });
    const body = await response.json() as { data?: { status: string; last_error?: string | null }; error?: { message?: string } };
    if (!response.ok || !body.data) throw new Error(body.error?.message ?? "Unable to read edit status.");
    return body.data;
  }

  async function cancelDocumentEditSession(sessionId: string) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) return;
    await fetch(`/api/cases/${caseId}/drive/edit/${sessionId}/status`, { method: "DELETE", headers: { Authorization: `Bearer ${data.session.access_token}` } });
  }

  async function downloadFile(file: DriveFile) {
    setDownloadingId(file.id); setError(null);
    try {
      const downloaded = await fetchFileBlob(file);
      const url = URL.createObjectURL(downloaded.blob);
      const disposition = downloaded.disposition;
      const encodedName = disposition.match(/filename\*=UTF-8''([^;]+)/i)?.[1];
      const downloadName = encodedName ? decodeURIComponent(encodedName) : file.name;
      const anchor = document.createElement("a");
      anchor.href = url; anchor.download = downloadName; document.body.appendChild(anchor); anchor.click(); anchor.remove();
      URL.revokeObjectURL(url);
    } catch (downloadError) { setError(downloadError instanceof Error ? downloadError.message : "Unable to download the file."); }
    finally { setDownloadingId(null); }
  }

  async function uploadOne(item: UploadItem) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) { setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, status: "failed", error: "Your session has expired." } : upload)); return; }
    const request = new XMLHttpRequest(); uploadRequests.current.set(item.id, request);
    setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, status: "uploading", progress: 0, error: undefined } : upload));
    request.upload.onprogress = (event) => { if (event.lengthComputable) setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, progress: Math.min(99, Math.round(event.loaded / event.total * 100)) } : upload)); };
    request.onload = () => {
      uploadRequests.current.delete(item.id);
      if (request.status >= 200 && request.status < 300) {
        setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, status: "complete", progress: 100 } : upload));
        if (currentFolderId.current === item.destinationId) {
          try {
            const uploaded = (JSON.parse(request.responseText) as { data?: { item?: Partial<DriveFile> } }).data?.item;
            if (uploaded?.id && uploaded.name) setDrive((current) => current && current.currentFolder.id === item.destinationId ? { ...current, files: [...current.files.filter((file) => file.id !== uploaded.id), { id: uploaded.id!, name: uploaded.name!, mimeType: uploaded.mimeType || item.file.type || "application/octet-stream", webViewLink: uploaded.webViewLink ?? null, webContentLink: uploaded.webContentLink ?? null, size: uploaded.size ?? String(item.file.size), modifiedTime: uploaded.modifiedTime ?? new Date().toISOString() }] } : current);
          } catch { /* The background refresh remains authoritative. */ }
          void load(item.destinationId, true);
        }
        const timer = setTimeout(() => { setUploads((items) => items.filter((upload) => upload.id !== item.id)); uploadDismissTimers.current.delete(timer); }, 1200); uploadDismissTimers.current.add(timer);
        return;
      }
      let message = "The file could not be uploaded."; try { message = (JSON.parse(request.responseText) as { error?: { message?: string } }).error?.message ?? message; } catch { /* Non-JSON error response. */ }
      setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, status: "failed", error: message } : upload));
    };
    request.onerror = () => { uploadRequests.current.delete(item.id); setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, status: "failed", error: "A network error interrupted the upload." } : upload)); };
    request.onabort = () => { uploadRequests.current.delete(item.id); setUploads((items) => items.map((upload) => upload.id === item.id ? { ...upload, status: "cancelled", error: undefined } : upload)); };
    const form = new FormData(); form.append("parentId", item.destinationId); form.append("file", item.file);
    request.open("POST", `/api/cases/${caseId}/drive/upload`); request.setRequestHeader("Authorization", `Bearer ${data.session.access_token}`); request.send(form);
  }

  function addUploads(files: File[]) {
    if (!drive || !files.length) return;
    const items = files.map<UploadItem>((file) => ({ id: crypto.randomUUID(), file, destinationId: drive.currentFolder.id, progress: 0, status: "queued" }));
    const valid: UploadItem[] = []; const rejected: UploadItem[] = [];
    items.forEach((item) => { if (!item.file.name.trim()) rejected.push({ ...item, status: "failed", error: "The file name is invalid." }); else if (!item.file.size) rejected.push({ ...item, status: "failed", error: "Empty files cannot be uploaded." }); else if (item.file.size > 100 * 1024 * 1024) rejected.push({ ...item, status: "failed", error: "Each upload is limited to 100 MB." }); else valid.push(item); });
    setUploads((current) => [...valid, ...rejected, ...current].slice(0, 50)); valid.forEach((item) => void uploadOne(item));
  }

  function retryUpload(id: string) { const item = uploads.find((upload) => upload.id === id); if (item) void uploadOne(item); }

  async function folderRequest(method: "POST" | "PATCH" | "DELETE", body?: Record<string, string>, folderId?: string) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession();
    if (!data.session?.access_token) throw new Error("Your session has expired.");
    const query = folderId ? `?folderId=${encodeURIComponent(folderId)}` : "";
    const response = await fetch(`/api/cases/${caseId}/drive/folders${query}`, { method, headers: { Authorization: `Bearer ${data.session.access_token}`, ...(body ? { "content-type": "application/json" } : {}) }, body: body ? JSON.stringify(body) : undefined });
    const result = await response.json().catch(() => null) as { error?: { message?: string } } | null;
    if (!response.ok) throw new Error(result?.error?.message ?? "The folder operation failed.");
  }

  async function createChildFolder() {
    if (!drive) return; const name = window.prompt("New folder name"); if (name === null) return;
    if (!name.trim()) { setError("Enter a folder name."); return; }
    setCreatingChildFolder(true); setError(null);
    try { await folderRequest("POST", { parentId: drive.currentFolder.id, name }); await load(drive.currentFolder.id, true); }
    catch (operationError) { setError(operationError instanceof Error ? operationError.message : "The folder could not be created."); }
    finally { setCreatingChildFolder(false); }
  }

  async function renameFolder(folder: DriveFile) {
    if (!drive) return; const name = window.prompt("Rename folder", folder.name); if (name === null || name === folder.name) return;
    if (!name.trim()) { setError("Enter a folder name."); return; }
    setManagingFolderId(folder.id); setError(null);
    try { await folderRequest("PATCH", { folderId: folder.id, name }); await load(drive.currentFolder.id, true); }
    catch (operationError) { setError(operationError instanceof Error ? operationError.message : "The folder could not be renamed."); }
    finally { setManagingFolderId(null); }
  }

  async function trashFolder(folder: DriveFile) {
    if (!drive || !window.confirm(`Move “${folder.name}” and all of its contents to Google Drive trash?`)) return;
    setManagingFolderId(folder.id); setError(null);
    try { await folderRequest("DELETE", undefined, folder.id); await load(drive.currentFolder.id, true); }
    catch (operationError) { setError(operationError instanceof Error ? operationError.message : "The folder could not be moved to trash."); }
    finally { setManagingFolderId(null); }
  }

  async function fileRequest(file: DriveFile, method: "PATCH" | "DELETE", body?: Record<string, string>) {
    const supabase = await getSupabaseBrowserClient(); const { data } = await supabase.auth.getSession(); if (!data.session?.access_token) throw new Error("Your session has expired.");
    const response = await fetch(`/api/cases/${caseId}/drive/files/${encodeURIComponent(file.id)}`, { method, headers: { Authorization: `Bearer ${data.session.access_token}`, ...(body ? { "content-type": "application/json" } : {}) }, body: body ? JSON.stringify(body) : undefined });
    const result = await response.json().catch(() => null) as { error?: { message?: string } } | null; if (!response.ok) throw new Error(result?.error?.message ?? "The file operation failed.");
  }

  async function shareFile(file: DriveFile) {
    try { const downloaded = await fetchFileBlob(file); const sharedFile = new File([downloaded.blob], file.name, { type: file.mimeType || downloaded.blob.type || "application/octet-stream" }); if (!navigator.canShare?.({ files: [sharedFile] })) throw new Error("This browser cannot share this file."); await navigator.share({ title: file.name, files: [sharedFile] }); }
    catch (shareError) { if (shareError instanceof DOMException && shareError.name === "AbortError") return; setError(shareError instanceof Error ? shareError.message : "The file could not be shared."); }
  }

  async function renameFile(file: DriveFile) {
    if (!drive) return; const name = window.prompt("Rename file", file.name); if (name === null || name === file.name) return; if (!name.trim()) { setError("Enter a file name."); return; }
    setManagingFileId(file.id); setError(null);
    try { await fileRequest(file, "PATCH", { action: "rename", name }); setDrive((current) => current ? { ...current, files: current.files.map((item) => item.id === file.id ? { ...item, name: name.trim(), modifiedTime: new Date().toISOString() } : item) } : current); void load(drive.currentFolder.id, true); }
    catch (operationError) { setError(operationError instanceof Error ? operationError.message : "The file could not be renamed."); } finally { setManagingFileId(null); }
  }

  async function moveFile(file: DriveFile) {
    if (!drive) return;
    const candidates = [...folderStack, ...drive.files.filter((item) => item.mimeType === "application/vnd.google-apps.folder").map((item) => ({ id: item.id, name: item.name }))].filter((folder, index, all) => all.findIndex((item) => item.id === folder.id) === index && folder.id !== drive.currentFolder.id);
    if (!candidates.length) { setError("Create or browse to another folder before moving this file."); return; }
    const choice = window.prompt(`Move “${file.name}” to:\n${candidates.map((folder, index) => `${index + 1}. ${folder.name}`).join("\n")}\n\nEnter a folder number:`); if (choice === null) return;
    const destination = candidates[Number(choice) - 1]; if (!destination) { setError("Choose a valid destination folder number."); return; }
    setManagingFileId(file.id); setError(null);
    try { await fileRequest(file, "PATCH", { action: "move", destinationFolderId: destination.id }); setDrive((current) => current ? { ...current, files: current.files.filter((item) => item.id !== file.id) } : current); void load(drive.currentFolder.id, true); }
    catch (operationError) { setError(operationError instanceof Error ? operationError.message : "The file could not be moved."); } finally { setManagingFileId(null); }
  }

  async function trashFile(file: DriveFile) {
    if (!drive || !window.confirm(`Move “${file.name}” to Google Drive trash?`)) return; setManagingFileId(file.id); setError(null);
    try { await fileRequest(file, "DELETE"); setDrive((current) => current ? { ...current, files: current.files.filter((item) => item.id !== file.id) } : current); void load(drive.currentFolder.id, true); }
    catch (operationError) { setError(operationError instanceof Error ? operationError.message : "The file could not be moved to trash."); } finally { setManagingFileId(null); }
  }

  function browseFolder(folder: DriveFile) {
    if (!drive) return;
    setFolderStack((items) => [...items, { id: drive.currentFolder.id, name: drive.currentFolder.name }]);
    void load(folder.id);
  }

  function browseBack() {
    const parent = folderStack[folderStack.length - 1];
    if (!parent) return;
    setFolderStack((items) => items.slice(0, -1));
    void load(parent.id);
  }

  const nestedLocation = drive && drive.currentFolder.id !== drive.folder.id
    ? [...folderStack.slice(1).map((folder) => folder.name), drive.currentFolder.name]
    : [];

  const destination = `${docketYear ?? "Unknown year"} / ${docketType ?? "Unknown type"} / ${docketNumber ?? "Unknown docket"}${nestedLocation.length ? ` / ${nestedLocation.join(" / ")}` : ""}`;

  return <div className={`relative space-y-4 rounded-lg transition-colors ${dragging ? "bg-primary/5 ring-2 ring-primary ring-offset-4" : ""}`} onDragEnter={(event) => { event.preventDefault(); if (drive && event.dataTransfer.types.includes("Files")) setDragging(true); }} onDragOver={(event) => { event.preventDefault(); if (drive) event.dataTransfer.dropEffect = "copy"; }} onDragLeave={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setDragging(false); }} onDrop={(event) => { event.preventDefault(); setDragging(false); addUploads(Array.from(event.dataTransfer.files)); }}>
    {dragging ? <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center rounded-lg bg-background/90"><div className="text-center"><UploadCloud className="mx-auto mb-2 h-10 w-10 text-primary" /><p className="font-semibold">Drop files to upload</p><p className="text-sm text-muted-foreground">Destination: {destination}</p></div></div> : null}
    <div className="flex flex-wrap items-center justify-between gap-3">
      <p className="text-sm text-muted-foreground">Location: <strong>{docketYear ?? "Unknown year"}</strong> / <strong>{docketType ?? "Unknown type"}</strong> / <strong>{docketNumber ?? "Unknown docket"}</strong>{nestedLocation.map((name, index) => <span key={`${name}-${index}`}> / <strong>{name}</strong></span>)}</p>
      <div className="flex gap-2">
        {folderStack.length ? <Button variant="outline" onClick={browseBack} disabled={loading}><ArrowLeft className="mr-2 h-4 w-4" />Back</Button> : null}
        {drive ? <Button variant="outline" onClick={() => void createChildFolder()} disabled={loading || creatingChildFolder}><FolderPlus className="mr-2 h-4 w-4" />{creatingChildFolder ? "Creating…" : "Create Folder"}</Button> : null}
        {drive ? <><input ref={uploadInput} type="file" multiple className="sr-only" onChange={(event) => { addUploads(Array.from(event.target.files ?? [])); event.target.value = ""; }} /><Button variant="outline" onClick={() => uploadInput.current?.click()} disabled={loading || creating}><Upload className="mr-2 h-4 w-4" />Upload Files</Button></> : null}
        <Button variant="outline" onClick={() => void load(drive?.currentFolder.id, Boolean(drive))} disabled={loading || refreshing || creating}><RefreshCw className={`mr-2 h-4 w-4 ${loading || refreshing ? "animate-spin" : ""}`} />Refresh</Button>
      </div>
    </div>
    {loading && !drive ? <div className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" />Finding the docket folder and loading files…</div> : null}
    {creating ? <div className="flex items-center gap-2 text-sm text-muted-foreground"><Loader2 className="h-4 w-4 animate-spin" />Creating folder</div> : null}
    {folderCreated ? <div className="flex items-center gap-3 rounded-lg border border-green-200 bg-green-50 p-4 text-green-800"><CheckCircle2 className="h-6 w-6 motion-safe:animate-[bounce_600ms_ease-out_1]" /><div><p className="font-medium">Folder created</p><p className="text-sm">The new Google Drive docket folder is empty.</p></div></div> : null}
    {error ? <Alert variant="destructive"><AlertTitle>Google Drive unavailable</AlertTitle><AlertDescription className="space-y-3"><p>{error}</p>{canCreate ? <Button onClick={() => void createFolder()} disabled={creating}><FolderPlus className="mr-2 h-4 w-4" />Create GDrive folder</Button> : null}</AlertDescription></Alert> : null}
    {drive ? <DriveUploadManager uploads={uploads} onCancel={(id) => uploadRequests.current.get(id)?.abort()} onRetry={retryUpload} /> : null}
    {drive && !loading ? <AttachmentWorkspace files={drive.files} downloadingId={downloadingId} managingFolderId={managingFolderId} managingFileId={managingFileId} canShare={canShareFiles} onBrowse={browseFolder} onDownload={(file) => void downloadFile(file)} onShare={(file) => void shareFile(file)} onRenameFile={(file) => void renameFile(file)} onMoveFile={(file) => void moveFile(file)} onTrashFile={(file) => void trashFile(file)} onRenameFolder={(folder) => void renameFolder(folder)} onTrashFolder={(folder) => void trashFolder(folder)} loadBlob={loadPreviewBlob} startEdit={startDocumentEdit} checkEditStatus={checkDocumentEditStatus} cancelEditSession={cancelDocumentEditSession} onDocumentSaved={() => void load(drive.currentFolder.id)} onPreviewChange={onPreviewChange} onError={setError} /> : null}
  </div>;
}
