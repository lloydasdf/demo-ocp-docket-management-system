import { NextResponse } from 'next/server';

import { DriveProvisionError, provisionDriveFolder, safeError, type DocketResult } from '@/lib/docket-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';

export async function POST(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return NextResponse.json({ error: { code: 'unauthenticated', message: 'Authentication is required.' } }, { status: 401 });

  const caseId = Number((await context.params).caseId);
  if (!Number.isSafeInteger(caseId) || caseId <= 0) {
    return NextResponse.json({ error: { code: 'not_found', message: 'Case not found.' } }, { status: 404 });
  }

  const { data: allowed, error: accessError } = await auth.client.rpc('can_view_case_details' as never, { p_case_id: caseId } as never);
  if (accessError || allowed !== true) {
    return NextResponse.json({ error: { code: 'forbidden', message: 'You do not have access to this case.' } }, { status: 403 });
  }

  const { data, error } = await auth.client.from('v_case_details_page' as never)
    .select('id,docket_year,docket_display_number').eq('id', caseId).maybeSingle();
  if (error || !data) return NextResponse.json({ error: { code: 'not_found', message: 'Case not found.' } }, { status: 404 });
  const row = data as unknown as { id: number; docket_year: number; docket_display_number: string };
  const docket: DocketResult = { caseId: row.id, docketYear: row.docket_year, docketDisplayNumber: row.docket_display_number };

  // Force provisioning to verify/recreate the expected year/docket path rather
  // than short-circuiting on a stale READY database mapping.
  const reset = await getSupabaseAdminClient().from('case_drive_folders' as never)
    .update({ status: 'PENDING', last_error: null, updated_at: new Date().toISOString() } as never).eq('case_id', caseId);
  if (reset.error) return NextResponse.json({ error: { code: reset.error.code, message: 'Unable to prepare the Drive folder mapping for creation.' } }, { status: 500 });

  try {
    const drive = await provisionDriveFolder(docket);
    return NextResponse.json({ data: { caseId, drive } });
  } catch (driveError) {
    console.error('[Drive] Provisioning retry FAILED', driveError instanceof DriveProvisionError ? driveError.diagnostic() : { message: safeError(driveError) });
    const message = safeError(driveError);
    const failedUpdate = await getSupabaseAdminClient().from('case_drive_folders' as never)
      .update({ status: 'FAILED', last_error: message, updated_at: new Date().toISOString() } as never).eq('case_id', caseId);
    if (failedUpdate.error) console.error('[Drive] Failed to persist FAILED case status', { table: 'case_drive_folders', operation: 'update', code: failedUpdate.error.code, message: safeError(failedUpdate.error) });
    const driveProvision = process.env.NODE_ENV === 'development' && driveError instanceof DriveProvisionError ? driveError.diagnostic() : undefined;
    return NextResponse.json({ data: { caseId, drive: { status: 'FAILED', folderCreated: false }, driveProvision } }, { status: 200 });
  }
}
