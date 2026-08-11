'use client';

import { useParams } from 'next/navigation';

import {
  CaseStageRelatedScreen,
  formatCaseStageIdentifier,
} from '@/components/case-stage-monitor/case-stage-related-screen';

export default function CaseStagePage() {
  const params = useParams<{ stageCode: string }>();
  const stageCode = params.stageCode?.trim() ?? '';

  return (
    <CaseStageRelatedScreen
      title={stageCode ? formatCaseStageIdentifier(stageCode) : 'Invalid case stage'}
      description={stageCode ? `Active cases whose canonical current stage code is ${stageCode}.` : 'The stage code in this URL is invalid.'}
      badge="Stage view"
      stageCode={stageCode || '__INVALID_STAGE__'}
    />
  );
}
