'use client';

import { Sidebar } from '@/components/sidebar';
import CaseDetailsComponent from '@/components/pages/case-details';
import { useSearchParams } from 'next/navigation';

export default function CaseDetailsPage() {
  const searchParams = useSearchParams();
  const caseId = searchParams.get('caseId') || '';
  const docketId = searchParams.get('docketId') || '';

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <CaseDetailsComponent caseId={caseId} docketId={docketId} />
      </main>
    </div>
  );
}
