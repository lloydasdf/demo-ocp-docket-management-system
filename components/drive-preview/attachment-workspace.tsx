"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { GripVertical } from "lucide-react";
import { Panel, PanelGroup, PanelResizeHandle } from "react-resizable-panels";
import { AttachmentList } from "./attachment-list";
import { AttachmentPreviewPane } from "./attachment-preview-pane";
import { isExecutable, type PreviewFile } from "./types";

export function AttachmentWorkspace({ files, downloadingId, onBrowse, onDownload, loadBlob, onPreviewChange, onError }: { files: PreviewFile[]; downloadingId: string | null; onBrowse: (file: PreviewFile) => void; onDownload: (file: PreviewFile) => void; loadBlob: (file: PreviewFile) => Promise<Blob>; onPreviewChange?: (active: boolean, widthPercent?: number) => void; onError: (message: string) => void }) {
  const [selected, setSelected] = useState<PreviewFile | null>(null); const [blob, setBlob] = useState<Blob | null>(null); const [url, setUrl] = useState<string | null>(null); const [loading, setLoading] = useState(false);
  useEffect(() => () => { if (url) URL.revokeObjectURL(url); }, [url]);
  useEffect(() => () => onPreviewChange?.(false), [onPreviewChange]);
  useEffect(() => { if (selected && !files.some((file) => file.id === selected.id)) { setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false); } }, [files, selected, onPreviewChange]);
  async function select(file: PreviewFile) { setSelected(file); setBlob(null); setLoading(true); onPreviewChange?.(true); try { const nextBlob = isExecutable(file) ? new Blob([], { type: file.mimeType || "application/octet-stream" }) : await loadBlob(file); setBlob(nextBlob); setUrl((old) => { if (old) URL.revokeObjectURL(old); return URL.createObjectURL(nextBlob); }); } catch (error) { onError(error instanceof Error ? error.message : "Unable to load preview."); setSelected(null); onPreviewChange?.(false); } finally { setLoading(false); } }
  function close() { setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false); }
  async function share() { if (!selected) return; try { if (isExecutable(selected)) throw new Error("Executable files cannot be shared from the preview workspace."); const content = blob ?? await loadBlob(selected); const shareFile = new File([content], selected.name, { type: selected.mimeType || content.type }); if (navigator.share && navigator.canShare?.({ files: [shareFile] })) await navigator.share({ title: selected.name, files: [shareFile] }); else throw new Error("File sharing is not supported by this browser. Download the file to share it manually."); } catch (error) { onError(error instanceof Error ? error.message : "Unable to share file."); } }
  const preview = selected ? <AttachmentPreviewPane key={selected.id} file={selected} blob={blob} url={url} loading={loading} onShare={() => void share()} onDownload={() => onDownload(selected)} onClose={close} /> : null;
  return <><AttachmentList files={files} selectedId={selected?.id} downloadingId={downloadingId} onSelect={(file) => void select(file)} onDownload={onDownload} onBrowse={onBrowse} />{preview ? <div className="mt-4 lg:hidden">{preview}</div> : null}{preview && typeof document !== "undefined" ? createPortal(<PanelGroup direction="horizontal" autoSaveId="case-attachment-preview-layout" onLayout={(layout) => onPreviewChange?.(true, layout[1])} className="pointer-events-none fixed inset-0 z-40 hidden lg:flex"><Panel defaultSize={52} minSize={35} /><PanelResizeHandle className="pointer-events-auto relative flex w-2 cursor-col-resize items-center justify-center bg-border transition-colors hover:bg-primary/30 data-[resize-handle-active]:bg-primary/40"><span className="absolute flex h-10 w-5 items-center justify-center rounded border bg-background shadow"><GripVertical className="h-4 w-4" /></span></PanelResizeHandle><Panel defaultSize={48} minSize={28} maxSize={65} className="pointer-events-auto animate-in slide-in-from-right bg-background p-3 shadow-2xl duration-300">{preview}</Panel></PanelGroup>, document.body) : null}</>;
}
