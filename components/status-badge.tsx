import { Badge } from '@/components/ui/badge';
import { CaseStatus } from '@/lib/types';

interface StatusBadgeProps {
  status: CaseStatus | string | null | undefined;
  size?: 'sm' | 'md' | 'lg';
}

const statusConfig: Record<CaseStatus, { bg: string; text: string; label: string }> = {
  Pending: {
    bg: 'bg-[hsl(var(--status-pending))]',
    text: 'text-gray-900',
    label: 'Pending',
  },
  Filed: {
    bg: 'bg-[hsl(var(--status-filed))]',
    text: 'text-white',
    label: 'Filed',
  },
  Dismissed: {
    bg: 'bg-[hsl(var(--status-dismissed))]',
    text: 'text-gray-700',
    label: 'Dismissed',
  },
  Resolved: {
    bg: 'bg-[hsl(var(--status-resolved))]',
    text: 'text-white',
    label: 'Resolved',
  },
  RFI: {
    bg: 'bg-[hsl(var(--status-rfi))]',
    text: 'text-white',
    label: 'RFI',
  },
};

function isKnownCaseStatus(status: string): status is CaseStatus {
  return status in statusConfig;
}

export function StatusBadge({ status, size = 'md' }: StatusBadgeProps) {
  const statusLabel = status?.trim() || 'Unknown';
  const config = isKnownCaseStatus(statusLabel)
    ? statusConfig[statusLabel]
    : {
        bg: 'bg-muted',
        text: 'text-muted-foreground',
        label: statusLabel,
      };
  const sizeClasses = {
    sm: 'text-xs px-2 py-1',
    md: 'text-sm px-3 py-1.5',
    lg: 'text-base px-4 py-2',
  };

  return (
    <Badge
      className={`${config.bg} ${config.text} ${sizeClasses[size]} font-medium whitespace-nowrap`}
    >
      {config.label}
    </Badge>
  );
}
