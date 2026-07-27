import { NextResponse } from 'next/server';

import { DriveProvisionError, provisionDriveFolder, safeError, type DocketResult } from '@/lib/docket-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';


const errorResponse = (status: number, code: string, message: string) =>
  NextResponse.json({ error: { code, message } }, { status });

export async function POST(request: Request) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return errorResponse(401, 'unauthenticated', 'Authentication is required.');

  let body: { payload?: Record<string, unknown>; idempotencyKey?: string };
  try { body = await request.json(); } catch { return errorResponse(400, 'invalid_json', 'A valid JSON body is required.'); }
  if (!body.payload || typeof body.idempotencyKey !== 'string' || !/^[0-9a-f-]{36}$/i.test(body.idempotencyKey)) {
    return errorResponse(400, 'invalid_request', 'A docket payload and idempotency key are required.');
  }

  const { linkedPeCaseId, ...rpcPayload } = body.payload;
  const { data, error } = await auth.client.rpc('create_docket_entry_idempotent' as never, {
    p_payload: rpcPayload,
    p_idempotency_key: body.idempotencyKey,
    p_linked_pe_case_id: linkedPeCaseId ?? null,
  } as never);
  if (error || !data) {
    const active = error?.message?.includes('DOCKET_CREATION_IN_PROGRESS');
    return errorResponse(active ? 409 : 400, active ? 'creation_in_progress' : error?.code ?? 'docket_creation_failed', active
      ? 'This docket submission is actively being processed. Please retry in a moment.'
      : error?.message ?? 'Docket creation failed.');
  }

  const result = data as unknown as DocketResult;

  try {
    const drive = await provisionDriveFolder(result);
    return NextResponse.json({ data: { ...result, drive } }, { status: 201 });
  } catch (error) {
    console.error('[Drive] Provisioning FAILED', error instanceof DriveProvisionError ? error.diagnostic() : { message: safeError(error) });
    const message = safeError(error);
    const failedUpdate = await getSupabaseAdminClient().from('case_drive_folders' as never).update({ status: 'FAILED', last_error: message, updated_at: new Date().toISOString() } as never).eq('case_id', result.caseId);
    if (failedUpdate.error) console.error('[Drive] Failed to persist FAILED case status', { table: 'case_drive_folders', operation: 'update', code: failedUpdate.error.code, message: safeError(failedUpdate.error) });
    const driveProvision = process.env.NODE_ENV === 'development' && error instanceof DriveProvisionError ? error.diagnostic() : undefined;
    return NextResponse.json({ data: { ...result, drive: { status: 'FAILED', folderCreated: false }, driveProvision } }, { status: 201 });
  }
}
