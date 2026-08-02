import { NextResponse } from "next/server";
import { getDriveItemMetadata, isDriveItemInsideFolder, uploadDriveFile } from "@/lib/google-drive";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";
import { getAuthenticatedSupabase } from "@/lib/supabase/server-user";

export const runtime = "nodejs";
const MAX_UPLOAD_BYTES = 4.5 * 1024 * 1024;
const UPLOAD_LIMIT_MESSAGE = "This file cannot be uploaded here, go to Gdrive folder ot this case and upload the file there. Max upload here is 4.5MB";

function safeName(value: string) { const name = value.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, 200); return name && name !== "." && name !== ".." ? name : null; }

export async function POST(request: Request, context: { params: Promise<{ caseId: string }> }) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return NextResponse.json({ error: { code: "unauthenticated", message: "Authentication is required." } }, { status: 401 });
  const caseId = Number((await context.params).caseId);
  if (!Number.isSafeInteger(caseId) || caseId <= 0) return NextResponse.json({ error: { code: "not_found", message: "Case not found." } }, { status: 404 });
  const permission = await auth.client.rpc("can_edit_case_details" as never, { p_case_id: caseId } as never);
  if (permission.error || permission.data !== true) return NextResponse.json({ error: { code: "forbidden", message: "You do not have permission to upload attachments." } }, { status: 403 });
  const admin = getSupabaseAdminClient();
  const mappingResult = await admin.from("case_drive_folders" as never).select("folder_id,status").eq("case_id", caseId).maybeSingle();
  const mapping = mappingResult.data as unknown as { folder_id: string | null; status: string } | null;
  if (mappingResult.error || !mapping?.folder_id || mapping.status !== "READY") return NextResponse.json({ error: { code: "drive_unavailable", message: "The case Drive folder is not ready." } }, { status: 409 });
  try {
    const form = await request.formData(); const parentId = String(form.get("parentId") ?? ""); const file = form.get("file");
    if (!(file instanceof File) || !parentId || !safeName(file.name)) return NextResponse.json({ error: { code: "invalid_upload", message: "A valid file and destination folder are required." } }, { status: 400 });
    if (file.size === 0) return NextResponse.json({ error: { code: "empty_file", message: "Empty files cannot be uploaded." } }, { status: 400 });
    if (file.size > MAX_UPLOAD_BYTES) return NextResponse.json({ error: { code: "file_too_large", message: UPLOAD_LIMIT_MESSAGE } }, { status: 413 });
    if (!(await isDriveItemInsideFolder(parentId, mapping.folder_id))) return NextResponse.json({ error: { code: "invalid_destination", message: "The upload destination is outside this docket." } }, { status: 400 });
    const parent = await getDriveItemMetadata(parentId);
    if (parent.mimeType !== "application/vnd.google-apps.folder") return NextResponse.json({ error: { code: "invalid_destination", message: "The upload destination is not a folder." } }, { status: 400 });
    const uploaded = await uploadDriveFile(parentId, safeName(file.name)!, file.type || "application/octet-stream", file);
    const metadata = await getDriveItemMetadata(uploaded.id); const scannedAt = new Date().toISOString();
    const indexed = await admin.from("case_attachment_index").upsert({ case_id: caseId, gdrive_file_id: metadata.id, gdrive_parent_folder_id: parentId, file_name: metadata.name, mime_type: metadata.mimeType, web_view_link: metadata.webViewLink, file_size_bytes: metadata.size ? Number(metadata.size) : null, modified_time: metadata.modifiedTime, last_seen_at: scannedAt, last_scanned_at: scannedAt, file_status: "VISIBLE" }, { onConflict: "case_id,gdrive_file_id" });
    if (indexed.error) console.error("[Drive upload] attachment index synchronization failed", { code: indexed.error.code, caseId, fileId: metadata.id });
    return NextResponse.json({ data: { item: metadata, indexed: !indexed.error } }, { status: 201 });
  } catch (error) { console.error("[Drive upload] failed", error); return NextResponse.json({ error: { code: "upload_failed", message: "Google Drive could not upload this file." } }, { status: 502 }); }
}
