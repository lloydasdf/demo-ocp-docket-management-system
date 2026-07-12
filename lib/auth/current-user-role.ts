import { getCurrentAppRoleCodes } from '@/lib/supabase/queries';
import { normalizeRoleCode, type AppRoleCode } from '@/lib/auth/ui-permissions';

function readStringProperty(value: object, property: 'role_code' | 'code') {
  if (property in value) {
    const candidate = value[property as keyof typeof value];
    return typeof candidate === 'string' ? candidate : null;
  }

  return null;
}

export function extractRoleCode(value: unknown): string | null {
  if (typeof value === 'string') {
    return value;
  }

  if (value && typeof value === 'object') {
    return readStringProperty(value, 'role_code') ?? readStringProperty(value, 'code');
  }

  return null;
}

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

  const roles = Array.from(new Set((result.data ?? [])
    .map((role: unknown) => normalizeRoleCode(extractRoleCode(role)))
    .filter((role): role is AppRoleCode => Boolean(role))));

  return { role: roles.length === 1 ? roles[0] : null, roles, error: null };
}
