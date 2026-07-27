import { NextResponse } from 'next/server';

import {
  createFolder,
  getDocketRootFolderId,
  getConnectedDriveAccount,
  getFolderMetadata,
  getGoogleDriveEnvironmentStatus,
  GoogleDriveError,
  listFolderChildren,
  renameFolder,
  trashFolder,
  uploadDiagnosticTextFile,
} from '@/lib/google-drive';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';
const DIAGNOSTIC_PREFIX = '.ocpgentri-diagnostic-';

function maskedId(value: string) {
  if (value.length <= 8) return '••••••••';
  return `${value.slice(0, 5)}...${value.slice(-4)}`;
}

function connectionFailure(error: unknown) {
  if (error instanceof GoogleDriveError) {
    const suggestions: Record<string, string> = {
      invalid_grant: 'Generate a new refresh token. It may be expired, revoked, issued to a different OAuth client, or invalidated after the Google account password changed.',
      invalid_client: 'Verify that GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET belong to the same OAuth client used to issue the refresh token.',
      insufficientPermissions: 'Re-authorize the refresh token with a Google Drive scope that permits folder and file access.',
      notFound: 'Verify the root folder ID and share that folder with the Google account that authorized the refresh token.',
    };
    return {
      status: 'FAILED',
      stage: error.stage,
      // This is a sanitized machine-readable code (for example,
      // "invalid_grant"), never an OAuth response body or credential.
      code: error.code,
      description: process.env.NODE_ENV === 'development' ? error.description : undefined,
      message: error.message,
      suggestion: (error.code && suggestions[error.code]) || (error.stage === 'OAUTH'
        ? 'Re-authorize Google Drive and replace the refresh token, then restart the Next.js server.'
        : 'Confirm the Drive API is enabled and the authorized Google account can access the configured root folder.'),
    };
  }
  return { status: 'FAILED', stage: 'UNKNOWN', message: error instanceof Error ? error.message : 'Connection failed.' };
}

async function authorize(request: Request) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return { error: NextResponse.json({ error: { message: 'Authentication is required.' } }, { status: 401 }) };
  const { data, error } = await auth.client.rpc('has_app_role' as never, { p_role_code: 'DEVELOPER' } as never);
  if (error || data !== true) return { error: NextResponse.json({ error: { message: 'Developer role is required.' } }, { status: 403 }) };
  return { auth };
}

async function readDiagnosticFolder(folderId: string) {
  const rootId = getDocketRootFolderId();
  const folder = await getFolderMetadata(folderId);
  if (!folder.name.startsWith(DIAGNOSTIC_PREFIX) || !folder.parents.includes(rootId)) throw new Error('Only diagnostic folders directly under the configured root can be changed.');
  return folder;
}

export async function GET(request: Request) {
  const authorization = await authorize(request);
  if ('error' in authorization) return authorization.error;
  try {
    const rootId = getDocketRootFolderId();
    const [root, account] = await Promise.all([getFolderMetadata(rootId), getConnectedDriveAccount()]);
    const includeContents = new URL(request.url).searchParams.get('listRoot') === '1';
    const rootContents = includeContents ? await listFolderChildren(rootId) : undefined;
    return NextResponse.json({ data: { environment: getGoogleDriveEnvironmentStatus(), connection: { status: 'CONNECTED', account, rootName: root.name, maskedRootId: maskedId(rootId), rootContents } } });
  } catch (error) {
    return NextResponse.json({ data: { environment: getGoogleDriveEnvironmentStatus(), connection: connectionFailure(error) } });
  }
}

export async function POST(request: Request) {
  const authorization = await authorize(request);
  if ('error' in authorization) return authorization.error;
  try {
    const body = await request.json().catch(() => ({})) as { action?: string; folderId?: string };
    if (body.action === 'upload') {
      if (!body.folderId) return NextResponse.json({ error: { message: 'Diagnostic folder ID is required.' } }, { status: 400 });
      const folder = await readDiagnosticFolder(body.folderId);
      const file = await uploadDiagnosticTextFile(folder.id, `ocpgentri-upload-test-${Date.now()}.txt`, 'OCPGenTri Google Drive upload diagnostic succeeded.');
      return NextResponse.json({ data: { file } }, { status: 201 });
    }
    const name = `${DIAGNOSTIC_PREFIX}${new Date().toISOString().replace(/[:.]/g, '-')}`;
    const id = await createFolder(getDocketRootFolderId(), name);
    return NextResponse.json({ data: { folder: await getFolderMetadata(id) } }, { status: 201 });
  } catch (error) {
    return NextResponse.json({ error: { message: error instanceof Error ? error.message : 'Unable to create diagnostic folder.' } }, { status: 502 });
  }
}

export async function PATCH(request: Request) {
  const authorization = await authorize(request);
  if ('error' in authorization) return authorization.error;
  const body = await request.json().catch(() => null) as { folderId?: string } | null;
  if (!body?.folderId) return NextResponse.json({ error: { message: 'Diagnostic folder ID is required.' } }, { status: 400 });
  try {
    const folder = await readDiagnosticFolder(body.folderId);
    const updated = await renameFolder(folder.id, `${DIAGNOSTIC_PREFIX}renamed-${Date.now()}`);
    return NextResponse.json({ data: { folder: updated } });
  } catch (error) {
    return NextResponse.json({ error: { message: error instanceof Error ? error.message : 'Unable to rename diagnostic folder.' } }, { status: 400 });
  }
}

export async function DELETE(request: Request) {
  const authorization = await authorize(request);
  if ('error' in authorization) return authorization.error;
  const folderId = new URL(request.url).searchParams.get('folderId');
  if (!folderId) return NextResponse.json({ error: { message: 'Diagnostic folder ID is required.' } }, { status: 400 });
  try {
    const folder = await readDiagnosticFolder(folderId);
    await trashFolder(folder.id);
    return NextResponse.json({ data: { deleted: true } });
  } catch (error) {
    return NextResponse.json({ error: { message: error instanceof Error ? error.message : 'Unable to delete diagnostic folder.' } }, { status: 400 });
  }
}
