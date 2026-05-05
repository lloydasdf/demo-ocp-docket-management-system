'use client';

import { Sidebar } from '@/components/sidebar';
import CaseDetailsComponent from '@/components/pages/case-details';
import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

function CaseDetailsContent() {
  const searchParams = useSearchParams();
  const caseId = searchParams.get('caseId') || '';
  const docketId = searchParams.get('docketId') || '';

  return (
    <CaseDetailsComponent caseId={caseId} docketId={docketId} />
  );
}

export default function CaseDetailsPage() {
  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <Suspense fallback={<div className="p-8">Loading...</div>}>
          <CaseDetailsContent />
        </Suspense>
      </main>
    </div>
  );
}
