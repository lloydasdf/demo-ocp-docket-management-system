'use client';

import { useParams } from 'next/navigation';

import { AuditLogRelatedScreen } from '@/components/audit-logs/audit-log-related-screen';
import { formatAuditIdentifier } from '@/components/audit-logs/audit-log-ui';

export default function AuditActivityHistoryPage() {
  const params = useParams<{ entityName: string; action: string }>();
  const entityName = params.entityName?.trim() ?? '';
  const action = params.action?.trim() ?? '';
  const isValid = Boolean(entityName && action);

  return (
    <AuditLogRelatedScreen
      title={isValid ? formatAuditIdentifier(action) : 'Invalid activity'}
      description={isValid
        ? `Every ${action} audit entry recorded against the ${entityName} entity type.`
        : 'The activity identifiers in this URL are invalid.'}
      badge={isValid ? formatAuditIdentifier(entityName) : 'Activity history'}
      filters={{
        entityName: isValid ? entityName : '__INVALID_ENTITY__',
        action: isValid ? action : '__INVALID_ACTION__',
      }}
    />
  );
}
