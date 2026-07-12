'use client';

import { useEffect, useState } from 'react';
import { getCurrentUserRole } from '@/lib/auth/current-user-role';
import type { AppRoleCode } from '@/lib/auth/ui-permissions';

export function useCurrentUserRole(enabled = true) {
  const [role, setRole] = useState<AppRoleCode | null>(null);
  const [roles, setRoles] = useState<AppRoleCode[]>([]);
  const [isLoading, setIsLoading] = useState(enabled);
  const [error, setError] = useState<unknown | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function loadRole() {
      if (!enabled) {
        setRole(null);
        setRoles([]);
        setIsLoading(false);
        setError(null);
        return;
      }

      setIsLoading(true);
      const result = await getCurrentUserRole();
      if (!isMounted) return;
      setRole(result.role);
      setRoles(result.roles);
      setError(result.error);
      setIsLoading(false);
    }

    loadRole();
    return () => {
      isMounted = false;
    };
  }, [enabled]);

  return { role, roles, isLoading, error };
}
