'use client';

import { Sidebar } from '@/components/sidebar';
import ClearanceSearchComponent from '@/components/pages/clearance-search';

export default function ClearanceSearchPage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <ClearanceSearchComponent />
      </main>
    </div>
  );
}
