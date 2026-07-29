import { NextResponse } from "next/server";

import { createFolder, getDriveItemMetadata, isDriveItemInsideFolder, renameDriveItem, trashDriveItem } from "@/lib/google-drive";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";
import { getAuthenticatedSupabase } from "@/lib/supabase/server-user";

export const runtime = "nodejs";

function validName(value: unknown) {
  if (typeof value !== "string") return null;
  const name = value.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, 200);
  return name && name !== "." && name !== ".." ? name : null;
}

async function authorize(request: Request, caseId: number) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return { response: NextResponse.json({ error: { code: "unauthenticated", message: "Authentication is required." } }, { status: 401 }) };
  const permission = await auth.client.rpc("can_edit_case_details" as never, { p_case_id: caseId } as never);
  if (permission.error || permission.data !== true) return { response: NextResponse.json({ error: { code: "forbidden", message: "You do not have permission to manage attachment folders." } }, { status: 403 }) };
  const mappingResult = await getSupabaseAdminClient().from("case_drive_folders" as never).select("folder_id,status").eq("case_id", caseId).maybeSingle();
  const mapping = mappingResult.data as unknown as { folder_id: string | null; status: string } | null;
  if (mappingResult.error || !mapping?.folder_id || mapping.status !== "READY") return { response: NextResponse.json({ error: { code: "drive_unavailable", message: "The case Drive folder is not ready." } }, { status: 409 }) };
  return { rootId: mapping.folder_id };
}

async function folderInsideDocket(itemId: string, rootId: string) {
  if (!(await isDriveItemInsideFolder(itemId, rootId))) return false;
  return (await getDriveItemMetadata(itemId)).mimeType === "application/vnd.google-apps.folder";
}

export async function POST(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const caseId = Number((await context.params).caseId);
  if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: "not_found", message: "Case not found." } }, { status: 404 });
  const authorization = await authorize(request, caseId); if (authorization.response) return authorization.response;
  try {
    const body = await request.json().catch(() => null) as { parentId?: string; name?: string } | null; const name = validName(body?.name);
    if (!body?.parentId || !name || !(await folderInsideDocket(body.parentId, authorization.rootId!))) return NextResponse.json({ error: { code: "invalid_folder", message: "A valid folder name and destination are required." } }, { status: 400 });
    const folderId = await createFolder(body.parentId, name);
    return NextResponse.json({ data: { folder: await getDriveItemMetadata(folderId) } }, { status: 201 });
  } catch (error) { console.error("[Drive folder] create failed", error); return NextResponse.json({ error: { code: "folder_create_failed", message: "The folder could not be created." } }, { status: 502 }); }
}

export async function PATCH(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const caseId = Number((await context.params).caseId); if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: "not_found", message: "Case not found." } }, { status: 404 });
  const authorization = await authorize(request, caseId); if (authorization.response) return authorization.response;
  try {
    const body = await request.json().catch(() => null) as { folderId?: string; name?: string } | null; const name = validName(body?.name);
    if (!body?.folderId || body.folderId === authorization.rootId || !name || !(await folderInsideDocket(body.folderId, authorization.rootId!))) return NextResponse.json({ error: { code: "invalid_folder", message: "The selected folder cannot be renamed." } }, { status: 400 });
    return NextResponse.json({ data: { folder: await renameDriveItem(body.folderId, name) } });
  } catch (error) { console.error("[Drive folder] rename failed", error); return NextResponse.json({ error: { code: "folder_rename_failed", message: "The folder could not be renamed." } }, { status: 502 }); }
}

export async function DELETE(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const caseId = Number((await context.params).caseId); if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: "not_found", message: "Case not found." } }, { status: 404 });
  const authorization = await authorize(request, caseId); if (authorization.response) return authorization.response;
  try {
    const folderId = new URL(request.url).searchParams.get("folderId");
    if (!folderId || folderId === authorization.rootId || !(await folderInsideDocket(folderId, authorization.rootId!))) return NextResponse.json({ error: { code: "invalid_folder", message: "The selected folder cannot be trashed." } }, { status: 400 });
    await trashDriveItem(folderId); return NextResponse.json({ data: { trashed: true } });
  } catch (error) { console.error("[Drive folder] trash failed", error); return NextResponse.json({ error: { code: "folder_trash_failed", message: "The folder could not be moved to trash." } }, { status: 502 }); }
}
