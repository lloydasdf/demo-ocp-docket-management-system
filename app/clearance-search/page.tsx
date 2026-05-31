'use client';

import { Sidebar } from '@/components/sidebar';
import ClearanceSearchComponent from '@/components/pages/clearance-search';

export default function ClearanceSearchPage() {
  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto">
        <ClearanceSearchComponent />
      </main>
    </div>
  );
}
