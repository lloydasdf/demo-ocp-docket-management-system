'use client';

import { Sidebar } from '@/components/sidebar';
import ProsecutorAssignmentComponent from '@/components/pages/prosecutor-assignment';

export default function ProsecutorAssignmentPage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <ProsecutorAssignmentComponent />
      </main>
    </div>
  );
}
