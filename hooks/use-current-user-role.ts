'use client';

import { useAppAuthRole } from '@/hooks/use-app-auth-role';

export function useCurrentUserRole(enabled = true) {
  const { role, roles, isRoleLoading, roleError } = useAppAuthRole();

  if (!enabled) {
    return { role: null, roles: [], isLoading: false, error: null };
  }

  return { role, roles, isLoading: isRoleLoading, error: roleError };
}
