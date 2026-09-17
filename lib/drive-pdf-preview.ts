import 'server-only';

import { createHmac, timingSafeEqual } from 'node:crypto';

const PDF_MIME_TYPE = 'application/pdf';
const FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder';
const TOKEN_CONTEXT = 'ocp-drive-pdf-preview-v1';
const TOKEN_TTL_SECONDS = 60 * 60;
const TOKEN_REFRESH_SKEW_MS = 60_000;

const GOOGLE_PDF_EXPORT_MIME_TYPES = new Set([
  'application/vnd.google-apps.document',
  'application/vnd.google-apps.presentation',
  'application/vnd.google-apps.drawing',
]);

type PreviewTokenClaims = {
  v: 1;
  caseId: number;
  fileId: string;
  rootFolderId: string;
  parentFolderId: string;
  exp: number;
};

type DrivePreviewMetadata = {
  id: string;
  name: string;
  mimeType: string | null;
  parents?: string[];
  trashed?: boolean;
};

type CachedAccessToken = {
  value: string;
  expiresAt: number;
};

let cachedAccessToken: CachedAccessToken | null = null;
let accessTokenPromise: Promise<string> | null = null;

function required(name: 'GOOGLE_CLIENT_ID' | 'GOOGLE_CLIENT_SECRET' | 'GOOGLE_REFRESH_TOKEN') {
  const value = process.env[name];
  if (!value) throw new Error(`Missing server Google Drive configuration: ${name}`);
  return value;
}

function signingSecret() {
  const value = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!value) throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY for signed PDF preview URLs.');
  return value;
}

function signPayload(payload: string) {
  return createHmac('sha256', signingSecret())
    .update(`${TOKEN_CONTEXT}.${payload}`)
    .digest('base64url');
}

function signaturesMatch(actual: string, expected: string) {
  const actualBuffer = Buffer.from(actual);
  const expectedBuffer = Buffer.from(expected);
  return actualBuffer.length === expectedBuffer.length && timingSafeEqual(actualBuffer, expectedBuffer);
}

export function supportsDrivePdfPreview(file: { name: string; mimeType: string | null }) {
  const mimeType = file.mimeType ?? '';
  return mimeType === PDF_MIME_TYPE || GOOGLE_PDF_EXPORT_MIME_TYPES.has(mimeType) || /\.pdf$/i.test(file.name);
}

export function createDrivePdfPreviewUrl({
  caseId,
  fileId,
  rootFolderId,
  parentFolderId,
}: {
  caseId: number;
  fileId: string;
  rootFolderId: string;
  parentFolderId: string;
}) {
  const claims: PreviewTokenClaims = {
    v: 1,
    caseId,
    fileId,
    rootFolderId,
    parentFolderId,
    exp: Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS,
  };
  const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
  const token = `${payload}.${signPayload(payload)}`;
  return `/api/cases/${caseId}/drive/files/${encodeURIComponent(fileId)}/preview?token=${encodeURIComponent(token)}`;
}

export function verifyDrivePdfPreviewToken(token: string | null, caseId: number, fileId: string) {
  if (!token) return null;
  const [payload, signature, extra] = token.split('.');
  if (!payload || !signature || extra || !signaturesMatch(signature, signPayload(payload))) return null;

  try {
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as Partial<PreviewTokenClaims>;
    const now = Math.floor(Date.now() / 1000);
    if (
      claims.v !== 1 ||
      claims.caseId !== caseId ||
      claims.fileId !== fileId ||
      typeof claims.rootFolderId !== 'string' || !claims.rootFolderId ||
      typeof claims.parentFolderId !== 'string' || !claims.parentFolderId ||
      typeof claims.exp !== 'number' || claims.exp <= now
    ) return null;
    return claims as PreviewTokenClaims;
  } catch {
    return null;
  }
}

async function googleAccessToken() {
  if (cachedAccessToken && cachedAccessToken.expiresAt - TOKEN_REFRESH_SKEW_MS > Date.now()) {
    return cachedAccessToken.value;
  }
  if (accessTokenPromise) return accessTokenPromise;

  accessTokenPromise = (async () => {
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: required('GOOGLE_CLIENT_ID'),
        client_secret: required('GOOGLE_CLIENT_SECRET'),
        refresh_token: required('GOOGLE_REFRESH_TOKEN'),
        grant_type: 'refresh_token',
      }),
      cache: 'no-store',
    });
    const body = await response.json().catch(() => ({})) as { access_token?: string; expires_in?: number };
    if (!response.ok || !body.access_token) throw new Error(`Google OAuth request failed (${response.status}).`);
    const expiresInSeconds = typeof body.expires_in === 'number' && Number.isFinite(body.expires_in) && body.expires_in > 0
      ? body.expires_in
      : 3600;
    cachedAccessToken = {
      value: body.access_token,
      expiresAt: Date.now() + expiresInSeconds * 1000,
    };
    return body.access_token;
  })();

  try {
    return await accessTokenPromise;
  } finally {
    accessTokenPromise = null;
  }
}

async function driveRequest(path: string, init?: RequestInit) {
  const token = await googleAccessToken();
  return fetch(`https://www.googleapis.com/drive/v3/${path}`, {
    ...init,
    headers: { authorization: `Bearer ${token}`, ...(init?.headers ?? {}) },
    cache: 'no-store',
  });
}

async function getPreviewMetadata(fileId: string) {
  const response = await driveRequest(`files/${encodeURIComponent(fileId)}?fields=id,name,mimeType,parents,trashed`);
  if (!response.ok) throw new Error(`Google Drive metadata request failed (${response.status}).`);
  return response.json() as Promise<DrivePreviewMetadata>;
}

async function isParentInsideRoot(parentFolderId: string, rootFolderId: string) {
  if (parentFolderId === rootFolderId) return true;
  let currentId = parentFolderId;
  const visited = new Set<string>();

  for (let depth = 0; depth < 100; depth += 1) {
    if (currentId === rootFolderId) return true;
    if (visited.has(currentId)) return false;
    visited.add(currentId);

    const metadata = await getPreviewMetadata(currentId);
    if (metadata.trashed || metadata.mimeType !== FOLDER_MIME_TYPE) return false;
    const parents = metadata.parents ?? [];
    if (parents.includes(rootFolderId)) return true;
    if (parents.length !== 1) return false;
    currentId = parents[0];
  }

  return false;
}

function normalizedRangeHeader(value: string | null) {
  if (!value) return null;
  const range = value.trim();
  if (!/^bytes=(?:\d+-\d*|-\d+)$/.test(range)) return null;
  return range;
}

export async function openDrivePdfPreview({
  fileId,
  rootFolderId,
  parentFolderId,
  range,
}: {
  fileId: string;
  rootFolderId: string;
  parentFolderId: string;
  range: string | null;
}) {
  const metadata = await getPreviewMetadata(fileId);
  if (metadata.trashed || metadata.mimeType === FOLDER_MIME_TYPE) throw new Error('The requested PDF is unavailable.');
  if (!supportsDrivePdfPreview(metadata)) throw new Error('The requested file is not a PDF preview.');
  if (!(metadata.parents ?? []).includes(parentFolderId)) throw new Error('The requested PDF moved outside its authorized folder.');
  if (!(await isParentInsideRoot(parentFolderId, rootFolderId))) throw new Error('The requested PDF is outside the trusted case folder.');

  const googleExport = metadata.mimeType ? GOOGLE_PDF_EXPORT_MIME_TYPES.has(metadata.mimeType) : false;
  const requestRange = googleExport ? null : normalizedRangeHeader(range);
  const path = googleExport
    ? `files/${encodeURIComponent(fileId)}/export?mimeType=${encodeURIComponent(PDF_MIME_TYPE)}`
    : `files/${encodeURIComponent(fileId)}?alt=media`;
  const response = await driveRequest(path, requestRange ? { headers: { range: requestRange } } : undefined);
  if (!response.ok && response.status !== 416) throw new Error(`Google Drive PDF request failed (${response.status}).`);

  const hasExtension = /\.[a-z0-9]{1,10}$/i.test(metadata.name);
  const fileName = googleExport && !hasExtension ? `${metadata.name}.pdf` : metadata.name;
  return {
    body: response.body,
    status: response.status,
    contentType: googleExport ? PDF_MIME_TYPE : response.headers.get('content-type') ?? (fileName.toLowerCase().endsWith('.pdf') ? PDF_MIME_TYPE : 'application/octet-stream'),
    fileName,
    contentLength: response.headers.get('content-length'),
    contentRange: response.headers.get('content-range'),
    acceptRanges: googleExport ? 'none' : response.headers.get('accept-ranges') ?? 'bytes',
  };
}
