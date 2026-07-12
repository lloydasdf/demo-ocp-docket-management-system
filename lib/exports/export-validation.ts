import type { CaseExcelExportRow, CaseExportManifestRow } from '@/lib/supabase/case-export';

export type ExportValidationResult =
  | { valid: true }
  | {
      valid: false;
      message: string;
      expectedCount: number;
      loadedCount: number;
      missingGroups: string[];
    };

type ExportGroupIdentity = {
  key: string;
  label: string;
};

const PREFERRED_DOCKET_TYPE_ORDER = ['INV', 'INQ', 'PE', 'DC'];

function normalizedText(value: string | null | undefined) {
  const normalized = value?.trim();
  return normalized ? normalized : '';
}

function normalizedNumber(value: number | null | undefined) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function inferDocketTypePrefix(docketNo: string | null | undefined) {
  const parts = normalizedText(docketNo).split('-').map((part) => part.trim()).filter(Boolean);
  const preferredPart = parts.find((part) => PREFERRED_DOCKET_TYPE_ORDER.includes(part.toUpperCase()));
  if (preferredPart) return preferredPart;
  const alphaParts = parts.filter((part) => /[A-Za-z]/.test(part));
  if (alphaParts.length > 1 && /^OCP$/i.test(alphaParts[0])) return alphaParts[1];
  return alphaParts[0] ?? '';
}

function formatGroupYear(year: number | null) {
  return year === null ? '' : String(year).slice(-2).padStart(2, '0');
}

function groupIdentity(params: {
  docketTypeId: number | null | undefined;
  docketTypePrefix: string | null | undefined;
  docketTypeLabel: string | null | undefined;
  docketYear: number | null | undefined;
  docketNo?: string | null;
}): ExportGroupIdentity {
  const id = normalizedNumber(params.docketTypeId);
  const prefix = normalizedText(params.docketTypePrefix);
  const label = normalizedText(params.docketTypeLabel);
  const inferredPrefix = inferDocketTypePrefix(params.docketNo);
  const year = normalizedNumber(params.docketYear);
  const yearKey = year ?? 'unknown';
  const displayPrefix = prefix || label || inferredPrefix || 'Other';
  const displayYear = formatGroupYear(year);
  const displayLabel = `${displayPrefix}${displayYear}`;

  if (id !== null) return { key: `id:${id}:year:${yearKey}`, label: displayLabel };
  if (prefix) return { key: `prefix:${prefix.toUpperCase()}:year:${yearKey}`, label: displayLabel };
  if (label) return { key: `label:${label.toUpperCase()}:year:${yearKey}`, label: displayLabel };
  if (inferredPrefix) return { key: `inferred-prefix:${inferredPrefix.toUpperCase()}:year:${yearKey}`, label: `${inferredPrefix}${displayYear}` };
  return { key: `other:year:${yearKey}`, label: displayLabel };
}

function buildFailure(params: {
  expectedCount: number;
  loadedCount: number;
  missingGroups: string[];
}): ExportValidationResult {
  const missingGroupsText = params.missingGroups.length > 0 ? `\n\nMissing groups: ${params.missingGroups.join(' ')}` : '';

  return {
    valid: false,
    expectedCount: params.expectedCount,
    loadedCount: params.loadedCount,
    missingGroups: params.missingGroups,
    message: `The export could not be completed because not all cases were retrieved.\n\nExpected: ${params.expectedCount.toLocaleString()} cases\nLoaded: ${params.loadedCount.toLocaleString()} cases${missingGroupsText}\n\nPlease try again.`,
  };
}

export function validateExportCompleteness(
  manifest: CaseExportManifestRow[],
  rows: CaseExcelExportRow[],
): ExportValidationResult {
  const expectedCountsByGroup = new Map<string, { expectedCount: number; label: string }>();
  let totalExpectedCount = 0;

  for (const manifestRow of manifest) {
    const expectedCount = Number(manifestRow.expected_case_count ?? 0);
    const identity = groupIdentity({
      docketTypeId: manifestRow.docket_type_id,
      docketTypePrefix: manifestRow.docket_type_prefix,
      docketTypeLabel: manifestRow.docket_type_label,
      docketYear: manifestRow.docket_year,
    });
    const existing = expectedCountsByGroup.get(identity.key);
    const nextExpectedCount = (existing?.expectedCount ?? 0) + expectedCount;
    expectedCountsByGroup.set(identity.key, { expectedCount: nextExpectedCount, label: existing?.label ?? identity.label });
    totalExpectedCount += expectedCount;
  }

  const actualCountsByGroup = new Map<string, number>();
  const seenCaseIds = new Set<number>();

  for (const row of rows) {
    if (seenCaseIds.has(row.case_id)) {
      return buildFailure({
        expectedCount: totalExpectedCount,
        loadedCount: rows.length,
        missingGroups: ['Duplicate case rows detected'],
      });
    }
    seenCaseIds.add(row.case_id);

    const identity = groupIdentity({
      docketTypeId: row.docket_type_id,
      docketTypePrefix: row.docket_type_prefix,
      docketTypeLabel: row.docket_type_label,
      docketYear: row.docket_year,
      docketNo: row.docket_no,
    });

    if (!expectedCountsByGroup.has(identity.key)) {
      return buildFailure({
        expectedCount: totalExpectedCount,
        loadedCount: rows.length,
        missingGroups: [`Unexpected group ${identity.label}`],
      });
    }

    actualCountsByGroup.set(identity.key, (actualCountsByGroup.get(identity.key) ?? 0) + 1);
  }

  const missingGroups: string[] = [];
  for (const [key, expected] of expectedCountsByGroup.entries()) {
    const actualCount = actualCountsByGroup.get(key) ?? 0;
    if (actualCount !== expected.expectedCount) missingGroups.push(expected.label);
  }

  if (totalExpectedCount !== rows.length || missingGroups.length > 0) {
    return buildFailure({ expectedCount: totalExpectedCount, loadedCount: rows.length, missingGroups });
  }

  return { valid: true };
}
