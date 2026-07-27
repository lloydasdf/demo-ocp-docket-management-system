import { NextResponse } from 'next/server';

import { listFolderFiles } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';

export async function GET(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return NextResponse.json({ error: { code: 'unauthenticated', message: 'Authentication is required.' } }, { status: 401 });
  const caseId = Number((await context.params).caseId);
  if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: 'not_found', message: 'Case not found.' } }, { status: 404 });

  const { data: allowed, error: accessError } = await auth.client.rpc('can_view_case_details' as never, { p_case_id: caseId } as never);
  if (accessError || allowed !== true) return NextResponse.json({ error: { code: 'forbidden', message: 'You do not have access to this case.' } }, { status: 403 });

  const admin = getSupabaseAdminClient();
  const { data: mapping } = await admin.from('case_drive_folders' as never).select('folder_id,status')
    .eq('case_id', caseId).maybeSingle() as unknown as { data: { folder_id: string | null; status: string } | null };
  if (!mapping?.folder_id || mapping.status !== 'READY') {
    return NextResponse.json({ error: { code: 'drive_unavailable', message: 'The Drive folder is not ready.' } }, { status: 409 });
  }
  const folderId = mapping.folder_id;

  try {
    const files = await listFolderFiles(folderId);
    const scannedAt = new Date().toISOString();
    const ids = files.map((file) => file.id);
    if (ids.length) {
      await admin.from('case_attachment_index').update({ file_status: 'MISSING', last_scanned_at: scannedAt }).eq('case_id', caseId).not('gdrive_file_id', 'in', `(${ids.map((id) => `"${id.replace(/"/g, '')}"`).join(',')})`);
      await admin.from('case_attachment_index').upsert(files.map((file) => ({
        case_id: caseId,
        gdrive_file_id: file.id,
        gdrive_parent_folder_id: folderId,
        file_name: file.name,
        mime_type: file.mimeType,
        web_view_link: file.webViewLink,
        web_content_link: file.webContentLink,
        file_size_bytes: file.size ? Number(file.size) : null,
        md5_checksum: file.md5Checksum,
        modified_time: file.modifiedTime,
        last_seen_at: scannedAt,
        last_scanned_at: scannedAt,
        file_status: 'VISIBLE',
      })), { onConflict: 'case_id,gdrive_file_id' });
    } else {
      await admin.from('case_attachment_index').update({ file_status: 'MISSING', last_scanned_at: scannedAt }).eq('case_id', caseId);
    }
    await admin.from('case_drive_folders' as never).update({ last_scanned_at: scannedAt, status: 'READY', last_error: null } as never).eq('case_id', caseId);
    return NextResponse.json({ data: { files, scannedAt } });
  } catch {
    await admin.from('case_drive_folders' as never).update({ status: 'DISCONNECTED', last_error: 'Unable to list Google Drive files.' } as never).eq('case_id', caseId);
    return NextResponse.json({ error: { code: 'drive_unavailable', message: 'Unable to list Drive files.' } }, { status: 502 });
  }
}
