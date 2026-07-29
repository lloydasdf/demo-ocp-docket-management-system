"use client";

import { useCallback, useRef, useState } from "react";
import { Loader2 } from "lucide-react";
import { FilePreview } from "./file-preview";
import { PreviewToolbar } from "./preview-toolbar";
import type { PreviewFile } from "./types";
import { OnlyOfficeEditor, type OnlyOfficeSession } from "./onlyoffice-editor";

export function AttachmentPreviewPane({ file, blob, url, loading, narrow, onShare, onDownload, onStartEdit, checkEditStatus, cancelEditSession, onSaved, onError, onClose }: { file: PreviewFile; blob: Blob | null; url: string | null; loading: boolean; narrow: boolean; onShare: () => void; onDownload: () => void; onStartEdit: () => Promise<OnlyOfficeSession>; checkEditStatus: (sessionId: string) => Promise<{ status: string; last_error?: string | null }>; cancelEditSession: (sessionId: string) => Promise<void>; onSaved: () => void; onError: (message: string) => void; onClose: () => void }) {
  const [zoom, setZoom] = useState(1); const [rotation, setRotation] = useState(0); const [editor, setEditor] = useState<OnlyOfficeSession | null>(null); const [launching, setLaunching] = useState(false); const paneRef = useRef<HTMLDivElement>(null);
  const extension = file.name.split('.').pop()?.toLowerCase(); const mobilePdf = narrow && (extension === 'pdf' || blob?.type === 'application/pdf'); const canEdit = extension === 'docx' || extension === 'xlsx' || extension === 'pptx';
  const startEdit = useCallback(async () => { setLaunching(true); try { setEditor(await onStartEdit()); } catch (error) { onError(error instanceof Error ? error.message : 'Unable to launch document editor.'); } finally { setLaunching(false); } }, [onError, onStartEdit]);
  const editorSaved = useCallback(() => { setEditor(null); onSaved(); }, [onSaved]); const editorError = useCallback((message: string) => onError(message), [onError]);
  return <section ref={paneRef} className="flex h-full min-h-[72vh] flex-col overflow-hidden rounded-lg border bg-background shadow-xl">{!mobilePdf ? <PreviewToolbar file={file} zoom={zoom} rotation={rotation} canEdit={canEdit} editing={Boolean(editor) || launching} onEdit={() => void startEdit()} onZoom={setZoom} onRotate={() => setRotation((value) => (value + 90) % 360)} onShare={onShare} onDownload={onDownload} onFullscreen={() => void paneRef.current?.requestFullscreen()} onClose={onClose} /> : null}<div className="flex flex-1 items-center justify-center overflow-auto bg-muted/40 p-3">{editor ? <OnlyOfficeEditor session={editor} checkStatus={checkEditStatus} cancelSession={cancelEditSession} onSaved={editorSaved} onError={editorError} /> : loading || launching || !blob || !url ? <div className="flex items-center gap-2 text-muted-foreground"><Loader2 className="h-5 w-5 animate-spin" />{launching ? 'Starting editor…' : 'Loading preview…'}</div> : <div style={mobilePdf ? undefined : { transform: `scale(${zoom}) rotate(${rotation}deg)`, transformOrigin: "center" }} className="flex h-full w-full items-center justify-center transition-transform"><FilePreview file={file} blob={blob} url={url} narrow={narrow} onShare={onShare} onDownload={onDownload} onClose={onClose} /></div>}</div></section>;
}
