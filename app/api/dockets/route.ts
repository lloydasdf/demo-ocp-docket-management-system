import { NextResponse } from 'next/server';

import { findOrCreateFolder, getDocketRootFolderId } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';

type DocketResult = { caseId: number; docketYear: number; docketDisplayNumber: string } & Record<string, unknown>;

const errorResponse = (status: number, code: string, message: string) =>
  NextResponse.json({ error: { code, message } }, { status });

function safeError(error: unknown) {
  return (error instanceof Error ? error.message : 'Google Drive folder provisioning failed.').slice(0, 500);
}

async function provisionDriveFolder(result: DocketResult) {
  const admin = getSupabaseAdminClient();
  const rootFolderId = getDocketRootFolderId();
  const year = result.docketYear;

  const { data: existingCaseFolder } = await admin.from('case_drive_folders' as never)
    .select('*').eq('case_id', result.caseId).maybeSingle() as unknown as { data: { folder_id?: string; status?: string } | null };
  if (existingCaseFolder?.folder_id && existingCaseFolder.status === 'READY') {
    return { status: 'READY', folderCreated: false };
  }

  await admin.from('case_drive_folders' as never).upsert({
    case_id: result.caseId, docket_year: year, folder_name: result.docketDisplayNumber,
    parent_folder_id: rootFolderId, status: 'PENDING', last_error: null,
  } as never, { onConflict: 'case_id' });

  let ownsYearClaim = false;
  const { error: insertError } = await admin.from('docket_year_drive_folders' as never).insert({
    docket_year: year, root_folder_id: rootFolderId, status: 'CREATING',
  } as never);
  ownsYearClaim = !insertError;

  if (!ownsYearClaim) {
    const { data: claimed } = await admin.from('docket_year_drive_folders' as never)
      .update({ status: 'CREATING', updated_at: new Date().toISOString() } as never)
      .eq('docket_year', year).eq('root_folder_id', rootFolderId).in('status', ['FAILED', 'DISCONNECTED'])
      .select('docket_year').maybeSingle();
    ownsYearClaim = Boolean(claimed);
  }

  let yearFolderId: string | null = null;
  if (ownsYearClaim) {
    try {
      yearFolderId = await findOrCreateFolder(rootFolderId, String(year));
      await admin.from('docket_year_drive_folders' as never).update({ folder_id: yearFolderId, status: 'READY', updated_at: new Date().toISOString() } as never)
        .eq('docket_year', year).eq('root_folder_id', rootFolderId);
    } catch (error) {
      await admin.from('docket_year_drive_folders' as never).update({ status: 'FAILED', updated_at: new Date().toISOString() } as never)
        .eq('docket_year', year).eq('root_folder_id', rootFolderId);
      throw error;
    }
  } else {
    for (let attempt = 0; attempt < 20; attempt += 1) {
      const { data } = await admin.from('docket_year_drive_folders' as never).select('folder_id,status')
        .eq('docket_year', year).eq('root_folder_id', rootFolderId).maybeSingle() as unknown as { data: { folder_id: string | null; status: string } | null };
      if (data?.status === 'READY' && data.folder_id) { yearFolderId = data.folder_id; break; }
      if (data?.status === 'FAILED') throw new Error('Year folder provisioning failed.');
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  if (!yearFolderId) throw new Error('Year folder provisioning is still in progress.');

  await admin.from('case_drive_folders' as never).update({ parent_folder_id: yearFolderId, status: 'CREATING', last_error: null } as never).eq('case_id', result.caseId);
  const folderId = await findOrCreateFolder(yearFolderId, result.docketDisplayNumber);
  await admin.from('case_drive_folders' as never).update({
    folder_id: folderId, parent_folder_id: yearFolderId, status: 'READY', last_error: null, updated_at: new Date().toISOString(),
  } as never).eq('case_id', result.caseId);
  return { status: 'READY', folderCreated: true };
}

export async function POST(request: Request) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return errorResponse(401, 'unauthenticated', 'Authentication is required.');

  let body: { payload?: Record<string, unknown>; idempotencyKey?: string };
  try { body = await request.json(); } catch { return errorResponse(400, 'invalid_json', 'A valid JSON body is required.'); }
  if (!body.payload || typeof body.idempotencyKey !== 'string' || !/^[0-9a-f-]{36}$/i.test(body.idempotencyKey)) {
    return errorResponse(400, 'invalid_request', 'A docket payload and idempotency key are required.');
  }

  const admin = getSupabaseAdminClient();
  const { data: prior } = await admin.from('docket_creation_requests' as never).select('status,result')
    .eq('auth_user_id', auth.userId).eq('idempotency_key', body.idempotencyKey).maybeSingle() as unknown as { data: { status: string; result: DocketResult | null } | null };
  if (prior?.result) {
    const drive = await provisionDriveFolder(prior.result).catch(() => ({ status: 'FAILED', folderCreated: false }));
    return NextResponse.json({ data: { ...prior.result, drive } });
  }
  if (prior?.status === 'CREATING') return errorResponse(409, 'creation_in_progress', 'This docket submission is already being processed.');

  const { error: claimError } = await admin.from('docket_creation_requests' as never).insert({
    auth_user_id: auth.userId, idempotency_key: body.idempotencyKey, status: 'CREATING',
  } as never);
  if (claimError) return errorResponse(409, 'creation_in_progress', 'This docket submission is already being processed.');

  const { linkedPeCaseId, ...rpcPayload } = body.payload;
  const { data, error } = linkedPeCaseId
    ? await auth.client.rpc('create_linked_docket_entry' as never, { p_payload: rpcPayload, p_pe_case_id: linkedPeCaseId } as never)
    : await auth.client.rpc('create_new_docket_entry' as never, { p_payload: rpcPayload } as never);
  if (error || !data) {
    await admin.from('docket_creation_requests' as never).delete().eq('auth_user_id', auth.userId).eq('idempotency_key', body.idempotencyKey);
    return errorResponse(400, error?.code ?? 'docket_creation_failed', error?.message ?? 'Docket creation failed.');
  }

  const result = data as unknown as DocketResult;
  await admin.from('docket_creation_requests' as never).update({ status: 'CREATED', case_id: result.caseId, result } as never)
    .eq('auth_user_id', auth.userId).eq('idempotency_key', body.idempotencyKey);

  try {
    const drive = await provisionDriveFolder(result);
    return NextResponse.json({ data: { ...result, drive } }, { status: 201 });
  } catch (error) {
    const message = safeError(error);
    await admin.from('case_drive_folders' as never).update({ status: 'FAILED', last_error: message, updated_at: new Date().toISOString() } as never).eq('case_id', result.caseId);
    return NextResponse.json({ data: { ...result, drive: { status: 'FAILED', folderCreated: false } } }, { status: 201 });
  }
}
