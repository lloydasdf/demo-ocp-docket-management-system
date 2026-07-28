import { NextResponse } from 'next/server';

import { getDriveItemMetadata, updateDriveFileContent } from '@/lib/google-drive';
import { getOnlyOfficeConfiguration, verifyOnlyOfficeToken } from '@/lib/onlyoffice';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';

export const runtime = 'nodejs';
type Callback = { status?: number; url?: string; token?: string; key?: string };

export async function POST(request: Request, context: { params: Promise<{ caseId: string; sessionId: string }> }) {
  const { caseId, sessionId } = await context.params; const access = new URL(request.url).searchParams.get('access');
  let onlyOffice;
  try { onlyOffice = getOnlyOfficeConfiguration(); } catch { return NextResponse.json({ error: 1 }); }
  const authorization = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  const body = await request.json().catch(() => null) as Callback | null;
  const token = authorization || body?.token;
  if (!body || !token || !verifyOnlyOfficeToken(token, onlyOffice.jwtSecret)) return NextResponse.json({ error: 1 }, { status: 403 });

  const admin = getSupabaseAdminClient();
  const result = await admin.from('drive_document_edit_sessions' as never).select('*').eq('id', sessionId).eq('editor_access_token', access ?? '').maybeSingle();
  const session = result.data as unknown as { case_id: number; gdrive_file_id: string; file_name: string; mime_type: string; actor_user_id: number | null; expected_modified_time: string | null; status: string } | null;
  if (result.error || !session || session.case_id !== Number(caseId)) return NextResponse.json({ error: 1 }, { status: 403 });
  if (body.status === 1) return NextResponse.json({ error: 0 });
  if (body.status === 4) { await admin.from('drive_document_edit_sessions' as never).update({ status: 'CLOSED', updated_at: new Date().toISOString() } as never).eq('id', sessionId); return NextResponse.json({ error: 0 }); }
  if (body.status !== 2 && body.status !== 6) return NextResponse.json({ error: 0 });
  if (session.status !== 'ACTIVE' || !body.url) return NextResponse.json({ error: 1 });

  try {
    const outputUrl = new URL(body.url); const editorOrigin = new URL(onlyOffice.serverUrl).origin;
    if (outputUrl.origin !== editorOrigin) throw new Error('Editor output URL has an unexpected origin.');
    const current = await getDriveItemMetadata(session.gdrive_file_id);
    if (session.expected_modified_time && current.modifiedTime && new Date(current.modifiedTime).getTime() !== new Date(session.expected_modified_time).getTime()) throw new Error('The Drive document changed after this edit session started.');
    const output = await fetch(outputUrl, { cache: 'no-store' });
    if (!output.ok) throw new Error(`ONLYOFFICE output download failed (${output.status}).`);
    const updated = await updateDriveFileContent(session.gdrive_file_id, await output.arrayBuffer(), session.mime_type);
    const now = new Date().toISOString();
    const nextStatus = body.status === 6 ? 'ACTIVE' : 'SAVED';
    const sessionUpdate = await admin.from('drive_document_edit_sessions' as never).update({ status: nextStatus, expected_modified_time: updated.modifiedTime ?? null, updated_at: now, last_error: null } as never).eq('id', sessionId).eq('status', 'ACTIVE');
    if (sessionUpdate.error) throw new Error(sessionUpdate.error.message);
    await admin.from('case_attachment_index').update({ file_size_bytes: updated.size ? Number(updated.size) : null, modified_time: updated.modifiedTime ?? now, md5_checksum: updated.md5Checksum ?? null, last_seen_at: now, last_scanned_at: now, file_status: 'VISIBLE' }).eq('case_id', session.case_id).eq('gdrive_file_id', session.gdrive_file_id);
    const audit = await admin.from('audit_logs').insert({ actor_user_id: session.actor_user_id, entity_name: 'case_attachment_index', action: 'EDIT_GDRIVE_DOCUMENT', case_id: session.case_id, summary: `Edited Google Drive document ${session.file_name}.`, old_data: { modified_time: current.modifiedTime, size: current.size }, new_data: { modified_time: updated.modifiedTime, size: updated.size }, metadata: { gdrive_file_id: session.gdrive_file_id, edit_session_id: sessionId, editor: 'ONLYOFFICE' } } as never);
    if (audit.error) console.error('[Drive Edit] Audit insert failed', { code: audit.error.code, message: audit.error.message, sessionId });
    return NextResponse.json({ error: 0 });
  } catch (error) {
    const message = error instanceof Error ? error.message.slice(0, 500) : 'Document save failed.';
    await admin.from('drive_document_edit_sessions' as never).update({ status: 'FAILED', last_error: message, updated_at: new Date().toISOString() } as never).eq('id', sessionId);
    console.error('[Drive Edit] Save failed; original Drive revision was retained', { sessionId, caseId, message });
    return NextResponse.json({ error: 1 });
  }
}
