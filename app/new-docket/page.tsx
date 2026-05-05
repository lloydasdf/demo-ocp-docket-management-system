'use client';

import { Sidebar } from '@/components/sidebar';
import NewDocketComponent from '@/components/pages/new-docket';

export default function NewDocketPage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <NewDocketComponent />
      </main>
    </div>
  );
}
