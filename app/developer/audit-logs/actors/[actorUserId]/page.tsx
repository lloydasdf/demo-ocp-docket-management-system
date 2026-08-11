'use client';

import { useParams } from 'next/navigation';

import { AuditLogRelatedScreen } from '@/components/audit-logs/audit-log-related-screen';

export default function AuditActorHistoryPage() {
  const params = useParams<{ actorUserId: string }>();
  const actorUserId = Number(params.actorUserId);
  const isValid = Number.isSafeInteger(actorUserId) && actorUserId > 0;

  return (
    <AuditLogRelatedScreen
      title={isValid ? `Actor activity: User #${actorUserId}` : 'Invalid actor'}
      description={isValid ? 'Every recorded action performed by this application user.' : 'The actor identifier in this URL is invalid.'}
      badge="Actor history"
      filters={{ actorUserId: isValid ? actorUserId : -1 }}
    />
  );
}
