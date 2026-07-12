'use client';

import { usePathname, useRouter } from 'next/navigation';
import { useEffect, type ReactNode } from 'react';
import { Button } from '@/components/ui/button';
import { canAccessRoute } from '@/lib/auth/ui-permissions';
import { useAppAuthRole } from '@/hooks/use-app-auth-role';

function getLoginPath(pathname: string) {
  const returnTo = pathname.startsWith('/') ? pathname : '/cases';
  return `/login?returnTo=${encodeURIComponent(returnTo)}`;
}

function CheckingAccess() {
  return <div className="flex min-h-screen items-center justify-center bg-background text-sm text-muted-foreground">Checking access…</div>;
}

export function RoleRouteGuard({ children, route }: { children: ReactNode; route?: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const {
    roles,
    isAuthLoading,
    isRoleLoading,
    isAuthenticated,
    authError,
    roleError,
    refreshRole,
  } = useAppAuthRole();
  const routeToCheck = route ?? pathname;
  const roleResolved = !isRoleLoading && roles.length > 0;

  useEffect(() => {
    if (isAuthLoading) return;
    if (!isAuthenticated) {
      router.replace(getLoginPath(pathname));
    }
  }, [isAuthLoading, isAuthenticated, pathname, router]);

  useEffect(() => {
    if (
      isAuthLoading ||
      !isAuthenticated ||
      isRoleLoading ||
      roleError ||
      !roleResolved ||
      pathname === '/cases'
    ) {
      return;
    }

    if (!canAccessRoute(roles, routeToCheck)) {
      router.replace('/cases');
    }
  }, [isAuthLoading, isAuthenticated, isRoleLoading, pathname, roleError, roleResolved, roles, routeToCheck, router]);

  if (isAuthLoading || (!isAuthenticated && !authError) || (isAuthenticated && isRoleLoading)) {
    return <CheckingAccess />;
  }

  if (authError) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-6 text-center">
        <div className="max-w-md space-y-4 rounded-lg border bg-card p-6 shadow-sm">
          <h1 className="text-lg font-semibold">Unable to verify your session</h1>
          <p className="text-sm text-muted-foreground">Please refresh the page or sign in again.</p>
          <Button type="button" onClick={() => router.replace(getLoginPath(pathname))}>Sign in again</Button>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <CheckingAccess />;
  }

  if (roleError) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-6 text-center">
        <div className="max-w-md space-y-4 rounded-lg border bg-card p-6 shadow-sm">
          <h1 className="text-lg font-semibold">Unable to verify your application role</h1>
          <p className="text-sm text-muted-foreground">Unable to verify your application role. Please refresh the page or sign in again.</p>
          <div className="flex flex-wrap justify-center gap-2">
            <Button type="button" onClick={refreshRole}>Retry</Button>
            <Button type="button" variant="outline" onClick={() => router.replace('/cases')}>Return to Cases</Button>
          </div>
        </div>
      </div>
    );
  }

  if (!roleResolved) {
    return <CheckingAccess />;
  }

  if (!canAccessRoute(roles, routeToCheck)) {
    return <CheckingAccess />;
  }

  return <>{children}</>;
}
