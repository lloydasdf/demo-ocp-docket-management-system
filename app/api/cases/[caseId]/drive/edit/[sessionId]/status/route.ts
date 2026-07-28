import { NextResponse } from 'next/server';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export async function GET(request: Request, context: { params: Promise<{ caseId: string; sessionId: string }> }) {
  const auth = await getAuthenticatedSupabase(request); if (!auth) return NextResponse.json({ error: { code: 'unauthenticated', message: 'Authentication is required.' } }, { status: 401 });
  const { caseId, sessionId } = await context.params;
  const result = await getSupabaseAdminClient().from('drive_document_edit_sessions' as never).select('status,last_error,updated_at').eq('id', sessionId).eq('case_id', Number(caseId)).eq('actor_auth_user_id', auth.userId).maybeSingle();
  if (result.error || !result.data) return NextResponse.json({ error: { code: 'not_found', message: 'Edit session not found.' } }, { status: 404 });
  return NextResponse.json({ data: result.data });
}

export async function DELETE(request: Request, context: { params: Promise<{ caseId: string; sessionId: string }> }) {
  const auth = await getAuthenticatedSupabase(request); if (!auth) return NextResponse.json({ error: { code: 'unauthenticated', message: 'Authentication is required.' } }, { status: 401 });
  const { caseId, sessionId } = await context.params;
  const result = await getSupabaseAdminClient().from('drive_document_edit_sessions' as never).update({ status: 'CLOSED', updated_at: new Date().toISOString() } as never).eq('id', sessionId).eq('case_id', Number(caseId)).eq('actor_auth_user_id', auth.userId).eq('status', 'ACTIVE');
  if (result.error) return NextResponse.json({ error: { code: result.error.code, message: 'Unable to close the edit session.' } }, { status: 500 });
  return NextResponse.json({ data: { closed: true } });
}
