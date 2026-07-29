import { NextResponse } from "next/server";

import { getDriveItemMetadata, isDriveItemInsideFolder, moveDriveItem, renameDriveItem, trashDriveItem } from "@/lib/google-drive";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";
import { getAuthenticatedSupabase } from "@/lib/supabase/server-user";

export const runtime = "nodejs";
const FOLDER_MIME = "application/vnd.google-apps.folder";

function validName(value: unknown) { if (typeof value !== "string") return null; const name = value.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, 200); return name && name !== "." && name !== ".." ? name : null; }

async function authorize(request: Request, caseId: number, fileId: string) {
  const auth = await getAuthenticatedSupabase(request); if (!auth) return { response: NextResponse.json({ error: { code: "unauthenticated", message: "Authentication is required." } }, { status: 401 }) };
  const permission = await auth.client.rpc("can_edit_case_details" as never, { p_case_id: caseId } as never); if (permission.error || permission.data !== true) return { response: NextResponse.json({ error: { code: "forbidden", message: "You do not have permission to manage attachments." } }, { status: 403 }) };
  const admin = getSupabaseAdminClient(); const mappingResult = await admin.from("case_drive_folders" as never).select("folder_id,status").eq("case_id", caseId).maybeSingle(); const mapping = mappingResult.data as unknown as { folder_id: string | null; status: string } | null;
  if (mappingResult.error || !mapping?.folder_id || mapping.status !== "READY") return { response: NextResponse.json({ error: { code: "drive_unavailable", message: "The case Drive folder is not ready." } }, { status: 409 }) };
  if (!(await isDriveItemInsideFolder(fileId, mapping.folder_id))) return { response: NextResponse.json({ error: { code: "not_found", message: "File not found in this docket." } }, { status: 404 }) };
  const metadata = await getDriveItemMetadata(fileId); if (metadata.mimeType === FOLDER_MIME) return { response: NextResponse.json({ error: { code: "invalid_file", message: "Folder operations use the folder endpoint." } }, { status: 400 }) };
  return { rootId: mapping.folder_id, metadata, admin };
}

export async function PATCH(request: Request, context: { params: Promise<{ caseId: string; fileId: string }> }) {
  const params = await context.params; const caseId = Number(params.caseId); if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: "not_found", message: "Case not found." } }, { status: 404 });
  try {
    const authorization = await authorize(request, caseId, params.fileId); if (authorization.response) return authorization.response;
    const body = await request.json().catch(() => null) as { action?: "rename" | "move"; name?: string; destinationFolderId?: string } | null;
    if (body?.action === "rename") { const name = validName(body.name); if (!name) return NextResponse.json({ error: { code: "invalid_name", message: "Enter a valid file name." } }, { status: 400 }); await renameDriveItem(params.fileId, name); }
    else if (body?.action === "move" && body.destinationFolderId) { if (!(await isDriveItemInsideFolder(body.destinationFolderId, authorization.rootId!))) return NextResponse.json({ error: { code: "invalid_destination", message: "The destination is outside this docket." } }, { status: 400 }); const destination = await getDriveItemMetadata(body.destinationFolderId); if (destination.mimeType !== FOLDER_MIME) return NextResponse.json({ error: { code: "invalid_destination", message: "The destination is not a folder." } }, { status: 400 }); await moveDriveItem(params.fileId, body.destinationFolderId, authorization.metadata!.parents ?? []); }
    else return NextResponse.json({ error: { code: "invalid_request", message: "Choose a valid file operation." } }, { status: 400 });
    const item = await getDriveItemMetadata(params.fileId);
    const updated = await authorization.admin!.from("case_attachment_index").update({ file_name: item.name, gdrive_parent_folder_id: item.parents?.[0] ?? authorization.metadata!.parents?.[0], modified_time: item.modifiedTime ?? new Date().toISOString(), file_size_bytes: item.size ? Number(item.size) : authorization.metadata!.size ? Number(authorization.metadata!.size) : null, file_status: "VISIBLE", last_seen_at: new Date().toISOString() }).eq("case_id", caseId).eq("gdrive_file_id", params.fileId);
    if (updated.error) console.error("[Drive file] index update failed", { caseId, fileId: params.fileId, code: updated.error.code });
    return NextResponse.json({ data: { item } });
  } catch (error) { console.error("[Drive file] update failed", error); return NextResponse.json({ error: { code: "file_update_failed", message: "The file operation could not be completed." } }, { status: 502 }); }
}

export async function DELETE(request: Request, context: { params: Promise<{ caseId: string; fileId: string }> }) {
  const params = await context.params; const caseId = Number(params.caseId); if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: "not_found", message: "Case not found." } }, { status: 404 });
  try { const authorization = await authorize(request, caseId, params.fileId); if (authorization.response) return authorization.response; await trashDriveItem(params.fileId); const updated = await authorization.admin!.from("case_attachment_index").update({ file_status: "MISSING", last_scanned_at: new Date().toISOString() }).eq("case_id", caseId).eq("gdrive_file_id", params.fileId); if (updated.error) console.error("[Drive file] index trash update failed", { caseId, fileId: params.fileId, code: updated.error.code }); return NextResponse.json({ data: { trashed: true } }); }
  catch (error) { console.error("[Drive file] trash failed", error); return NextResponse.json({ error: { code: "file_trash_failed", message: "The file could not be moved to trash." } }, { status: 502 }); }
}
