import { NextResponse } from 'next/server';

import { openDrivePdfPreview, verifyDrivePdfPreviewToken } from '@/lib/drive-pdf-preview';

export const runtime = 'nodejs';

function contentDisposition(name: string) {
  const safeAscii = name.replace(/[^\x20-\x7e]/g, '_').replace(/["\\]/g, '_').slice(0, 180) || 'preview.pdf';
  return `inline; filename="${safeAscii}"; filename*=UTF-8''${encodeURIComponent(name.slice(0, 240))}`;
}

export async function GET(request: Request, context: { params: Promise<{ caseId: string; fileId: string }> }) {
  const params = await context.params;
  const caseId = Number(params.caseId);
  if (!Number.isSafeInteger(caseId) || caseId <= 0 || !params.fileId) {
    return NextResponse.json({ error: { code: 'not_found', message: 'PDF preview not found.' } }, { status: 404 });
  }

  const token = new URL(request.url).searchParams.get('token');
  const claims = verifyDrivePdfPreviewToken(token, caseId, params.fileId);
  if (!claims) {
    return NextResponse.json({ error: { code: 'preview_expired', message: 'This PDF preview link is invalid or expired. Refresh the attachments and try again.' } }, { status: 401 });
  }

  try {
    const preview = await openDrivePdfPreview({
      fileId: params.fileId,
      rootFolderId: claims.rootFolderId,
      parentFolderId: claims.parentFolderId,
      range: request.headers.get('range'),
    });

    const headers = new Headers({
      'content-type': preview.contentType,
      'content-disposition': contentDisposition(preview.fileName),
      'cache-control': 'private, no-store',
      'accept-ranges': preview.acceptRanges,
      'x-content-type-options': 'nosniff',
      'vary': 'Range',
    });
    if (preview.contentLength) headers.set('content-length', preview.contentLength);
    if (preview.contentRange) headers.set('content-range', preview.contentRange);

    return new Response(preview.status === 416 ? null : preview.body, {
      status: preview.status,
      headers,
    });
  } catch (error) {
    console.error('[Drive PDF preview] Streaming failed', {
      caseId,
      fileId: params.fileId,
      message: error instanceof Error ? error.message : 'Unknown error',
    });
    return NextResponse.json({ error: { code: 'preview_failed', message: 'Unable to preview the PDF.' } }, { status: 502 });
  }
}
