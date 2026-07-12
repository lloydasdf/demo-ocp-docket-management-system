'use client';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import ClearanceSearchComponent from '@/components/pages/clearance-search';

export default function ClearanceSearchPage() {
  return (
    <RoleRouteGuard route="/clearance-search">
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto">
        <ClearanceSearchComponent />
      </main>
    </div>
    </RoleRouteGuard>
  );
}
