import { getCurrentAppRoleCodes, type CurrentAppRoleCode } from '@/lib/supabase/queries';
import { normalizeRoleCode, type AppRoleCode } from '@/lib/auth/ui-permissions';

const ROLE_PRIORITY = ['DEVELOPER', 'CHIEF', 'ADMIN', 'PROSECUTOR', 'STAFF'];

export type CurrentUserRoleResult = {
  role: AppRoleCode | null;
  roles: AppRoleCode[];
  error: unknown | null;
};

export async function getCurrentUserRole(): Promise<CurrentUserRoleResult> {
  const result = await getCurrentAppRoleCodes();

  if (result.error) {
    return { role: null, roles: [], error: result.error };
  }

  const roles = (result.data ?? [])
    .map((role: CurrentAppRoleCode) => normalizeRoleCode(role))
    .filter((role): role is AppRoleCode => Boolean(role));

  const role = ROLE_PRIORITY.find((candidate) => roles.includes(candidate)) ?? roles[0] ?? null;
  return { role, roles, error: null };
}
