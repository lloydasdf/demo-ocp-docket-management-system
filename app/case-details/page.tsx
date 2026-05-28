import { Suspense } from 'react';
import { CaseDetailsContent } from './case-details-content';

export default function CaseDetailsPage() {
  return (
    <Suspense fallback={null}>
      <CaseDetailsContent />
    </Suspense>
  );
}
