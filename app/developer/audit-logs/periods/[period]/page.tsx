'use client';

import { useParams } from 'next/navigation';

import { AuditLogRelatedScreen } from '@/components/audit-logs/audit-log-related-screen';

const PERIODS = {
  all: { title: 'All audit records', description: 'The complete audit history available to the developer account.' },
  '24h': { title: 'Activity in the last 24 hours', description: 'Audit entries recorded during the rolling 24-hour window.' },
  '7d': { title: 'Activity in the last 7 days', description: 'Audit entries recorded during the rolling seven-day window.' },
  '30d': { title: 'Activity in the last 30 days', description: 'Audit entries recorded during the rolling 30-day window.' },
} as const;

export default function AuditPeriodPage() {
  const params = useParams<{ period: string }>();
  const period = params.period as keyof typeof PERIODS;
  const definition = PERIODS[period] ?? PERIODS.all;

  return (
    <AuditLogRelatedScreen
      title={definition.title}
      description={definition.description}
      badge="Time window"
      filters={{}}
      initialPeriod={period in PERIODS ? period : 'all'}
    />
  );
}
