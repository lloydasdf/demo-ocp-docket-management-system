'use client';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import NewDocketComponent from '@/components/pages/new-docket';

export default function NewDocketPage() {
  return (
    <RoleRouteGuard route="/new-docket">
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto">
        <NewDocketComponent />
      </main>
    </div>
    </RoleRouteGuard>
  );
}
