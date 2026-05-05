'use client';

import { Sidebar } from '@/components/sidebar';
import ReportsComponent from '@/components/pages/reports';

export default function ReportsPage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <ReportsComponent />
      </main>
    </div>
  );
}
