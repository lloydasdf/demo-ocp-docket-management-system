'use client';

import { useParams } from 'next/navigation';

import {
  CASE_STAGE_QUEUE_DEFINITIONS,
  CaseStageRelatedScreen,
  isDeveloperCaseStageQueue,
} from '@/components/case-stage-monitor/case-stage-related-screen';

export default function CaseStageQueuePage() {
  const params = useParams<{ queue: string }>();
  const requestedQueue = params.queue?.trim() ?? '';
  const isValid = isDeveloperCaseStageQueue(requestedQueue);
  const queue = isValid ? requestedQueue : 'all';
  const definition = isValid
    ? CASE_STAGE_QUEUE_DEFINITIONS[queue]
    : { title: 'Invalid monitoring queue', description: 'The monitoring queue in this URL is not recognized.' };

  return (
    <CaseStageRelatedScreen
      title={definition.title}
      description={definition.description}
      badge="Queue view"
      queue={queue}
      stageCode={isValid ? null : '__INVALID_QUEUE__'}
    />
  );
}
