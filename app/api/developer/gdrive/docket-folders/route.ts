import { NextResponse } from 'next/server';

import { reconcileDocketFolders } from '@/lib/docket-folder-reconciliation';
import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return NextResponse.json({ error: { message: 'Authentication is required.' } }, { status: 401 });
  const role = await auth.client.rpc('has_app_role' as never, { p_role_code: 'DEVELOPER' } as never);
  if (role.error || role.data !== true) return NextResponse.json({ error: { message: 'Developer role is required.' } }, { status: 403 });
  const body = await request.json().catch(() => null) as { caseIds?: unknown } | null;
  if (!Array.isArray(body?.caseIds) || body.caseIds.length > 10000 || body.caseIds.some((id) => !Number.isSafeInteger(id))) {
    return NextResponse.json({ error: { message: 'A valid list of at most 10,000 case IDs is required.' } }, { status: 400 });
  }
  try {
    return NextResponse.json({ data: await reconcileDocketFolders(body.caseIds as number[]) });
  } catch (error) {
    return NextResponse.json({ error: { message: error instanceof Error ? error.message : 'Unable to reconcile docket folders.' } }, { status: 502 });
  }
}
