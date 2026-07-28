export type PreviewFile = {
  id: string;
  name: string;
  mimeType: string | null;
  webViewLink: string | null;
  webContentLink: string | null;
  size: string | null;
  modifiedTime: string | null;
};

export function formattedFileSize(value: string | null) {
  const bytes = value ? Number(value) : 0;
  if (!Number.isFinite(bytes) || bytes <= 0) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
}

export function isFolder(file: PreviewFile) {
  return file.mimeType === "application/vnd.google-apps.folder";
}

export function isExecutable(file: PreviewFile) {
  return /\.(exe|msi|bat|cmd|com|scr|ps1|sh|app|dmg)$/i.test(file.name) || file.mimeType === "application/x-msdownload";
}
