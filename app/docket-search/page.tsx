'use client';

import { Sidebar } from '@/components/sidebar';
import DocketSearchComponent from '@/components/pages/docket-search';

export default function DocketSearchPage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <DocketSearchComponent />
      </main>
    </div>
  );
}
