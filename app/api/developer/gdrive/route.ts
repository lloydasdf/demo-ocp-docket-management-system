import { NextResponse } from 'next/server';

import {
  createFolder,
  getDocketRootFolderId,
  getFolderMetadata,
  getGoogleDriveEnvironmentStatus,
  renameFolder,
  trashFolder,
} from '@/lib/google-drive';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';
const DIAGNOSTIC_PREFIX = '.ocpgentri-diagnostic-';

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
    const root = await getFolderMetadata(getDocketRootFolderId());
    return NextResponse.json({ data: { environment: getGoogleDriveEnvironmentStatus(), connection: { status: 'CONNECTED', rootName: root.name } } });
  } catch (error) {
    return NextResponse.json({ data: { environment: getGoogleDriveEnvironmentStatus(), connection: { status: 'FAILED', message: error instanceof Error ? error.message : 'Connection failed.' } } });
  }
}

export async function POST(request: Request) {
  const authorization = await authorize(request);
  if ('error' in authorization) return authorization.error;
  try {
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
