'use client';

import { useParams } from 'next/navigation';

import { AuditLogRelatedScreen } from '@/components/audit-logs/audit-log-related-screen';
import { formatAuditIdentifier } from '@/components/audit-logs/audit-log-ui';

export default function AuditActionHistoryPage() {
  const params = useParams<{ action: string }>();
  const action = params.action?.trim() ?? '';

  return (
    <AuditLogRelatedScreen
      title={action ? formatAuditIdentifier(action) : 'Invalid action'}
      description={action ? `Every audit entry recorded with the ${action} action code.` : 'The action code in this URL is invalid.'}
      badge="Action history"
      filters={{ action: action || '__INVALID_ACTION__' }}
    />
  );
}
