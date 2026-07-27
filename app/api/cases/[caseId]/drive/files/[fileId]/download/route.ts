import { NextResponse } from 'next/server';

import { downloadDriveFile } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';

function contentDisposition(name: string) {
  const safeAscii = name.replace(/[^\x20-\x7e]/g, '_').replace(/["\\]/g, '_').slice(0, 180) || 'download';
  return `attachment; filename="${safeAscii}"; filename*=UTF-8''${encodeURIComponent(name.slice(0, 240))}`;
}

export async function GET(request: Request, context: { params: Promise<{ caseId: string; fileId: string }> }) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return NextResponse.json({ error: { code: 'unauthenticated', message: 'Authentication is required.' } }, { status: 401 });
  const params = await context.params;
  const caseId = Number(params.caseId);
  if (!Number.isSafeInteger(caseId) || caseId <= 0 || !params.fileId) return NextResponse.json({ error: { code: 'not_found', message: 'File not found.' } }, { status: 404 });

  const { data: allowed, error: accessError } = await auth.client.rpc('can_view_case_details' as never, { p_case_id: caseId } as never);
  if (accessError || allowed !== true) return NextResponse.json({ error: { code: 'forbidden', message: 'You do not have access to this case.' } }, { status: 403 });

  const mappingResult = await getSupabaseAdminClient().from('case_drive_folders' as never)
    .select('folder_id,status').eq('case_id', caseId).maybeSingle();
  if (mappingResult.error) return NextResponse.json({ error: { code: mappingResult.error.code, message: 'Unable to resolve the case Drive folder.' } }, { status: 500 });
  const mapping = mappingResult.data as unknown as { folder_id: string | null; status: string } | null;
  if (!mapping?.folder_id || mapping.status !== 'READY') return NextResponse.json({ error: { code: 'drive_unavailable', message: 'The case Drive folder is not ready.' } }, { status: 409 });

  try {
    const file = await downloadDriveFile(params.fileId, mapping.folder_id);
    return new Response(file.body, {
      headers: {
        'content-type': file.contentType,
        'content-disposition': contentDisposition(file.fileName),
        'cache-control': 'private, no-store',
        'x-content-type-options': 'nosniff',
      },
    });
  } catch (error) {
    console.error('[Drive] File download failed', { caseId, code: error instanceof Error ? error.name : 'unknown', message: error instanceof Error ? error.message : 'Unknown error' });
    return NextResponse.json({ error: { code: 'download_failed', message: 'Unable to download the Google Drive file.' } }, { status: 502 });
  }
}
