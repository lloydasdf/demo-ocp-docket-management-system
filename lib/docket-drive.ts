import 'server-only';

import { findOrCreateFolder, getDocketRootFolderId } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';

export type DocketResult = { caseId: number; docketYear: number; docketDisplayNumber: string } & Record<string, unknown>;

export function safeError(error: unknown) {
  return (error instanceof Error ? error.message : 'Google Drive folder provisioning failed.').slice(0, 500);
}

export async function provisionDriveFolder(result: DocketResult) {
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

  if (!ownsYearClaim) {
    const { data: stale } = await admin.from('docket_year_drive_folders' as never).select('updated_at')
      .eq('docket_year', year).eq('root_folder_id', rootFolderId).eq('status', 'CREATING').maybeSingle() as unknown as { data: { updated_at: string } | null };
    if (stale && Date.now() - new Date(stale.updated_at).getTime() > 120_000) {
      const { data: reclaimed } = await admin.from('docket_year_drive_folders' as never)
        .update({ updated_at: new Date().toISOString() } as never)
        .eq('docket_year', year).eq('root_folder_id', rootFolderId).eq('status', 'CREATING').eq('updated_at', stale.updated_at)
        .select('docket_year').maybeSingle();
      ownsYearClaim = Boolean(reclaimed);
    }
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
