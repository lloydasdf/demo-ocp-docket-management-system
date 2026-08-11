'use client';

import { useParams } from 'next/navigation';

import { CaseStageRelatedScreen } from '@/components/case-stage-monitor/case-stage-related-screen';

export default function CaseStageYearPage() {
  const params = useParams<{ year: string }>();
  const year = Number(params.year);
  const isValid = Number.isInteger(year) && year > 0;

  return (
    <CaseStageRelatedScreen
      title={isValid ? `Docket year ${year}` : 'Invalid docket year'}
      description={isValid ? `Every active monitored case received under docket year ${year}.` : 'The docket year in this URL is invalid.'}
      badge="Year view"
      stageCode={isValid ? null : '__INVALID_YEAR__'}
      initialDocketYear={isValid ? year : null}
    />
  );
}
