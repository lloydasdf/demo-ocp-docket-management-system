import { NextResponse } from 'next/server';
import { downloadDriveFile } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';

export const runtime = 'nodejs';
export async function GET(request: Request, context: { params: Promise<{ caseId: string; sessionId: string }> }) {
  const { caseId, sessionId } = await context.params; const access = new URL(request.url).searchParams.get('access');
  const result = await getSupabaseAdminClient().from('drive_document_edit_sessions' as never).select('case_id,gdrive_file_id,file_name,mime_type,status,expires_at').eq('id', sessionId).eq('editor_access_token', access ?? '').maybeSingle();
  const session = result.data as unknown as { case_id: number; gdrive_file_id: string; file_name: string; mime_type: string; status: string; expires_at: string } | null;
  if (result.error || !session || session.case_id !== Number(caseId) || session.status !== 'ACTIVE' || new Date(session.expires_at) <= new Date()) return NextResponse.json({ error: { code: 'invalid_session', message: 'Edit session is invalid or expired.' } }, { status: 403 });
  const mapping = await getSupabaseAdminClient().from('case_drive_folders' as never).select('folder_id').eq('case_id', session.case_id).single();
  const folderId = (mapping.data as unknown as { folder_id?: string } | null)?.folder_id;
  if (mapping.error || !folderId) return NextResponse.json({ error: { code: 'drive_unavailable', message: 'Case folder is unavailable.' } }, { status: 409 });
  const file = await downloadDriveFile(session.gdrive_file_id, folderId);
  return new Response(file.body, { headers: { 'content-type': session.mime_type, 'content-disposition': `inline; filename*=UTF-8''${encodeURIComponent(session.file_name)}`, 'cache-control': 'private, no-store' } });
}
