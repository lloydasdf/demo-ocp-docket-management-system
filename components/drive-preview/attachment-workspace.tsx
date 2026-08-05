"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { GripVertical } from "lucide-react";
import { Panel, PanelGroup, PanelResizeHandle } from "react-resizable-panels";
import { AttachmentList, type AttachmentSortOption } from "./attachment-list";
import { AttachmentPreviewPane } from "./attachment-preview-pane";
import { isExecutable, type PreviewFile } from "./types";
import type { OnlyOfficeSession } from "./onlyoffice-editor";

export function AttachmentWorkspace({ files, sort, downloadingId, managingFolderId, managingFileId, canShare, onBrowse, onDownload, onShare, onRenameFile, onMoveFile, onTrashFile, onRenameFolder, onTrashFolder, loadBlob, startEdit, checkEditStatus, cancelEditSession, onDocumentSaved, previewPlacement = "responsive", onPreviewChange, onError }: { files: PreviewFile[]; sort: AttachmentSortOption; downloadingId: string | null; managingFolderId?: string | null; managingFileId?: string | null; canShare?: boolean; onBrowse: (file: PreviewFile) => void; onDownload: (file: PreviewFile) => void; onShare: (file: PreviewFile) => void; onRenameFile: (file: PreviewFile) => void; onMoveFile: (file: PreviewFile) => void; onTrashFile: (file: PreviewFile) => void; onRenameFolder: (file: PreviewFile) => void; onTrashFolder: (file: PreviewFile) => void; loadBlob: (file: PreviewFile) => Promise<Blob>; startEdit: (file: PreviewFile) => Promise<OnlyOfficeSession>; checkEditStatus: (sessionId: string) => Promise<{ status: string; last_error?: string | null }>; cancelEditSession: (sessionId: string) => Promise<void>; onDocumentSaved: () => void; previewPlacement?: "responsive" | "modal"; onPreviewChange?: (active: boolean, widthPercent?: number) => void; onError: (message: string) => void }) {
  const [selected, setSelected] = useState<PreviewFile | null>(null); const [blob, setBlob] = useState<Blob | null>(null); const [url, setUrl] = useState<string | null>(null); const [loading, setLoading] = useState(false);
  const [previewMode, setPreviewMode] = useState<"mobile" | "tablet" | "desktop">("mobile");
  const historyMarker = useRef(`attachment-preview-${Math.random().toString(36).slice(2)}`); const previewScrollY = useRef(0); const historyActive = useRef(false);
  useEffect(() => { const updateMode = () => setPreviewMode(window.innerWidth < 768 ? "mobile" : window.innerWidth < 1024 ? "tablet" : "desktop"); updateMode(); window.addEventListener("resize", updateMode); return () => window.removeEventListener("resize", updateMode); }, []);
  useEffect(() => { if (!selected || previewMode === "desktop") return; const previousOverflow = document.body.style.overflow; document.body.style.overflow = "hidden"; return () => { document.body.style.overflow = previousOverflow; }; }, [previewMode, selected]);
  const narrowPreviewOpen = Boolean(selected) && previewMode !== "desktop";
  useEffect(() => {
    if (!narrowPreviewOpen) return;
    previewScrollY.current = window.scrollY;
    if (!historyActive.current) { window.history.pushState({ ...window.history.state, attachmentPreview: historyMarker.current }, ""); historyActive.current = true; }
    const handlePopState = () => {
      if (!historyActive.current) return;
      historyActive.current = false; setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false);
      requestAnimationFrame(() => window.scrollTo({ top: previewScrollY.current }));
    };
    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, [narrowPreviewOpen, onPreviewChange]);
  useEffect(() => () => { if (url) URL.revokeObjectURL(url); }, [url]);
  useEffect(() => () => onPreviewChange?.(false), [onPreviewChange]);
  useEffect(() => { if (selected && !files.some((file) => file.id === selected.id)) { setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false); } }, [files, selected, onPreviewChange]);
  async function select(file: PreviewFile) { setSelected(file); setBlob(null); setLoading(true); onPreviewChange?.(true); try { const nextBlob = isExecutable(file) ? new Blob([], { type: file.mimeType || "application/octet-stream" }) : await loadBlob(file); setBlob(nextBlob); setUrl((old) => { if (old) URL.revokeObjectURL(old); return URL.createObjectURL(nextBlob); }); } catch (error) { onError(error instanceof Error ? error.message : "Unable to load preview."); setSelected(null); onPreviewChange?.(false); } finally { setLoading(false); } }
  function close() { const removeHistoryEntry = historyActive.current && window.history.state?.attachmentPreview === historyMarker.current; historyActive.current = false; setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false); if (removeHistoryEntry) window.history.back(); requestAnimationFrame(() => window.scrollTo({ top: previewScrollY.current })); }
  async function share() { if (!selected) return; try { if (isExecutable(selected)) throw new Error("Executable files cannot be shared from the preview workspace."); const content = blob ?? await loadBlob(selected); const shareFile = new File([content], selected.name, { type: selected.mimeType || content.type }); if (navigator.share && navigator.canShare?.({ files: [shareFile] })) await navigator.share({ title: selected.name, files: [shareFile] }); else throw new Error("File sharing is not supported by this browser. Download the file to share it manually."); } catch (error) { onError(error instanceof Error ? error.message : "Unable to share file."); } }
  async function refreshAfterSave() { if (!selected) return; try { const nextBlob = await loadBlob(selected); setBlob(nextBlob); setUrl((old) => { if (old) URL.revokeObjectURL(old); return URL.createObjectURL(nextBlob); }); onDocumentSaved(); } catch (error) { onError(error instanceof Error ? error.message : 'The saved document could not be refreshed.'); } }
  const preview = selected ? <AttachmentPreviewPane key={selected.id} file={selected} blob={blob} url={url} loading={loading} narrow={previewMode !== "desktop"} onShare={() => void share()} onDownload={() => onDownload(selected)} onStartEdit={() => startEdit(selected)} checkEditStatus={checkEditStatus} cancelEditSession={cancelEditSession} onSaved={() => void refreshAfterSave()} onError={onError} onClose={close} /> : null;
  const previewLayer = preview && typeof document !== "undefined" ? previewPlacement === "modal"
    ? <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" role="presentation" onPointerDown={(event) => { if (event.target === event.currentTarget) close(); }}><div role="dialog" aria-modal="true" aria-label="Attachment preview" className="h-[min(88vh,54rem)] w-[min(92vw,70rem)] animate-in zoom-in-95 rounded-lg bg-background p-3 shadow-2xl duration-200">{preview}</div></div>
    : previewMode === "desktop"
    ? <PanelGroup direction="horizontal" autoSaveId="case-attachment-preview-layout" onLayout={(layout) => onPreviewChange?.(true, layout[1])} className="pointer-events-none fixed inset-0 z-40 flex"><Panel defaultSize={52} minSize={35} /><PanelResizeHandle className="pointer-events-auto relative flex w-2 cursor-col-resize items-center justify-center bg-border transition-colors hover:bg-primary/30 data-[resize-handle-active]:bg-primary/40"><span className="absolute flex h-10 w-5 items-center justify-center rounded border bg-background shadow"><GripVertical className="h-4 w-4" /></span></PanelResizeHandle><Panel defaultSize={48} minSize={28} maxSize={65} className="pointer-events-auto animate-in slide-in-from-right bg-background p-3 shadow-2xl duration-300">{preview}</Panel></PanelGroup>
    : previewMode === "tablet"
      ? <div className="fixed inset-0 z-50 bg-black/25" role="presentation" onPointerDown={(event) => { if (event.target === event.currentTarget) close(); }}><aside aria-label="Attachment preview" className="ml-auto h-full w-[min(82vw,46rem)] animate-in slide-in-from-right bg-background p-3 shadow-2xl duration-300">{preview}</aside></div>
      : <div className="fixed inset-0 z-50 bg-background p-0 [&>section]:rounded-none [&>section]:border-0" aria-label="Attachment preview">{preview}</div>
    : null;
  return <><AttachmentList files={files} sort={sort} selectedId={selected?.id} downloadingId={downloadingId} managingFolderId={managingFolderId} managingFileId={managingFileId} canShare={canShare} onSelect={(file) => void select(file)} onDownload={onDownload} onShare={onShare} onRenameFile={onRenameFile} onMoveFile={onMoveFile} onTrashFile={onTrashFile} onBrowse={onBrowse} onRenameFolder={onRenameFolder} onTrashFolder={onTrashFolder} />{previewLayer ? createPortal(previewLayer, document.body) : null}</>;
}
