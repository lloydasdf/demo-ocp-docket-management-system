import { Badge } from '@/components/ui/badge';
import type { CaseStage, CaseStatus } from '@/lib/types';

interface StatusBadgeProps {
  status: CaseStatus | string | null | undefined;
  size?: 'sm' | 'md' | 'lg';
}

interface StageBadgeProps {
  stage: CaseStage | string | null | undefined;
  size?: 'sm' | 'md' | 'lg';
}

type BadgeConfig = { bg: string; text: string; label: string };

const statusConfig: Record<CaseStatus, BadgeConfig> = {
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
  'Mixed Result': {
    bg: 'bg-orange-100',
    text: 'text-orange-900',
    label: 'Mixed Result',
  },
};

const stageConfig: Record<CaseStage, BadgeConfig> = {
  'For Raffle': {
    bg: 'bg-gray-50',
    text: 'text-gray-800',
    label: 'For Raffle',
  },
  'Case Raffled': {
    bg: 'bg-blue-50',
    text: 'text-blue-800',
    label: 'Case Raffled',
  },
  'Case Reassigned': {
    bg: 'bg-indigo-50',
    text: 'text-indigo-800',
    label: 'Case Reassigned',
  },
  Pending: {
    bg: 'bg-amber-50',
    text: 'text-amber-800',
    label: 'Pending',
  },
  'Reso for Approval': {
    bg: 'bg-blue-50',
    text: 'text-blue-800',
    label: 'Reso for Approval',
  },
  'For Filing': {
    bg: 'bg-violet-50',
    text: 'text-violet-800',
    label: 'For Filing',
  },
  'Filed; other resolution for approval': {
    bg: 'bg-indigo-50',
    text: 'text-indigo-800',
    label: 'Filed; other resolution for approval',
  },
  'Filed; other info for filing': {
    bg: 'bg-cyan-50',
    text: 'text-cyan-800',
    label: 'Filed; other info for filing',
  },
  Filed: {
    bg: 'bg-green-50',
    text: 'text-green-800',
    label: 'Filed',
  },
  Dismissed: {
    bg: 'bg-slate-50',
    text: 'text-slate-800',
    label: 'Dismissed',
  },
  'Mixed Result': {
    bg: 'bg-orange-50',
    text: 'text-orange-800',
    label: 'Mixed Result',
  },
};

const normalizedStatusLabels: Record<string, CaseStatus> = {
  PENDING: 'Pending',
  FILED: 'Filed',
  DISMISSED: 'Dismissed',
  MIXED_RESULT: 'Mixed Result',
};

const normalizedStageLabels: Record<string, CaseStage> = {
  FOR_RAFFLE: 'For Raffle',
  CASE_RAFFLED: 'Case Raffled',
  CASE_REASSIGNED: 'Case Reassigned',
  PENDING: 'Pending',
  RESO_FOR_APPROVAL: 'Reso for Approval',
  FOR_FILING: 'For Filing',
  FILED_OTHER_RESO_FOR_APPROVAL: 'Filed; other resolution for approval',
  FILED_OTHER_INFO_FOR_FILING: 'Filed; other info for filing',
  FILED: 'Filed',
  DISMISSED: 'Dismissed',
  MIXED_RESULT: 'Mixed Result',
};

const sizeClasses = {
  sm: 'text-xs px-2 py-1',
  md: 'text-sm px-3 py-1.5',
  lg: 'text-base px-4 py-2',
};

function normalizeBadgeValue<T extends string>(value: string, knownLabels: Record<string, T>) {
  return knownLabels[value.trim().toUpperCase()] ?? value.trim();
}

function renderBadge(config: BadgeConfig, size: 'sm' | 'md' | 'lg') {
  return (
    <Badge className={`${config.bg} ${config.text} ${sizeClasses[size]} font-medium whitespace-nowrap`}>
      {config.label}
    </Badge>
  );
}

export function StatusBadge({ status, size = 'md' }: StatusBadgeProps) {
  const statusLabel = normalizeBadgeValue(status || 'Unknown', normalizedStatusLabels);
  const config = statusLabel in statusConfig
    ? statusConfig[statusLabel as CaseStatus]
    : {
        bg: 'bg-muted',
        text: 'text-muted-foreground',
        label: statusLabel,
      };

  return renderBadge(config, size);
}

export function StageBadge({ stage, size = 'md' }: StageBadgeProps) {
  const stageLabel = normalizeBadgeValue(stage || 'Unknown', normalizedStageLabels);
  const config = stageLabel in stageConfig
    ? stageConfig[stageLabel as CaseStage]
    : {
        bg: 'bg-muted',
        text: 'text-muted-foreground',
        label: stageLabel,
      };

  return renderBadge(config, size);
}
