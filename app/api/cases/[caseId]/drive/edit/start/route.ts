import { NextResponse } from 'next/server';

import { getDriveItemMetadata, isDriveItemInsideFolder } from '@/lib/google-drive';
import { getOnlyOfficeConfiguration, signOnlyOfficeToken } from '@/lib/onlyoffice';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';
const EDITABLE = { docx: { documentType: 'word', mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }, xlsx: { documentType: 'cell', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }, pptx: { documentType: 'slide', mime: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' } } as const;

export async function POST(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return NextResponse.json({ error: { code: 'unauthenticated', message: 'Authentication is required.' } }, { status: 401 });
  const caseId = Number((await context.params).caseId);
  const body = await request.json().catch(() => null) as { fileId?: string } | null;
  if (!Number.isSafeInteger(caseId) || caseId <= 0 || !body?.fileId) return NextResponse.json({ error: { code: 'invalid_request', message: 'A valid case and file are required.' } }, { status: 400 });
  const { data: canEdit, error: permissionError } = await auth.client.rpc('can_edit_case_details' as never, { p_case_id: caseId } as never);
  if (permissionError || canEdit !== true) return NextResponse.json({ error: { code: 'forbidden', message: 'You do not have permission to edit documents for this case.' } }, { status: 403 });

  const admin = getSupabaseAdminClient();
  const mappingResult = await admin.from('case_drive_folders' as never).select('folder_id,status').eq('case_id', caseId).maybeSingle();
  const mapping = mappingResult.data as unknown as { folder_id: string | null; status: string } | null;
  if (mappingResult.error || !mapping?.folder_id || mapping.status !== 'READY') return NextResponse.json({ error: { code: 'drive_unavailable', message: 'The case Drive folder is not ready.' } }, { status: 409 });
  const metadata = await getDriveItemMetadata(body.fileId).catch(() => null);
  if (!metadata || !(await isDriveItemInsideFolder(body.fileId, mapping.folder_id))) return NextResponse.json({ error: { code: 'not_found', message: 'Document not found in this case.' } }, { status: 404 });
  const extension = metadata.name.split('.').pop()?.toLowerCase() as keyof typeof EDITABLE | undefined;
  if (!extension || !EDITABLE[extension]) return NextResponse.json({ error: { code: 'unsupported_type', message: 'Only DOCX, XLSX, and PPTX files can be edited.' } }, { status: 400 });
  let onlyOffice;
  try { onlyOffice = getOnlyOfficeConfiguration(); } catch { return NextResponse.json({ error: { code: 'editor_unavailable', message: 'The document editor is not configured.' } }, { status: 503 }); }

  const now = new Date().toISOString();
  await admin.from('drive_document_edit_sessions' as never).update({ status: 'EXPIRED', updated_at: now } as never).eq('gdrive_file_id', body.fileId).eq('status', 'ACTIVE').lt('expires_at', now);
  const actorIdResult = await auth.client.rpc('current_app_user_id' as never);
  const actorId = Number(actorIdResult.data);
  if (actorIdResult.error || !Number.isSafeInteger(actorId) || actorId <= 0) return NextResponse.json({ error: { code: 'user_not_linked', message: 'Your application user account could not be resolved.' } }, { status: 403 });
  const actorResult = await admin.from('users').select('id,email').eq('id', actorId).maybeSingle();
  if (actorResult.error || !actorResult.data) return NextResponse.json({ error: { code: 'user_not_linked', message: 'Your application user account could not be resolved.' } }, { status: 403 });
  const actor = actorResult.data as unknown as { id: number; email: string };
  const sessionResult = await admin.from('drive_document_edit_sessions' as never).insert({ case_id: caseId, gdrive_file_id: body.fileId, file_name: metadata.name, mime_type: EDITABLE[extension].mime, actor_auth_user_id: auth.userId, actor_user_id: actor.id, expected_modified_time: metadata.modifiedTime ?? null, status: 'ACTIVE' } as never).select('id,editor_access_token').single();
  if (sessionResult.error) {
    if (sessionResult.error.code === '23505') return NextResponse.json({ error: { code: 'document_locked', message: 'This document is already being edited by another user.' } }, { status: 423 });
    return NextResponse.json({ error: { code: sessionResult.error.code, message: 'Unable to start the edit session.' } }, { status: 500 });
  }
  const session = sessionResult.data as unknown as { id: string; editor_access_token: string };
  const contentUrl = `${onlyOffice.publicAppUrl}/api/cases/${caseId}/drive/edit/${session.id}/content?access=${session.editor_access_token}`;
  const callbackUrl = `${onlyOffice.publicAppUrl}/api/cases/${caseId}/drive/edit/${session.id}/callback?access=${session.editor_access_token}`;
  const editorConfig = { document: { fileType: extension, key: `${body.fileId}-${metadata.modifiedTime ?? Date.now()}`.replace(/[^a-zA-Z0-9_.=-]/g, '_').slice(0, 120), title: metadata.name, url: contentUrl, permissions: { edit: true, download: false, print: true } }, documentType: EDITABLE[extension].documentType, editorConfig: { callbackUrl, mode: 'edit', user: { id: String(actor.id), name: actor.email }, customization: { autosave: true, forcesave: true } } };
  return NextResponse.json({ data: { sessionId: session.id, serverUrl: onlyOffice.serverUrl, config: { ...editorConfig, token: signOnlyOfficeToken(editorConfig, onlyOffice.jwtSecret) } } });
}
