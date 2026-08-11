'use client';

import { useParams } from 'next/navigation';

import { AuditLogRelatedScreen } from '@/components/audit-logs/audit-log-related-screen';
import { formatAuditIdentifier } from '@/components/audit-logs/audit-log-ui';

export default function AuditEntityHistoryPage() {
  const params = useParams<{ entityName: string; entityId?: string[] }>();
  const entityName = params.entityName?.trim() ?? '';
  const entityIdValue = params.entityId?.[0];
  const entityId = entityIdValue === undefined ? null : Number(entityIdValue);
  const hasValidEntityId = entityId === null || (Number.isSafeInteger(entityId) && entityId > 0);
  const isValid = Boolean(entityName) && hasValidEntityId;
  const entityLabel = entityName ? formatAuditIdentifier(entityName) : 'Invalid entity';

  return (
    <AuditLogRelatedScreen
      title={isValid && entityId !== null ? `${entityLabel} #${entityId}` : entityLabel}
      description={isValid
        ? entityId === null
          ? `Every audit entry associated with the ${entityName} entity type.`
          : `The complete audit history for ${entityName} record #${entityId}.`
        : 'The entity identifier in this URL is invalid.'}
      badge={entityId === null ? 'Entity type history' : 'Entity record history'}
      filters={{ entityName: isValid ? entityName : '__INVALID_ENTITY__', entityId: isValid ? entityId : -1 }}
    />
  );
}
