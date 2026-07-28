"use client";

import { useEffect, useState } from "react";
import { AttachmentList } from "./attachment-list";
import { AttachmentPreviewPane } from "./attachment-preview-pane";
import { isExecutable, type PreviewFile } from "./types";

export function AttachmentWorkspace({ files, downloadingId, onBrowse, onDownload, loadBlob, onPreviewChange, onError }: { files: PreviewFile[]; downloadingId: string | null; onBrowse: (file: PreviewFile) => void; onDownload: (file: PreviewFile) => void; loadBlob: (file: PreviewFile) => Promise<Blob>; onPreviewChange?: (active: boolean) => void; onError: (message: string) => void }) {
  const [selected, setSelected] = useState<PreviewFile | null>(null); const [blob, setBlob] = useState<Blob | null>(null); const [url, setUrl] = useState<string | null>(null); const [loading, setLoading] = useState(false);
  useEffect(() => () => { if (url) URL.revokeObjectURL(url); }, [url]);
  useEffect(() => { if (selected && !files.some((file) => file.id === selected.id)) { setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false); } }, [files, selected, onPreviewChange]);
  async function select(file: PreviewFile) { setSelected(file); setBlob(null); setLoading(true); onPreviewChange?.(true); try { const nextBlob = isExecutable(file) ? new Blob([], { type: file.mimeType || "application/octet-stream" }) : await loadBlob(file); setBlob(nextBlob); setUrl((old) => { if (old) URL.revokeObjectURL(old); return URL.createObjectURL(nextBlob); }); } catch (error) { onError(error instanceof Error ? error.message : "Unable to load preview."); setSelected(null); onPreviewChange?.(false); } finally { setLoading(false); } }
  function close() { setSelected(null); setBlob(null); setUrl((old) => { if (old) URL.revokeObjectURL(old); return null; }); onPreviewChange?.(false); }
  async function share() { if (!selected) return; try { if (isExecutable(selected)) throw new Error("Executable files cannot be shared from the preview workspace."); const content = blob ?? await loadBlob(selected); const shareFile = new File([content], selected.name, { type: selected.mimeType || content.type }); if (navigator.share && navigator.canShare?.({ files: [shareFile] })) await navigator.share({ title: selected.name, files: [shareFile] }); else throw new Error("File sharing is not supported by this browser. Download the file to share it manually."); } catch (error) { onError(error instanceof Error ? error.message : "Unable to share file."); } }
  return <div className={selected ? "grid gap-4 lg:grid-cols-[minmax(320px,0.8fr)_minmax(520px,1.5fr)]" : "block"}><div className={selected ? "max-h-[78vh] overflow-auto" : ""}><AttachmentList files={files} selectedId={selected?.id} downloadingId={downloadingId} onSelect={(file) => void select(file)} onDownload={onDownload} onBrowse={onBrowse} /></div>{selected ? <AttachmentPreviewPane key={selected.id} file={selected} blob={blob} url={url} loading={loading} onShare={() => void share()} onDownload={() => onDownload(selected)} onClose={close} /> : null}</div>;
}
