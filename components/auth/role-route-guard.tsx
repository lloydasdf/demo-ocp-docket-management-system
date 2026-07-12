'use client';

import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import { canAccessRoute } from '@/lib/auth/ui-permissions';
import { useCurrentUserRole } from '@/hooks/use-current-user-role';

function getLoginPath(pathname: string) {
  const returnTo = pathname.startsWith('/') ? pathname : '/cases';
  return `/login?returnTo=${encodeURIComponent(returnTo)}`;
}

export function RoleRouteGuard({ children, route }: { children: ReactNode; route?: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [authChecked, setAuthChecked] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const { role, isLoading: isRoleLoading, error } = useCurrentUserRole(isAuthenticated);
  const routeToCheck = route ?? pathname;

  useEffect(() => {
    let isMounted = true;
    async function checkAuth() {
      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getSession();
      if (!isMounted) return;
      setIsAuthenticated(Boolean(data.session));
      setAuthChecked(true);
      if (!data.session) router.replace(getLoginPath(pathname));
    }
    checkAuth();
    return () => { isMounted = false; };
  }, [pathname, router]);

  useEffect(() => {
    if (!authChecked || !isAuthenticated || isRoleLoading) return;
    if (error) console.error('Unable to resolve application role for route guard.', error);
    if (!canAccessRoute(error ? null : role, routeToCheck) && pathname !== '/cases') {
      router.replace('/cases');
    }
  }, [authChecked, error, isAuthenticated, isRoleLoading, pathname, role, routeToCheck, router]);

  if (!authChecked || !isAuthenticated || isRoleLoading || !canAccessRoute(error ? null : role, routeToCheck)) {
    return <div className="flex min-h-screen items-center justify-center bg-background text-sm text-muted-foreground">Checking access…</div>;
  }

  return <>{children}</>;
}
