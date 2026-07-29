"use client";

import { DocxPreview } from "./docx-preview";
import { ImagePreview } from "./image-preview";
import { MediaPreview } from "./media-preview";
import { PdfPreview } from "./pdf-preview";
import { SpreadsheetPreview } from "./spreadsheet-preview";
import { TextPreview } from "./text-preview";
import { UnsupportedPreview } from "./unsupported-preview";
import { isExecutable, type PreviewFile } from "./types";

export function FilePreview({ file, blob, url, narrow = false, onShare, onDownload, onClose }: { file: PreviewFile; blob: Blob; url: string; narrow?: boolean; onShare: () => void; onDownload: () => void; onClose: () => void }) {
  // The server may export a Google-native document to PDF/XLSX, so the
  // downloaded blob's content type is authoritative for preview dispatch.
  const mime = blob.type || file.mimeType || "application/octet-stream";
  if (isExecutable(file)) return <UnsupportedPreview file={file} executable />;
  if (mime === "application/pdf" || /\.pdf$/i.test(file.name)) return <PdfPreview url={url} name={file.name} narrow={narrow} onShare={onShare} onDownload={onDownload} onClose={onClose} />;
  if (mime.startsWith("image/")) return <ImagePreview url={url} name={file.name} />;
  if (mime.startsWith("video/") || mime.startsWith("audio/")) return <MediaPreview url={url} mimeType={mime} />;
  if (mime.includes("wordprocessingml") || /\.docx$/i.test(file.name)) return <DocxPreview blob={blob} onDownload={onDownload} />;
  if (mime.includes("spreadsheetml") || /\.xlsx?$/i.test(file.name)) return <SpreadsheetPreview blob={blob} isCsv={false} />;
  if (mime === "text/csv" || /\.csv$/i.test(file.name)) return <SpreadsheetPreview blob={blob} isCsv />;
  if (mime.startsWith("text/") || mime.includes("json") || /\.(txt|log|json|xml|md|yaml|yml)$/i.test(file.name)) return <TextPreview blob={blob} />;
  return <UnsupportedPreview file={file} executable={false} />;
}
