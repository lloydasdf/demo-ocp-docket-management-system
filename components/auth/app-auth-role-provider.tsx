'use client';

import { createContext, useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import type { User } from '@supabase/supabase-js';
import { getCurrentUserRole } from '@/lib/auth/current-user-role';
import type { AppRoleCode } from '@/lib/auth/ui-permissions';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';

export type AppAuthRoleContextValue = {
  user: User | null;
  role: AppRoleCode | null;
  roles: AppRoleCode[];
  isAuthLoading: boolean;
  isRoleLoading: boolean;
  isAuthenticated: boolean;
  authError: unknown | null;
  roleError: unknown | null;
  refreshRole: () => Promise<void>;
};

export const AppAuthRoleContext = createContext<AppAuthRoleContextValue | null>(null);

export function AppAuthRoleProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [role, setRole] = useState<AppRoleCode | null>(null);
  const [roles, setRoles] = useState<AppRoleCode[]>([]);
  const [isAuthLoading, setIsAuthLoading] = useState(true);
  const [isRoleLoading, setIsRoleLoading] = useState(false);
  const [authError, setAuthError] = useState<unknown | null>(null);
  const [roleError, setRoleError] = useState<unknown | null>(null);
  const loadRoleSequenceRef = useRef(0);
  const authenticatedUserIdRef = useRef<string | null>(null);

  const clearRole = useCallback(() => {
    loadRoleSequenceRef.current += 1;
    setRole(null);
    setRoles([]);
    setRoleError(null);
    setIsRoleLoading(false);
  }, []);

  const refreshRole = useCallback(async () => {
    const sequence = loadRoleSequenceRef.current + 1;
    loadRoleSequenceRef.current = sequence;
    setIsRoleLoading(true);
    setRoleError(null);

    try {
      const result = await getCurrentUserRole();
      if (loadRoleSequenceRef.current !== sequence) return;
      setRole(result.role);
      setRoles(result.roles);
      setRoleError(result.error);
    } catch (error) {
      if (loadRoleSequenceRef.current !== sequence) return;
      setRole(null);
      setRoles([]);
      setRoleError(error);
    } finally {
      if (loadRoleSequenceRef.current === sequence) {
        setIsRoleLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    let isMounted = true;
    let unsubscribe: (() => void) | undefined;

    async function initializeAuth() {
      try {
        const supabase = await getSupabaseBrowserClient();
        const { data, error } = await supabase.auth.getSession();

        if (!isMounted) return;
        if (error) {
          setAuthError(error);
        }

        const initialUser = data.session?.user ?? null;
        authenticatedUserIdRef.current = initialUser?.id ?? null;
        setUser(initialUser);
        setIsAuthLoading(false);

        const { data: authListener } = supabase.auth.onAuthStateChange((event, session) => {
          const nextUser = session?.user ?? null;
          const nextUserId = nextUser?.id ?? null;

          if (authenticatedUserIdRef.current !== nextUserId) {
            clearRole();
          }

          authenticatedUserIdRef.current = nextUserId;
          setUser(nextUser);
          setAuthError(null);

          if (event === 'SIGNED_OUT' || !session) {
            clearRole();
          }
        });

        unsubscribe = () => authListener.subscription.unsubscribe();
      } catch (error) {
        if (!isMounted) return;
        authenticatedUserIdRef.current = null;
        setUser(null);
        setAuthError(error);
        clearRole();
        setIsAuthLoading(false);
      }
    }

    initializeAuth();

    return () => {
      isMounted = false;
      unsubscribe?.();
      loadRoleSequenceRef.current += 1;
    };
  }, [clearRole]);

  useEffect(() => {
    if (isAuthLoading) return;
    if (!user) {
      clearRole();
      return;
    }

    refreshRole();
  }, [clearRole, isAuthLoading, refreshRole, user?.id]);

  const value = useMemo<AppAuthRoleContextValue>(() => ({
    user,
    role,
    roles,
    isAuthLoading,
    isRoleLoading,
    isAuthenticated: Boolean(user),
    authError,
    roleError,
    refreshRole,
  }), [authError, isAuthLoading, isRoleLoading, refreshRole, role, roleError, roles, user]);

  return <AppAuthRoleContext.Provider value={value}>{children}</AppAuthRoleContext.Provider>;
}
