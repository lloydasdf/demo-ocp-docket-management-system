import 'server-only';

const FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder';

export interface DriveFile {
  id: string;
  name: string;
  mimeType: string | null;
  webViewLink: string | null;
  webContentLink: string | null;
  size: string | null;
  md5Checksum: string | null;
  modifiedTime: string | null;
  trashed: boolean;
}

export type DriveFolderMetadata = { id: string; name: string; webViewLink: string | null; parents: string[] };

function required(name: 'GOOGLE_CLIENT_ID' | 'GOOGLE_CLIENT_SECRET' | 'GOOGLE_REFRESH_TOKEN' | 'GOOGLE_DRIVE_DOCKET_ROOT_FOLDER_ID') {
  const value = process.env[name];
  if (!value) throw new Error(`Missing server Google Drive configuration: ${name}`);
  return value;
}

async function accessToken() {
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
  if (!response.ok) throw new Error(`Google OAuth request failed (${response.status}).`);
  const body = await response.json() as { access_token?: string };
  if (!body.access_token) throw new Error('Google OAuth response did not contain an access token.');
  return body.access_token;
}

async function driveFetch(path: string, init?: RequestInit) {
  const token = await accessToken();
  const response = await fetch(`https://www.googleapis.com/drive/v3/${path}`, {
    ...init,
    headers: { authorization: `Bearer ${token}`, ...(init?.headers ?? {}) },
    cache: 'no-store',
  });
  if (!response.ok) throw new Error(`Google Drive request failed (${response.status}).`);
  return response;
}

export function getGoogleDriveEnvironmentStatus() {
  const names = ['GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'GOOGLE_REFRESH_TOKEN', 'GOOGLE_DRIVE_DOCKET_ROOT_FOLDER_ID'] as const;
  return names.map((name) => {
    const value = process.env[name] ?? '';
    return {
      name,
      configured: Boolean(value),
      maskedValue: value ? '[configured — value hidden]' : '',
      source: 'process.env',
    };
  });
}

export async function getFolderMetadata(folderId: string): Promise<DriveFolderMetadata> {
  const response = await driveFetch(`files/${encodeURIComponent(folderId)}?fields=id,name,webViewLink,parents`);
  const folder = await response.json() as Partial<DriveFolderMetadata>;
  if (!folder.id || !folder.name) throw new Error('Google Drive did not return folder metadata.');
  return { id: folder.id, name: folder.name, webViewLink: folder.webViewLink ?? null, parents: folder.parents ?? [] };
}

export async function renameFolder(folderId: string, name: string) {
  const response = await driveFetch(`files/${encodeURIComponent(folderId)}?fields=id,name,webViewLink,parents`, {
    method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ name }),
  });
  return response.json() as Promise<DriveFolderMetadata>;
}

export async function trashFolder(folderId: string) {
  await driveFetch(`files/${encodeURIComponent(folderId)}?fields=id`, {
    method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ trashed: true }),
  });
}

function escapeQuery(value: string) {
  return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

export function getDocketRootFolderId() {
  return required('GOOGLE_DRIVE_DOCKET_ROOT_FOLDER_ID');
}

export async function findFolder(parentId: string, name: string) {
  const query = `'${escapeQuery(parentId)}' in parents and name = '${escapeQuery(name)}' and mimeType = '${FOLDER_MIME_TYPE}' and trashed = false`;
  const params = new URLSearchParams({ q: query, fields: 'files(id,name)', pageSize: '1', spaces: 'drive' });
  const response = await driveFetch(`files?${params}`);
  const body = await response.json() as { files?: Array<{ id?: string }> };
  return body.files?.[0]?.id ?? null;
}

export async function createFolder(parentId: string, name: string) {
  const response = await driveFetch('files?fields=id', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name, mimeType: FOLDER_MIME_TYPE, parents: [parentId] }),
  });
  const body = await response.json() as { id?: string };
  if (!body.id) throw new Error('Google Drive did not return the created folder ID.');
  return body.id;
}

export async function findOrCreateFolder(parentId: string, name: string) {
  return (await findFolder(parentId, name)) ?? createFolder(parentId, name);
}

export async function listFolderFiles(folderId: string): Promise<DriveFile[]> {
  const query = `'${escapeQuery(folderId)}' in parents and trashed = false`;
  const files: DriveFile[] = [];
  let pageToken: string | undefined;
  do {
    const params = new URLSearchParams({
      q: query,
      fields: 'nextPageToken,files(id,name,mimeType,webViewLink,webContentLink,size,md5Checksum,modifiedTime,trashed)',
      pageSize: '1000',
      spaces: 'drive',
    });
    if (pageToken) params.set('pageToken', pageToken);
    const response = await driveFetch(`files?${params}`);
    const body = await response.json() as { nextPageToken?: string; files?: DriveFile[] };
    files.push(...(body.files ?? []));
    pageToken = body.nextPageToken;
  } while (pageToken);
  return files;
}
