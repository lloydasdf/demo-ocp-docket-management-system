'use client';

import { Sidebar } from '@/components/sidebar';
import StatusUpdateComponent from '@/components/pages/status-update';

export default function StatusUpdatePage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <StatusUpdateComponent />
      </main>
    </div>
  );
}
