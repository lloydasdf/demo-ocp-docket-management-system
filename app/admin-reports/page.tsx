'use client';

import { RoleRouteGuard } from '@/components/auth/role-route-guard';
import { Sidebar } from '@/components/sidebar';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

export default function AdminReportsPage() {
  return (
    <RoleRouteGuard route="/admin-reports">
      <div className="flex h-screen overflow-hidden bg-background">
        <Sidebar />
        <main className="min-w-0 flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">
          <Card>
            <CardHeader>
              <CardTitle>Admin Reports</CardTitle>
              <CardDescription>View administrative reports</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">Not yet configured</p>
            </CardContent>
          </Card>
        </main>
      </div>
    </RoleRouteGuard>
  );
}
