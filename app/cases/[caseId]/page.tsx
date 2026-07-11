"use client";

import type React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ChevronDown, ExternalLink } from "lucide-react";

import { CaseTimeline } from "@/components/case-timeline";
import { StageBadge, StatusBadge } from "@/components/status-badge";
import { Sidebar } from "@/components/sidebar";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import {
  getAddressTypes,
  getCaseAttachmentsIndex,
  getCaseCourtDetails,
  editCaseOverviewSection,
  getCaseClassifications,
  getCaseDetailsPageById,
  getCaseStatuses,
  getCaseStages,
  addCaseStage,
  getDocketTypes,
  getCaseMotions,
  getCaseParticipants,
  getCasePetitionsForReview,
  getCaseTimelineEvents,
  getCaseManagedNotes,
  getCaseManagedViolations,
  getCaseParticipantCorrections,
  getCaseParticipantCorrectionsForCase,
  getCaseOverviewChangeHistory,
  getCasePlaces,
  getViolations,
  manageCaseNotes,
  manageCaseParticipants,
  manageCasePlaces,
  manageCaseViolations,
  type CaseCourtRecord,
  type CaseDetailsPageViewRecord,
  type CaseMotionRecord,
  type CaseParticipantRecord,
  type CasePetitionForReviewRecord,
  type CaseTimelineEventRecord,
  type CaseOverviewChangeHistoryRecord,
  type CaseParticipantCorrectionRecord,
  type CaseOverviewEditSection,
  type CaseNoteManagementRecord,
  type CasePlaceRecord,
  type CaseViolationManagementRecord,
} from "@/lib/supabase/queries";
import type { TableRow as SupabaseTableRow } from "@/lib/supabase/types";


type CaseNoteRecord = {
  id?: number | null;
  note_text?: string | null;
  is_private?: boolean | null;
  created_by_user_id?: number | null;
  created_at?: string | null;
  updated_at?: string | null;
  is_deleted?: boolean | null;
};

type CaseAddressRecord = {
  id?: number | null;
  address_type_label?: string | null;
  is_primary?: boolean | null;
  remarks?: string | null;
  addresses?: {
    line1: string | null;
    line2: string | null;
    barangay: string | null;
    city: string | null;
    province: string | null;
    region: string | null;
    zip_code: string | null;
    country: string | null;
  } | null;
};

type CaseDetailsState = {
  compact: CaseDetailsPageViewRecord | null;
  details: CaseDetailsPageViewRecord | null;
  participants: CaseParticipantRecord[];
  participantCorrections: CaseParticipantCorrectionRecord[];
  timeline: CaseTimelineEventRecord[];
  courts: CaseCourtRecord[];
  motions: CaseMotionRecord[];
  petitionsForReview: CasePetitionForReviewRecord[];
  attachments: SupabaseTableRow<"case_attachment_index">[];
  warnings: string[];
};

function caseNotes(details: CaseDetailsPageViewRecord | null): CaseNoteRecord[] {
  if (!details?.notes || !Array.isArray(details.notes)) {
    return [];
  }

  return details.notes.filter(
    (note): note is CaseNoteRecord =>
      Boolean(note) &&
      typeof note === "object" &&
      !Array.isArray(note) &&
      typeof (note as CaseNoteRecord).note_text === "string" &&
      (note as CaseNoteRecord).note_text?.trim() !== "" &&
      (note as CaseNoteRecord).is_deleted !== true,
  );
}


function caseNotesDetails(details: CaseDetailsPageViewRecord | null) {
  const notes = caseNotes(details);

  if (notes.length === 0) {
    return null;
  }

  return (
    <div className="space-y-3">
      {notes.map((note, index) => (
        <div key={note.id ?? `note-${index}`} className="space-y-1">
          <p className="whitespace-pre-wrap break-words">{note.note_text}</p>
          <div className="flex flex-wrap items-center gap-2 text-xs font-normal text-muted-foreground">
            <span>{formatDate(note.created_at)}</span>
            {note.is_private ? <Badge variant="secondary">Private</Badge> : null}
          </div>
        </div>
      ))}
    </div>
  );
}


function isFinalCaseStatus(codeOrLabel: string | null | undefined) {
  const normalized = codeOrLabel?.trim().toUpperCase().replace(/[\s-]+/g, "_");
  return normalized === "FILED" || normalized === "DISMISSED" || normalized === "MIXED_RESULT";
}

function withoutAutoStatusStageRemark(value: string | null | undefined) {
  const normalized = value?.trim();
  if (!normalized) {
    return null;
  }

  const autoRemarks = new Set([
    "Case Assignment voided. Broad case status remains Pending.",
    "Case Assignment voided. Workflow stage recomputed.",
    "Case Reassignment voided. Broad case status remains Pending.",
    "Case Reassignment voided. Workflow stage recomputed.",
    "Court filing voided. Status recomputed.",
    "Timeline event voided. Status recomputed.",
  ]);

  return autoRemarks.has(normalized) ? null : normalized;
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return "—";
  }

  const parsedDate = new Date(value);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleDateString();
}

function formatLongDate(value: string | null | undefined) {
  if (!value) {
    return null;
  }

  const dateOnlyMatch = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  const parsedDate = dateOnlyMatch
    ? new Date(
        Number(dateOnlyMatch[1]),
        Number(dateOnlyMatch[2]) - 1,
        Number(dateOnlyMatch[3]),
      )
    : new Date(value);

  if (Number.isNaN(parsedDate.getTime())) {
    return value;
  }

  return parsedDate.toLocaleDateString("en-US", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

function formatFileSize(bytes: number | null) {
  if (bytes === null) {
    return "—";
  }

  if (bytes < 1024) {
    return `${bytes} B`;
  }

  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }

  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function firstDisplayValue(...values: (string | number | null | undefined)[]) {
  return values.find(
    (value) =>
      value !== null && value !== undefined && String(value).trim() !== "",
  );
}

function displayValue(value: string | number | null | undefined) {
  return value === null || value === undefined || value === ""
    ? "—"
    : String(value);
}

function participantName(participant: CaseParticipantRecord) {
  return (
    participant.persons?.full_name ??
    participant.organizations?.organization_name ??
    participant.display_name_snapshot ??
    "Unnamed participant"
  );
}

function isVoidedPersonParticipant(participant: CaseParticipantRecord) {
  const persons = participant.persons as Record<string, unknown> | null | undefined;
  return persons?.is_voided === true;
}

function participantProfileHref(participant: CaseParticipantRecord) {
  if (participant.person_id) {
    return `/persons/${participant.person_id}`;
  }

  if (participant.organization_id) {
    return `/organizations/${participant.organization_id}`;
  }

  return null;
}

function formatOrganizationDetails(details: unknown) {
  if (
    !details ||
    typeof details !== "object" ||
    Array.isArray(details) ||
    Object.keys(details as Record<string, unknown>).length === 0
  )
    return null;
  return Object.entries(details as Record<string, unknown>)
    .map(
      ([key, value]) =>
        `${key}: ${typeof value === "object" ? JSON.stringify(value) : String(value)}`,
    )
    .join("; ");
}

function participantAliasNames(participant: CaseParticipantRecord) {
  const aliases =
    participant.participant_kind === "ORGANIZATION"
      ? participant.organizations?.organization_aliases
      : participant.persons?.person_aliases;
  if (!Array.isArray(aliases)) return [];
  const names = aliases
    .map((alias) =>
      typeof alias === "object" && alias && "alias_name" in alias
        ? String(alias.alias_name)
        : null,
    )
    .filter((name): name is string => Boolean(name));
  return names;
}

function participantAliasBadges(participant: CaseParticipantRecord) {
  const aliases = participantAliasNames(participant);

  if (aliases.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap gap-2">
      {aliases.map((alias) => (
        <Badge key={alias} variant="outline" className="text-xs font-normal">
          @{alias}
        </Badge>
      ))}
    </div>
  );
}

function roleLabel(participant: CaseParticipantRecord) {
  return (
    participant.participant_roles?.display_label ??
    participant.participant_roles?.code ??
    "Party"
  );
}

function personBirthDateAndSex(participant: CaseParticipantRecord) {
  const gender =
    participant.case_participant_attributes?.gender_text ??
    participant.case_participant_attributes?.gender_normalized ??
    participant.persons?.gender;
  const birthdate = formatLongDate(participant.persons?.birth_date);

  if (!birthdate && !gender) {
    return "";
  }

  return [`Birthdate: ${birthdate ?? "—"}`, gender ?? null]
    .filter((part): part is string => Boolean(part))
    .join(" | ");
}

function ageAtCase(participant: CaseParticipantRecord) {
  const attributes = participant.case_participant_attributes;
  return attributes?.age_text ?? attributes?.age_years ?? null;
}

function caseSpecificFlags(participant: CaseParticipantRecord) {
  const attributes = participant.case_participant_attributes;
  const flags = [
    attributes?.is_minor_at_case ? "Minor" : null,
    attributes?.is_senior_at_case ? "Senior" : null,
    attributes?.is_pwd_at_case ? "PWD" : null,
  ].filter((flag): flag is string => Boolean(flag));

  return flags;
}

function caseFlagBadges(participant: CaseParticipantRecord) {
  const flags = caseSpecificFlags(participant);

  if (flags.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap gap-2">
      {flags.map((flag) => (
        <Badge key={flag} variant="secondary" className="text-xs">
          {flag}
        </Badge>
      ))}
    </div>
  );
}

function formatAddress(
  address: NonNullable<
    NonNullable<CaseParticipantRecord["persons"]>["person_addresses"]
  >[number]["addresses"],
) {
  if (!address) {
    return null;
  }

  const parts = [
    address.line1,
    address.line2,
    address.barangay ? `Brgy. ${address.barangay}` : null,
    address.city,
    address.province,
    address.region,
    address.zip_code,
    address.country,
  ].filter((part): part is string => Boolean(part?.trim()));

  return parts.length > 0 ? parts.join(", ") : null;
}


function participantContacts(participant: CaseParticipantRecord) {
  const contacts = participant.contact_informations ?? [];
  if (!Array.isArray(contacts) || contacts.length === 0) {
    return null;
  }

  return (
    <div className="space-y-1">
      {contacts.map((contact) => (
        <div key={contact.participant_contact_information_id ?? contact.id} className="flex flex-wrap items-center gap-2">
          <span>{contact.contact_value}</span>
          <Badge variant="outline" className="text-xs">{contact.label || contact.contact_type}</Badge>
          {contact.is_primary ? <Badge variant="secondary" className="text-xs">Primary</Badge> : null}
        </div>
      ))}
    </div>
  );
}

function participantAddresses(participant: CaseParticipantRecord) {
  return participant.participant_kind === "ORGANIZATION"
    ? (participant.organizations?.organization_addresses ?? [])
    : (participant.persons?.person_addresses ?? []);
}

function ParticipantAddresses({
  participant,
}: {
  participant: CaseParticipantRecord;
}) {
  const addresses = participantAddresses(participant)
    .map((address) => ({
      id: address.id,
      isPrimary: address.is_primary,
      remarks: address.remarks,
      text: formatAddress(address.addresses ?? null),
    }))
    .filter((address) => address.text);

  if (addresses.length === 0) {
    return null;
  }

  return (
    <div className="space-y-2">
      {addresses.map((address, index) => (
        <div
          key={address.id ?? `${address.text}-${index}`}
          className="space-y-1"
        >
          <div className="flex flex-wrap items-center gap-2">
            <span>{address.text}</span>
            {address.isPrimary ? (
              <Badge variant="secondary" className="text-xs">
                Primary
              </Badge>
            ) : null}
          </div>
          {address.remarks ? (
            <p className="text-xs font-normal text-muted-foreground">
              {address.remarks}
            </p>
          ) : null}
        </div>
      ))}
    </div>
  );
}

function caseAddresses(
  details: CaseDetailsPageViewRecord | null,
): CaseAddressRecord[] {
  return Array.isArray(details?.case_addresses)
    ? (details.case_addresses as CaseAddressRecord[])
    : [];
}

function formatCaseAddress(address: CaseAddressRecord) {
  return formatAddress(address.addresses ?? null);
}

function classificationLabel(details: CaseDetailsPageViewRecord) {
  return (
    details.case_classifications?.display_label ??
    details.case_classifications?.name ??
    details.case_classifications?.code ??
    null
  );
}

function placeOfCommission(details: CaseDetailsPageViewRecord | null) {
  const addresses = caseAddresses(details);

  if (addresses.length === 0) {
    return null;
  }

  return (
    <div className="space-y-2">
      {addresses.map((address) => {
        const addressText = formatCaseAddress(address) ?? "Unnamed address";

        return (
          <div key={address.id ?? addressText} className="min-w-0 space-y-1">
            <p className="break-words">{addressText}</p>
            {address.remarks ? (
              <p className="break-words text-xs font-normal text-muted-foreground">
                {address.remarks}
              </p>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}

function SectionEmpty({ children = "No records yet." }: { children?: string }) {
  return (
    <p className="rounded-md border border-dashed p-4 text-sm text-muted-foreground">
      {children}
    </p>
  );
}

function hasDetailValue(value: React.ReactNode) {
  return value !== null && value !== undefined && value !== "" && value !== "—";
}

function OptionalDetailItem({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  if (!hasDetailValue(value)) {
    return null;
  }

  return <DetailItem label={label} value={value} />;
}

function DetailItem({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="min-w-0 space-y-1">
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </p>
      <div className="min-w-0 break-words text-sm font-medium text-foreground">
        {value}
      </div>
    </div>
  );
}

const overviewEditorCopy: Record<
  CaseOverviewEditSection,
  { title: string; description: string }
> = {
  docket_info: {
    title: "Docket Info",
    description: "Correct docket identifiers and receipt date. Creates audit logs only.",
  },
  case_details: {
    title: "Case Details",
    description: "Correct classification, summary flags, summary text, and remarks. Creates audit logs only.",
  },
  status: {
    title: "Status",
    description: "Manually update Case Status and Case Stage. Creates a voidable timeline activity, conditional history rows, and audit logs.",
  },
  places: {
    title: "Places of Commission",
    description: "Placeholder for the Places correction slice. Will use RPC and audit logs only.",
  },
  notes: {
    title: "Notes",
    description: "Placeholder for the Notes correction slice. Will use RPC and audit logs only.",
  },
  violations: {
    title: "Violations",
    description: "Manage case violations with RPC-backed audit logs only.",
  },
};

function getOverviewInitialData(
  section: CaseOverviewEditSection,
  details: CaseDetailsPageViewRecord,
): Record<string, string | number | boolean | null | undefined> {
  if (section === "docket_info") {
    return {
      docketTypeId: details.docket_type_id,
      docketYear: details.docket_year,
      docketNumber: details.docket_number,
      docketMonthCode: details.docket_month_code,
      dateReceived: details.date_received,
    };
  }

  if (section === "case_details") {
    return {
      caseClassificationId: details.case_classification_id,
      isSummaryProcedure: details.is_summary_procedure,
      summaryText: details.summary_text,
      remarks: details.remarks,
    };
  }

  if (section === "status") {
    return {
      statusId: details.current_case_status_id ?? details.current_status_id,
      stageId: details.current_case_stage_id,
      statusDate: details.current_case_status_date ?? details.current_status_date,
      remarks: withoutAutoStatusStageRemark(
        details.current_case_status_remarks ?? details.current_status_remarks,
      ),
    };
  }

  return {};
}

type OverviewAction = CaseOverviewEditSection | "participants" | "history";

type RefOption = { id: number; display_label?: string | null; name?: string | null; prefix?: string | null; code?: string | null; full_name?: string | null; short_name?: string | null };
type OverviewRefs = { docketTypes: RefOption[]; classifications: RefOption[]; statuses: RefOption[]; stages: RefOption[]; addressTypes: RefOption[] };

type OverviewEditorProps = {
  title: string;
  description: string;
  section: CaseOverviewEditSection;
  caseId: number;
  initialData: Record<string, string | number | boolean | null | undefined>;
  refs: OverviewRefs;
  onSaved: () => Promise<void>;
  open: boolean;
  onOpenChange: (open: boolean) => void;
};

function OverviewSectionEditor({ title, description, section, caseId, initialData, refs, onSaved, open, onOpenChange }: OverviewEditorProps) {
  const [formData, setFormData] = useState<Record<string, string | boolean>>({});
  const [reason, setReason] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isStageDialogOpen, setIsStageDialogOpen] = useState(false);
  const [stageLabel, setStageLabel] = useState("");
  const [localStages, setLocalStages] = useState<RefOption[]>(refs.stages);

  useEffect(() => {
    if (!open) return;
    setFormData(Object.fromEntries(Object.entries(initialData).map(([key, value]) => [key, typeof value === "boolean" ? value : value == null ? "" : String(value)])));
    setReason("");
    setError(null);
    setLocalStages(refs.stages);
  }, [initialData, open, refs.stages]);

  const setValue = (key: string, value: string | boolean) => setFormData((current) => ({ ...current, [key]: value }));
  const optionLabel = (option: RefOption) => option.display_label ?? option.full_name ?? option.name ?? option.short_name ?? option.prefix ?? option.code ?? String(option.id);

  async function save() {
    if (section === "status" && (!String(formData.statusId ?? "").trim() || !String(formData.stageId ?? "").trim() || !String(formData.statusDate ?? "").trim())) { setError("Case Status, Case Stage, and Status Date are required."); return; }
    if (!reason.trim()) { setError("Reason is required."); return; }
    setIsSaving(true);
    setError(null);
    const result = await editCaseOverviewSection({ caseId, section, reason: reason.trim(), data: formData });
    setIsSaving(false);
    if (result.error) { setError(result.error.message); return; }
    onOpenChange(false);
    await onSaved();
  }

  async function handleAddStageSave() {
    if (!stageLabel.trim()) { setError("Display Label is required."); return; }
    setIsSaving(true);
    setError(null);
    const result = await addCaseStage({ displayLabel: stageLabel });
    if (result.error) { setIsSaving(false); setError(result.error.message); return; }
    const stagesResult = await getCaseStages();
    if (!stagesResult.error) setLocalStages((stagesResult.data ?? []) as RefOption[]);
    setValue("stageId", String(result.data));
    setStageLabel("");
    setIsStageDialogOpen(false);
    setIsSaving(false);
  }

  const notReady = section === "places" || section === "notes";

  return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>Edit {title}</DialogTitle>
            <DialogDescription>{description}</DialogDescription>
          </DialogHeader>
          {notReady ? (
            <SectionEmpty>This section has an edit placeholder. The RPC-backed form is scheduled after the current vertical slices.</SectionEmpty>
          ) : (
            <div className="grid gap-4 py-2 sm:grid-cols-2">
              {section === "docket_info" ? (<>
                <FieldSelect label="Docket type" value={String(formData.docketTypeId ?? "")} onChange={(v) => setValue("docketTypeId", v)} options={refs.docketTypes} optionLabel={optionLabel} />
                <FieldInput label="Docket year" value={String(formData.docketYear ?? "")} onChange={(v) => setValue("docketYear", v)} />
                <FieldInput label="Docket number" value={String(formData.docketNumber ?? "")} onChange={(v) => setValue("docketNumber", v)} />
                <FieldInput label="Docket month code" value={String(formData.docketMonthCode ?? "")} onChange={(v) => setValue("docketMonthCode", v.toUpperCase())} />
                <FieldInput label="Date received" type="date" value={String(formData.dateReceived ?? "")} onChange={(v) => setValue("dateReceived", v)} />
              </>) : null}
              {section === "case_details" ? (<>
                <FieldSelect label="Classification" value={String(formData.caseClassificationId ?? "")} onChange={(v) => setValue("caseClassificationId", v)} options={refs.classifications} optionLabel={optionLabel} allowEmpty />
                <label className="flex items-center gap-2 pt-7 text-sm"><input type="checkbox" checked={Boolean(formData.isSummaryProcedure)} onChange={(e) => setValue("isSummaryProcedure", e.target.checked)} /> Summary procedure</label>
                <FieldTextarea label="Summary" value={String(formData.summaryText ?? "")} onChange={(v) => setValue("summaryText", v)} className="sm:col-span-2" />
                <FieldTextarea label="Remarks" value={String(formData.remarks ?? "")} onChange={(v) => setValue("remarks", v)} className="sm:col-span-2" />
              </>) : null}
              {section === "status" ? (<>
                <FieldSelect label="Case Status" value={String(formData.statusId ?? "")} onChange={(v) => setValue("statusId", v)} options={refs.statuses} optionLabel={optionLabel} />
                <FieldSelect label="Case Stage" value={String(formData.stageId ?? "")} onChange={(v) => { if (v === "__add__") { setStageLabel(""); setIsStageDialogOpen(true); return; } setValue("stageId", v); }} options={localStages} optionLabel={optionLabel} extraOption={{ value: "__add__", label: "+ Add Case Stage" }} />
                <FieldInput label="Status Date" type="date" value={String(formData.statusDate ?? "")} onChange={(v) => setValue("statusDate", v)} className="sm:col-span-2" />
                <FieldTextarea label="Remarks" value={String(formData.remarks ?? "")} onChange={(v) => setValue("remarks", v)} className="sm:col-span-2" />
              </>) : null}
              <FieldTextarea label="Reason for edit" value={reason} onChange={setReason} className="sm:col-span-2" />
            </div>
          )}
          {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
            {!notReady ? <Button onClick={save} disabled={isSaving}>{isSaving ? "Saving..." : "Save changes"}</Button> : null}
          </DialogFooter>
        </DialogContent>
        <Dialog open={isStageDialogOpen} onOpenChange={setIsStageDialogOpen}>
          <DialogContent className="sm:max-w-md">
            <DialogHeader><DialogTitle>Add Case Stage</DialogTitle><DialogDescription>Create an active Case Stage option for manual status updates. The code is generated automatically.</DialogDescription></DialogHeader>
            <div className="space-y-4 py-2">
              <FieldInput label="Display Label" value={stageLabel} onChange={setStageLabel} />
            </div>
            <DialogFooter><Button type="button" variant="outline" onClick={() => setIsStageDialogOpen(false)}>Cancel</Button><Button type="button" onClick={handleAddStageSave} disabled={isSaving || !stageLabel.trim()}>{isSaving ? "Saving..." : "Save Case Stage"}</Button></DialogFooter>
          </DialogContent>
        </Dialog>
      </Dialog>
  );
}

function FieldInput({ label, value, onChange, type = "text", className }: { label: string; value: string; onChange: (value: string) => void; type?: string; className?: string }) {
  return <div className={className}><Label>{label}</Label><Input type={type} value={value} onChange={(e) => onChange(e.target.value)} /></div>;
}
function FieldTextarea({ label, value, onChange, className }: { label: string; value: string; onChange: (value: string) => void; className?: string }) {
  return <div className={className}><Label>{label}</Label><Textarea value={value} onChange={(e) => onChange(e.target.value)} /></div>;
}
function FieldSelect({ label, value, onChange, options, optionLabel, allowEmpty = false, valueKey = "id", extraOption }: { label: string; value: string; onChange: (value: string) => void; options: RefOption[]; optionLabel: (option: RefOption) => string; allowEmpty?: boolean; valueKey?: "id" | "code"; extraOption?: { value: string; label: string } }) {
  return <div><Label>{label}</Label><select className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm" value={value} onChange={(e) => onChange(e.target.value)}>{allowEmpty ? <option value="">—</option> : null}{options.map((option) => <option key={option.id} value={valueKey === "code" ? option.code ?? "" : option.id}>{optionLabel(option)}</option>)}{extraOption ? <option value={extraOption.value}>{extraOption.label}</option> : null}</select></div>;
}

function formatJsonPreview(value: unknown) {
  return JSON.stringify(value ?? null, null, 2);
}

function correctionSnapshot(snapshot: unknown, key: "person" | "organization" | "attributes") {
  return typeof snapshot === "object" && snapshot && !Array.isArray(snapshot) && key in snapshot ? (snapshot as Record<string, unknown>)[key] : null;
}

const snapshotFieldLabels: Record<string, string> = {
  age: "Age", age_text: "Age", birth_date: "Birth date", contact_number: "Contact number", contact_person: "Contact person", display_name: "Display name", email: "Email", first_name: "First name", full_name: "Full name", gender: "Gender", gender_text: "Gender", is_minor_at_case: "Minor at case", is_pwd_at_case: "PWD at case", is_senior_at_case: "Senior at case", last_name: "Last name", middle_name: "Middle name", notes: "Notes", organization_name: "Organization name", person_descriptor: "Descriptor", remarks: "Remarks", source_detail: "Source detail", suffix: "Suffix",
};

function humanizeSnapshotKey(key: string) {
  return snapshotFieldLabels[key] ?? key.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatSnapshotValue(value: unknown): React.ReactNode {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (typeof value === "string") return value;
  if (typeof value === "number") return String(value);
  return <pre className="whitespace-pre-wrap text-xs font-normal">{formatJsonPreview(value)}</pre>;
}

function SnapshotDetails({ snapshot }: { snapshot: unknown }) {
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) return <SectionEmpty>No previous details captured.</SectionEmpty>;
  const entries = Object.entries(snapshot as Record<string, unknown>).filter(([, value]) => value !== null && value !== undefined && value !== "");
  if (entries.length === 0) return <SectionEmpty>No previous details captured.</SectionEmpty>;
  return <div className="grid gap-3 sm:grid-cols-2">{entries.map(([key, value]) => <DetailItem key={key} label={humanizeSnapshotKey(key)} value={formatSnapshotValue(value)} />)}</div>;
}

function ParticipantCorrectionHistoryDialog({ corrections, onOpenChange, open, participant }: { corrections: CaseParticipantCorrectionRecord[]; onOpenChange: (open: boolean) => void; open: boolean; participant: CaseParticipantRecord | null }) {
  const identityKey = participant?.participant_kind === "ORGANIZATION" ? "organization" : "person";
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-4xl"><DialogHeader><DialogTitle>Participant Correction History</DialogTitle><DialogDescription>Previous incorrect details for {participant ? participantName(participant) : "this participant"}.</DialogDescription></DialogHeader><div className="space-y-3">{corrections.length === 0 ? <SectionEmpty>No participant corrections recorded.</SectionEmpty> : corrections.map((entry) => <Card key={entry.id}><CardHeader className="space-y-2 pb-3"><div className="flex flex-wrap items-center gap-2"><Badge variant="outline">Correction</Badge><span className="text-sm text-muted-foreground">{formatDate(entry.corrected_at)}</span><span className="text-sm text-muted-foreground">by {entry.corrected_by_display ?? (entry.corrected_by_user_id ? `User #${entry.corrected_by_user_id}` : "—")}</span></div><CardDescription>Reason: {entry.reason ?? "—"}</CardDescription></CardHeader><CardContent className="space-y-4"><DetailItem label="Previous incorrect version" value={<SnapshotDetails snapshot={correctionSnapshot(entry.old_snapshot_json, identityKey)} />} /><OptionalDetailItem label="Previous attributes" value={<SnapshotDetails snapshot={correctionSnapshot(entry.old_snapshot_json, "attributes")} />} /></CardContent></Card>)}</div><DialogFooter><Button type="button" onClick={() => onOpenChange(false)}>Close</Button></DialogFooter></DialogContent></Dialog>;
}

function placeOfCommissionAddressTypeId(refs: OverviewRefs) {
  return String(
    refs.addressTypes.find((type) =>
      [type.code, type.display_label, type.name]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes("commission")),
    )?.id ?? refs.addressTypes[0]?.id ?? "",
  );
}

const emptyPlaceForm = {
  id: "",
  addressTypeId: "",
  line1: "",
  line2: "",
  barangay: "",
  city: "",
  province: "",
  region: "",
  zipCode: "",
  country: "Philippines",
  latitude: "",
  longitude: "",
  isPrimary: false,
  remarks: "",
};

function placeToForm(place: CasePlaceRecord, refs: OverviewRefs) {
  return {
    id: String(place.id),
    addressTypeId: placeOfCommissionAddressTypeId(refs) || String(place.address_type_id ?? ""),
    line1: place.addresses?.line1 ?? "",
    line2: place.addresses?.line2 ?? "",
    barangay: place.addresses?.barangay ?? "",
    city: place.addresses?.city ?? "",
    province: place.addresses?.province ?? "",
    region: place.addresses?.region ?? "",
    zipCode: place.addresses?.zip_code ?? "",
    country: place.addresses?.country ?? "Philippines",
    latitude: place.addresses?.latitude == null ? "" : String(place.addresses.latitude),
    longitude: place.addresses?.longitude == null ? "" : String(place.addresses.longitude),
    isPrimary: Boolean(place.is_primary),
    remarks: place.remarks ?? "",
  };
}

function ManagePlacesDialog({ caseId, refs, open, onOpenChange, onSaved }: { caseId: number; refs: OverviewRefs; open: boolean; onOpenChange: (open: boolean) => void; onSaved: () => Promise<void> }) {
  const [places, setPlaces] = useState<CasePlaceRecord[]>([]);
  const [showRemoved, setShowRemoved] = useState(false);
  const [formData, setFormData] = useState(emptyPlaceForm);
  const [reason, setReason] = useState("");
  const [mode, setMode] = useState<"add" | "edit" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [placeActionReasons, setPlaceActionReasons] = useState<Record<number, string>>({});
  const [pendingPlaceAction, setPendingPlaceAction] = useState<{
    id: number;
    action: "remove" | "restore";
  } | null>(null);
  const [showEditReason, setShowEditReason] = useState(false);

  const loadPlaces = useCallback(async () => {
    const result = await getCasePlaces(caseId, showRemoved);
    if (result.error) setError(result.error.message);
    setPlaces(result.data ?? []);
  }, [caseId, showRemoved]);

  useEffect(() => { if (open) void loadPlaces(); }, [loadPlaces, open]);
  useEffect(() => {
    if (open && mode === "add") {
      setFormData((current) => ({
        ...current,
        addressTypeId: placeOfCommissionAddressTypeId(refs),
      }));
    }
  }, [mode, open, refs]);

  const setValue = (key: keyof typeof emptyPlaceForm, value: string | boolean) => setFormData((current) => ({ ...current, [key]: value }));
  const resetForm = () => { setMode(null); setFormData(emptyPlaceForm); setReason(""); setError(null); setShowEditReason(false); };
  async function save(action: "add" | "edit" | "remove" | "restore", place?: CasePlaceRecord) {
    if (action === "edit" && !showEditReason) {
      setShowEditReason(true);
      setError("Reason is required.");
      return;
    }

    const actionReason = place ? (placeActionReasons[place.id] ?? "") : reason;
    if (!actionReason.trim()) { setError(action === "remove" || action === "restore" ? "Remove/restore reason is required." : "Reason is required."); return; }
    setIsSaving(true);
    setError(null);
    const result = await manageCasePlaces({
      caseId,
      action,
      reason: actionReason.trim(),
      place: place
        ? { id: place.id }
        : { ...formData, addressTypeId: formData.addressTypeId || placeOfCommissionAddressTypeId(refs) },
    });
    setIsSaving(false);
    if (result.error) { setError(result.error.message); return; }
    if (place) {
      setPlaceActionReasons((current) => {
        const next = { ...current };
        delete next[place.id];
        return next;
      });
      setPendingPlaceAction(null);
    }
    resetForm();
    await loadPlaces();
    await onSaved();
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-4xl">
        <DialogHeader>
          <DialogTitle>Manage Places of Commission</DialogTitle>
          <DialogDescription>Add, update, remove, or restore places of commission. Changes create audit logs only.</DialogDescription>
        </DialogHeader>
        {mode === "edit" ? null : (
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={showRemoved} onChange={(event) => setShowRemoved(event.target.checked)} /> Show removed places</label>
        )}
        {mode === "edit" ? null : (
          <div className="space-y-3">
            {places.length === 0 ? <SectionEmpty>No places recorded.</SectionEmpty> : places.map((place) => {
              const isPendingAction = pendingPlaceAction?.id === place.id;
              const pendingAction = isPendingAction ? pendingPlaceAction.action : null;

              return (
                <div key={place.id} className="rounded-lg border p-3 text-sm">
                  <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-start">
                    <div className="min-w-0">
                      <p className="font-medium">{formatCaseAddress({ addresses: place.addresses, remarks: place.remarks }) ?? "Unnamed address"}</p>
                      <div className="mt-1 flex flex-wrap gap-2 text-xs text-muted-foreground">
                        <span>{place.address_types?.display_label ?? "Place of Commission"}</span>
                        {place.is_primary ? <Badge variant="secondary">Primary</Badge> : null}
                        {place.is_deleted ? <Badge variant="destructive">REMOVED</Badge> : null}
                      </div>
                      {place.is_deleted ? <p className="mt-2 text-xs text-muted-foreground">Removed {formatDate(place.deleted_at)}{place.deleted_by_user_id ? ` by user #${place.deleted_by_user_id}` : ""} — {place.delete_reason ?? "No reason recorded"}</p> : null}
                    </div>
                    <div className="flex min-w-56 flex-col items-stretch gap-2 sm:items-end">
                      {pendingAction ? null : (
                        <div className="flex justify-end gap-2">
                          {place.is_deleted ? (
                            <Button size="sm" variant="outline" onClick={() => setPendingPlaceAction({ id: place.id, action: "restore" })}>Restore</Button>
                          ) : (
                            <>
                              <Button size="sm" variant="outline" onClick={() => { setMode("edit"); setFormData(placeToForm(place, refs)); setReason(""); setError(null); setShowEditReason(false); }}>Edit</Button>
                              <Button size="sm" variant="outline" onClick={() => setPendingPlaceAction({ id: place.id, action: "remove" })}>Remove</Button>
                            </>
                          )}
                        </div>
                      )}
                      {pendingAction ? (
                        <div className="w-full space-y-2">
                          <Input
                            placeholder={pendingAction === "restore" ? "Restore reason" : "Remove reason"}
                            value={placeActionReasons[place.id] ?? ""}
                            onChange={(event) =>
                              setPlaceActionReasons((current) => ({
                                ...current,
                                [place.id]: event.target.value,
                              }))
                            }
                          />
                          <div className="flex justify-end gap-2">
                            <Button size="sm" variant="outline" onClick={() => setPendingPlaceAction(null)}>Cancel</Button>
                            <Button size="sm" onClick={() => save(pendingAction, place)}>{pendingAction === "restore" ? "Restore" : "Remove"}</Button>
                          </div>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        {mode === null ? (
          <Button variant="outline" onClick={() => { setMode("add"); setFormData({ ...emptyPlaceForm, addressTypeId: placeOfCommissionAddressTypeId(refs) }); setReason(""); setError(null); }}>
            Add Place
          </Button>
        ) : null}
        {mode ? (
          <div className="grid gap-4 rounded-lg border p-4 sm:grid-cols-2">
            <h3 className="sm:col-span-2 font-semibold">{mode === "add" ? "Add Place" : "Edit Place"}</h3>
            <div className="text-sm text-muted-foreground">
              Address type is fixed to Place of Commission for case addresses.
            </div>
            <label className="flex items-center gap-2 text-sm sm:pt-7"><input type="checkbox" checked={formData.isPrimary} onChange={(event) => setValue("isPrimary", event.target.checked)} /> Primary</label>
            <FieldInput label="Line 1" value={formData.line1} onChange={(value) => setValue("line1", value)} />
            <FieldInput label="Line 2" value={formData.line2} onChange={(value) => setValue("line2", value)} />
            <FieldInput label="Barangay" value={formData.barangay} onChange={(value) => setValue("barangay", value)} />
            <FieldInput label="City" value={formData.city} onChange={(value) => setValue("city", value)} />
            <FieldInput label="Province" value={formData.province} onChange={(value) => setValue("province", value)} />
            <FieldInput label="Region" value={formData.region} onChange={(value) => setValue("region", value)} />
            <FieldInput label="ZIP code" value={formData.zipCode} onChange={(value) => setValue("zipCode", value)} />
            <FieldInput label="Country" value={formData.country} onChange={(value) => setValue("country", value)} />
            <FieldInput label="Latitude" value={formData.latitude} onChange={(value) => setValue("latitude", value)} />
            <FieldInput label="Longitude" value={formData.longitude} onChange={(value) => setValue("longitude", value)} />
            <FieldTextarea label="Remarks" value={formData.remarks} onChange={(value) => setValue("remarks", value)} className="sm:col-span-2" />
            {mode === "add" || showEditReason ? <FieldTextarea label="Reason for edit" value={reason} onChange={setReason} className="sm:col-span-2" /> : null}
          </div>
        ) : null}
        {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Close</Button>
          {mode ? <Button variant="outline" onClick={resetForm}>Cancel {mode}</Button> : null}
          {mode ? <Button disabled={isSaving} onClick={() => save(mode)}>{isSaving ? "Saving..." : mode === "add" ? "Add place" : "Save"}</Button> : null}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}


function violationLabel(violation: CaseViolationManagementRecord) {
  return violation.raw_violation_text || violation.violations?.short_label || violation.violations?.title || `Violation #${violation.violation_id}`;
}

function ManageViolationsDialog({ caseId, open, onOpenChange, onSaved }: { caseId: number; open: boolean; onOpenChange: (open: boolean) => void; onSaved: () => Promise<void> }) {
  const [caseViolations, setCaseViolations] = useState<CaseViolationManagementRecord[]>([]);
  const [violationOptions, setViolationOptions] = useState<SupabaseTableRow<"violations">[]>([]);
  const [showRemoved, setShowRemoved] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [violationId, setViolationId] = useState("");
  const [violationOrder, setViolationOrder] = useState("");
  const [rawViolationText, setRawViolationText] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [actionReasons, setActionReasons] = useState<Record<number, string>>({});
  const [pendingAction, setPendingAction] = useState<{ id: number; action: "remove" | "restore" } | null>(null);

  const loadViolations = useCallback(async () => {
    const [caseResult, optionsResult] = await Promise.all([getCaseManagedViolations(caseId, showRemoved), getViolations(250)]);
    if (caseResult.error) setError(caseResult.error.message);
    if (optionsResult.error) setError(optionsResult.error.message);
    setCaseViolations(caseResult.data ?? []);
    setViolationOptions(optionsResult.data ?? []);
  }, [caseId, showRemoved]);

  useEffect(() => { if (open) void loadViolations(); }, [loadViolations, open]);
  const resetForm = () => { setEditingId(null); setViolationId(""); setViolationOrder(""); setRawViolationText(""); setReason(""); setError(null); };
  async function save(action: "add" | "edit" | "remove" | "restore", violation?: CaseViolationManagementRecord) {
    const actionReason = violation ? (actionReasons[violation.id] ?? "") : reason;
    if (!actionReason.trim()) { setError(action === "remove" || action === "restore" ? "Remove/restore reason is required." : "Reason is required."); return; }
    if ((action === "add" || action === "edit") && !violationId) { setError("Violation is required."); return; }
    setIsSaving(true); setError(null);
    const result = await manageCaseViolations({
      caseId,
      action,
      reason: actionReason.trim(),
      violation: violation ? { id: violation.id } : { id: editingId, violationId, violationOrder, rawViolationText },
    });
    setIsSaving(false);
    if (result.error) { setError(result.error.message); return; }
    if (violation) {
      setActionReasons((current) => { const next = { ...current }; delete next[violation.id]; return next; });
      setPendingAction(null);
    }
    resetForm(); await loadViolations(); await onSaved();
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-3xl">
        <DialogHeader><DialogTitle>Manage Violations</DialogTitle><DialogDescription>Add, update, remove, or restore case violation links. Changes create audit logs only.</DialogDescription></DialogHeader>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={showRemoved} onChange={(event) => setShowRemoved(event.target.checked)} /> Show removed violations</label>
        <div className="space-y-3">
          {caseViolations.length === 0 ? <SectionEmpty>No violations recorded.</SectionEmpty> : caseViolations.map((violation) => {
            const isPendingAction = pendingAction?.id === violation.id;
            const currentAction = isPendingAction ? pendingAction.action : null;
            return <div key={violation.id} className="rounded-lg border p-3 text-sm">
              <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-start">
                <div className="min-w-0"><p className="font-medium">{violationLabel(violation)}</p><div className="mt-1 flex flex-wrap gap-2 text-xs text-muted-foreground"><span>Order {violation.violation_order ?? "—"}</span>{violation.violations?.law_reference ? <span>{violation.violations.law_reference}</span> : null}{violation.is_deleted ? <Badge variant="destructive">REMOVED</Badge> : null}</div>{violation.is_deleted ? <p className="mt-2 text-xs text-muted-foreground">Removed {formatDate(violation.deleted_at)} — {violation.delete_reason ?? "No reason recorded"}</p> : null}</div>
                <div className="flex min-w-56 flex-col items-stretch gap-2 sm:items-end">
                  {currentAction ? null : <div className="flex justify-end gap-2">{violation.is_deleted ? <Button size="sm" variant="outline" onClick={() => setPendingAction({ id: violation.id, action: "restore" })}>Restore</Button> : <><Button size="sm" variant="outline" onClick={() => { setEditingId(violation.id); setViolationId(String(violation.violation_id)); setViolationOrder(violation.violation_order == null ? "" : String(violation.violation_order)); setRawViolationText(violation.raw_violation_text ?? ""); setReason(""); }}>Edit</Button><Button size="sm" variant="outline" onClick={() => setPendingAction({ id: violation.id, action: "remove" })}>Remove</Button></>}</div>}
                  {currentAction ? <div className="w-full space-y-2"><Input placeholder={currentAction === "restore" ? "Restore reason" : "Remove reason"} value={actionReasons[violation.id] ?? ""} onChange={(event) => setActionReasons((current) => ({ ...current, [violation.id]: event.target.value }))} /><div className="flex justify-end gap-2"><Button size="sm" variant="outline" onClick={() => setPendingAction(null)}>Cancel</Button><Button size="sm" onClick={() => save(currentAction, violation)}>{currentAction === "restore" ? "Restore" : "Remove"}</Button></div></div> : null}
                </div>
              </div>
            </div>;
          })}
        </div>
        <div className="grid gap-4 rounded-lg border p-4 sm:grid-cols-2"><h3 className="font-semibold sm:col-span-2">{editingId ? "Edit Violation" : "Add Violation"}</h3><FieldSelect label="Violation" value={violationId} onChange={setViolationId} options={violationOptions} optionLabel={(option) => (option as SupabaseTableRow<"violations">).short_label ?? (option as SupabaseTableRow<"violations">).title ?? String(option.id)} allowEmpty /><FieldInput label="Order" value={violationOrder} onChange={setViolationOrder} /><FieldTextarea label="Raw/display text" value={rawViolationText} onChange={setRawViolationText} className="sm:col-span-2" /><FieldTextarea label="Reason for edit" value={reason} onChange={setReason} className="sm:col-span-2" /></div>
        {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
        <DialogFooter><Button variant="outline" onClick={() => onOpenChange(false)}>Close</Button>{editingId ? <Button variant="outline" onClick={resetForm}>Cancel edit</Button> : null}<Button disabled={isSaving} onClick={() => save(editingId ? "edit" : "add")}>{isSaving ? "Saving..." : editingId ? "Save violation" : "Add violation"}</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function ManageNotesDialog({ caseId, open, onOpenChange, onSaved }: { caseId: number; open: boolean; onOpenChange: (open: boolean) => void; onSaved: () => Promise<void> }) {
  const [notes, setNotes] = useState<CaseNoteManagementRecord[]>([]);
  const [showDeleted, setShowDeleted] = useState(false);
  const [noteText, setNoteText] = useState("");
  const [isPrivate, setIsPrivate] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [noteActionReasons, setNoteActionReasons] = useState<Record<number, string>>({});
  const [pendingNoteAction, setPendingNoteAction] = useState<{
    id: number;
    action: "remove" | "restore";
  } | null>(null);

  const loadNotes = useCallback(async () => {
    const result = await getCaseManagedNotes(caseId, showDeleted);
    if (result.error) setError(result.error.message);
    setNotes(result.data ?? []);
  }, [caseId, showDeleted]);

  useEffect(() => { if (open) void loadNotes(); }, [loadNotes, open]);
  const resetForm = () => { setEditingId(null); setNoteText(""); setIsPrivate(false); setReason(""); setError(null); };
  async function save(action: "add" | "edit" | "remove" | "restore", note?: CaseNoteManagementRecord) {
    const actionReason = note ? (noteActionReasons[note.id] ?? "") : reason;
    if (!actionReason.trim()) { setError(action === "remove" || action === "restore" ? "Remove/restore reason is required." : "Reason is required."); return; }
    setIsSaving(true); setError(null);
    const result = await manageCaseNotes({ caseId, action, reason: actionReason.trim(), note: note ? { id: note.id } : { id: editingId, noteText, isPrivate } });
    setIsSaving(false);
    if (result.error) { setError(result.error.message); return; }
    if (note) {
      setNoteActionReasons((current) => {
        const next = { ...current };
        delete next[note.id];
        return next;
      });
      setPendingNoteAction(null);
    }
    resetForm(); await loadNotes(); await onSaved();
  }
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-3xl">
        <DialogHeader><DialogTitle>Manage Notes</DialogTitle><DialogDescription>Add, update, remove, or restore notes. Changes create audit logs only.</DialogDescription></DialogHeader>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={showDeleted} onChange={(event) => setShowDeleted(event.target.checked)} /> Show deleted notes</label>
        <div className="space-y-3">
          {notes.length === 0 ? <SectionEmpty>No notes recorded.</SectionEmpty> : notes.map((note) => {
            const isPendingAction = pendingNoteAction?.id === note.id;
            const pendingAction = isPendingAction ? pendingNoteAction.action : null;

            return (
              <div key={note.id} className="rounded-lg border p-3 text-sm">
                <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-start">
                  <div className="min-w-0">
                    <p className="whitespace-pre-wrap">{note.note_text}</p>
                    <div className="mt-2 flex flex-wrap gap-2 text-xs text-muted-foreground"><span>{formatDate(note.created_at)}</span>{note.is_private ? <Badge variant="secondary">Private</Badge> : null}{note.is_deleted ? <Badge variant="destructive">DELETED</Badge> : null}</div>
                    {note.is_deleted ? <p className="mt-2 text-xs text-muted-foreground">Deleted {formatDate(note.deleted_at)}{note.deleted_by_user_id ? ` by user #${note.deleted_by_user_id}` : ""} — {note.delete_reason ?? "No reason recorded"}</p> : null}
                  </div>
                  <div className="flex min-w-56 flex-col items-stretch gap-2 sm:items-end">
                    {pendingAction ? null : (
                      <div className="flex justify-end gap-2">
                        {note.is_deleted ? (
                          <Button size="sm" variant="outline" onClick={() => setPendingNoteAction({ id: note.id, action: "restore" })}>Restore</Button>
                        ) : (
                          <>
                            <Button size="sm" variant="outline" onClick={() => { setEditingId(note.id); setNoteText(note.note_text); setIsPrivate(note.is_private); setReason(""); }}>Edit</Button>
                            <Button size="sm" variant="outline" onClick={() => setPendingNoteAction({ id: note.id, action: "remove" })}>Remove</Button>
                          </>
                        )}
                      </div>
                    )}
                    {pendingAction ? (
                      <div className="w-full space-y-2">
                        <Input placeholder={pendingAction === "restore" ? "Restore reason" : "Remove reason"} value={noteActionReasons[note.id] ?? ""} onChange={(event) => setNoteActionReasons((current) => ({ ...current, [note.id]: event.target.value }))} />
                        <div className="flex justify-end gap-2">
                          <Button size="sm" variant="outline" onClick={() => setPendingNoteAction(null)}>Cancel</Button>
                          <Button size="sm" onClick={() => save(pendingAction, note)}>{pendingAction === "restore" ? "Restore" : "Remove"}</Button>
                        </div>
                      </div>
                    ) : null}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
        <div className="grid gap-4 rounded-lg border p-4"><h3 className="font-semibold">{editingId ? "Edit Note" : "Add Note"}</h3><FieldTextarea label="Note" value={noteText} onChange={setNoteText} /><label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={isPrivate} onChange={(event) => setIsPrivate(event.target.checked)} /> Private</label><FieldTextarea label="Reason for edit" value={reason} onChange={setReason} /></div>
        {error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}
        <DialogFooter><Button variant="outline" onClick={() => onOpenChange(false)}>Close</Button>{editingId ? <Button variant="outline" onClick={resetForm}>Cancel edit</Button> : null}<Button disabled={isSaving} onClick={() => save(editingId ? "edit" : "add")}>{isSaving ? "Saving..." : editingId ? "Save note" : "Add note"}</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  );
}


type ParticipantEditorMode = "main" | "alias" | "address" | "contact";

function participantArray<T = Record<string, unknown>>(value: unknown): T[] {
  return Array.isArray(value) ? (value as T[]) : [];
}

function participantAddressRows(participant: CaseParticipantRecord) {
  return participant.participant_kind === "ORGANIZATION"
    ? participantArray(participant.organizations?.organization_addresses)
    : participantArray(participant.persons?.person_addresses);
}

function ManageParticipantsDialog({ addressTypes, caseId, onOpenChange, onSaved, open, participants }: { addressTypes: RefOption[]; caseId: number; onOpenChange: (open: boolean) => void; onSaved: () => Promise<void>; open: boolean; participants: CaseParticipantRecord[] }) {
  const complainants = participants.filter((participant) => roleLabel(participant).toLowerCase().includes("complainant"));
  const respondents = participants.filter((participant) => roleLabel(participant).toLowerCase().includes("respondent"));
  const others = participants.filter((participant) => !complainants.includes(participant) && !respondents.includes(participant));
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [mode, setMode] = useState<ParticipantEditorMode | null>(null);
  const [editingRecord, setEditingRecord] = useState<Record<string, unknown> | null>(null);
  const [pendingDelete, setPendingDelete] = useState<{ action: "remove_alias" | "remove_address" | "remove_contact"; record: Record<string, unknown>; label: string } | null>(null);
  const [formData, setFormData] = useState<Record<string, string | boolean>>({});
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [reasonError, setReasonError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [correctionHistoryOpen, setCorrectionHistoryOpen] = useState(false);
  const [correctionHistory, setCorrectionHistory] = useState<CaseParticipantCorrectionRecord[]>([]);
  const [correctionHistoryError, setCorrectionHistoryError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setSelectedId((current) => current && participants.some((participant) => participant.id === current) ? current : participants[0]?.id ?? null);
    setMode(null);
    setEditingRecord(null);
    setPendingDelete(null);
    setFormData({});
    setReason("");
    setError(null);
    setReasonError(null);
  }, [open, participants]);

  useEffect(() => {
    if (!open || !selectedId) {
      setCorrectionHistory([]);
      setCorrectionHistoryError(null);
      return;
    }
    void getCaseParticipantCorrections(selectedId).then((result) => {
      if (result.error) {
        setCorrectionHistoryError(result.error.message);
        setCorrectionHistory([]);
        return;
      }
      setCorrectionHistory(result.data ?? []);
      setCorrectionHistoryError(null);
    });
  }, [open, selectedId]);

  const selected = participants.find((participant) => participant.id === selectedId) ?? null;
  const aliases = selected?.participant_kind === "ORGANIZATION" ? participantArray(selected.organizations?.organization_aliases) : participantArray(selected?.persons?.person_aliases);
  const addresses = selected ? participantAddressRows(selected) : [];
  const contacts = participantArray(selected?.contact_informations);
  const legacyFullNameOnly = Boolean(selected?.persons && !selected.persons.first_name && !selected.persons.middle_name && !selected.persons.last_name && selected.persons.full_name);

  const setValue = (key: string, value: string | boolean) => setFormData((current) => ({ ...current, [key]: value }));

  function openEditor(nextMode: ParticipantEditorMode, record?: Record<string, unknown>) {
    if (!selected) return;
    setMode(nextMode);
    setEditingRecord(record ?? null);
    setPendingDelete(null);
    setReason("");
    setError(null);
    setReasonError(null);
    if (nextMode === "main") {
      setFormData(selected.participant_kind === "ORGANIZATION" ? {
        organizationName: selected.organizations?.organization_name ?? "",
        contactPerson: selected.organizations?.contact_person ?? "",
        contactNumber: selected.organizations?.contact_number ?? "",
        email: selected.organizations?.email ?? "",
        isMinorAtCase: selected.case_participant_attributes?.is_minor_at_case === true,
        isSeniorAtCase: selected.case_participant_attributes?.is_senior_at_case === true,
        isPwdAtCase: selected.case_participant_attributes?.is_pwd_at_case === true,
        remarks: selected.remarks ?? "",
        sourceDetail: selected.case_participant_private_details?.source_detail ?? "",
      } : {
        useStructuredName: !legacyFullNameOnly,
        fullName: selected.persons?.full_name ?? selected.display_name_snapshot ?? "",
        firstName: selected.persons?.first_name ?? "",
        middleName: selected.persons?.middle_name ?? "",
        lastName: selected.persons?.last_name ?? "",
        suffix: selected.persons?.suffix ?? "",
        gender: selected.persons?.gender ?? selected.case_participant_attributes?.gender_text ?? "",
        birthDate: selected.persons?.birth_date ?? "",
        age: selected.persons?.age ?? selected.case_participant_attributes?.age_text ?? "",
        personDescriptor: selected.persons?.person_descriptor ?? "",
        notes: selected.persons?.notes ?? "",
        remarks: selected.remarks ?? "",
        sourceDetail: selected.case_participant_private_details?.source_detail ?? "",
        isMinorAtCase: selected.case_participant_attributes?.is_minor_at_case === true,
        isSeniorAtCase: selected.case_participant_attributes?.is_senior_at_case === true,
        isPwdAtCase: selected.case_participant_attributes?.is_pwd_at_case === true,
      });
    } else if (nextMode === "alias") {
      setFormData({ aliasName: String(record?.alias_name ?? "") });
    } else if (nextMode === "address") {
      const address = record?.addresses as Record<string, unknown> | undefined;
      setFormData({
        addressTypeId: String(record?.address_type_id ?? addressTypes[0]?.id ?? ""),
        line1: String(address?.line1 ?? ""), line2: String(address?.line2 ?? ""), barangay: String(address?.barangay ?? ""), city: String(address?.city ?? ""), province: String(address?.province ?? ""), region: String(address?.region ?? ""), zipCode: String(address?.zip_code ?? ""), country: String(address?.country ?? "Philippines"), remarks: String(record?.remarks ?? ""), isPrimary: record?.is_primary === true,
      });
    } else {
      setFormData({ contactType: String(record?.contact_type ?? "PHONE"), contactValue: String(record?.contact_value ?? ""), label: String(record?.label ?? ""), remarks: String(record?.remarks ?? ""), isPrimary: record?.is_primary === true });
    }
  }

  async function save(action?: "remove_alias" | "remove_address" | "remove_contact", reasonOverride?: string, recordOverride?: Record<string, unknown>) {
    if (!selected) return;
    const nextAction = action ?? (mode === "main" ? "edit_main_details" : mode === "alias" ? (editingRecord ? "edit_alias" : "add_alias") : mode === "address" ? (editingRecord ? "edit_address" : "add_address") : mode === "contact" ? (editingRecord ? "edit_contact" : "add_contact") : null);
    if (!nextAction) return;
    const effectiveReason = reasonOverride ?? (mode === "main" ? reason : nextAction.replace(/_/g, " "));
    if ((mode === "main" || action) && !effectiveReason.trim()) { setReasonError("Reason is required."); return; }
    setIsSaving(true);
    setError(null);
    setReasonError(null);
    const targetRecord = recordOverride ?? editingRecord;
    const payload = {
      ...formData,
      id: selected.id,
      aliasId: targetRecord?.id,
      addressRelationId: targetRecord?.id,
      addressId: targetRecord?.address_id,
      participantContactInformationId: targetRecord?.participant_contact_information_id,
      contactInformationId: targetRecord?.id,
    };
    const result = await manageCaseParticipants({ caseId, action: nextAction, reason: effectiveReason.trim(), participant: payload });
    setIsSaving(false);
    if (result.error) { setError(result.error.message); return; }
    setMode(null);
    setEditingRecord(null);
    setPendingDelete(null);
    setReason("");
    setReasonError(null);
    await onSaved();
    if (selected?.id) {
      const historyResult = await getCaseParticipantCorrections(selected.id);
      if (!historyResult.error) setCorrectionHistory(historyResult.data ?? []);
    }
  }

  function openCorrectionHistory() {
    if (!selected) return;
    setCorrectionHistoryOpen(true);
    void getCaseParticipantCorrections(selected.id).then((result) => {
      if (result.error) {
        setCorrectionHistoryError(result.error.message);
        setCorrectionHistory([]);
        return;
      }
      setCorrectionHistory(result.data ?? []);
      setCorrectionHistoryError(null);
    });
  }


  function openDelete(action: "remove_alias" | "remove_address" | "remove_contact", record: Record<string, unknown>, label: string) {
    setMode(null);
    setEditingRecord(null);
    setPendingDelete({ action, record, label });
    setReason("");
    setReasonError(null);
    setError(null);
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    await save(pendingDelete.action, reason, pendingDelete.record);
  }

  function participantButton(participant: CaseParticipantRecord) {
    return <button key={participant.id} type="button" className={`rounded-lg border p-3 text-left text-sm ${selectedId === participant.id ? "border-primary bg-primary/5" : "hover:bg-muted"}`} onClick={() => setSelectedId(participant.id)}><span className="font-medium">{participantName(participant)}</span><span className="mt-1 block text-xs text-muted-foreground">{roleLabel(participant)}</span></button>;
  }

  const detailListMaxHeight = mode ? "max-h-40" : "max-h-72";
  const renderEditor = () => mode ? <div className="space-y-3 rounded-lg border p-4"><h3 className="font-semibold">{mode === "main" ? "Participant name and details" : mode === "alias" ? "Alias" : mode === "address" ? "Address" : "Contact info"}</h3>{selected?.participant_kind !== "ORGANIZATION" && mode === "main" && legacyFullNameOnly ? <label className="flex items-center gap-2 text-sm"><Checkbox checked={Boolean(formData.useStructuredName)} onCheckedChange={(checked: boolean | "indeterminate") => setValue("useStructuredName", checked === true)} /> Convert legacy full name to structured name</label> : null}<div className="grid gap-3 sm:grid-cols-2">{mode === "main" && selected?.participant_kind === "ORGANIZATION" ? <><FieldInput label="Organization Name" value={String(formData.organizationName ?? "")} onChange={(v) => setValue("organizationName", v)} /><FieldInput label="Contact Person" value={String(formData.contactPerson ?? "")} onChange={(v) => setValue("contactPerson", v)} /><FieldInput label="Contact Number" value={String(formData.contactNumber ?? "")} onChange={(v) => setValue("contactNumber", v)} /><FieldInput label="Email" value={String(formData.email ?? "")} onChange={(v) => setValue("email", v)} /></> : null}{mode === "main" && selected?.participant_kind !== "ORGANIZATION" ? (formData.useStructuredName ? <><FieldInput label="First Name" value={String(formData.firstName ?? "")} onChange={(v) => setValue("firstName", v)} /><FieldInput label="Middle Name" value={String(formData.middleName ?? "")} onChange={(v) => setValue("middleName", v)} /><FieldInput label="Last Name" value={String(formData.lastName ?? "")} onChange={(v) => setValue("lastName", v)} /><FieldInput label="Suffix" value={String(formData.suffix ?? "")} onChange={(v) => setValue("suffix", v)} /></> : <FieldInput label="Full Name" value={String(formData.fullName ?? "")} onChange={(v) => setValue("fullName", v)} className="sm:col-span-2" />) : null}{mode === "main" ? <><FieldInput label="Gender" value={String(formData.gender ?? "")} onChange={(v) => setValue("gender", v)} /><FieldInput label="Birthdate" type="date" value={String(formData.birthDate ?? "")} onChange={(v) => setValue("birthDate", v)} /><FieldInput label="Age" value={String(formData.age ?? "")} onChange={(v) => setValue("age", v)} /><FieldInput label="Remarks" value={String(formData.remarks ?? "")} onChange={(v) => setValue("remarks", v)} /><div className="flex flex-wrap items-center gap-4 pt-2 sm:col-span-2"><label className="flex items-center gap-2 text-sm"><Checkbox checked={Boolean(formData.isMinorAtCase)} onCheckedChange={(checked: boolean | "indeterminate") => setValue("isMinorAtCase", checked === true)} /> Minor</label><label className="flex items-center gap-2 text-sm"><Checkbox checked={Boolean(formData.isSeniorAtCase)} onCheckedChange={(checked: boolean | "indeterminate") => setValue("isSeniorAtCase", checked === true)} /> Senior</label><label className="flex items-center gap-2 text-sm"><Checkbox checked={Boolean(formData.isPwdAtCase)} onCheckedChange={(checked: boolean | "indeterminate") => setValue("isPwdAtCase", checked === true)} /> PWD</label></div></> : null}{mode === "alias" ? <FieldInput label="Alias" value={String(formData.aliasName ?? "")} onChange={(v) => setValue("aliasName", v)} className="sm:col-span-2" /> : null}{mode === "address" ? <><FieldSelect label="Address type" value={String(formData.addressTypeId ?? "")} onChange={(v) => setValue("addressTypeId", v)} options={addressTypes} optionLabel={(option) => option.display_label ?? option.code ?? String(option.id)} /><FieldInput label="Line 1" value={String(formData.line1 ?? "")} onChange={(v) => setValue("line1", v)} /><FieldInput label="Line 2" value={String(formData.line2 ?? "")} onChange={(v) => setValue("line2", v)} /><FieldInput label="Barangay" value={String(formData.barangay ?? "")} onChange={(v) => setValue("barangay", v)} /><FieldInput label="City" value={String(formData.city ?? "")} onChange={(v) => setValue("city", v)} /><FieldInput label="Province" value={String(formData.province ?? "")} onChange={(v) => setValue("province", v)} /><FieldInput label="Country" value={String(formData.country ?? "")} onChange={(v) => setValue("country", v)} /></> : null}{mode === "contact" ? <><FieldSelect label="Type" value={String(formData.contactType ?? "PHONE")} onChange={(v) => setValue("contactType", v)} options={[{id:1,code:"PHONE",display_label:"Phone"},{id:2,code:"EMAIL",display_label:"Email"},{id:3,code:"OTHER",display_label:"Other"}]} valueKey="code" optionLabel={(option) => option.display_label ?? String(option.id)} /><FieldInput label="Value" value={String(formData.contactValue ?? "")} onChange={(v) => setValue("contactValue", v)} /><FieldInput label="Label" value={String(formData.label ?? "")} onChange={(v) => setValue("label", v)} /></> : null}{mode === "main" ? <div className="sm:col-span-2"><Label>Reason</Label><Textarea value={reason} onChange={(event) => { setReason(event.target.value); setReasonError(null); }} className={reasonError ? "border-destructive" : undefined} />{reasonError ? <p className="mt-1 text-sm text-destructive">{reasonError}</p> : null}</div> : null}</div>{error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}<div className="flex justify-end gap-2"><Button type="button" variant="outline" onClick={() => setMode(null)}>Cancel</Button><Button type="button" onClick={() => save()} disabled={isSaving}>{isSaving ? "Saving..." : "Save"}</Button></div></div> : null;
  const contactHref = (contact: Record<string, unknown>) => String(contact.contact_type).toUpperCase() === "EMAIL" ? `mailto:${String(contact.contact_value ?? "")}` : String(contact.contact_type).toUpperCase() === "PHONE" ? `tel:${String(contact.contact_value ?? "")}` : undefined;
  const correctionSnapshot = (snapshot: unknown, key: "person" | "organization" | "attributes") => typeof snapshot === "object" && snapshot && !Array.isArray(snapshot) && key in snapshot ? (snapshot as Record<string, unknown>)[key] : null;
  const correctionIdentityKey = selected?.participant_kind === "ORGANIZATION" ? "organization" : "person";

  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="flex max-h-[90vh] flex-col overflow-hidden sm:max-w-5xl"><DialogHeader className="shrink-0"><DialogTitle>Manage Participants</DialogTitle><DialogDescription>Select a participant, then edit main details, aliases, addresses, or contact information.</DialogDescription></DialogHeader>
    <div className="grid min-h-0 flex-1 gap-4 lg:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)]">
      <div className="min-h-0 overflow-y-auto pr-2"><div className="grid gap-4 md:grid-cols-2 lg:grid-cols-1"><div><h3 className="mb-2 font-semibold">Complainants</h3><div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">{complainants.length ? complainants.map(participantButton) : <SectionEmpty>No complainants.</SectionEmpty>}</div></div><div><h3 className="mb-2 font-semibold">Respondents</h3><div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">{respondents.length ? respondents.map(participantButton) : <SectionEmpty>No respondents.</SectionEmpty>}</div></div>{others.length ? <div className="md:col-span-2 lg:col-span-1"><h3 className="mb-2 font-semibold">Other Participants</h3><div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">{others.map(participantButton)}</div></div> : null}</div></div>
      <div className="min-w-0 space-y-4 rounded-lg border p-4">{selected ? <><div className="flex flex-wrap items-start justify-between gap-3"><div className="min-w-0"><h3 className="break-words text-lg font-semibold">{participantName(selected)}</h3><p className="text-sm text-muted-foreground">{roleLabel(selected)} • {selected.participant_kind ?? "PERSON"}</p><div className="mt-2 flex flex-wrap gap-2">{legacyFullNameOnly ? <Badge variant="outline">Legacy full-name only</Badge> : null}{correctionHistory.length ? <button type="button" onClick={openCorrectionHistory}><Badge variant="secondary" className="cursor-pointer">Corrected</Badge></button> : null}</div></div><Button type="button" size="sm" onClick={() => openEditor("main")}>Correct Identity</Button></div>
        <div className="grid gap-3 sm:grid-cols-3"><div className={`flex ${detailListMaxHeight} min-h-0 flex-col rounded-md border p-3`}><div className="mb-2 flex shrink-0 items-center justify-between gap-2"><p className="font-medium">Aliases</p><Button type="button" size="sm" variant="outline" onClick={() => openEditor("alias")}>Add</Button></div>{aliases.length ? <div className="min-h-0 flex-1 divide-y overflow-y-auto pr-1">{aliases.map((alias) => <div key={String(alias.id)} className="space-y-2 py-2 text-sm"><p className="break-words">{String(alias.alias_name ?? "")}</p><div className="flex flex-wrap gap-2"><Button type="button" size="sm" variant="ghost" onClick={() => openEditor("alias", alias)}>Edit</Button><Button type="button" size="sm" variant="ghost" className="text-destructive" onClick={() => { setMode("alias"); setEditingRecord(alias); openDelete("remove_alias", alias, "alias") }}>Remove</Button></div></div>)}</div> : <p className="text-sm text-muted-foreground">No aliases.</p>}</div>
        <div className={`flex ${detailListMaxHeight} min-h-0 flex-col rounded-md border p-3`}><div className="mb-2 flex shrink-0 items-center justify-between gap-2"><p className="font-medium">Addresses</p><Button type="button" size="sm" variant="outline" onClick={() => openEditor("address")}>Add</Button></div>{addresses.length ? <div className="min-h-0 flex-1 divide-y overflow-y-auto pr-1">{addresses.map((address) => <div key={String(address.id)} className="space-y-2 py-2"><p className="break-words text-sm">{formatAddress((address.addresses ?? {}) as never) || "Address"}</p><div className="flex flex-wrap gap-2"><Button type="button" size="sm" variant="ghost" onClick={() => openEditor("address", address)}>Edit</Button><Button type="button" size="sm" variant="ghost" className="text-destructive" onClick={() => { setMode("address"); setEditingRecord(address); openDelete("remove_address", address, "address") }}>Remove</Button></div></div>)}</div> : <p className="text-sm text-muted-foreground">No addresses.</p>}</div>
        <div className={`flex ${detailListMaxHeight} min-h-0 flex-col rounded-md border p-3`}><div className="mb-2 flex shrink-0 items-center justify-between gap-2"><p className="font-medium">Contacts</p><Button type="button" size="sm" variant="outline" onClick={() => openEditor("contact")}>Add</Button></div>{contacts.length ? <div className="min-h-0 flex-1 divide-y overflow-y-auto pr-1">{contacts.map((contact) => <div key={String(contact.participant_contact_information_id ?? contact.id)} className="space-y-2 py-2"><p className="text-xs font-medium uppercase text-muted-foreground">{String(contact.contact_type)}</p>{contactHref(contact as never) ? <a className="block break-all text-sm text-primary hover:underline" href={contactHref(contact as never)}>{String(contact.contact_value)}</a> : <p className="break-all text-sm">{String(contact.contact_value)}</p>}<div className="flex flex-wrap gap-2"><Button type="button" size="sm" variant="ghost" onClick={() => openEditor("contact", contact as never)}>Edit</Button><Button type="button" size="sm" variant="ghost" className="text-destructive" onClick={() => { setMode("contact"); setEditingRecord(contact as never); openDelete("remove_contact", contact as never, "contact info") }}>Remove</Button></div></div>)}</div> : <p className="text-sm text-muted-foreground">No contacts.</p>}</div></div>{pendingDelete ? <div className="space-y-3 rounded-lg border p-4"><h3 className="font-semibold">Remove {pendingDelete.label}</h3><p className="text-sm text-muted-foreground">Enter a reason before removing this {pendingDelete.label}.</p><div><Label>Reason</Label><Textarea value={reason} onChange={(event) => { setReason(event.target.value); setReasonError(null); }} className={reasonError ? "border-destructive" : undefined} />{reasonError ? <p className="mt-1 text-sm text-destructive">{reasonError}</p> : null}</div><div className="flex justify-end gap-2"><Button type="button" variant="outline" onClick={() => { setPendingDelete(null); setReason(""); setReasonError(null); }}>Cancel</Button><Button type="button" variant="destructive" onClick={confirmDelete} disabled={isSaving}>{isSaving ? "Removing..." : "Remove"}</Button></div></div> : renderEditor()}</> : <SectionEmpty>No participant selected.</SectionEmpty>}
      </div>
    </div>
    <DialogFooter className="shrink-0"><Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Close</Button></DialogFooter></DialogContent>
    <Dialog open={correctionHistoryOpen} onOpenChange={setCorrectionHistoryOpen}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-4xl">
        <DialogHeader><DialogTitle>Correction History</DialogTitle><DialogDescription>Prior voided person details are shown only in this correction history.</DialogDescription></DialogHeader>
        {correctionHistoryError ? <Alert variant="destructive"><AlertDescription>{correctionHistoryError}</AlertDescription></Alert> : null}
        <div className="space-y-3">{correctionHistory.length === 0 ? <SectionEmpty>No participant corrections recorded.</SectionEmpty> : correctionHistory.map((entry) => <div key={entry.id} className="rounded-lg border p-3 text-sm">
          <div className="flex flex-wrap items-center gap-2"><Badge variant="outline">Correction</Badge><span className="text-muted-foreground">{formatDate(entry.corrected_at)}</span><span className="text-muted-foreground">by {entry.corrected_by_display ?? (entry.corrected_by_user_id ? `User #${entry.corrected_by_user_id}` : "—")}</span></div>
          <p className="mt-2 text-muted-foreground">Reason: {entry.reason ?? "—"}</p>
          <div className="mt-3 grid gap-3 md:grid-cols-2"><div><p className="mb-1 font-medium">Old name/details</p><pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{formatJsonPreview(correctionSnapshot(entry.old_snapshot_json, correctionIdentityKey))}</pre></div><div><p className="mb-1 font-medium">New name/details</p><pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{formatJsonPreview(correctionSnapshot(entry.new_snapshot_json, correctionIdentityKey))}</pre></div><div><p className="mb-1 font-medium">Old attributes</p><pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{formatJsonPreview(correctionSnapshot(entry.old_snapshot_json, "attributes"))}</pre></div><div><p className="mb-1 font-medium">New attributes</p><pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{formatJsonPreview(correctionSnapshot(entry.new_snapshot_json, "attributes"))}</pre></div></div>
        </div>)}</div>
        <DialogFooter><Button type="button" onClick={() => setCorrectionHistoryOpen(false)}>Close</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  </Dialog>;
}

function OverviewHistoryDialog({ caseId, open, onOpenChange }: { caseId: number; open: boolean; onOpenChange: (open: boolean) => void }) {
  const [history, setHistory] = useState<CaseOverviewChangeHistoryRecord[]>([]);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { if (!open) return; void getCaseOverviewChangeHistory(caseId).then((result) => { if (result.error) setError(result.error.message); setHistory(result.data ?? []); }); }, [caseId, open]);
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-4xl"><DialogHeader><DialogTitle>Overview Change History</DialogTitle><DialogDescription>Audit entries for overview edits, places, and notes.</DialogDescription></DialogHeader>{error ? <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert> : null}<div className="space-y-3">{history.length === 0 ? <SectionEmpty>No overview changes recorded.</SectionEmpty> : history.map((entry) => <div key={entry.id} className="rounded-lg border p-3 text-sm"><div className="flex flex-wrap items-center gap-2"><Badge variant="outline">{entry.action}</Badge><span className="text-muted-foreground">{formatDate(entry.created_at)}</span></div><p className="mt-2 font-medium">{entry.summary ?? "—"}</p><p className="text-muted-foreground">Reason: {typeof entry.metadata === "object" && entry.metadata && !Array.isArray(entry.metadata) && "reason" in entry.metadata ? String(entry.metadata.reason) : "—"}</p><div className="mt-3 grid gap-3 md:grid-cols-2"><pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{formatJsonPreview(entry.old_data)}</pre><pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{formatJsonPreview(entry.new_data)}</pre></div></div>)}</div><DialogFooter><Button onClick={() => onOpenChange(false)}>Close</Button></DialogFooter></DialogContent></Dialog>;
}


export default function CaseDetailsPage() {
  const params = useParams<{ caseId: string }>();
  const caseId = Number.parseInt(params.caseId, 10);
  const [data, setData] = useState<CaseDetailsState | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [refs, setRefs] = useState<OverviewRefs>({ docketTypes: [], classifications: [], statuses: [], stages: [], addressTypes: [] });
  const [activeOverviewEditor, setActiveOverviewEditor] =
    useState<OverviewAction | null>(null);
  const [correctionParticipantId, setCorrectionParticipantId] = useState<number | null>(null);
  const loadCase = useCallback(async () => {
    if (!Number.isFinite(caseId)) {
      setErrorMessage("Invalid case id.");
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    const [
      caseDetailsPage,
      participants,
      participantCorrections,
      attachments,
      timeline,
      courts,
      motions,
      petitionsForReview,
      docketTypes,
      classifications,
      statuses,
      stages,
      addressTypes,
    ] = await Promise.all([
      getCaseDetailsPageById(caseId),
      getCaseParticipants(caseId),
      getCaseParticipantCorrectionsForCase(caseId),
      getCaseAttachmentsIndex(caseId),
      getCaseTimelineEvents(caseId),
      getCaseCourtDetails(caseId),
      getCaseMotions(caseId),
      getCasePetitionsForReview(caseId),
      getDocketTypes(),
      getCaseClassifications(),
      getCaseStatuses(),
      getCaseStages(),
      getAddressTypes(),
    ]);

    const criticalError = caseDetailsPage.error;

    if (criticalError) {
      setErrorMessage(criticalError.message);
      setData(null);
      setIsLoading(false);
      return;
    }

    const warnings = [
      participants,
      participantCorrections,
      attachments,
      timeline,
      courts,
      motions,
      petitionsForReview,
    ]
      .map((result) => result.error?.message)
      .filter((message): message is string => Boolean(message));

    setRefs({
      docketTypes: (docketTypes.data ?? []) as RefOption[],
      classifications: (classifications.data ?? []) as RefOption[],
      statuses: ((statuses.data ?? []) as RefOption[]).filter((status) => ["PENDING", "FILED", "DISMISSED", "MIXED_RESULT"].includes(String(status.code))),
      stages: (stages.data ?? []) as RefOption[],
      addressTypes: (addressTypes.data ?? []) as RefOption[],
    });

    setData({
      compact: caseDetailsPage.data,
      details: caseDetailsPage.data,
      participants: participants.data ?? [],
      participantCorrections: participantCorrections.data ?? [],
      attachments: attachments.data ?? [],
      timeline: timeline.data ?? [],
      courts: courts.data ?? [],
      motions: motions.data ?? [],
      petitionsForReview: petitionsForReview.data ?? [],
      warnings,
    });
    setIsLoading(false);
  }, [caseId]);

  useEffect(() => {
    loadCase();
  }, [loadCase]);

  const openOverviewEditor = useCallback(
    (section: OverviewAction) => setActiveOverviewEditor(section),
    [],
  );

  const partiesByRole = useMemo(() => {
    const grouped = new Map<string, CaseParticipantRecord[]>();

    for (const participant of data?.participants ?? []) {
      if (isVoidedPersonParticipant(participant)) continue;
      const role = roleLabel(participant);
      grouped.set(role, [...(grouped.get(role) ?? []), participant]);
    }

    return Array.from(grouped.entries());
  }, [data?.participants]);

  const participantCorrectionsByParticipantId = useMemo(() => {
    const grouped = new Map<number, CaseParticipantCorrectionRecord[]>();
    for (const correction of data?.participantCorrections ?? []) {
      grouped.set(correction.case_participant_id, [...(grouped.get(correction.case_participant_id) ?? []), correction]);
    }
    return grouped;
  }, [data?.participantCorrections]);

  const selectedCorrectionParticipant = data?.participants.find((participant) => participant.id === correctionParticipantId) ?? null;
  const selectedCorrectionHistory = correctionParticipantId ? (participantCorrectionsByParticipantId.get(correctionParticipantId) ?? []) : [];

  const activeSectionEditor =
    activeOverviewEditor && activeOverviewEditor !== "history" && activeOverviewEditor !== "participants"
      ? activeOverviewEditor
      : null;
  const activeEditorCopy = activeSectionEditor
    ? overviewEditorCopy[activeSectionEditor]
    : null;

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-y-auto p-3 pt-16 md:p-8">
        <div className="flex w-full max-w-[824px] flex-col gap-4 md:gap-6">
          {isLoading ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Loading case details...
              </CardContent>
            </Card>
          ) : errorMessage ? (
            <Alert variant="destructive">
              <AlertTitle>Unable to load case details</AlertTitle>
              <AlertDescription>{errorMessage}</AlertDescription>
            </Alert>
          ) : !data?.details || !data.compact ? (
            <Card>
              <CardContent className="py-10 text-center text-sm text-muted-foreground">
                Case not found.
              </CardContent>
            </Card>
          ) : (
            <>
              {data.warnings.length > 0 ? (
                <Alert>
                  <AlertTitle>
                    Some related sections could not be loaded
                  </AlertTitle>
                  <AlertDescription>{data.warnings.join(" ")}</AlertDescription>
                </Alert>
              ) : null}

              <Card>
                <CardHeader className="gap-5 p-4 sm:p-6">
                  <div className="flex min-w-0 flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div className="min-w-0">
                      <CardTitle className="text-2xl sm:text-3xl">
                        {data.compact.docket_display_number ??
                          displayValue(data.details.docket_number)}
                      </CardTitle>
                      <CardDescription className="mt-3 text-sm text-foreground sm:text-base">
                        {data.compact.violations ?? "No violation recorded"}
                      </CardDescription>
                      {classificationLabel(data.details) ||
                      data.details.is_summary_procedure ? (
                        <div className="mt-3 flex min-w-0 flex-wrap items-center gap-2">
                          {classificationLabel(data.details) ? (
                            <Badge variant="outline">
                              {classificationLabel(data.details)}
                            </Badge>
                          ) : null}
                          {data.details.is_summary_procedure ? (
                            <Badge variant="secondary">Summary Procedure</Badge>
                          ) : null}
                        </div>
                      ) : null}
                    </div>

                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="outline" className="shrink-0 self-start">
                          Actions
                          <ChevronDown className="ml-2 h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" className="w-56">
                        <DropdownMenuItem onSelect={() => openOverviewEditor("docket_info")}>Edit Docket Info</DropdownMenuItem>
                        <DropdownMenuItem onSelect={() => openOverviewEditor("case_details")}>Edit Case Details</DropdownMenuItem>
                        <DropdownMenuItem onSelect={() => openOverviewEditor("places")}>Manage Places of Commission</DropdownMenuItem>
                        <DropdownMenuItem onSelect={() => openOverviewEditor("violations")}>Manage Violations</DropdownMenuItem>
                        <DropdownMenuItem onSelect={() => openOverviewEditor("notes")}>Manage Notes</DropdownMenuItem>
                        <DropdownMenuItem onSelect={() => openOverviewEditor("history")}>View Overview Change History</DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>

                  <div className="grid gap-6 border-t pt-4 md:grid-cols-[minmax(0,1fr)_minmax(14rem,18rem)] md:gap-x-12">
                    <div className="space-y-4">
                      <DetailItem
                        label="Date received"
                        value={formatDate(
                          data.compact.date_received ??
                            data.details.date_received,
                        )}
                      />
                      <DetailItem
                        label="Assigned prosecutor"
                        value={
                          data.compact.prosecutor_full_name ??
                          data.compact.prosecutor_short_name ??
                          "—"
                        }
                      />
                      <OptionalDetailItem
                        label="Places of commission"
                        value={placeOfCommission(data.details)}
                      />
                    </div>

                    <div className="space-y-4">
                      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 sm:items-start">
                        <DetailItem
                          label="Current status"
                          value={
                            <StatusBadge
                              status={
                                data.details.current_case_status?.display_label ??
                                data.details.current_case_status?.code ??
                                data.details.current_status?.display_label ??
                                data.details.current_status?.code ??
                                data.details.current_status_raw ??
                                "—"
                              }
                              size="sm"
                            />
                          }
                        />
                        {isFinalCaseStatus(data.details.current_case_status?.code ?? data.details.current_case_status?.display_label) ? (
                          <DetailItem
                            label="Status date"
                            value={formatDate(
                              data.details.current_case_status_date ??
                                data.details.current_status_date ??
                                data.compact.current_case_status_date ??
                                data.compact.current_status_date,
                            )}
                          />
                        ) : null}
                      </div>
                      <DetailItem
                        label="Current stage"
                        value={
                          <StageBadge
                            stage={
                              data.details.current_case_stage?.display_label ??
                              data.details.current_case_stage?.code ??
                              "—"
                            }
                            size="sm"
                          />
                        }
                      />
                      <OptionalDetailItem
                        label="Status approved date"
                        value={firstDisplayValue(
                          data.details.status_approved_date_raw,
                          formatDate(data.details.status_approved_date),
                        )}
                      />
                      <OptionalDetailItem
                        label="Status remarks"
                        value={withoutAutoStatusStageRemark(
                          data.details.current_case_status_remarks ??
                            data.details.current_status_remarks,
                        )}
                      />
                      <OptionalDetailItem
                        label="Stage remarks"
                        value={withoutAutoStatusStageRemark(data.details.current_case_stage_remarks)}
                      />
                      <OptionalDetailItem
                        label="Summary"
                        value={data.details.summary_text}
                      />
                      <OptionalDetailItem
                        label="Summary remarks"
                        value={data.details.remarks}
                      />
                      <OptionalDetailItem
                        label="Case notes"
                        value={caseNotesDetails(data.details)}
                      />
                    </div>
                  </div>
                </CardHeader>
              </Card>

              {activeSectionEditor && activeEditorCopy &&
              activeSectionEditor !== "places" &&
              activeSectionEditor !== "notes" &&
              activeSectionEditor !== "violations" ? (
                <OverviewSectionEditor
                  caseId={caseId}
                  description={activeEditorCopy.description}
                  initialData={getOverviewInitialData(
                    activeSectionEditor,
                    data.details,
                  )}
                  onOpenChange={(open) =>
                    setActiveOverviewEditor(open ? activeSectionEditor : null)
                  }
                  onSaved={loadCase}
                  open
                  refs={refs}
                  section={activeSectionEditor}
                  title={activeEditorCopy.title}
                />
              ) : null}
              <ManagePlacesDialog
                caseId={caseId}
                onOpenChange={(open) =>
                  setActiveOverviewEditor(open ? "places" : null)
                }
                onSaved={loadCase}
                open={activeOverviewEditor === "places"}
                refs={refs}
              />
              <ManageViolationsDialog
                caseId={caseId}
                onOpenChange={(open) =>
                  setActiveOverviewEditor(open ? "violations" : null)
                }
                onSaved={loadCase}
                open={activeOverviewEditor === "violations"}
              />
              <ManageNotesDialog
                caseId={caseId}
                onOpenChange={(open) =>
                  setActiveOverviewEditor(open ? "notes" : null)
                }
                onSaved={loadCase}
                open={activeOverviewEditor === "notes"}
              />
              <ManageParticipantsDialog
                addressTypes={refs.addressTypes}
                caseId={caseId}
                onOpenChange={(open) =>
                  setActiveOverviewEditor(open ? "participants" : null)
                }
                onSaved={loadCase}
                open={activeOverviewEditor === "participants"}
                participants={data.participants.filter((participant) => !isVoidedPersonParticipant(participant))}
              />
              <ParticipantCorrectionHistoryDialog corrections={selectedCorrectionHistory} onOpenChange={(open) => setCorrectionParticipantId(open ? correctionParticipantId : null)} open={Boolean(correctionParticipantId)} participant={selectedCorrectionParticipant} />
              <OverviewHistoryDialog
                caseId={caseId}
                onOpenChange={(open) =>
                  setActiveOverviewEditor(open ? "history" : null)
                }
                open={activeOverviewEditor === "history"}
              />

              <div className="space-y-6">
                <Card>
                  <CardHeader className="p-4 sm:p-6">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <CardTitle>Parties</CardTitle>
                      <Button type="button" variant="outline" onClick={() => openOverviewEditor("participants")}>Manage Participants</Button>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-4 p-4 pt-0 sm:p-6 sm:pt-0">
                    {partiesByRole.length === 0 ? (
                      <SectionEmpty />
                    ) : (
                      partiesByRole.map(([role, participants]) => (
                        <div key={role} className="space-y-3">
                          <h3 className="font-semibold">{role}</h3>
                          <div className="grid gap-3 md:grid-cols-2">
                            {participants.map((participant) => (
                              <div
                                key={participant.id}
                                className="rounded-lg border p-4"
                              >
                                <div className="space-y-2">
                                  <div className="flex flex-wrap items-center gap-2">
                                    {participantProfileHref(participant) ? (
                                      <Link
                                        href={participantProfileHref(participant) ?? "#"}
                                        className="font-medium text-primary hover:underline"
                                      >
                                        {participantName(participant)}
                                      </Link>
                                    ) : (
                                      <p className="font-medium">
                                        {participantName(participant)}
                                      </p>
                                    )}
                                    {(participantCorrectionsByParticipantId.get(participant.id)?.length ?? 0) > 0 ? <button type="button" className="rounded-full focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2" onClick={() => setCorrectionParticipantId(participant.id)} aria-label={`View correction history for ${participantName(participant)}`}><Badge variant="secondary" className="cursor-pointer">Corrected</Badge></button> : null}
                                    {caseFlagBadges(participant)}
                                  </div>
                                  {participantAliasBadges(participant)}
                                  {personBirthDateAndSex(participant) ? (
                                    <p className="text-sm text-muted-foreground">
                                      {personBirthDateAndSex(participant)}
                                    </p>
                                  ) : null}
                                </div>
                                <Separator className="my-3" />
                                <div className="grid gap-4 text-sm sm:grid-cols-2">
                                  <OptionalDetailItem
                                    label="Addresses"
                                    value={
                                      <ParticipantAddresses
                                        participant={participant}
                                      />
                                    }
                                  />
                                  <OptionalDetailItem
                                    label="Contact information"
                                    value={participantContacts(participant)}
                                  />
                                  <div className="space-y-2">
                                    <OptionalDetailItem
                                      label="Age at case"
                                      value={ageAtCase(participant)}
                                    />
                                    <OptionalDetailItem
                                      label="Remarks"
                                      value={participant.remarks}
                                    />
                                  </div>
                                  <OptionalDetailItem
                                    label="Organization details"
                                    value={formatOrganizationDetails(
                                      participant.organizations?.details_jsonb,
                                    )}
                                  />
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      ))
                    )}
                  </CardContent>
                </Card>


                <CaseTimeline
                  caseId={caseId}
                  courts={data.courts}
                  events={data.timeline}
                  motions={data.motions}
                  onChanged={loadCase}
                  onUpdateStatus={() => openOverviewEditor("status")}
                  petitionsForReview={data.petitionsForReview}
                />

                <Card>
                  <CardHeader>
                    <CardTitle>Attachments</CardTitle>
                    <CardDescription>
                      Google Drive folder and indexed file records, when
                      available.
                    </CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {data.details.gdrive_folder_link ? (
                      <Button variant="outline" asChild>
                        <a
                          href={data.details.gdrive_folder_link}
                          target="_blank"
                          rel="noreferrer"
                        >
                          Open Google Drive folder
                          <ExternalLink className="ml-2 h-4 w-4" />
                        </a>
                      </Button>
                    ) : null}

                    {data.attachments.length === 0 ? (
                      <SectionEmpty>
                        Attachments integration not yet connected.
                      </SectionEmpty>
                    ) : (
                      <div className="space-y-3">
                        {data.attachments.map((attachment) => (
                          <div
                            key={attachment.id}
                            className="rounded-lg border p-3 text-sm"
                          >
                            <div className="flex items-start justify-between gap-3">
                              <div className="min-w-0">
                                <p className="truncate font-medium">
                                  {attachment.file_name}
                                </p>
                                <p className="text-muted-foreground">
                                  {formatFileSize(attachment.file_size_bytes)} •{" "}
                                  {attachment.file_status}
                                </p>
                              </div>
                              {attachment.web_view_link ? (
                                <Button variant="ghost" size="sm" asChild>
                                  <a
                                    href={attachment.web_view_link}
                                    target="_blank"
                                    rel="noreferrer"
                                    aria-label={`Open ${attachment.file_name}`}
                                  >
                                    <ExternalLink className="h-4 w-4" />
                                  </a>
                                </Button>
                              ) : null}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </CardContent>
                </Card>
              </div>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
