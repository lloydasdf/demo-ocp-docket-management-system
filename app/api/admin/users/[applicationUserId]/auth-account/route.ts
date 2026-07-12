import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';

import type { Database } from '@/lib/database.types';
import { getSupabaseAdminClient } from '@/lib/supabase/admin';

function json(status: number, code: string, message: string) {
  return NextResponse.json({ error: { code, message } }, { status });
}

function statusForPostgrestError(error: { code?: string; message?: string }) {
  const code = error.code ?? '';
  const message = (error.message ?? '').toLowerCase();
  if (code === '42501' || message.includes('not authorized') || message.includes('permission denied')) return 403;
  if (code === 'P0002' || message.includes('does not exist')) return 404;
  if (code === '23514' || code === 'P0001' || message.includes('already deleted') || message.includes('cannot delete') || message.includes('final active')) return 409;
  return 500;
}

function sanitizeErrorMessage(message: string) {
  return message.replace(/(service[_-]?role|bearer)\s+[A-Za-z0-9._~+/=-]+/gi, '$1 [redacted]').slice(0, 500);
}

export async function DELETE(request: NextRequest, context: { params: Promise<{ applicationUserId: string }> }) {
  const { applicationUserId } = await context.params;
  const targetUserId = Number(applicationUserId);

  if (!Number.isSafeInteger(targetUserId) || targetUserId <= 0) {
    return json(404, 'not_found', 'Target application user was not found.');
  }

  const authHeader = request.headers.get('authorization');
  const accessToken = authHeader?.match(/^Bearer\s+(.+)$/i)?.[1] ?? null;
  if (!accessToken) return json(401, 'unauthenticated', 'Authentication is required.');

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseAnonKey) return json(500, 'server_config_error', 'Supabase client environment variables are not configured.');

  const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: currentUserData, error: currentUserError } = await supabase.auth.getUser(accessToken);
  if (currentUserError || !currentUserData.user) return json(401, 'unauthenticated', 'Authentication is required.');

  const { data: prepared, error: prepareError } = await supabase.rpc('prepare_auth_account_deletion' as never, { p_target_user_id: targetUserId } as never);
  if (prepareError) return json(statusForPostgrestError(prepareError), prepareError.code ?? 'prepare_failed', prepareError.message ?? 'Unable to prepare auth account deletion.');

  const deletion = Array.isArray(prepared) ? prepared[0] : prepared;
  const preparedDeletion = deletion as { auth_user_id?: string | null; actor_user_id?: number | string | null; old_data?: unknown } | null;
  const authUserId = preparedDeletion?.auth_user_id;
  const actorUserId = preparedDeletion?.actor_user_id;
  const oldData = preparedDeletion?.old_data ?? null;
  if (!authUserId) return json(409, 'auth_account_already_deleted', 'The target user does not have an active login account.');
  if (!actorUserId) return json(500, 'prepare_failed', 'Unable to resolve the authenticated application user.');

  let admin;
  try {
    admin = getSupabaseAdminClient();
  } catch (error) {
    console.error('Supabase admin client configuration error', error);
    return json(500, 'server_config_error', 'Supabase admin client is not configured.');
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(authUserId);

  if (deleteError) {
    const sanitized = sanitizeErrorMessage(deleteError.message || 'Supabase Auth deletion failed.');
    const { error: auditError } = await admin.rpc('record_auth_account_deletion_failure' as never, {
      p_target_user_id: targetUserId,
      p_expected_auth_user_id: authUserId,
      p_error_message: sanitized,
      p_actor_user_id: actorUserId,
    } as never);
    if (auditError) {
      console.error('Failed to audit Supabase Auth account deletion failure', auditError);
    }
    console.error('Supabase Auth account deletion failed', { targetUserId, authUserId, error: sanitized });
    return NextResponse.json(
      { error: { code: 'auth_delete_failed', message: 'Unable to delete the login account.' } },
      { status: 500 },
    );
  }

  const finalizeArgs = {
    p_target_user_id: targetUserId,
    p_expected_auth_user_id: authUserId,
    p_actor_user_id: actorUserId,
    p_old_data: oldData,
  } as never;

  const { error: finalizeError } = await admin.rpc('finalize_auth_account_deletion' as never, finalizeArgs);

  if (finalizeError) {
    console.error('Auth account was deleted but database finalization failed; retrying once', { targetUserId, authUserId, error: finalizeError });
    const { error: retryFinalizeError } = await admin.rpc('finalize_auth_account_deletion' as never, finalizeArgs);

    if (retryFinalizeError) {
      console.error('Auth account was deleted but database finalization still failed after retry', { targetUserId, authUserId, error: retryFinalizeError });
      const repairMessage = sanitizeErrorMessage(retryFinalizeError.message || 'Database finalization failed after Auth deletion.');
      const { error: repairAuditError } = await admin.rpc('record_auth_account_finalization_failure' as never, {
        p_target_user_id: targetUserId,
        p_expected_auth_user_id: authUserId,
        p_error_message: repairMessage,
        p_actor_user_id: actorUserId,
      } as never);
      if (repairAuditError) {
        console.error('Failed to audit Auth account finalization repair requirement', { targetUserId, authUserId, error: repairAuditError });
      }
      return json(500, 'finalize_repair_required', 'The Auth login was deleted, but database finalization needs repair.');
    }
  }

  return NextResponse.json({ data: { application_user_id: targetUserId, login_deleted: true } });
}
