import 'server-only';

import { createFolder, findFolder, getDocketRootFolderId, getFolderMetadata, GoogleDriveError } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';

export type DocketFolderReconciliationResult = {
  totalCasesChecked: number;
  existingFolders: number;
  newFoldersCreated: number;
  databaseMappingsUpdated: number;
  failedCases: Array<{ caseId: number; docketNumber: string; error: string }>;
};

type CaseRow = { id: number; docket_year: number; docket_display_number: string; docket_type_prefix: string };
type MappingRow = { folder_id: string | null; parent_folder_id: string; folder_name: string; status: string };

async function folderExists(folderId: string) {
  try {
    await getFolderMetadata(folderId);
    return true;
  } catch (error) {
    if (error instanceof GoogleDriveError && error.httpStatus === 404) return false;
    throw error;
  }
}

async function findOrCreate(parentId: string, name: string) {
  const existingId = await findFolder(parentId, name);
  return existingId ? { id: existingId, created: false } : { id: await createFolder(parentId, name), created: true };
}

export async function reconcileDocketFolders(caseIds: number[]): Promise<DocketFolderReconciliationResult> {
  const ids = Array.from(new Set(caseIds.filter(Number.isSafeInteger)));
  const result: DocketFolderReconciliationResult = { totalCasesChecked: 0, existingFolders: 0, newFoldersCreated: 0, databaseMappingsUpdated: 0, failedCases: [] };
  if (!ids.length) return result;

  const admin = getSupabaseAdminClient();
  const loaded = await admin.from('v_case_details_page' as never)
    .select('id,docket_year,docket_display_number,docket_type_prefix')
    .in('id', ids) as unknown as { data: CaseRow[] | null; error: { message?: string } | null };
  if (loaded.error) throw new Error(loaded.error.message ?? 'Unable to load filtered cases.');
  const casesById = new Map((loaded.data ?? []).map((row) => [row.id, row]));
  const rootId = getDocketRootFolderId();

  for (const caseId of ids) {
    const caseRow = casesById.get(caseId);
    const docketNumber = caseRow?.docket_display_number ?? `Case ${caseId}`;
    result.totalCasesChecked += 1;
    try {
      if (!caseRow?.docket_year || !caseRow.docket_display_number || !caseRow.docket_type_prefix) throw new Error('The case docket data is incomplete.');
      const mappingResponse = await admin.from('case_drive_folders' as never).select('folder_id,parent_folder_id,folder_name,status').eq('case_id', caseId).maybeSingle();
      if (mappingResponse.error) throw new Error(mappingResponse.error.message);
      const mapping = mappingResponse.data as unknown as MappingRow | null;
      if (mapping?.folder_id && await folderExists(mapping.folder_id)) {
        result.existingFolders += 1;
        const scanned = await admin.from('case_drive_folders' as never).update({ last_scanned_at: new Date().toISOString(), last_error: null } as never).eq('case_id', caseId);
        if (scanned.error) throw new Error(scanned.error.message);
        continue;
      }

      const year = await findOrCreate(rootId, String(caseRow.docket_year));
      const type = await findOrCreate(year.id, caseRow.docket_type_prefix.trim().toUpperCase());
      const docket = await findOrCreate(type.id, caseRow.docket_display_number);
      if (docket.created) result.newFoldersCreated += 1;
      const mappingChanged = !mapping || mapping.folder_id !== docket.id || mapping.parent_folder_id !== type.id || mapping.folder_name !== caseRow.docket_display_number || mapping.status !== 'READY';
      const saved = await admin.from('case_drive_folders' as never).upsert({
        case_id: caseId, docket_year: caseRow.docket_year, folder_id: docket.id, parent_folder_id: type.id,
        folder_name: caseRow.docket_display_number, status: 'READY', last_error: null,
        last_scanned_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      } as never, { onConflict: 'case_id' });
      if (saved.error) throw new Error(saved.error.message);
      if (mappingChanged) result.databaseMappingsUpdated += 1;
    } catch (error) {
      result.failedCases.push({ caseId, docketNumber, error: error instanceof Error ? error.message : 'Unknown error' });
    }
  }
  return result;
}
