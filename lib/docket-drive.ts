import 'server-only';

import { findFolder, findOrCreateFolder, getDocketRootFolderId, GoogleDriveError } from '@/lib/google-drive';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';

export type DocketResult = { caseId: number; docketYear: number; docketDisplayNumber: string } & Record<string, unknown>;
export type DriveProvisionStage =
  | 'VALIDATE_CONFIGURATION' | 'CREATE_ADMIN_CLIENT' | 'LOAD_CASE' | 'LOAD_YEAR_FOLDER'
  | 'UPSERT_YEAR_FOLDER' | 'CREATE_GOOGLE_YEAR_FOLDER' | 'UPDATE_YEAR_FOLDER'
  | 'UPSERT_CASE_FOLDER' | 'CREATE_GOOGLE_CASE_FOLDER' | 'UPDATE_CASE_FOLDER' | 'COMPLETE';

type ProvisionErrorDetails = {
  stage: DriveProvisionStage;
  operation: string;
  httpStatus?: number;
  table?: string;
  databaseOperation?: 'insert' | 'update' | 'select' | 'upsert';
  googleEndpoint?: string;
  code?: string;
  originalMessage?: string;
  cause?: unknown;
};

function sanitized(value: unknown, limit = 500) {
  let text = value instanceof Error ? value.message : String(value ?? 'Unknown error');
  for (const secret of [process.env.GOOGLE_CLIENT_SECRET, process.env.GOOGLE_REFRESH_TOKEN, process.env.SUPABASE_SERVICE_ROLE_KEY]) {
    if (secret) text = text.split(secret).join('[redacted]');
  }
  return text.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, limit);
}

export class DriveProvisionError extends Error {
  readonly stage: DriveProvisionStage;
  readonly operation: string;
  readonly httpStatus?: number;
  readonly table?: string;
  readonly databaseOperation?: 'insert' | 'update' | 'select' | 'upsert';
  readonly googleEndpoint?: string;
  readonly originalCode?: string;
  readonly originalMessage: string;

  constructor(details: ProvisionErrorDetails) {
    const source = details.cause instanceof GoogleDriveError ? details.cause : undefined;
    const originalMessage = sanitized(details.originalMessage ?? details.cause);
    super(`Drive provisioning failed at ${details.stage}: ${originalMessage}`, { cause: details.cause });
    this.name = 'DriveProvisionError';
    this.stage = details.stage;
    this.operation = details.operation;
    this.httpStatus = details.httpStatus ?? source?.httpStatus;
    this.table = details.table;
    this.databaseOperation = details.databaseOperation;
    this.googleEndpoint = details.googleEndpoint ?? source?.endpoint;
    this.originalCode = sanitized(details.code ?? source?.code ?? '', 100) || undefined;
    this.originalMessage = originalMessage;
  }

  diagnostic() {
    return {
      stage: this.stage, operation: this.operation, table: this.table,
      databaseOperation: this.databaseOperation, status: 'FAILED', code: this.originalCode,
      message: this.originalMessage, httpStatus: this.httpStatus, googleEndpoint: this.googleEndpoint,
      ...(process.env.NODE_ENV === 'development' ? { stack: sanitized(this.stack, 4000) } : {}),
    };
  }
}

export function safeError(error: unknown) {
  return sanitized(error instanceof DriveProvisionError ? error.originalMessage : error);
}

function logStage(stage: DriveProvisionStage, message: string, details?: unknown) {
  console.info(`[Drive] Stage: ${stage}\n[Drive] ${message}`, details ?? '');
}

async function googleStage<T>(stage: DriveProvisionStage, operation: string, work: () => Promise<T>) {
  logStage(stage, 'Starting');
  try {
    const value = await work();
    logStage(stage, 'Success');
    return value;
  } catch (cause) {
    const error = cause instanceof DriveProvisionError ? cause : new DriveProvisionError({ stage, operation, cause });
    logStage(stage, 'FAILED', error.diagnostic());
    throw error;
  }
}

function dbFailure(stage: DriveProvisionStage, operation: string, table: string, databaseOperation: ProvisionErrorDetails['databaseOperation'], error: { code?: string; message?: string }) {
  const failure = new DriveProvisionError({ stage, operation, table, databaseOperation, code: error.code, originalMessage: error.message });
  logStage(stage, 'FAILED', failure.diagnostic());
  return failure;
}

export async function provisionDriveFolder(result: DocketResult) {
  logStage('VALIDATE_CONFIGURATION', 'Starting');
  if (!Number.isSafeInteger(result.caseId) || !Number.isInteger(result.docketYear) || !result.docketDisplayNumber) {
    throw new DriveProvisionError({ stage: 'VALIDATE_CONFIGURATION', operation: 'validate docket RPC result', originalMessage: 'The docket result is incomplete.' });
  }
  let rootFolderId: string;
  try { rootFolderId = getDocketRootFolderId(); logStage('VALIDATE_CONFIGURATION', 'Success'); }
  catch (cause) { throw new DriveProvisionError({ stage: 'VALIDATE_CONFIGURATION', operation: 'read Drive root configuration', cause }); }

  logStage('CREATE_ADMIN_CLIENT', 'Starting');
  let admin: ReturnType<typeof getSupabaseAdminClient>;
  try { admin = getSupabaseAdminClient(); logStage('CREATE_ADMIN_CLIENT', 'Success'); }
  catch (cause) { throw new DriveProvisionError({ stage: 'CREATE_ADMIN_CLIENT', operation: 'create Supabase admin client', cause }); }

  logStage('LOAD_CASE', 'Starting');
  const existing = await admin.from('case_drive_folders' as never).select('folder_id,status').eq('case_id', result.caseId).maybeSingle();
  if (existing.error) throw dbFailure('LOAD_CASE', 'load existing case folder mapping', 'case_drive_folders', 'select', existing.error);
  logStage('LOAD_CASE', 'Success');
  const existingCase = existing.data as unknown as { folder_id?: string; status?: string } | null;
  if (existingCase?.folder_id && existingCase.status === 'READY') { logStage('COMPLETE', 'Existing mapping is READY'); return { status: 'READY', folderCreated: false }; }

  logStage('UPSERT_CASE_FOLDER', 'Starting');
  const pending = await admin.from('case_drive_folders' as never).upsert({ case_id: result.caseId, docket_year: result.docketYear, folder_name: result.docketDisplayNumber, parent_folder_id: rootFolderId, status: 'PENDING', last_error: null } as never, { onConflict: 'case_id' });
  if (pending.error) throw dbFailure('UPSERT_CASE_FOLDER', 'upsert pending case folder mapping', 'case_drive_folders', 'upsert', pending.error);
  logStage('UPSERT_CASE_FOLDER', 'Success');

  logStage('LOAD_YEAR_FOLDER', 'Starting');
  const loadedYear = await admin.from('docket_year_drive_folders' as never).select('folder_id,status').eq('docket_year', result.docketYear).eq('root_folder_id', rootFolderId).maybeSingle();
  if (loadedYear.error) throw dbFailure('LOAD_YEAR_FOLDER', 'load year folder mapping', 'docket_year_drive_folders', 'select', loadedYear.error);
  logStage('LOAD_YEAR_FOLDER', 'Success');
  const mappedYearFolderId = (loadedYear.data as unknown as { folder_id?: string; status?: string } | null)?.folder_id ?? null;
  let yearFolderId = await googleStage('LOAD_YEAR_FOLDER', 'find Google year folder inside configured root', () => findFolder(rootFolderId, String(result.docketYear)));
  if (mappedYearFolderId && !yearFolderId) logStage('LOAD_YEAR_FOLDER', 'Database mapping is stale; Google year folder was not found');

  if (!yearFolderId) {
    logStage('UPSERT_YEAR_FOLDER', 'Starting');
    const yearClaim = await admin.from('docket_year_drive_folders' as never).upsert({ docket_year: result.docketYear, root_folder_id: rootFolderId, status: 'CREATING', updated_at: new Date().toISOString() } as never, { onConflict: 'docket_year,root_folder_id' });
    if (yearClaim.error) throw dbFailure('UPSERT_YEAR_FOLDER', 'upsert year folder claim', 'docket_year_drive_folders', 'upsert', yearClaim.error);
    logStage('UPSERT_YEAR_FOLDER', 'Success');
    yearFolderId = await googleStage('CREATE_GOOGLE_YEAR_FOLDER', 'find or create Google year folder', () => findOrCreateFolder(rootFolderId, String(result.docketYear)));
    logStage('CREATE_GOOGLE_YEAR_FOLDER', `Google folder id = ${yearFolderId}`);
    const yearReady = await admin.from('docket_year_drive_folders' as never).update({ folder_id: yearFolderId, status: 'READY', updated_at: new Date().toISOString() } as never).eq('docket_year', result.docketYear).eq('root_folder_id', rootFolderId);
    if (yearReady.error) throw dbFailure('UPDATE_YEAR_FOLDER', 'mark year folder ready', 'docket_year_drive_folders', 'update', yearReady.error);
    logStage('UPDATE_YEAR_FOLDER', 'Success');
  } else {
    logStage('UPSERT_YEAR_FOLDER', 'Starting');
    const yearReady = await admin.from('docket_year_drive_folders' as never).upsert({ docket_year: result.docketYear, root_folder_id: rootFolderId, folder_id: yearFolderId, status: 'READY', updated_at: new Date().toISOString() } as never, { onConflict: 'docket_year,root_folder_id' });
    if (yearReady.error) throw dbFailure('UPSERT_YEAR_FOLDER', 'map existing Google year folder', 'docket_year_drive_folders', 'upsert', yearReady.error);
    logStage('UPSERT_YEAR_FOLDER', 'Success');
  }

  logStage('UPDATE_CASE_FOLDER', 'Starting');
  const creating = await admin.from('case_drive_folders' as never).update({ parent_folder_id: yearFolderId, status: 'CREATING', last_error: null } as never).eq('case_id', result.caseId);
  if (creating.error) throw dbFailure('UPDATE_CASE_FOLDER', 'mark case folder creating', 'case_drive_folders', 'update', creating.error);
  logStage('UPDATE_CASE_FOLDER', 'Success');
  const folderId = await googleStage('CREATE_GOOGLE_CASE_FOLDER', 'find or create Google case folder', () => findOrCreateFolder(yearFolderId!, result.docketDisplayNumber));
  logStage('CREATE_GOOGLE_CASE_FOLDER', `Google folder id = ${folderId}`);
  const ready = await admin.from('case_drive_folders' as never).update({ folder_id: folderId, parent_folder_id: yearFolderId, status: 'READY', last_error: null, updated_at: new Date().toISOString() } as never).eq('case_id', result.caseId);
  if (ready.error) throw dbFailure('UPDATE_CASE_FOLDER', 'mark case folder ready', 'case_drive_folders', 'update', ready.error);
  logStage('COMPLETE', 'Success');
  return { status: 'READY', folderCreated: true };
}
