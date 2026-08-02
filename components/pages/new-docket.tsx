'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AlertCircle, CheckCircle2, Loader2, MapPin, Plus, Search, Settings2, X } from 'lucide-react';

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { CreatableLookupSelect } from '@/components/lookups/creatable-lookup-select';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Textarea } from '@/components/ui/textarea';
import { formatManilaClock, getManilaDateTimeInputValues } from '@/lib/philippine-time';
import {
  addAddressType,
  addCaseClassification,
  addParticipantRole,
  getAddressTypes,
  getCaseStatuses,
  getCaseClassifications,
  getCaseDetailsPageById,
  getCaseManagedViolations,
  getCasePlaces,
  getCaseParticipants,
  getCurrentDatabaseUser,
  getDocketTypes,
  getNextDocketNumber,
  getParticipantRoles,
  getProsecutors,
  getViolations,
  searchAddressSuggestions,
  searchPersons,
  searchOrganizations,
  searchViolationSuggestions,
  type DatabaseUserSummary,
  type NewDocketAddressInput,
  type NewDocketEntryInput,
  type NewDocketParticipantInput,
  type NewDocketViolationInput,
  type OrganizationDetailsSearchRow,
  type PersonDetailsSearchRow,
} from '@/lib/supabase/queries';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import type { TableRow } from '@/lib/supabase/types';

type LookupState = {
  docketTypes: TableRow<'docket_types'>[];
  participantRoles: TableRow<'participant_roles'>[];
  addressTypes: TableRow<'address_types'>[];
  violations: TableRow<'violations'>[];
  statuses: TableRow<'case_statuses'>[];
  caseClassifications: TableRow<'case_classifications'>[];
  prosecutors: TableRow<'prosecutors'>[];
};

type MessageState =
  | { type: 'success'; text: string; caseId?: number }
  | { type: 'error'; text: string }
  | null;

type AliasEntry = { id: string; aliasName: string; remarks?: string | null };
type ExistingAliasEntry = { aliasName: string };
type AddressEntry = NewDocketAddressInput & { id: string; suggestionQuery: string; selectedExistingLabel?: string | null; existingRelation?: boolean };
type CustomOrganizationDetailEntry = { id: string; fieldTitle: string; fieldValue: string };
type ContactInformationEntry = { id: string; contactType: "PHONE" | "EMAIL" | "OTHER"; contactValue: string; label?: string | null; isPrimary?: boolean | null; remarks?: string | null };
type ParticipantColumnRole = 'Complainant' | 'Respondent';
type ParticipantDialogState = { role: ParticipantColumnRole; step: number; entry: PersonEntry } | null;
type AddOnDialogState = { personId: string; kind: 'alias' | 'address' | 'contact'; step: number; alias: AliasEntry; address: AddressEntry; contact: ContactInformationEntry } | null;
type CaseModalState = { kind: 'docket' | 'violation' | 'procedure' | 'place' | 'assignment'; step: number; id?: string; violation?: ViolationEntry; place?: AddressEntry } | null;
type ParticipantEditDialogState = { personId: string; mode: 'attributes' | 'addresses' | 'contacts' } | null;
type PersonEntry = NewDocketParticipantInput & { id: string; selectedExistingName?: string | null; selectedExistingOrganizationName?: string | null; fullNamePreview?: string | null; aliases?: AliasEntry[]; existingAliases?: ExistingAliasEntry[]; addresses?: AddressEntry[]; organizationDetails?: CustomOrganizationDetailEntry[]; showOrganizationDetails?: boolean; correctionReason?: string };
type ViolationEntry = NewDocketViolationInput & { id: string; searchText: string; selectedExistingTitle?: string | null; createNew?: boolean; newViolationTitle?: string | null; referenceCode?: string | null; shortLabel?: string | null; description?: string | null; lawReference?: string | null };

const emptyLookups: LookupState = {
  docketTypes: [],
  participantRoles: [],
  addressTypes: [],
  violations: [],
  statuses: [],
  caseClassifications: [],
  prosecutors: [],
};


const newDocketDraftStorageKey = 'ocp:new-docket-entry:draft:v1';

type NewDocketDraftState = {
  activeTab: string;
  docketTypeId: string;
  docketYear: string;
  dateReceived: string;
  timeReceived: string;
  caseReceivedDescription: string;
  isCaseReceivedDescriptionEdited: boolean;
  initialStatusId: string;
  caseClassificationId: string;
  caseAlsoRaffled: boolean;
  assignedProsecutorId: string;
  assignmentRemarks: string;
  assignmentDate: string;
  assignmentTime: string;
  isDocketInformationSaved: boolean;
  regionCode: string;
  summaryText: string;
  remarks: string;
  notes: string;
  isSummaryProcedure: boolean;
  persons: PersonEntry[];
  placesOfCommission: AddressEntry[];
  violations: ViolationEntry[];
};

const thisYear = new Date().getFullYear();
const genderOptions = ['Female', 'Male', 'Other', 'Unspecified'];
const participantWorkflowSteps = ['Participant Type', 'Participant Details'];
const aliasWorkflowSteps = ['Alias Name', 'Remarks'];
const addressWorkflowSteps = ['Address Type', 'Address Details'];
const contactWorkflowSteps = ['Contact Type', 'Contact Value', 'Primary', 'Remarks'];
const docketWorkflowSteps = ['Docket Type'];
const violationWorkflowSteps = ['Type new or Search Existing Violations', 'Remarks'];
const procedureWorkflowSteps = ['Procedure and Case Classification'];
const placeWorkflowSteps = ['Address Type', 'Address Details'];
const assignmentWorkflowSteps = ['Assignment Details'];
const defaultRegionCode = 'IV-31';
const defaultAddressRegionCode = 'IV-A';

function makeId(prefix: string) {
  return `${prefix}-${crypto.randomUUID()}`;
}

function toNumber(value: string) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function getFirstId(rows: { id: number }[]) {
  return rows[0]?.id.toString() ?? '';
}

function getAddressTypeIdByKeywords(
  rows: TableRow<'address_types'>[],
  keywords: string[],
) {
  const normalizedKeywords = keywords.map((keyword) => keyword.toLowerCase());
  const match = rows.find((type) => {
    const searchable = [type.code, type.display_label]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    return normalizedKeywords.some((keyword) => searchable.includes(keyword));
  });

  return match?.id.toString() ?? getFirstId(rows);
}

function getReceivedStatusId(statuses: TableRow<'case_statuses'>[]) {
  const receivedStatus = statuses.find((status) => {
    const code = status.code.toLowerCase();
    const label = status.display_label.toLowerCase();
    return code === 'received' || label === 'received';
  });

  return receivedStatus?.id.toString() ?? getFirstId(statuses);
}

function getDocketMonthCode(dateReceived: string) {
  const date = new Date(`${dateReceived}T00:00:00`);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return String.fromCharCode(65 + date.getMonth());
}

function formatDocketNumber(prefix: string | undefined, year: string, number: number | null, monthCode?: string | null, regionCode?: string | null) {
  if (!prefix || !year || !number) {
    return 'Select docket type and date to preview';
  }

  return [regionCode || null, prefix, `${year.slice(-2)}${monthCode ?? ''}`, String(number).padStart(6, '0')].filter(Boolean).join('-');
}

function cleanString(value: string | null | undefined) {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

function namePartsFromStoredFullName(fullName: string | null | undefined) {
  const parts = (fullName ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { firstName: '', middleName: '', lastName: '' };
  if (parts.length === 1) return { firstName: parts[0], middleName: '', lastName: '' };
  return { firstName: parts[0], middleName: parts.length > 2 ? parts.slice(1, -1).join(' ') : '', lastName: parts.at(-1) ?? '' };
}

function buildPersonFullName(person: Pick<PersonEntry, 'firstName' | 'middleName' | 'lastName' | 'suffix' | 'noMiddleName'>) {
  return [
    cleanString(person.firstName),
    person.noMiddleName ? 'NMN' : cleanString(person.middleName),
    cleanString(person.lastName),
    cleanString(person.suffix),
  ]
    .filter(Boolean)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}



function shortPreview(value: string | null | undefined, fallback = '—') {
  const cleaned = cleanString(value);
  if (!cleaned) return fallback;
  return cleaned.length > 90 ? `${cleaned.slice(0, 87)}…` : cleaned;
}

function buildLegalNamePreview(person: Pick<PersonEntry, 'firstName' | 'middleName' | 'lastName' | 'suffix' | 'noMiddleName'>) {
  const surname = cleanString(person.lastName)?.toUpperCase();
  const firstName = cleanString(person.firstName)?.toUpperCase();
  const middleName = person.noMiddleName ? 'NMN' : cleanString(person.middleName)?.toUpperCase();
  const suffix = cleanString(person.suffix)?.toUpperCase();
  const given = [firstName, middleName && middleName !== 'NMN' ? `y ${middleName}` : middleName, suffix].filter(Boolean).join(' ');
  if (surname && given) return `${surname}, ${given}`;
  return surname || given || 'Unnamed person';
}

function formatBirthdatePreview(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) return value;
  return `Born on ${date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}`;
}

function getRoleIdByLabel(rows: TableRow<'participant_roles'>[], label: ParticipantColumnRole, fallback: string) {
  const normalized = label.toLowerCase();
  const match = rows.find((role) => [role.code, role.display_label].filter(Boolean).join(' ').toLowerCase().includes(normalized));
  return match?.id.toString() ?? fallback;
}

function formatAddress(address: TableRow<'addresses'>) {
  return [address.line1, address.line2, address.barangay, address.city, address.province, address.region]
    .filter(Boolean)
    .join(', ');
}

function buildOrganizationDetailsJson(details: CustomOrganizationDetailEntry[] | null | undefined) {
  const entries = (details ?? [])
    .map((detail) => ({ fieldTitle: detail.fieldTitle.trim(), fieldValue: detail.fieldValue.trim() }))
    .filter((detail) => detail.fieldTitle || detail.fieldValue);

  const missingTitle = entries.find((detail) => !detail.fieldTitle);
  if (missingTitle) return { value: null, error: 'Each organization custom detail needs a field title.' };

  const seenTitles = new Set<string>();
  const value: Record<string, string> = {};

  for (const detail of entries) {
    const normalizedTitle = detail.fieldTitle.toLowerCase();
    if (seenTitles.has(normalizedTitle)) {
      return { value: null, error: `Duplicate organization custom field: ${detail.fieldTitle}.` };
    }
    seenTitles.add(normalizedTitle);
    value[detail.fieldTitle] = detail.fieldValue;
  }

  return { value: entries.length ? value : null, error: null };
}

function formatAddressLike(address: Partial<NewDocketAddressInput> & { zip_code?: string | null }) {
  return [address.line1, address.line2, address.barangay, address.city, address.province, address.region, address.zipCode ?? address.zip_code, address.country]
    .filter(Boolean)
    .join(', ');
}

function formatCaseReceivedDefaultDescription(dateReceived: string) {
  const date = new Date(`${dateReceived}T00:00:00`);

  if (Number.isNaN(date.getTime())) {
    return 'Case received';
  }

  return `Case received on ${date.toLocaleDateString('en-US')}`;
}

function makeEmptyAddress(defaultAddressTypeId: string, prefix = 'address'): AddressEntry {
  return {
    id: makeId(prefix),
    addressTypeId: toNumber(defaultAddressTypeId),
    line1: '',
    line2: '',
    barangay: '',
    city: '',
    province: '',
    region: defaultAddressRegionCode,
    zipCode: '',
    country: 'Philippines',
    remarks: '',
    suggestionQuery: '',
    isPrimary: false,
  };
}

export default function NewDocket() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const linkedPeCaseId = Number.parseInt(searchParams.get('linkedPeCaseId') ?? '', 10);
  const linkedDocketType = searchParams.get('docketType')?.toUpperCase();
  const [activeTab, setActiveTab] = useState('case-info');
  const [lookups, setLookups] = useState<LookupState>(emptyLookups);
  const [currentUser, setCurrentUser] = useState<DatabaseUserSummary | null>(null);
  const [isLoadingLookups, setIsLoadingLookups] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState<MessageState>(null);
  const [isDraftHydrated, setIsDraftHydrated] = useState(false);

  const [docketTypeId, setDocketTypeId] = useState('');
  const [docketYear, setDocketYear] = useState(String(thisYear));
  const [nextDocketNumber, setNextDocketNumber] = useState<number | null>(null);
  const [isLoadingNextDocket, setIsLoadingNextDocket] = useState(false);
  const initialManilaDateTime = getManilaDateTimeInputValues();
  const [manilaNow, setManilaNow] = useState(() => new Date());
  const [isReceivedDateTimeDirty, setIsReceivedDateTimeDirty] = useState(false);
  const [isAssignmentDateTimeDirty, setIsAssignmentDateTimeDirty] = useState(false);
  const [dateReceived, setDateReceived] = useState(initialManilaDateTime.date);
  const [timeReceived, setTimeReceived] = useState(initialManilaDateTime.time);
  const [caseReceivedDescription, setCaseReceivedDescription] = useState(() => formatCaseReceivedDefaultDescription(new Date().toISOString().slice(0, 10)));
  const [isCaseReceivedDescriptionEdited, setIsCaseReceivedDescriptionEdited] = useState(false);
  const [initialStatusId, setInitialStatusId] = useState('');
  const [caseClassificationId, setCaseClassificationId] = useState('');
  const [caseClassificationSearch, setCaseClassificationSearch] = useState('');
  const [prosecutorSearch, setProsecutorSearch] = useState('');
  const [caseAlsoRaffled, setCaseAlsoRaffled] = useState(false);
  const [assignedProsecutorId, setAssignedProsecutorId] = useState('');
  const [assignmentRemarks, setAssignmentRemarks] = useState('');
  const [assignmentDate, setAssignmentDate] = useState(initialManilaDateTime.date);
  const [assignmentTime, setAssignmentTime] = useState(initialManilaDateTime.time);
  const [isDocketInformationSaved, setIsDocketInformationSaved] = useState(false);
  const [regionCode, setRegionCode] = useState(defaultRegionCode);
  const [summaryText, setSummaryText] = useState('');
  const [remarks, setRemarks] = useState('');
  const [notes, setNotes] = useState('');
  const [isSummaryProcedure, setIsSummaryProcedure] = useState(false);

  // A linked docket is intentionally initialized from database read views, not
  // from a browser draft, so users review the PE's actual current details.
  useEffect(() => {
    if (!Number.isFinite(linkedPeCaseId) || !linkedDocketType || lookups.docketTypes.length === 0) return;
    let mounted = true;
    async function prefillLinkedDocket() {
      const [detailsResult, participantsResult, violationsResult, placesResult] = await Promise.all([
        getCaseDetailsPageById(linkedPeCaseId),
        getCaseParticipants(linkedPeCaseId),
        getCaseManagedViolations(linkedPeCaseId),
        getCasePlaces(linkedPeCaseId),
      ]);
      if (!mounted) return;
      const details = detailsResult.data;
      const targetType = lookups.docketTypes.find((type) => type.prefix.toUpperCase() === linkedDocketType);
      if (!details || !targetType || participantsResult.error || violationsResult.error || placesResult.error) {
        setMessage({ type: 'error', text: 'Unable to pre-fill the linked PE docket.' });
        return;
      }
      setDocketTypeId(String(targetType.id));
      setDocketYear(String(details.docket_year ?? thisYear));
      setDateReceived(details.date_received ?? getManilaDateTimeInputValues().date);
      setTimeReceived(getManilaDateTimeInputValues().time);
      setCaseReceivedDescription(details.summary_text ?? 'Linked from PE docket');
      setIsCaseReceivedDescriptionEdited(true);
      setCaseClassificationId(details.case_classification_id ? String(details.case_classification_id) : '');
      setRegionCode(details.region_code ?? defaultRegionCode);
      setSummaryText(details.summary_text ?? '');
      setRemarks(details.remarks ?? '');
      setIsSummaryProcedure(Boolean(details.is_summary_procedure));
      const defaultParticipantAddressTypeId = getFirstId(lookups.addressTypes);
      setPersons((participantsResult.data ?? []).map((participant, index) => {
        const person = participant.persons;
        const organization = participant.organizations;
        const nameParts = namePartsFromStoredFullName(person?.full_name);
        const storedAddresses = participant.participant_kind === 'ORGANIZATION'
          ? organization?.organization_addresses ?? []
          : person?.person_addresses ?? [];
        const aliases = participant.participant_kind === 'ORGANIZATION'
          ? organization?.organization_aliases
          : person?.person_aliases;
        const attributes = participant.case_participant_attributes;
        return ({
        id: makeId('linked-person'), participantKind: (participant.participant_kind === 'ORGANIZATION' || participant.organization_id ? 'ORGANIZATION' : 'PERSON') as 'PERSON' | 'ORGANIZATION',
        roleId: participant.role_id ?? 0, participantOrder: participant.participant_order ?? index + 1,
        existingPersonId: participant.person_id ?? undefined, existingOrganizationId: participant.organization_id ?? undefined,
        firstName: person?.first_name ?? nameParts.firstName, middleName: person?.middle_name ?? nameParts.middleName, lastName: person?.last_name ?? nameParts.lastName, suffix: person?.suffix ?? '',
        gender: person?.gender ?? attributes?.gender_text ?? 'Unspecified', age: attributes?.age_text ?? person?.age ?? '', birthDate: person?.birth_date ?? '', noMiddleName: person?.middle_name === 'NMN',
        organizationName: organization?.organization_name ?? '', contactPerson: organization?.contact_person ?? '', contactNumber: organization?.contact_number ?? '', email: organization?.email ?? '',
        selectedExistingName: person?.full_name ?? null, fullNamePreview: person?.full_name ?? null, selectedExistingOrganizationName: organization?.organization_name ?? null,
        remarks: participant.case_participant_private_details?.remarks ?? '', notes: person?.notes ?? '', personDescriptor: person?.person_descriptor ?? '',
        attributes: attributes ? { ageText: attributes.age_text, ageYears: attributes.age_years, genderText: attributes.gender_text, genderNormalized: attributes.gender_normalized, isMinorAtCase: attributes.is_minor_at_case, isSeniorAtCase: attributes.is_senior_at_case, isPwdAtCase: attributes.is_pwd_at_case } : undefined,
        aliases: Array.isArray(aliases) ? aliases.map((alias: any) => ({ id: makeId('linked-alias'), aliasName: alias.alias_name ?? String(alias) })) : [],
        addresses: storedAddresses.map((entry) => ({ id: makeId('linked-address'), existingAddressId: (entry.addresses as any)?.id ?? null, addressTypeId: toNumber(defaultParticipantAddressTypeId), isPrimary: entry.is_primary === true, remarks: entry.remarks ?? '', line1: entry.addresses?.line1 ?? '', line2: entry.addresses?.line2 ?? '', barangay: entry.addresses?.barangay ?? '', city: entry.addresses?.city ?? '', province: entry.addresses?.province ?? '', region: entry.addresses?.region ?? defaultAddressRegionCode, zipCode: entry.addresses?.zip_code ?? '', country: entry.addresses?.country ?? 'Philippines', suggestionQuery: '', selectedExistingLabel: '' })),
        contactInformations: (participant.contact_informations ?? []).map((contact) => ({ id: makeId('linked-contact'), contactType: contact.contact_type, contactValue: contact.contact_value, label: contact.label, isPrimary: contact.is_primary, remarks: contact.remarks })),
      });
      }));
      setViolations((violationsResult.data ?? []).map((violation, index) => ({
        id: makeId('linked-violation'), existingViolationId: violation.violation_id ?? undefined, violationOrder: violation.violation_order ?? index + 1,
        rawViolationText: violation.raw_violation_text ?? null, searchText: violation.violations?.title ?? violation.raw_violation_text ?? '', selectedExistingTitle: violation.violations?.title ?? null,
      })));
      setPlacesOfCommission((placesResult.data ?? []).map((place) => ({
        id: makeId('linked-place'), existingAddressId: place.address_id ?? null, addressTypeId: place.address_type_id ?? toNumber(defaultParticipantAddressTypeId),
        isPrimary: place.is_primary === true, remarks: place.remarks ?? '', line1: place.addresses?.line1 ?? '', line2: place.addresses?.line2 ?? '', barangay: place.addresses?.barangay ?? '', city: place.addresses?.city ?? '', province: place.addresses?.province ?? '', region: place.addresses?.region ?? defaultAddressRegionCode, zipCode: place.addresses?.zip_code ?? '', country: place.addresses?.country ?? 'Philippines', suggestionQuery: '', selectedExistingLabel: '',
      })));
      setIsDocketInformationSaved(true);
      setActiveTab('review');
    }
    void prefillLinkedDocket();
    return () => { mounted = false; };
  }, [linkedDocketType, linkedPeCaseId, lookups.docketTypes]);

  useEffect(() => {
    if (!isCaseReceivedDescriptionEdited) {
      setCaseReceivedDescription(formatCaseReceivedDefaultDescription(dateReceived));
    }
  }, [dateReceived, isCaseReceivedDescriptionEdited]);


  const [persons, setPersons] = useState<PersonEntry[]>([]);
  const [placesOfCommission, setPlacesOfCommission] = useState<AddressEntry[]>([]);
  const [violations, setViolations] = useState<ViolationEntry[]>([]);
  const [personSuggestions, setPersonSuggestions] = useState<Record<string, PersonDetailsSearchRow[]>>({});
  const [organizationSuggestions, setOrganizationSuggestions] = useState<Record<string, OrganizationDetailsSearchRow[]>>({});
  const [addressSuggestions, setAddressSuggestions] = useState<Record<string, TableRow<'addresses'>[]>>({});
  const [violationSuggestions, setViolationSuggestions] = useState<Record<string, TableRow<'violations'>[]>>({});
  const [participantDialog, setParticipantDialog] = useState<ParticipantDialogState>(null);
  const [addOnDialog, setAddOnDialog] = useState<AddOnDialogState>(null);
  const [caseModal, setCaseModal] = useState<CaseModalState>(null);
  const [participantEditDialog, setParticipantEditDialog] = useState<ParticipantEditDialogState>(null);


  useEffect(() => {
    if (!participantDialog && !addOnDialog && !caseModal) return;

    const timer = window.setTimeout(() => {
      const dialog = document.querySelector('[data-slot="dialog-content"]') as HTMLElement | null;
      if (!dialog) return;

      const textField = dialog.querySelector('input:not([disabled]), textarea:not([disabled])') as HTMLElement | null;
      if (textField) {
        textField.focus();
        if (textField instanceof HTMLInputElement) {
          textField.select();
        }
        return;
      }

      const comboBox = dialog.querySelector('[role="combobox"]') as HTMLElement | null;
      if (comboBox) {
        comboBox.focus();
        if (caseModal?.kind !== 'docket' && caseModal?.kind !== 'assignment') {
          comboBox.click();
        }
        return;
      }

      const checkbox = dialog.querySelector('[role="checkbox"]') as HTMLElement | null;
      checkbox?.focus();
    }, 80);

    return () => window.clearTimeout(timer);
  }, [
    participantDialog?.step,
    participantDialog?.entry.participantKind,
    addOnDialog?.step,
    addOnDialog?.kind,
    caseModal?.step,
    caseModal?.kind,
    assignedProsecutorId,
    docketTypeId,
  ]);

  useEffect(() => {
    if (caseModal?.kind !== 'docket' && caseModal?.kind !== 'assignment') return;

    const tick = () => {
      const now = new Date();
      setManilaNow(now);
      const current = getManilaDateTimeInputValues(now);

      if (caseModal?.kind === 'docket' && !isReceivedDateTimeDirty) {
        setDateReceived(current.date);
        setTimeReceived(current.time);
      }

      if (caseModal?.kind === 'assignment' && !isAssignmentDateTimeDirty) {
        setAssignmentDate(current.date);
        setAssignmentTime(current.time);
      }
    };

    tick();
    const intervalId = window.setInterval(tick, 1000);
    return () => window.clearInterval(intervalId);
  }, [caseModal?.kind, isAssignmentDateTimeDirty, isReceivedDateTimeDirty]);

  useEffect(() => {
    try {
      const savedDraft = window.localStorage.getItem(newDocketDraftStorageKey);
      if (savedDraft) {
        const draft = JSON.parse(savedDraft) as Partial<NewDocketDraftState>;
        const fallbackDate = new Date().toISOString().slice(0, 10);

        setActiveTab(draft.activeTab || 'case-info');
        setDocketTypeId(draft.docketTypeId || '');
        setDocketYear(draft.docketYear || String(thisYear));
        setDateReceived(draft.dateReceived || fallbackDate);
        setTimeReceived(draft.timeReceived || '00:00:00');
        setCaseReceivedDescription(draft.caseReceivedDescription || formatCaseReceivedDefaultDescription(draft.dateReceived || fallbackDate));
        setIsCaseReceivedDescriptionEdited(Boolean(draft.isCaseReceivedDescriptionEdited));
        setInitialStatusId(draft.initialStatusId || '');
        setCaseClassificationId(draft.caseClassificationId || '');
        setCaseAlsoRaffled(Boolean(draft.caseAlsoRaffled));
        setAssignedProsecutorId(draft.assignedProsecutorId || '');
        setAssignmentRemarks(draft.assignmentRemarks || '');
        setAssignmentDate(draft.assignmentDate || fallbackDate);
        setAssignmentTime(draft.assignmentTime || draft.timeReceived || '00:00:00');
        setIsDocketInformationSaved(Boolean(draft.isDocketInformationSaved));
        setRegionCode(draft.regionCode || defaultRegionCode);
        setSummaryText(draft.summaryText || '');
        setRemarks(draft.remarks || '');
        setNotes(draft.notes || '');
        setIsSummaryProcedure(Boolean(draft.isSummaryProcedure));
        setPersons(Array.isArray(draft.persons) ? draft.persons : []);
        setPlacesOfCommission(Array.isArray(draft.placesOfCommission) ? draft.placesOfCommission : []);
        setViolations(Array.isArray(draft.violations) ? draft.violations : []);
      }
    } catch (error) {
      console.error('Unable to restore new docket draft', error);
    } finally {
      setIsDraftHydrated(true);
    }
  }, []);

  useEffect(() => {
    if (!isDraftHydrated) return;

    const draft: NewDocketDraftState = {
      activeTab,
      docketTypeId,
      docketYear,
      dateReceived,
      timeReceived,
      caseReceivedDescription,
      isCaseReceivedDescriptionEdited,
      initialStatusId,
      caseClassificationId,
      caseAlsoRaffled,
      assignedProsecutorId,
      assignmentRemarks,
      assignmentDate,
      assignmentTime,
      isDocketInformationSaved,
      regionCode,
      summaryText,
      remarks,
      notes,
      isSummaryProcedure,
      persons,
      placesOfCommission,
      violations,
    };

    try {
      window.localStorage.setItem(newDocketDraftStorageKey, JSON.stringify(draft));
    } catch (error) {
      console.error('Unable to save new docket draft', error);
    }
  }, [activeTab, docketTypeId, docketYear, dateReceived, caseReceivedDescription, isCaseReceivedDescriptionEdited, initialStatusId, caseClassificationId, caseAlsoRaffled, assignedProsecutorId, assignmentRemarks, assignmentDate, assignmentTime, isDocketInformationSaved, regionCode, summaryText, remarks, notes, isSummaryProcedure, persons, placesOfCommission, violations, isDraftHydrated]);

  useEffect(() => {
    let isMounted = true;

    async function loadLookups() {
      setIsLoadingLookups(true);
      const [docketTypes, participantRoles, addressTypes, violationsResult, statuses, caseClassifications, prosecutors, userResult] = await Promise.all([
        getDocketTypes(),
        getParticipantRoles(),
        getAddressTypes(),
        getViolations(500),
        getCaseStatuses(),
        getCaseClassifications(),
        getProsecutors(250),
        getCurrentDatabaseUser(),
      ]);

      if (!isMounted) {
        return;
      }

      const firstError = [docketTypes, participantRoles, addressTypes, violationsResult, statuses, caseClassifications, prosecutors, userResult].find(
        (result) => result.error,
      )?.error;

      if (firstError) {
        setMessage({ type: 'error', text: firstError.message });
      }

      const nextLookups = {
        docketTypes: docketTypes.data ?? [],
        participantRoles: participantRoles.data ?? [],
        addressTypes: addressTypes.data ?? [],
        violations: violationsResult.data ?? [],
        statuses: statuses.data ?? [],
        caseClassifications: caseClassifications.data ?? [],
        prosecutors: prosecutors.data ?? [],
      };

      setLookups(nextLookups);
      setCurrentUser(userResult.data ?? null);
      setInitialStatusId((current) => current || getReceivedStatusId(nextLookups.statuses));
      setIsLoadingLookups(false);
    }

    loadLookups();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    let isMounted = true;
    const safeDocketTypeId = toNumber(docketTypeId);
    const safeDocketYear = toNumber(docketYear);

    if (!safeDocketTypeId || !safeDocketYear) {
      setNextDocketNumber(null);
      return;
    }

    async function loadNextDocketNumber() {
      setIsLoadingNextDocket(true);
      const result = await getNextDocketNumber(safeDocketTypeId, safeDocketYear);

      if (!isMounted) {
        return;
      }

      if (result.error) {
        setMessage({ type: 'error', text: result.error.message });
        setNextDocketNumber(null);
      } else {
        setNextDocketNumber(result.data);
      }

      setIsLoadingNextDocket(false);
    }

    loadNextDocketNumber();

    return () => {
      isMounted = false;
    };
  }, [docketTypeId, docketYear]);

  const defaultRoleId = useMemo(() => getFirstId(lookups.participantRoles), [lookups.participantRoles]);
  const complainantRoleId = useMemo(() => getRoleIdByLabel(lookups.participantRoles, 'Complainant', defaultRoleId), [defaultRoleId, lookups.participantRoles]);
  const respondentRoleId = useMemo(() => getRoleIdByLabel(lookups.participantRoles, 'Respondent', defaultRoleId), [defaultRoleId, lookups.participantRoles]);
  const defaultAddressTypeId = useMemo(() => getFirstId(lookups.addressTypes), [lookups.addressTypes]);
  const defaultCaseAddressTypeId = useMemo(
    () => getAddressTypeIdByKeywords(lookups.addressTypes, ['commission', 'incident', 'offense', 'offence']),
    [lookups.addressTypes],
  );
  const defaultPersonAddressTypeId = useMemo(
    () => getAddressTypeIdByKeywords(lookups.addressTypes, ['residence', 'residential', 'home']),
    [lookups.addressTypes],
  );
  const selectedDocketType = useMemo(
    () => lookups.docketTypes.find((type) => type.id.toString() === docketTypeId),
    [docketTypeId, lookups.docketTypes],
  );
  const selectedProsecutor = useMemo(
    () => lookups.prosecutors.find((prosecutor) => prosecutor.id.toString() === assignedProsecutorId),
    [assignedProsecutorId, lookups.prosecutors],
  );
  const filteredCaseClassifications = useMemo(() => {
    const query = caseClassificationSearch.trim().toLowerCase();
    if (!query) return lookups.caseClassifications;
    return lookups.caseClassifications.filter((classification) => [classification.display_label].filter(Boolean).join(' ').toLowerCase().includes(query));
  }, [caseClassificationSearch, lookups.caseClassifications]);
  const filteredProsecutors = useMemo(() => {
    const query = prosecutorSearch.trim().toLowerCase();
    if (!query) return lookups.prosecutors;
    return lookups.prosecutors.filter((prosecutor) => [prosecutor.short_name, prosecutor.full_name].filter(Boolean).join(' ').toLowerCase().includes(query));
  }, [lookups.prosecutors, prosecutorSearch]);
  const docketMonthCode = getDocketMonthCode(dateReceived);
  const generatedDocketNumber = formatDocketNumber(selectedDocketType?.prefix, docketYear, nextDocketNumber, docketMonthCode === '—' ? null : docketMonthCode, regionCode);
  const reviewDocketStamp = useMemo(() => {
    const label = [selectedDocketType?.prefix, selectedDocketType?.name].filter(Boolean).join(' ').toLowerCase();
    if (label.includes('inquest') || label.includes('inq')) return { text: 'INQUEST', className: 'border-red-600 text-red-600' };
    if (label.includes('investigation') || label.includes('inv')) return { text: 'INVESTIGATION', className: 'border-blue-600 text-blue-600' };
    return { text: selectedDocketType?.prefix || 'DOCKET', className: 'border-foreground text-foreground' };
  }, [selectedDocketType]);

  const makeEmptyParticipant = (role: ParticipantColumnRole): PersonEntry => ({
    id: makeId(role.toLowerCase()),
    firstName: '',
    middleName: '',
    lastName: '',
    suffix: '',
    gender: 'Unspecified',
    age: '',
    birthDate: '',
    roleId: toNumber(role === 'Complainant' ? complainantRoleId : respondentRoleId),
    participantOrder: persons.length + 1,
    remarks: '',
    sourceDetail: role,
    participantKind: 'PERSON',
    aliases: [],
    addresses: [],
    contactInformations: [],
  });

  const openParticipantDialog = (role: ParticipantColumnRole) => {
    setParticipantDialog({ role, step: 0, entry: makeEmptyParticipant(role) });
  };

  const saveParticipantDialog = () => {
    if (!participantDialog) return;
    setPersons((current) => [...current, { ...participantDialog.entry, participantOrder: current.length + 1 }]);
    setParticipantDialog(null);
  };

  const addAddress = () => {
    setPlacesOfCommission((current) => [
      ...current,
      {
        ...makeEmptyAddress(defaultCaseAddressTypeId, 'place'),
        isPrimary: current.length === 0,
      },
    ]);
  };

  const addParticipantAddress = (personId: string) => {
    setPersons((current) => current.map((person) => (
      person.id === personId
        ? {
            ...person,
            addresses: [
              ...(person.addresses ?? []),
              makeEmptyAddress(
                person.participantKind === 'PERSON'
                  ? defaultPersonAddressTypeId
                  : defaultAddressTypeId,
                'participant-address',
              ),
            ],
          }
        : person
    )));
  };

  const addParticipantContact = (personId: string, contactType: 'PHONE' | 'EMAIL' | 'OTHER' = 'PHONE') => {
    setPersons((current) => current.map((person) => (
      person.id === personId
        ? { ...person, contactInformations: [...(person.contactInformations ?? []), { id: makeId('contact'), contactType, contactValue: '', label: '', isPrimary: (person.contactInformations ?? []).length === 0, remarks: '' }] }
        : person
    )));
  };

  const updateParticipantContact = (personId: string, contactId: string, updates: Partial<ContactInformationEntry>) => {
    setPersons((current) => current.map((person) => (
      person.id === personId
        ? { ...person, contactInformations: (person.contactInformations ?? []).map((contact) => contact.id === contactId ? { ...contact, ...updates } : contact) }
        : person
    )));
  };


  const addViolation = () => {
    setViolations((current) => [
      ...current,
      {
        id: makeId('violation'),
        existingViolationId: null,
        violationOrder: current.length + 1,
        rawViolationText: '',
        searchText: '',
        createNew: false,
      },
    ]);
  };

  const resetForm = () => {
    window.localStorage.removeItem(newDocketDraftStorageKey);
    setMessage(null);
    setParticipantDialog(null);
    setAddOnDialog(null);
    setCaseModal(null);
    setParticipantEditDialog(null);
    setDocketTypeId('');
    setDocketYear(String(thisYear));
    setDateReceived(new Date().toISOString().slice(0, 10));
    setCaseReceivedDescription(formatCaseReceivedDefaultDescription(new Date().toISOString().slice(0, 10)));
    setIsCaseReceivedDescriptionEdited(false);
    setRegionCode(defaultRegionCode);
    setSummaryText('');
    setRemarks('');
    setNotes('');
    setInitialStatusId(getReceivedStatusId(lookups.statuses));
    setCaseClassificationId('');
    setCaseClassificationSearch('');
    setProsecutorSearch('');
    setIsSummaryProcedure(false);
    setCaseAlsoRaffled(false);
    setAssignedProsecutorId('');
    setAssignmentRemarks('');
    setAssignmentDate(new Date().toISOString().slice(0, 10));
    setIsDocketInformationSaved(false);
    setPersons([]);
    setPlacesOfCommission([]);
    setViolations([]);
    setPersonSuggestions({});
    setOrganizationSuggestions({});
    setAddressSuggestions({});
    setViolationSuggestions({});
    setActiveTab('case-info');
  };

  const updatePerson = (id: string, updates: Partial<PersonEntry>) => {
    setPersons((current) => current.map((person) => (person.id === id ? { ...person, ...updates } : person)));
  };

  const switchParticipantKind = (id: string, participantKind: 'PERSON' | 'ORGANIZATION') => {
    setPersons((current) => current.map((person) => (person.id === id ? {
      id: person.id,
      roleId: person.roleId,
      participantOrder: person.participantOrder,
      remarks: person.remarks,
      sourceDetail: person.sourceDetail,
      participantKind,
      gender: participantKind === 'PERSON' ? 'Unspecified' : undefined,
      firstName: '',
      middleName: '',
      lastName: '',
      suffix: '',
      organizationName: '',
      aliases: [],
      existingAliases: [],
      addresses: [],
      organizationDetails: [],
      showOrganizationDetails: false,
    } : person)));
  };

  const clearSelectedPersonData = (person: PersonEntry, updates: Partial<PersonEntry>) => ({
    ...updates,
    existingPersonId: null,
    selectedExistingName: null,
    fullNamePreview: null,
    existingAliases: [],
    aliases: [],
    addresses: [],
  });

  const clearSelectedOrganizationData = (updates: Partial<PersonEntry>) => ({
    ...updates,
    existingOrganizationId: null,
    selectedExistingOrganizationName: null,
    existingAliases: [],
    aliases: [],
  });

  const updateParticipantAddress = (personId: string, addressId: string, updates: Partial<AddressEntry>) => {
    setPersons((current) => current.map((person) => person.id === personId ? { ...person, addresses: (person.addresses ?? []).map((address) => address.id === addressId ? { ...address, ...updates } : address) as AddressEntry[] } : person));
  };

  const updateAddress = (id: string, updates: Partial<AddressEntry>) => {
    setPlacesOfCommission((current) => current.map((address) => (address.id === id ? { ...address, ...updates } : address)));
  };

  const updateViolation = (id: string, updates: Partial<ViolationEntry>) => {
    setViolations((current) =>
      current.map((violation) => (violation.id === id ? { ...violation, ...updates } : violation)),
    );
  };

  const loadPersonSuggestions = useCallback(async (id: string, query: string) => {
    const safeQuery = query.trim();

    if (safeQuery.length < 2) {
      setPersonSuggestions((current) => ({ ...current, [id]: [] }));
      return;
    }

    const result = await searchPersons(safeQuery, 5);

    if (!result.error) {
      setPersonSuggestions((current) => ({ ...current, [id]: result.data }));
    }
  }, []);

  const loadOrganizationSuggestions = useCallback(async (id: string, query: string) => {
    const safeQuery = query.trim();
    if (safeQuery.length < 2) {
      setOrganizationSuggestions((current) => ({ ...current, [id]: [] }));
      return;
    }
    const result = await searchOrganizations(safeQuery, 5);
    if (!result.error) {
      setOrganizationSuggestions((current) => ({ ...current, [id]: result.data }));
    }
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      persons.forEach((person) => {
        if (person.participantKind === 'ORGANIZATION') {
          loadOrganizationSuggestions(person.id, person.organizationName ?? '');
          return;
        }
        loadPersonSuggestions(person.id, [person.firstName, person.middleName, person.lastName].filter(Boolean).join(' '));
      });
    }, 350);

    return () => window.clearTimeout(timer);
  }, [persons, loadOrganizationSuggestions, loadPersonSuggestions]);

  const loadAddressSuggestions = useCallback(async (id: string, query: string) => {
    const safeQuery = query.trim();

    if (safeQuery.length < 2) {
      setAddressSuggestions((current) => ({ ...current, [id]: [] }));
      return;
    }

    const result = await searchAddressSuggestions(safeQuery, 5);

    if (!result.error) {
      setAddressSuggestions((current) => ({ ...current, [id]: result.data }));
    }
  }, []);

  const loadViolationSuggestions = useCallback(async (id: string, query: string) => {
    const result = await searchViolationSuggestions(query, 8);

    if (!result.error) {
      setViolationSuggestions((current) => ({ ...current, [id]: result.data }));
    }
  }, []);

  const applyPersonSuggestion = (entryId: string, person: PersonDetailsSearchRow) => {
    updatePerson(entryId, {
      existingPersonId: person.id,
      selectedExistingName: person.full_name,
      fullNamePreview: person.full_name,
      age: person.age ?? '',
      birthDate: person.birth_date ?? '',
      firstName: person.first_name ?? '',
      gender: person.gender ?? 'Unspecified',
      lastName: person.last_name ?? '',
      middleName: person.middle_name ?? '',
      suffix: person.suffix ?? '',
      noMiddleName: person.middle_name === 'NMN',
      existingAliases: Array.isArray(person.person_aliases) ? person.person_aliases.map((alias: any) => ({ aliasName: alias.alias_name ?? '' })) : [],
      aliases: [],
      addresses: Array.isArray(person.person_addresses) ? person.person_addresses.map((entry: any) => ({
        id: makeId('participant-address'),
        existingAddressId: entry.address_id ?? entry.addresses?.address_id ?? entry.addresses?.id ?? null,
        addressTypeId: entry.address_type_id ?? toNumber(defaultPersonAddressTypeId),
        isPrimary: entry.is_primary === true,
        remarks: entry.remarks ?? '',
        line1: entry.addresses?.line1 ?? '',
        line2: entry.addresses?.line2 ?? '',
        barangay: entry.addresses?.barangay ?? '',
        city: entry.addresses?.city ?? '',
        province: entry.addresses?.province ?? '',
        region: entry.addresses?.region ?? defaultAddressRegionCode,
        zipCode: entry.addresses?.zip_code ?? '',
        country: entry.addresses?.country ?? 'Philippines',
        suggestionQuery: formatAddressLike({ ...(entry.addresses ?? {}), zipCode: entry.addresses?.zip_code }),
        selectedExistingLabel: formatAddressLike({ ...(entry.addresses ?? {}), zipCode: entry.addresses?.zip_code }),
        existingRelation: true,
      })) : [],
    });
    setPersonSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const applyOrganizationSuggestion = (entryId: string, organization: OrganizationDetailsSearchRow) => {
    updatePerson(entryId, {
      existingOrganizationId: organization.id,
      selectedExistingOrganizationName: organization.organization_name,
      organizationName: organization.organization_name,
      contactPerson: '',
      contactNumber: '',
      email: '',
      existingAliases: Array.isArray(organization.aliases) ? organization.aliases.map((alias: any) => ({ aliasName: String(alias) })) : [],
      aliases: [],
    });
    setOrganizationSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const applyAddressSuggestion = (entryId: string, address: TableRow<'addresses'>) => {
    updateAddress(entryId, {
      barangay: address.barangay ?? '',
      city: address.city ?? '',
      country: address.country ?? 'Philippines',
      line1: address.line1 ?? '',
      line2: address.line2 ?? '',
      province: address.province ?? '',
      region: address.region ?? defaultAddressRegionCode,
      suggestionQuery: formatAddress(address),
      zipCode: address.zip_code ?? '',
      existingAddressId: address.id,
      selectedExistingLabel: formatAddress(address),
    });
    setAddressSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const applyParticipantAddressSuggestion = (personId: string, entryId: string, address: TableRow<'addresses'>) => {
    updateParticipantAddress(personId, entryId, {
      barangay: address.barangay ?? '',
      city: address.city ?? '',
      country: address.country ?? 'Philippines',
      line1: address.line1 ?? '',
      line2: address.line2 ?? '',
      province: address.province ?? '',
      region: address.region ?? defaultAddressRegionCode,
      suggestionQuery: formatAddress(address),
      zipCode: address.zip_code ?? '',
      existingAddressId: address.id,
      selectedExistingLabel: formatAddress(address),
      existingRelation: false,
    });
    setAddressSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const applyViolationSuggestion = (entryId: string, violation: TableRow<'violations'>) => {
    updateViolation(entryId, {
      rawViolationText: violation.law_reference ?? violation.short_label ?? violation.title,
      searchText: violation.title,
      existingViolationId: violation.id,
      selectedExistingTitle: violation.title,
      createNew: false,
    });
    setViolationSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const validateForm = () => {
    if (!docketTypeId || !docketYear || !dateReceived) {
      return 'Docket type, year, and date received are required.';
    }

    if (!initialStatusId) {
      return 'The default Received status could not be found.';
    }

    if (persons.length === 0) {
      return 'Add at least one complainant, respondent, or other participant.';
    }

    if (caseAlsoRaffled && !assignedProsecutorId) {
      return 'Select a prosecutor when Case also raffled is checked.';
    }

    if (persons.some((person) => !person.roleId || (person.participantKind === 'ORGANIZATION' ? (!person.existingOrganizationId && !cleanString(person.organizationName)) : (!person.existingPersonId && !buildPersonFullName(person))))) {
      return 'Each participant needs a role and either a selected existing record or enough new participant details.';
    }

    if (violations.length === 0) {
      return 'Add at least one violation.';
    }

    const selectedIds = violations.map((violation) => violation.existingViolationId).filter(Boolean);
    if (new Set(selectedIds).size !== selectedIds.length) {
      return 'The same existing violation cannot be attached more than once.';
    }

    if (violations.some((violation) => !violation.existingViolationId && !cleanString(violation.searchText))) {
      return 'Each violation needs a selected suggestion or a typed violation title.';
    }

    if (placesOfCommission.some((address) => !address.addressTypeId)) {
      return 'Each place of commission must select a database address type.';
    }

    if (persons.some((person) => (person.addresses ?? []).some((address) => !address.addressTypeId))) {
      return 'Each participant address must select a database address type.';
    }

    const invalidOrganizationDetails = persons.find((person) => person.participantKind === 'ORGANIZATION' && buildOrganizationDetailsJson(person.organizationDetails).error);
    if (invalidOrganizationDetails) {
      return buildOrganizationDetailsJson(invalidOrganizationDetails.organizationDetails).error;
    }

    return null;
  };

  const handleSubmit = async () => {
    const validationError = validateForm();

    if (validationError) {
      setMessage({ type: 'error', text: validationError });
      return;
    }

    setIsSubmitting(true);
    setMessage(null);

    const payload: NewDocketEntryInput = {
      linkedPeCaseId: Number.isFinite(linkedPeCaseId) ? linkedPeCaseId : null,
      docketTypeId: toNumber(docketTypeId),
      docketYear: toNumber(docketYear),
      dateReceived,
      timeReceived,
      initialStatusId: toNumber(initialStatusId),
      regionCode: regionCode || defaultRegionCode,
      docketMonthCode: docketMonthCode === '—' ? null : docketMonthCode,
      summaryText: summaryText || null,
      remarks: remarks || null,
      notes: notes || null,
      caseReceivedDescription: caseReceivedDescription.trim() || null,
      isSummaryProcedure,
      caseAlsoRaffled,
      assignmentRemarks: caseAlsoRaffled ? assignmentRemarks.trim() || null : null,
      assignmentDate: caseAlsoRaffled ? assignmentDate : null,
      assignmentTime: caseAlsoRaffled ? assignmentTime : null,
      assignedProsecutorId: caseAlsoRaffled && assignedProsecutorId ? toNumber(assignedProsecutorId) : null,
      caseClassificationId: caseClassificationId ? toNumber(caseClassificationId) : null,
      placesOfCommission: placesOfCommission.map(({ id: _id, suggestionQuery: _sq, selectedExistingLabel: _sel, ...address }, index) => ({ ...address, isPrimary: address.isPrimary ?? index === 0, newAddress: address.existingAddressId ? undefined : { line1: address.line1, line2: address.line2, barangay: address.barangay, city: address.city, province: address.province, region: address.region, zipCode: address.zipCode, country: address.country } })),
      participants: persons.map(({ id: _id, selectedExistingName: _selectedExistingName, selectedExistingOrganizationName: _selectedExistingOrganizationName, fullNamePreview: _fullNamePreview, age, gender, aliases, addresses: participantAddresses, contactInformations, ...person }, index) => ({
        ...person,
        participantOrder: person.participantOrder ?? index + 1,
        aliases: aliases?.map((alias: any) => ({ aliasName: alias.aliasName })),
        contactInformations: contactInformations?.map(({ id: _contactId, ...contact }) => contact).filter((contact) => cleanString(contact.contactValue)),
        addresses: participantAddresses?.map(({ id: _addressId, suggestionQuery: _sq, selectedExistingLabel: _sel, ...address }) => ({ ...address, newAddress: address.existingAddressId ? undefined : { line1: address.line1, line2: address.line2, barangay: address.barangay, city: address.city, province: address.province, region: address.region, zipCode: address.zipCode, country: address.country } })),
        newOrganization: person.participantKind === 'ORGANIZATION' && !person.existingOrganizationId ? { organizationName: person.organizationName, contactPerson: person.contactPerson, contactNumber: person.contactNumber, email: person.email, detailsJsonb: buildOrganizationDetailsJson(person.organizationDetails).value } : undefined,
        newPerson: person.participantKind === 'PERSON' && !person.existingPersonId ? {
          firstName: person.firstName,
          middleName: person.noMiddleName ? 'NMN' : person.middleName,
          lastName: person.lastName,
          suffix: person.suffix,
          noMiddleName: person.noMiddleName,
          gender,
          birthDate: person.birthDate,
          notes: person.notes,
          personDescriptor: person.personDescriptor,
        } : undefined,
        attributes: person.participantKind === 'PERSON' ? {
          ...(person.attributes ?? {}),
          ageText: age ?? person.attributes?.ageText ?? null,
          ageYears: age ? Number.parseInt(age, 10) || null : person.attributes?.ageYears ?? null,
          genderText: gender ?? person.attributes?.genderText ?? null,
          genderNormalized: gender && gender !== 'Unspecified' ? gender.toUpperCase() : person.attributes?.genderNormalized ?? 'UNKNOWN',
        } : undefined,
      })) as NewDocketParticipantInput[],
      addresses: [],
      violations: violations.map(({ id: _id, searchText, selectedExistingTitle: _title, createNew: _createNew, newViolationTitle, referenceCode, shortLabel, description, lawReference, ...violation }, index) => ({
        ...violation,
        violationOrder: violation.violationOrder ?? index + 1,
        newViolation: !violation.existingViolationId ? { title: cleanString(newViolationTitle) || cleanString(searchText) || '', referenceCode, shortLabel, description, lawReference } : undefined,
      })),
    };

    const supabase = await getSupabaseBrowserClient();
    const { data: sessionData } = await supabase.auth.getSession();
    const accessToken = sessionData.session?.access_token;
    const idempotencyStorageKey = `${newDocketDraftStorageKey}:submission-id`;
    const idempotencyKey = window.localStorage.getItem(idempotencyStorageKey) ?? crypto.randomUUID();
    window.localStorage.setItem(idempotencyStorageKey, idempotencyKey);
    let response: Response | null = null;
    try {
      response = accessToken ? await fetch('/api/dockets', {
        method: 'POST',
        headers: { 'content-type': 'application/json', Authorization: `Bearer ${accessToken}` },
        body: JSON.stringify({ payload, idempotencyKey }),
      }) : null;
    } catch {
      setIsSubmitting(false);
      setMessage({ type: 'error', text: 'The server response could not be confirmed. Select Save again to safely retry this same submission.' });
      return;
    }
    const result = response ? await response.json() as {
      data?: { caseId: number; docketDisplayNumber: string; drive: { status: string }; driveProvision?: { stage?: string; operation?: string; code?: string; message?: string } };
      error?: { message?: string };
    } : { error: { message: 'Your session has expired. Please sign in again.' } };
    setIsSubmitting(false);

    if (!response?.ok || !result.data) {
      setMessage({ type: 'error', text: result.error?.message ?? 'Unable to create the docket.' });
      return;
    }

    const created = result.data;
    window.localStorage.removeItem(newDocketDraftStorageKey);
    window.localStorage.removeItem(idempotencyStorageKey);
    const diagnostic = created.driveProvision
      ? ` Stage: ${created.driveProvision.stage ?? 'UNKNOWN'}; operation: ${created.driveProvision.operation ?? 'unknown'}; code: ${created.driveProvision.code ?? 'unknown'}; message: ${created.driveProvision.message ?? 'unknown'}.`
      : '';
    const driveWarning = created.drive.status === 'READY' ? '' : ` The docket was saved, but its Google Drive folder could not be created.${diagnostic} You can safely continue without submitting it again.`;
    setMessage({ type: 'success', text: `Docket ${created.docketDisplayNumber} created as case #${created.caseId}.${driveWarning}`, caseId: created.caseId });
    if (created.drive.status === 'READY') router.push(`/cases/${created.caseId}`);
    else window.setTimeout(() => router.push(`/cases/${created.caseId}`), 3000);
  };


  const updateParticipantDraft = (updates: Partial<PersonEntry>) => {
    setParticipantDialog((current) => current ? { ...current, entry: { ...current.entry, ...updates } } : current);
  };

  const participantSteps = participantWorkflowSteps;
  const isParticipantFinalStep = Boolean(participantDialog && participantDialog.step >= participantSteps.length - 1);
  const participantsByColumn = (role: ParticipantColumnRole) => persons.filter((person) => person.sourceDetail === role || lookups.participantRoles.find((item) => item.id === person.roleId)?.display_label?.toLowerCase().includes(role.toLowerCase()));


  const formatParticipantPreviewName = (person: PersonEntry) => {
    const baseName = person.participantKind === 'ORGANIZATION' ? (cleanString(person.organizationName) || 'Unnamed organization') : buildLegalNamePreview(person);
    const aliases = [...(person.existingAliases ?? []), ...(person.aliases ?? [])]
      .map((alias) => cleanString(alias.aliasName))
      .filter(Boolean)
      .map((alias) => `@${alias}`)
      .join(' ');
    return aliases ? `${baseName} ${aliases}` : baseName;
  };

  const formatParticipantFlags = (person: PersonEntry) => [
    person.attributes?.isMinorAtCase ? 'Minor' : null,
    person.attributes?.isSeniorAtCase ? 'Senior' : null,
    person.attributes?.isPwdAtCase ? 'PWD' : null,
  ].filter(Boolean).join(' | ');

  const updateParticipantAlias = (personId: string, aliasId: string, aliasName: string) => updatePerson(personId, {
    aliases: (persons.find((person) => person.id === personId)?.aliases ?? []).map((alias) => alias.id === aliasId ? { ...alias, id: alias.id ?? makeId('alias'), aliasName } : { ...alias, id: alias.id ?? makeId('alias') }) as AliasEntry[],
  });


  const openAddOnDialog = (personId: string, kind: 'alias' | 'address' | 'contact') => {
    setAddOnDialog({
      personId,
      kind,
      step: 0,
      alias: { id: makeId('alias'), aliasName: '', remarks: '' },
      address: makeEmptyAddress(defaultPersonAddressTypeId, 'participant-address'),
      contact: { id: makeId('contact'), contactType: 'PHONE', contactValue: '', label: '', isPrimary: false, remarks: '' },
    });
  };

  const saveAddOnDialog = () => {
    if (!addOnDialog) return;
    setPersons((current) => current.map((person) => {
      if (person.id !== addOnDialog.personId) return person;
      if (addOnDialog.kind === 'alias') return { ...person, aliases: [...(person.aliases ?? []), addOnDialog.alias] };
      if (addOnDialog.kind === 'address') return { ...person, addresses: [...(person.addresses ?? []), addOnDialog.address] };
      return { ...person, contactInformations: [...(person.contactInformations ?? []), addOnDialog.contact] };
    }));
    setAddOnDialog(null);
  };

  const refreshParticipantRoles = async () => {
    const result = await getParticipantRoles();
    if (!result.error) setLookups((current) => ({ ...current, participantRoles: result.data }));
    return result;
  };

  const refreshAddressTypes = async () => {
    const result = await getAddressTypes();
    if (!result.error) setLookups((current) => ({ ...current, addressTypes: result.data }));
    return result;
  };

  const refreshCaseClassifications = async () => {
    const result = await getCaseClassifications();
    if (!result.error) setLookups((current) => ({ ...current, caseClassifications: result.data }));
    return result;
  };

  const createParticipantRoleOption = async (displayLabel: string) => {
    const result = await addParticipantRole({ displayLabel });
    if (result.error) return { id: 0, error: result.error.message };
    const refreshResult = await refreshParticipantRoles();
    if (refreshResult.error) {
      setLookups((current) => ({ ...current, participantRoles: [...current.participantRoles, { id: result.data, code: displayLabel.toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'ROLE', display_label: displayLabel, is_active: true }] }));
      return { id: result.data, error: refreshResult.error.message };
    }
    return { id: result.data };
  };

  const createAddressTypeOption = async (displayLabel: string) => {
    const result = await addAddressType({ displayLabel });
    if (result.error) return { id: 0, error: result.error.message };
    const refreshResult = await refreshAddressTypes();
    if (refreshResult.error) {
      setLookups((current) => ({ ...current, addressTypes: [...current.addressTypes, { id: result.data, code: displayLabel.toUpperCase().replace(/[^A-Z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'ADDRESS_TYPE', display_label: displayLabel, is_active: true }] }));
      return { id: result.data, error: refreshResult.error.message };
    }
    return { id: result.data };
  };

  const createCaseClassificationOption = async (displayLabel: string) => {
    const result = await addCaseClassification({ displayLabel });
    if (result.error) return { id: 0, error: result.error.message };
    const refreshResult = await refreshCaseClassifications();
    if (refreshResult.error) {
      setLookups((current) => ({ ...current, caseClassifications: [...current.caseClassifications, { id: result.data, display_label: displayLabel, description: null, is_active: true, created_at: new Date().toISOString() }] }));
      return { id: result.data, error: refreshResult.error.message };
    }
    return { id: result.data };
  };

  const renderParticipantDraftField = () => {
    if (!participantDialog) return null;
    const entry = participantDialog.entry;
    const stepName = participantSteps[participantDialog.step];
    if (stepName === 'Participant Type') return <Select value={entry.participantKind ?? 'PERSON'} onValueChange={(value) => updateParticipantDraft({ participantKind: value as 'PERSON' | 'ORGANIZATION' })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PERSON">Person</SelectItem><SelectItem value="ORGANIZATION">Organization</SelectItem></SelectContent></Select>;
    const field = (label: string, control: React.ReactNode, className = '') => <div className={className}><Label>{label}</Label>{control}</div>;
    const role = field('Role', <CreatableLookupSelect value={entry.roleId ? entry.roleId.toString() : ''} onValueChange={(value) => updateParticipantDraft({ roleId: toNumber(value) })} options={lookups.participantRoles} placeholder="Select role" addLabel="Add Role" dialogTitle="Add Participant Role" labelField="Role Label" onCreate={createParticipantRoleOption} />);
    const reason = field('Reason', <><span className="ml-2 text-sm text-muted-foreground">(optional)</span><Textarea value={entry.correctionReason ?? ''} onChange={(event) => updateParticipantDraft({ correctionReason: event.target.value })} /></>, 'sm:col-span-2');

    if (entry.participantKind === 'ORGANIZATION') return <div className="space-y-4 rounded-lg border p-4"><h3 className="font-semibold">Participant name and details</h3><div className="grid gap-3 sm:grid-cols-2">
      {field('Organization Name', <Input value={entry.organizationName ?? ''} onChange={(event) => updateParticipantDraft({ organizationName: event.target.value })} />)}
      {field('Contact Person', <Input value={entry.contactPerson ?? ''} onChange={(event) => updateParticipantDraft({ contactPerson: event.target.value })} />)}
      {field('Contact Number', <Input value={entry.contactNumber ?? ''} onChange={(event) => updateParticipantDraft({ contactNumber: event.target.value })} />)}
      {field('Email', <Input type="email" value={entry.email ?? ''} onChange={(event) => updateParticipantDraft({ email: event.target.value })} />)}
      {field('Remarks', <Input value={entry.remarks ?? ''} onChange={(event) => updateParticipantDraft({ remarks: event.target.value })} />, 'sm:col-span-2')}
      <div>{role}</div>{reason}
    </div></div>;

    return <div className="space-y-4 rounded-lg border p-4"><h3 className="font-semibold">Participant name and details</h3><div className="grid gap-3 sm:grid-cols-2">
      {field('First Name', <Input value={entry.firstName ?? ''} onChange={(event) => updateParticipantDraft({ firstName: event.target.value })} />)}
      {field('Middle Name', <div className="relative"><Input className="pr-24" value={entry.noMiddleName ? 'NMN' : (entry.middleName ?? '')} disabled={entry.noMiddleName === true} onChange={(event) => updateParticipantDraft({ middleName: event.target.value })} /><label className="absolute inset-y-0 right-3 flex items-center gap-2 text-sm italic text-muted-foreground"><Checkbox checked={entry.noMiddleName === true} onCheckedChange={(checked) => updateParticipantDraft({ noMiddleName: checked === true, middleName: checked === true ? 'NMN' : '' })} /><span>NMN</span></label></div>)}
      {field('Last Name', <Input value={entry.lastName ?? ''} onChange={(event) => updateParticipantDraft({ lastName: event.target.value })} />)}
      {field('Suffix', <Input value={entry.suffix ?? ''} onChange={(event) => updateParticipantDraft({ suffix: event.target.value })} />)}
      {field('Gender', <Select value={entry.gender ?? ''} onValueChange={(gender) => updateParticipantDraft({ gender })}><SelectTrigger><SelectValue placeholder="Select gender" /></SelectTrigger><SelectContent>{genderOptions.map((gender) => <SelectItem key={gender} value={gender}>{gender}</SelectItem>)}</SelectContent></Select>)}
      {field('Birthdate', <Input type="date" value={entry.birthDate ?? ''} onChange={(event) => updateParticipantDraft({ birthDate: event.target.value })} />)}
      {field('Age', <Input value={entry.age ?? ''} onChange={(event) => updateParticipantDraft({ age: event.target.value })} />)}
      {field('Remarks', <Input value={entry.remarks ?? ''} onChange={(event) => updateParticipantDraft({ remarks: event.target.value })} />)}
      <div>{role}</div>
      {field('Case Flags', <div className="flex min-h-9 flex-wrap items-center gap-4"><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.attributes?.isMinorAtCase === true} onCheckedChange={(checked) => updateParticipantDraft({ attributes: { ...(entry.attributes ?? {}), isMinorAtCase: checked === true, minorText: checked === true ? 'YES' : null } })} /> Minor</label><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.attributes?.isSeniorAtCase === true} onCheckedChange={(checked) => updateParticipantDraft({ attributes: { ...(entry.attributes ?? {}), isSeniorAtCase: checked === true, seniorText: checked === true ? 'YES' : null } })} /> Senior</label><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.attributes?.isPwdAtCase === true} onCheckedChange={(checked) => updateParticipantDraft({ attributes: { ...(entry.attributes ?? {}), isPwdAtCase: checked === true, pwdText: checked === true ? 'YES' : null } })} /> PWD</label></div>)}
      {reason}
    </div></div>;
  };

  const renderAddOnField = () => {
    if (!addOnDialog) return null;
    const steps = addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps;
    const stepName = steps[addOnDialog.step];
    const updateAddOn = (updates: Partial<AddOnDialogState>) => setAddOnDialog((current) => current ? { ...current, ...updates } as AddOnDialogState : current);
    if (addOnDialog.kind === 'alias') return stepName === 'Alias Name' ? <Input value={addOnDialog.alias.aliasName} onChange={(event) => updateAddOn({ alias: { ...addOnDialog.alias, aliasName: event.target.value } })} placeholder="Alias or skip" /> : <Input value={addOnDialog.alias.remarks ?? ''} onChange={(event) => updateAddOn({ alias: { ...addOnDialog.alias, remarks: event.target.value } })} placeholder="Remarks or skip" />;
    if (addOnDialog.kind === 'contact') {
      if (stepName === 'Contact Type') return <Select value={addOnDialog.contact.contactType} onValueChange={(value) => updateAddOn({ contact: { ...addOnDialog.contact, contactType: value as 'PHONE' | 'EMAIL' | 'OTHER' } })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PHONE">Phone</SelectItem><SelectItem value="EMAIL">Email</SelectItem><SelectItem value="OTHER">Other</SelectItem></SelectContent></Select>;
      if (stepName === 'Primary') return <label className="flex items-center gap-2 text-sm"><Checkbox checked={addOnDialog.contact.isPrimary === true} onCheckedChange={(checked) => updateAddOn({ contact: { ...addOnDialog.contact, isPrimary: checked === true } })} /> Primary contact</label>;
      const key = stepName === 'Contact Value' ? 'contactValue' : 'remarks';
      return <Input value={(addOnDialog.contact as any)[key] ?? ''} onChange={(event) => updateAddOn({ contact: { ...addOnDialog.contact, [key]: event.target.value } })} placeholder={`${stepName} or skip`} />;
    }
    if (stepName === 'Address Type') return <CreatableLookupSelect value={addOnDialog.address.addressTypeId ? addOnDialog.address.addressTypeId.toString() : ''} onValueChange={(value) => updateAddOn({ address: { ...addOnDialog.address, addressTypeId: toNumber(value) } })} options={lookups.addressTypes} placeholder="Select type" addLabel="Add Address Type" dialogTitle="Add Address Type" labelField="Address Type Label" onCreate={createAddressTypeOption} />;
    return <div className="grid grid-cols-1 gap-3 md:grid-cols-2"><div><Label className="text-xs">Line 1</Label><Input value={addOnDialog.address.line1 ?? ''} onChange={(event) => { const line1 = event.target.value; updateAddOn({ address: { ...addOnDialog.address, line1, suggestionQuery: [line1, addOnDialog.address.line2].filter(Boolean).join(' '), existingAddressId: null } }); loadAddressSuggestions(addOnDialog.address.id, [line1, addOnDialog.address.line2].filter(Boolean).join(' ')); }} className="mt-1" /></div><div><Label className="text-xs">Line 2</Label><Input value={addOnDialog.address.line2 ?? ''} onChange={(event) => { const line2 = event.target.value; updateAddOn({ address: { ...addOnDialog.address, line2, suggestionQuery: [addOnDialog.address.line1, line2].filter(Boolean).join(' '), existingAddressId: null } }); loadAddressSuggestions(addOnDialog.address.id, [addOnDialog.address.line1, line2].filter(Boolean).join(' ')); }} className="mt-1" /></div>{addressSuggestions[addOnDialog.address.id]?.length ? <div className="rounded-md border bg-background p-2 text-sm shadow-sm md:col-span-2"><p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing address suggestions</p><div className="flex flex-wrap gap-2">{addressSuggestions[addOnDialog.address.id].map((suggestion) => <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => { const formatted = formatAddress(suggestion); updateAddOn({ address: { ...addOnDialog.address, barangay: suggestion.barangay ?? '', city: suggestion.city ?? '', country: suggestion.country ?? 'Philippines', line1: suggestion.line1 ?? '', line2: suggestion.line2 ?? '', province: suggestion.province ?? '', region: suggestion.region ?? defaultAddressRegionCode, suggestionQuery: formatted, zipCode: suggestion.zip_code ?? '', existingAddressId: suggestion.id, selectedExistingLabel: formatted } }); setAddressSuggestions((current) => ({ ...current, [addOnDialog.address.id]: [] })); }}>{formatAddress(suggestion) || `Address #${suggestion.id}`}</Button>)}</div></div> : null}<div><Label className="text-xs">Barangay</Label><Input value={addOnDialog.address.barangay ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, barangay: event.target.value, existingAddressId: null } })} className="mt-1" /></div><div><Label className="text-xs">City</Label><Input value={addOnDialog.address.city ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, city: event.target.value, existingAddressId: null } })} className="mt-1" /></div><div><Label className="text-xs">Province</Label><Input value={addOnDialog.address.province ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, province: event.target.value, existingAddressId: null } })} className="mt-1" /></div><div><Label className="text-xs">Region</Label><Input value={addOnDialog.address.region ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, region: event.target.value, existingAddressId: null } })} className="mt-1" /></div><div><Label className="text-xs">ZIP Code</Label><Input value={addOnDialog.address.zipCode ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, zipCode: event.target.value, existingAddressId: null } })} className="mt-1" /></div><div><Label className="text-xs">Country</Label><Input value={addOnDialog.address.country ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, country: event.target.value, existingAddressId: null } })} className="mt-1" /></div><label className="flex items-center gap-2 text-xs"><Checkbox checked={addOnDialog.address.isPrimary === true} onCheckedChange={(checked) => updateAddOn({ address: { ...addOnDialog.address, isPrimary: checked === true } })} /> Primary</label><div><Label className="text-xs">Remarks</Label><Input value={addOnDialog.address.remarks ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, remarks: event.target.value } })} className="mt-1" /></div></div>;
  };



  const renderParticipantEditDialog = () => {
    if (!participantEditDialog) return null;
    const person = persons.find((item) => item.id === participantEditDialog.personId);
    if (!person) return null;
    if (participantEditDialog.mode === 'attributes') {
      return <div className="space-y-4"><div className="grid grid-cols-1 gap-3 md:grid-cols-2">{person.participantKind === 'ORGANIZATION' ? <><div className="md:col-span-2"><Label className="text-xs">Organization Name</Label><Input value={person.organizationName ?? ''} onChange={(event) => updatePerson(person.id, { organizationName: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Contact Person</Label><Input value={person.contactPerson ?? ''} onChange={(event) => updatePerson(person.id, { contactPerson: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Contact Number</Label><Input value={person.contactNumber ?? ''} onChange={(event) => updatePerson(person.id, { contactNumber: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Email</Label><Input value={person.email ?? ''} onChange={(event) => updatePerson(person.id, { email: event.target.value })} className="mt-1" /></div></> : <><div><Label className="text-xs">First Name</Label><Input value={person.firstName ?? ''} onChange={(event) => updatePerson(person.id, { firstName: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Middle Name</Label><Input value={person.middleName ?? ''} onChange={(event) => updatePerson(person.id, { middleName: event.target.value, noMiddleName: false })} className="mt-1" /></div><div><Label className="text-xs">Surname</Label><Input value={person.lastName ?? ''} onChange={(event) => updatePerson(person.id, { lastName: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Suffix</Label><Input value={person.suffix ?? ''} onChange={(event) => updatePerson(person.id, { suffix: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Gender</Label><Select value={person.gender ?? 'Unspecified'} onValueChange={(value) => updatePerson(person.id, { gender: value })}><SelectTrigger className="mt-1"><SelectValue /></SelectTrigger><SelectContent>{genderOptions.map((gender) => <SelectItem key={gender} value={gender}>{gender}</SelectItem>)}</SelectContent></Select></div><div><Label className="text-xs">Age</Label><Input value={person.age ?? ''} onChange={(event) => updatePerson(person.id, { age: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Birthdate</Label><Input type="date" value={person.birthDate ?? ''} onChange={(event) => updatePerson(person.id, { birthDate: event.target.value })} className="mt-1" /></div><div className="flex items-end gap-3"><label className="flex items-center gap-2 text-xs"><Checkbox checked={person.attributes?.isMinorAtCase === true} onCheckedChange={(checked) => updatePerson(person.id, { attributes: { ...(person.attributes ?? {}), isMinorAtCase: checked === true } })} /> Minor</label><label className="flex items-center gap-2 text-xs"><Checkbox checked={person.attributes?.isSeniorAtCase === true} onCheckedChange={(checked) => updatePerson(person.id, { attributes: { ...(person.attributes ?? {}), isSeniorAtCase: checked === true } })} /> Senior</label><label className="flex items-center gap-2 text-xs"><Checkbox checked={person.attributes?.isPwdAtCase === true} onCheckedChange={(checked) => updatePerson(person.id, { attributes: { ...(person.attributes ?? {}), isPwdAtCase: checked === true } })} /> PWD</label></div></>}</div>{person.participantKind === 'PERSON' ? <div className="space-y-2"><Label className="text-xs">Aliases</Label>{(person.aliases ?? []).length === 0 ? <p className="text-xs text-muted-foreground">No editable aliases added.</p> : null}{(person.aliases ?? []).map((alias) => <div key={alias.id} className="flex items-center gap-2"><span className="text-sm text-muted-foreground">@</span><Input value={alias.aliasName ?? ''} onChange={(event) => updateParticipantAlias(person.id, alias.id ?? '', event.target.value)} /><Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => updatePerson(person.id, { aliases: (person.aliases ?? []).filter((item) => item.id !== alias.id) as AliasEntry[] })}><X className="h-4 w-4" /></Button></div>)}</div> : null}</div>;
    }
    if (participantEditDialog.mode === 'addresses') {
      return <div className="space-y-3">{(person.addresses ?? []).length === 0 ? <p className="text-sm text-muted-foreground">No addresses added yet.</p> : null}{(person.addresses ?? []).map((address) => <div key={address.id} className="grid grid-cols-1 gap-2 rounded-md border p-3 md:grid-cols-2"><Input value={address.line1 ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { line1: event.target.value })} placeholder="Line 1" /><Input value={address.line2 ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { line2: event.target.value })} placeholder="Line 2" /><Input value={address.barangay ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { barangay: event.target.value })} placeholder="Barangay" /><Input value={address.city ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { city: event.target.value })} placeholder="City" /><Input value={address.province ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { province: event.target.value })} placeholder="Province" /><Input value={address.region ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { region: event.target.value })} placeholder="Region" /><Input value={address.zipCode ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { zipCode: event.target.value })} placeholder="ZIP Code" /><Input value={address.country ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { country: event.target.value })} placeholder="Country" /><Input value={address.remarks ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { remarks: event.target.value })} placeholder="Remarks" /><Button type="button" variant="ghost" size="sm" className="text-destructive md:col-span-2" onClick={() => updatePerson(person.id, { addresses: (person.addresses ?? []).filter((item) => item.id !== address.id) as AddressEntry[] })}>Delete Address</Button></div>)}</div>;
    }
    return <div className="space-y-3">{(person.contactInformations ?? []).length === 0 ? <p className="text-sm text-muted-foreground">No contact info added yet.</p> : null}{(person.contactInformations ?? []).map((contact) => <div key={contact.id} className="grid grid-cols-1 gap-2 rounded-md border p-3 md:grid-cols-[9rem_1fr]"><Select value={contact.contactType} onValueChange={(value) => updateParticipantContact(person.id, contact.id, { contactType: value as 'PHONE' | 'EMAIL' | 'OTHER' })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PHONE">Phone</SelectItem><SelectItem value="EMAIL">Email</SelectItem><SelectItem value="OTHER">Other</SelectItem></SelectContent></Select><Input value={contact.contactValue ?? ''} onChange={(event) => updateParticipantContact(person.id, contact.id, { contactValue: event.target.value })} placeholder="Contact value" /><Input value={contact.remarks ?? ''} onChange={(event) => updateParticipantContact(person.id, contact.id, { remarks: event.target.value })} placeholder="Remarks" /><Button type="button" variant="ghost" size="sm" className="text-destructive md:col-span-2" onClick={() => updatePerson(person.id, { contactInformations: (person.contactInformations ?? []).filter((item) => item.id !== contact.id) })}>Delete Contact Info</Button></div>)}</div>;
  };

  const openCaseModal = (kind: NonNullable<CaseModalState>['kind'], id?: string) => {
    if (kind === 'docket') setIsReceivedDateTimeDirty(false);
    if (kind === 'assignment') setIsAssignmentDateTimeDirty(false);
    if (kind === 'violation') {
      const existing = id ? violations.find((item) => item.id === id) : null;
      setCaseModal({ kind, step: 0, id, violation: existing ? { ...existing } : { id: makeId('violation'), existingViolationId: null, violationOrder: violations.length + 1, rawViolationText: '', searchText: '', createNew: true, newViolationTitle: '' } });
      return;
    }
    if (kind === 'place') {
      const existing = id ? placesOfCommission.find((item) => item.id === id) : null;
      setCaseModal({ kind, step: 0, id, place: existing ? { ...existing } : { ...makeEmptyAddress(defaultCaseAddressTypeId, 'place'), isPrimary: placesOfCommission.length === 0 } });
      return;
    }
    setCaseModal({ kind, step: 0 });
  };

  const saveCaseModal = () => {
    if (!caseModal) return;
    if (caseModal.kind === 'docket') {
      setIsDocketInformationSaved(Boolean(docketTypeId));
    }
    if (caseModal.kind === 'assignment') {
      setCaseAlsoRaffled(Boolean(assignedProsecutorId));
    }
    if (caseModal.kind === 'violation' && caseModal.violation) {
      setViolations((current) => caseModal.id ? current.map((item) => item.id === caseModal.id ? caseModal.violation as ViolationEntry : item) : [...current, { ...caseModal.violation as ViolationEntry, violationOrder: current.length + 1 }]);
    }
    if (caseModal.kind === 'place' && caseModal.place) {
      setPlacesOfCommission((current) => caseModal.id ? current.map((item) => item.id === caseModal.id ? caseModal.place as AddressEntry : item) : [...current, caseModal.place as AddressEntry]);
    }
    setCaseModal(null);
  };

  const getCaseModalSteps = () => {
    if (!caseModal) return docketWorkflowSteps;
    if (caseModal.kind === 'docket') return docketWorkflowSteps;
    if (caseModal.kind === 'violation') return violationWorkflowSteps;
    if (caseModal.kind === 'procedure') return procedureWorkflowSteps;
    if (caseModal.kind === 'place') return placeWorkflowSteps;
    return assignmentWorkflowSteps;
  };

  const caseModalSteps = getCaseModalSteps();
  const isCaseModalFinalStep = Boolean(caseModal && caseModal.step >= caseModalSteps.length - 1);
  const selectedCaseClassification = lookups.caseClassifications.find((classification) => classification.id.toString() === caseClassificationId);

  const updateViolationDraft = (updates: Partial<ViolationEntry>) => setCaseModal((current) => current?.kind === 'violation' && current.violation ? { ...current, violation: { ...current.violation, ...updates } } : current);
  const updatePlaceDraft = (updates: Partial<AddressEntry>) => setCaseModal((current) => current?.kind === 'place' && current.place ? { ...current, place: { ...current.place, ...updates } } : current);

  const applyViolationDraftSuggestion = (violation: TableRow<'violations'>) => {
    if (!caseModal?.violation) return;
    updateViolationDraft({ existingViolationId: violation.id, selectedExistingTitle: violation.title, searchText: violation.title, createNew: false, newViolationTitle: null, referenceCode: violation.reference_code ?? null, shortLabel: violation.short_label ?? null });
    setViolationSuggestions((current) => ({ ...current, [caseModal.violation?.id ?? '']: [] }));
  };

  const applyPlaceDraftSuggestion = (address: TableRow<'addresses'>) => {
    if (!caseModal?.place) return;
    updatePlaceDraft({ barangay: address.barangay ?? '', city: address.city ?? '', country: address.country ?? 'Philippines', line1: address.line1 ?? '', line2: address.line2 ?? '', province: address.province ?? '', region: address.region ?? defaultAddressRegionCode, suggestionQuery: formatAddress(address), zipCode: address.zip_code ?? '', existingAddressId: address.id, selectedExistingLabel: formatAddress(address) });
    setAddressSuggestions((current) => ({ ...current, [caseModal.place?.id ?? '']: [] }));
  };

  const renderCaseModalField = () => {
    if (!caseModal) return null;
    const stepName = caseModalSteps[caseModal.step];
    if (caseModal.kind === 'docket') {
      return <div className="space-y-4"><Select value={docketTypeId} onValueChange={setDocketTypeId} disabled={isLoadingLookups}><SelectTrigger><SelectValue placeholder="Select docket type" /></SelectTrigger><SelectContent>{lookups.docketTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.prefix} — {type.name}</SelectItem>)}</SelectContent></Select>{docketTypeId ? <div className="grid grid-cols-1 gap-3 md:grid-cols-2"><div><Label className="text-xs">Date Received</Label><Input type="date" value={dateReceived} onChange={(event) => { setIsReceivedDateTimeDirty(true); setDateReceived(event.target.value); }} className="mt-1" /></div><div><Label className="text-xs">Time Received</Label><Input type="time" step="1" value={timeReceived} onChange={(event) => { setIsReceivedDateTimeDirty(true); setTimeReceived(event.target.value); }} className="mt-1" /></div><div><Label className="text-xs">Docket Year</Label><Input type="number" value={docketYear} onChange={(event) => setDocketYear(event.target.value)} className="mt-1" /></div></div> : null}</div>;
    }
    if (caseModal.kind === 'procedure') {
      return <div className="space-y-4"><label className="flex items-center gap-2 text-sm"><Checkbox checked={isSummaryProcedure} onCheckedChange={(checked) => setIsSummaryProcedure(checked === true)} /> Falls under Summary Procedure</label><div><Label className="text-xs">Case Classification</Label><CreatableLookupSelect value={caseClassificationId || 'none'} onValueChange={(value) => setCaseClassificationId(value === 'none' ? '' : value)} disabled={isLoadingLookups} className="mt-1" options={filteredCaseClassifications} placeholder="Select classification" addLabel="Add Case Classification" dialogTitle="Add Case Classification" labelField="Classification Label" noneOption={{ value: 'none', label: 'No classification' }} searchValue={caseClassificationSearch} onSearchChange={setCaseClassificationSearch} searchPlaceholder="Search classifications" onCreate={createCaseClassificationOption} /></div>{isSummaryProcedure ? <div><Label className="text-xs">Remarks</Label><Textarea value={remarks} onChange={(event) => setRemarks(event.target.value)} placeholder="Optional summary procedure remarks" className="mt-1" /></div> : null}</div>;
    }
    if (caseModal.kind === 'assignment') {
      return <div className="grid grid-cols-1 gap-3 md:grid-cols-2"><div className="space-y-3"><div><Label className="text-xs">Prosecutor</Label><Select value={assignedProsecutorId || 'none'} onValueChange={(value) => { const nextValue = value === 'none' ? '' : value; setAssignedProsecutorId(nextValue); setCaseAlsoRaffled(Boolean(nextValue)); }} disabled={isLoadingLookups}><SelectTrigger className="mt-1"><SelectValue placeholder="Select prosecutor" /></SelectTrigger><SelectContent><div className="p-2"><Input value={prosecutorSearch} onChange={(event) => setProsecutorSearch(event.target.value)} onKeyDown={(event) => event.stopPropagation()} placeholder="Search prosecutors" /></div><SelectItem value="none">No prosecutor selected</SelectItem>{filteredProsecutors.map((prosecutor) => <SelectItem key={prosecutor.id} value={prosecutor.id.toString()}>{prosecutor.short_name ?? prosecutor.full_name}</SelectItem>)}</SelectContent></Select></div>{assignedProsecutorId ? <><div><Label className="text-xs">Assignment date</Label><Input type="date" value={assignmentDate} onChange={(event) => { setIsAssignmentDateTimeDirty(true); setAssignmentDate(event.target.value); }} className="mt-1" /></div><div><Label className="text-xs">Assignment time</Label><Input type="time" step="1" value={assignmentTime} onChange={(event) => { setIsAssignmentDateTimeDirty(true); setAssignmentTime(event.target.value); }} className="mt-1" /></div></> : null}</div>{assignedProsecutorId ? <div className="flex flex-col"><Label className="text-xs">Remarks</Label><Textarea value={assignmentRemarks} onChange={(event) => setAssignmentRemarks(event.target.value)} placeholder="Optional assignment remarks" className="mt-1 min-h-[7.75rem] flex-1" /></div> : null}</div>;
    }
    if (caseModal.kind === 'violation' && caseModal.violation) {
      const violation = caseModal.violation;
      if (stepName === 'Type new or Search Existing Violations') return <div className="space-y-3"><Input value={violation.searchText} placeholder="Type new or Search Existing Violations" onChange={(event) => { updateViolationDraft({ searchText: event.target.value, existingViolationId: null, selectedExistingTitle: null, createNew: true, newViolationTitle: event.target.value }); loadViolationSuggestions(violation.id, event.target.value); }} />{violationSuggestions[violation.id]?.length ? <div className="rounded-md border bg-background p-2 text-sm shadow-sm"><p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Violation suggestions</p><div className="flex flex-wrap gap-2">{violationSuggestions[violation.id].map((suggestion) => <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyViolationDraftSuggestion(suggestion)}>{suggestion.title}</Button>)}</div></div> : null}</div>;
      return <Textarea value={violation.description ?? ''} onChange={(event) => updateViolationDraft({ description: event.target.value })} placeholder="Remarks" />;
    }
    if (caseModal.kind === 'place' && caseModal.place) {
      const place = caseModal.place;
      if (stepName === 'Address Type') return <CreatableLookupSelect value={place.addressTypeId ? place.addressTypeId.toString() : ''} onValueChange={(value) => updatePlaceDraft({ addressTypeId: toNumber(value) })} options={lookups.addressTypes} placeholder="Select type" addLabel="Add Address Type" dialogTitle="Add Address Type" labelField="Address Type Label" onCreate={createAddressTypeOption} />;
      return <div className="space-y-3"><div className="grid grid-cols-1 gap-3 md:grid-cols-2"><div><Label className="text-xs">Line 1</Label><Input value={place.line1 ?? ''} onChange={(event) => { const line1 = event.target.value; updatePlaceDraft({ line1, suggestionQuery: [line1, place.line2].filter(Boolean).join(' '), existingAddressId: null }); loadAddressSuggestions(place.id, [line1, place.line2].filter(Boolean).join(' ')); }} className="mt-1" /></div><div><Label className="text-xs">Line 2</Label><Input value={place.line2 ?? ''} onChange={(event) => { const line2 = event.target.value; updatePlaceDraft({ line2, suggestionQuery: [place.line1, line2].filter(Boolean).join(' '), existingAddressId: null }); loadAddressSuggestions(place.id, [place.line1, line2].filter(Boolean).join(' ')); }} className="mt-1" /></div>{addressSuggestions[place.id]?.length ? <div className="rounded-md border bg-background p-2 text-sm shadow-sm md:col-span-2"><p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing address suggestions</p><div className="flex flex-wrap gap-2">{addressSuggestions[place.id].map((suggestion) => <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyPlaceDraftSuggestion(suggestion)}>{formatAddress(suggestion) || `Address #${suggestion.id}`}</Button>)}</div></div> : null}<div><Label className="text-xs">Barangay</Label><Input value={place.barangay ?? ''} onChange={(event) => updatePlaceDraft({ barangay: event.target.value, existingAddressId: null })} className="mt-1" /></div><div><Label className="text-xs">City</Label><Input value={place.city ?? ''} onChange={(event) => updatePlaceDraft({ city: event.target.value, existingAddressId: null })} className="mt-1" /></div><div><Label className="text-xs">Province</Label><Input value={place.province ?? ''} onChange={(event) => updatePlaceDraft({ province: event.target.value, existingAddressId: null })} className="mt-1" /></div><div><Label className="text-xs">Region</Label><Input value={place.region ?? ''} onChange={(event) => updatePlaceDraft({ region: event.target.value, existingAddressId: null })} className="mt-1" /></div><div><Label className="text-xs">ZIP Code</Label><Input value={place.zipCode ?? ''} onChange={(event) => updatePlaceDraft({ zipCode: event.target.value, existingAddressId: null })} className="mt-1" /></div><div><Label className="text-xs">Country</Label><Input value={place.country ?? ''} onChange={(event) => updatePlaceDraft({ country: event.target.value, existingAddressId: null })} className="mt-1" /></div><div className="md:col-span-2"><Label className="text-xs">Remarks</Label><Input value={place.remarks ?? ''} onChange={(event) => updatePlaceDraft({ remarks: event.target.value })} className="mt-1" /></div></div></div>;
    }
    return null;
  };

  const caseModalTitle = caseModal?.kind === 'docket' ? 'Docket Information' : caseModal?.kind === 'violation' ? 'Violation' : caseModal?.kind === 'procedure' ? 'Procedure and Case Classification' : caseModal?.kind === 'place' ? 'Place of Commission' : 'Assignment';


  const shouldAdvanceDialogOnEnter = (event: React.KeyboardEvent) => {
    const target = event.target as HTMLElement;
    return event.key === 'Enter' && target.tagName !== 'TEXTAREA';
  };

  const handleParticipantDialogEnter = (event: React.KeyboardEvent) => {
    if (!shouldAdvanceDialogOnEnter(event)) return;
    event.preventDefault();
    if (isParticipantFinalStep) saveParticipantDialog();
    else setParticipantDialog((current) => current ? { ...current, step: Math.min(current.step + 1, participantSteps.length - 1) } : current);
  };

  const handleAddOnDialogEnter = (event: React.KeyboardEvent) => {
    if (!shouldAdvanceDialogOnEnter(event) || !addOnDialog) return;
    event.preventDefault();
    const steps = addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps;
    if (addOnDialog.step >= steps.length - 1) saveAddOnDialog();
    else setAddOnDialog((current) => current ? { ...current, step: current.step + 1 } : current);
  };

  const handleCaseModalEnter = (event: React.KeyboardEvent) => {
    if (!shouldAdvanceDialogOnEnter(event) || !caseModal) return;
    event.preventDefault();
    if (isCaseModalFinalStep) saveCaseModal();
    else setCaseModal((current) => current ? { ...current, step: Math.min(current.step + 1, caseModalSteps.length - 1) } : current);
  };

  return (
    <div className="p-4 md:p-8">
      <div className="mx-auto flex w-full max-w-6xl flex-col gap-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-foreground">New Docket Entry</h1>
            <p className="mt-1 text-muted-foreground">Register a new docket with its case details, participants, and violations.</p>
          </div>
          <Button type="button" variant="outline" size="sm" onClick={resetForm}>
            Clear All Fields
          </Button>
        </div>

        {message && (
        <Alert variant={message.type === 'error' ? 'destructive' : 'default'}>
          {message.type === 'error' ? <AlertCircle className="h-4 w-4" /> : <CheckCircle2 className="h-4 w-4" />}
          <AlertTitle>{message.type === 'error' ? 'Unable to create docket' : 'Docket created'}</AlertTitle>
          <AlertDescription className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <span>{message.text}</span>
            {message.type === 'success' && message.caseId ? (
              <Button size="sm" onClick={() => router.push(`/cases/${message.caseId}`)}>
                View case
              </Button>
            ) : null}
          </AlertDescription>
        </Alert>
      )}

      <Card>
        <CardContent className="p-4 sm:p-6">
          <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="case-info">1. Case</TabsTrigger>
              <TabsTrigger value="persons">2. Participants</TabsTrigger>
              <TabsTrigger value="review">3. Review</TabsTrigger>
            </TabsList>

            <TabsContent value="case-info" className="space-y-4">
              {!isDocketInformationSaved ? (
                <section className="overflow-hidden rounded-lg border">
                  <div className="p-4">
                    <Button type="button" variant="outline" onClick={() => openCaseModal('docket')}>
                      <Plus className="mr-2 h-4 w-4" /> Add Docket
                    </Button>
                  </div>
                </section>
              ) : (
                <>
                  <div className="px-1">
                    <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Generated docket number</p>
                    <p className="mt-1 text-2xl font-bold tracking-tight text-primary">
                      {isLoadingNextDocket ? 'Detecting next number…' : generatedDocketNumber}
                    </p>
                  </div>

                  <div className="grid gap-4 lg:grid-cols-2">
                    <section className="overflow-hidden rounded-lg border">
                      <header className="flex items-center justify-between gap-2 border-b bg-muted/40 px-4 py-3">
                        <div className="flex items-center gap-2"><h3 className="text-sm font-semibold uppercase tracking-wide">Docket information</h3></div>
                        <Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('docket')}>Edit Docket</Button>
                      </header>
                      <div className="p-4 text-sm">
                        <div className="rounded-lg border p-4">
                          <div className="grid max-w-2xl gap-x-8 gap-y-2 md:grid-cols-2">
                            <p><strong>Docket type:</strong> {selectedDocketType ? `${selectedDocketType.prefix} — ${selectedDocketType.name}` : '—'}</p>
                            <p><strong>Docket year:</strong> {docketYear || '—'}</p>
                            <p><strong>Date received:</strong> {dateReceived || '—'}</p>
                          </div>
                        </div>
                      </div>
                    </section>

                    <section className="overflow-hidden rounded-lg border">
                      <header className="flex items-center justify-between gap-2 border-b bg-muted/40 px-4 py-3">
                        <div className="flex items-center gap-2"><h3 className="text-sm font-semibold uppercase tracking-wide">Violations</h3></div>
                        <Button type="button" onClick={() => openCaseModal('violation')} variant="outline" size="sm"><Plus className="mr-2 h-4 w-4" /> Add violation</Button>
                      </header>
                      <div className="space-y-3 p-4">
                        {violations.length === 0 ? <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No violations added yet</div> : null}
                        {violations.map((violation) => <div key={violation.id} className="rounded-lg border p-4">
                          <div className="flex items-start justify-between gap-3">
                            <div><p className="font-medium">{violation.existingViolationId ? violation.selectedExistingTitle : (violation.newViolationTitle || violation.searchText || 'Untitled violation')}</p>{violation.rawViolationText || violation.description ? <p className="mt-1 text-xs text-muted-foreground">{shortPreview(violation.rawViolationText || violation.description)}</p> : null}</div>
                            <div className="flex gap-2"><Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('violation', violation.id)}>Edit</Button><Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => setViolations((current) => current.filter((item) => item.id !== violation.id))}>Remove</Button></div>
                          </div>
                        </div>)}
                      </div>
                    </section>
                  </div>

                  {violations.length > 0 ? (
                    <>
                      <div className="grid gap-4 lg:grid-cols-2">
                        <section className="overflow-hidden rounded-lg border">
                          <header className="flex items-center gap-2 border-b bg-muted/40 px-4 py-3"><h3 className="text-sm font-semibold uppercase tracking-wide">Procedure and Case Classification</h3></header>
                          <div className="space-y-3 p-4">
                            <div className="rounded-lg border p-4 text-sm">
                              <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                                <label className="flex items-center gap-2 text-sm"><Checkbox checked={isSummaryProcedure} onCheckedChange={(checked) => setIsSummaryProcedure(checked === true)} /> Falls under Summary Procedure</label>
                                <div><Label className="text-xs">Case Classification</Label><CreatableLookupSelect value={caseClassificationId || 'none'} onValueChange={(value) => setCaseClassificationId(value === 'none' ? '' : value)} disabled={isLoadingLookups} className="mt-1" options={filteredCaseClassifications} placeholder="Select classification" addLabel="Add Case Classification" dialogTitle="Add Case Classification" labelField="Classification Label" noneOption={{ value: 'none', label: 'No classification' }} searchValue={caseClassificationSearch} onSearchChange={setCaseClassificationSearch} searchPlaceholder="Search classifications" onCreate={createCaseClassificationOption} /></div>
                                {isSummaryProcedure ? <div className="md:col-span-2"><Label className="text-xs">Summary Remarks</Label><Textarea value={remarks} onChange={(event) => setRemarks(event.target.value)} placeholder="Optional summary procedure remarks" className="mt-1" /></div> : null}
                              </div>
                            </div>
                          </div>
                        </section>

                        <section className="overflow-hidden rounded-lg border">
                          <header className="flex items-center gap-2 border-b bg-muted/40 px-4 py-3"><h3 className="text-sm font-semibold uppercase tracking-wide">Assignment</h3></header>
                          <div className="space-y-3 p-4">
                            {assignedProsecutorId ? <div className="rounded-lg border p-4 text-sm"><p><strong>Assigned prosecutor:</strong> {selectedProsecutor?.short_name ?? selectedProsecutor?.full_name ?? '—'}</p><p><strong>Assignment date/time:</strong> {assignmentDate || '—'} {assignmentTime || ''}</p><p><strong>Remarks:</strong> {shortPreview(assignmentRemarks)}</p></div> : null}
                            <Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('assignment')}>{assignedProsecutorId ? 'Edit Assignment' : 'Add Assignment'}</Button>
                          </div>
                        </section>
                      </div>

                      <section className="overflow-hidden rounded-lg border">
                        <header className="flex items-center justify-between gap-2 border-b bg-muted/40 px-4 py-3"><div className="flex items-center gap-2"><MapPin className="h-4 w-4 text-primary" /><h3 className="text-sm font-semibold uppercase tracking-wide">Places of commission</h3></div><Button type="button" onClick={() => openCaseModal('place')} variant="outline" size="sm" disabled={!defaultAddressTypeId}><Plus className="mr-2 h-4 w-4" /> Add place</Button></header>
                        <div className="space-y-3 p-4">
                          {placesOfCommission.length === 0 ? <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No place of commission added yet</div> : null}
                          {placesOfCommission.map((place) => <div key={place.id} className="rounded-lg border p-4"><div className="flex items-start justify-between gap-3"><div><p className="font-medium">{formatAddressLike(place) || place.selectedExistingLabel || 'Unspecified address'}</p>{place.remarks ? <p className="mt-1 text-xs text-muted-foreground">{place.remarks}</p> : null}</div><div className="flex gap-2"><Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('place', place.id)}>Edit</Button><Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => setPlacesOfCommission((current) => current.filter((item) => item.id !== place.id))}>Remove</Button></div></div></div>)}
                        </div>
                      </section>
                    </>
                  ) : null}
                </>
              )}

              <Dialog open={Boolean(caseModal)} onOpenChange={(open) => !open && setCaseModal(null)}>
                <DialogContent onKeyDown={handleCaseModalEnter}>
                  <DialogHeader><DialogTitle>{caseModalTitle}</DialogTitle><DialogDescription>{caseModal?.kind === 'docket' ? 'Choose a docket type first. Date received and docket year appear after selection.' : `Step ${(caseModal?.step ?? 0) + 1} of ${caseModalSteps.length}: ${caseModalSteps[caseModal?.step ?? 0]}. Nullable fields can be skipped.`}</DialogDescription>{caseModal?.kind === 'docket' || caseModal?.kind === 'assignment' ? <p className="text-xs text-muted-foreground">Current Philippine time: {formatManilaClock(manilaNow)}</p> : null}</DialogHeader>
                  <div className="space-y-2"><Label>{caseModalSteps[caseModal?.step ?? 0]}</Label>{renderCaseModalField()}</div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={() => setCaseModal(null)}>Cancel</Button>
                    {caseModal && caseModal.step > 0 ? <Button type="button" variant="outline" onClick={() => setCaseModal((current) => current ? { ...current, step: current.step - 1 } : current)}>Back</Button> : null}
                    {isCaseModalFinalStep ? <Button type="button" onClick={saveCaseModal} disabled={caseModal?.kind === 'docket' && !docketTypeId}>{caseModal?.kind === 'docket' ? 'Save' : 'OK'}</Button> : <Button type="button" onClick={() => setCaseModal((current) => current ? { ...current, step: Math.min(current.step + 1, caseModalSteps.length - 1) } : current)}>Next / Skip</Button>}
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              {isDocketInformationSaved ? (
                <div className="flex justify-end border-t pt-4">
                  <Button onClick={() => setActiveTab('persons')}>Continue to Participants</Button>
                </div>
              ) : null}
            </TabsContent>

            <TabsContent value="persons" className="space-y-4">
              <section className="overflow-hidden rounded-lg border">
                <header className="border-b bg-muted/40 px-4 py-3">
                  <div>
                    <h3 className="text-sm font-semibold uppercase tracking-wide">Case participants</h3>
                  </div>
                </header>
                <div className="grid gap-4 p-4 md:grid-cols-2">
                  {(['Complainant', 'Respondent'] as ParticipantColumnRole[]).map((columnRole) => {
                    const columnParticipants = participantsByColumn(columnRole);
                    return (
                      <div key={columnRole} className="space-y-3 rounded-lg border bg-muted/20 p-4">
                        <div className="flex items-center justify-between gap-3">
                          <div><h4 className="font-semibold">{columnRole}s</h4><p className="text-xs text-muted-foreground">{columnParticipants.length} added</p></div>
                          <Button type="button" variant="outline" onClick={() => openParticipantDialog(columnRole)} disabled={!defaultRoleId}><Plus className="mr-2 h-4 w-4" /> Add {columnRole}</Button>
                        </div>
                        {columnParticipants.length === 0 ? <div className="rounded-lg border border-dashed py-8 text-center text-sm text-muted-foreground">No {columnRole.toLowerCase()}s added yet</div> : null}
                        <div className="space-y-3">
                          {columnParticipants.map((person) => (
                            <div key={person.id} className="rounded-md border bg-background p-3 shadow-sm">
                              <div className="flex items-start justify-between gap-3">
                                <div className="min-w-0 flex-1 space-y-1">
                                  <p className="break-words font-medium">{formatParticipantPreviewName(person)}</p>
                                  {person.participantKind === 'PERSON' ? <p className="text-xs text-muted-foreground">{[person.gender, person.age ? `Age ${person.age}` : null, formatBirthdatePreview(person.birthDate), formatParticipantFlags(person), cleanString(person.remarks)].filter(Boolean).join(' | ')}</p> : <p className="text-xs text-muted-foreground">{[person.contactPerson, person.email, person.contactNumber].filter(Boolean).join(' | ') || 'Organization participant'}</p>}
                                  {(person.contactInformations ?? []).length ? <div className="text-xs text-muted-foreground">{(person.contactInformations ?? []).map((contact) => <p key={contact.id}>{[[contact.label, contact.contactValue].filter(Boolean).join(': ') || contact.contactType, contact.remarks ? `Remarks: ${contact.remarks}` : null].filter(Boolean).join(' | ')}</p>)}</div> : null}
                                  {(person.addresses ?? []).length ? <div className="text-xs text-muted-foreground">{(person.addresses ?? []).map((address, index) => <p key={address.id}>Address {index + 1}: {[formatAddressLike(address) || address.selectedExistingLabel || 'Unspecified address', address.remarks ? `Remarks: ${address.remarks}` : null].filter(Boolean).join(' | ')}</p>)}</div> : null}
                                </div>
                                <div className="flex shrink-0 items-center gap-1">
                                  <DropdownMenu><DropdownMenuTrigger asChild><Button type="button" variant="ghost" size="sm"><Settings2 className="h-4 w-4" /></Button></DropdownMenuTrigger><DropdownMenuContent align="end"><DropdownMenuItem onClick={() => setParticipantEditDialog({ personId: person.id, mode: 'attributes' })}>{person.participantKind === 'ORGANIZATION' ? 'Edit organization attributes' : 'Edit person attributes'}</DropdownMenuItem><DropdownMenuItem onClick={() => setParticipantEditDialog({ personId: person.id, mode: 'addresses' })}>Edit address</DropdownMenuItem><DropdownMenuItem onClick={() => setParticipantEditDialog({ personId: person.id, mode: 'contacts' })}>Edit contact info</DropdownMenuItem></DropdownMenuContent></DropdownMenu>
                                  <Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => setPersons((current) => current.filter((item) => item.id !== person.id))}><X className="h-4 w-4" /></Button>
                                </div>
                              </div>
                              <div className="mt-3 flex flex-nowrap gap-2 overflow-x-auto">
                                {person.participantKind === 'PERSON' ? <Button type="button" variant="outline" size="sm" className="shrink-0" onClick={() => openAddOnDialog(person.id, 'alias')}><Plus className="mr-1 h-3 w-3" /> Add Alias</Button> : null}
                                <Button type="button" variant="outline" size="sm" className="shrink-0" onClick={() => openAddOnDialog(person.id, 'address')}><Plus className="mr-1 h-3 w-3" /> Add Address</Button>
                                <Button type="button" variant="outline" size="sm" className="shrink-0" onClick={() => openAddOnDialog(person.id, 'contact')}><Plus className="mr-1 h-3 w-3" /> Add Contact Info</Button>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </section>

              <Dialog open={Boolean(participantDialog)} onOpenChange={(open) => !open && setParticipantDialog(null)}>
                <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-3xl" onKeyDown={handleParticipantDialogEnter}>
                  <DialogHeader><DialogTitle>Add {participantDialog?.role}</DialogTitle><DialogDescription>Step {(participantDialog?.step ?? 0) + 1} of 2: {participantSteps[participantDialog?.step ?? 0]}.</DialogDescription></DialogHeader>
                  <div className="space-y-2">{participantDialog?.step === 0 ? <Label>Participant Type</Label> : null}{renderParticipantDraftField()}</div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={() => setParticipantDialog(null)}>Cancel</Button>
                    {participantDialog && participantDialog.step > 0 ? <Button type="button" variant="outline" onClick={() => setParticipantDialog((current) => current ? { ...current, step: current.step - 1 } : current)}>Back</Button> : null}
                    {isParticipantFinalStep ? <Button type="button" onClick={saveParticipantDialog}>Save</Button> : <Button type="button" onClick={() => setParticipantDialog((current) => current ? { ...current, step: Math.min(current.step + 1, participantSteps.length - 1) } : current)}>Next</Button>}
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <Dialog open={Boolean(addOnDialog)} onOpenChange={(open) => !open && setAddOnDialog(null)}>
                <DialogContent onKeyDown={handleAddOnDialogEnter}>
                  <DialogHeader><DialogTitle>Add {addOnDialog?.kind === 'alias' ? 'Alias' : addOnDialog?.kind === 'address' ? 'Address' : 'Contact Info'}</DialogTitle><DialogDescription>Progressive entry with one nullable field at a time.</DialogDescription></DialogHeader>
                  <div className="space-y-2"><Label>{addOnDialog ? (addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps)[addOnDialog.step] : ''}</Label>{renderAddOnField()}</div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={() => setAddOnDialog(null)}>Cancel</Button>
                    {addOnDialog && addOnDialog.step > 0 ? <Button type="button" variant="outline" onClick={() => setAddOnDialog((current) => current ? { ...current, step: current.step - 1 } : current)}>Back</Button> : null}
                    {addOnDialog && addOnDialog.step >= (addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps).length - 1 ? <Button type="button" onClick={saveAddOnDialog}>OK</Button> : <Button type="button" onClick={() => setAddOnDialog((current) => current ? { ...current, step: current.step + 1 } : current)}>Next / Skip</Button>}
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <Dialog open={Boolean(participantEditDialog)} onOpenChange={(open) => !open && setParticipantEditDialog(null)}>
                <DialogContent className="sm:max-w-3xl">
                  <DialogHeader><DialogTitle>{participantEditDialog?.mode === 'attributes' ? (persons.find((item) => item.id === participantEditDialog?.personId)?.participantKind === 'ORGANIZATION' ? 'Edit organization Attributes' : 'Edit person attributes') : participantEditDialog?.mode === 'addresses' ? 'Edit addresses' : 'Edit contact info'}</DialogTitle><DialogDescription>Edit saved participant details directly, then save.</DialogDescription></DialogHeader>
                  {renderParticipantEditDialog()}
                  <DialogFooter><Button type="button" onClick={() => setParticipantEditDialog(null)}>Save</Button></DialogFooter>
                </DialogContent>
              </Dialog>

              <div className="flex flex-col-reverse gap-3 border-t pt-4 sm:flex-row sm:justify-between">
                <Button onClick={() => setActiveTab('case-info')} variant="outline">Back to Case</Button>
                <Button onClick={() => setActiveTab('review')}>Continue to Review</Button>
              </div>
            </TabsContent>

            <TabsContent value="review" className="space-y-4">
              <Card className="bg-background">
                <CardContent className="relative space-y-6 p-6 text-sm">
                  <div className="grid grid-cols-1 items-start gap-x-8 gap-y-4 md:grid-cols-[minmax(0,1fr)_16rem_14rem]">
                    <div className="space-y-3">
                      <p className="whitespace-nowrap text-base uppercase"><span>NPS DOCKET NO.</span> <span className="font-black">{generatedDocketNumber}</span></p>
                      <p className="text-base"><span className="font-medium uppercase">DATE RECEIVED:</span> {dateReceived}</p>
                    </div>
                    <div className="space-y-3 text-base md:justify-self-start">
                      <p><span className="font-medium">Assigned to:</span> {selectedProsecutor?.short_name ?? selectedProsecutor?.full_name ?? ''}</p>
                      <p><span className="font-medium">Date Assigned:</span> {assignedProsecutorId ? `${assignmentDate} ${assignmentTime}` : ''}</p>
                    </div>
                    <div className="hidden justify-self-start md:flex">
                      <div className={`rotate-[-6deg] rounded-md border-4 px-6 py-2 text-2xl font-black uppercase tracking-widest ${reviewDocketStamp.className}`}>{reviewDocketStamp.text}</div>
                    </div>
                  </div>

                  <div className="space-y-2 text-base">
                    {isSummaryProcedure ? <><p className="flex items-center gap-2"><span className="inline-flex size-4 items-center justify-center border border-foreground text-[10px] leading-none">✓</span><span>Falls Under Summary Procedure</span></p><p>Summary Remarks: {remarks || '—'}</p></> : null}
                    <p><span className="font-medium">Case Classification:</span> {selectedCaseClassification?.display_label ?? ''}</p>
                  </div>

                  <div className="border-t-2 border-foreground" />

                  <div className="grid grid-cols-1 gap-8 md:grid-cols-2">
                    <div className="space-y-2">
                      <h3 className="font-bold uppercase">COMPLAINANT/s:</h3>
                      {participantsByColumn('Complainant').map((person) => <div key={person.id} className="leading-tight"><p className="text-base">{formatParticipantPreviewName(person)}</p>{person.participantKind === 'PERSON' ? <p>{[person.gender, person.age ? `Age ${person.age}` : null, formatBirthdatePreview(person.birthDate), formatParticipantFlags(person), cleanString(person.remarks)].filter(Boolean).join(' | ')}</p> : null}{(person.contactInformations ?? []).map((contact) => <p key={contact.id}>{contact.contactValue}</p>)}{(person.addresses ?? []).map((address, index) => <p key={address.id}>Address {index + 1}: {formatAddressLike(address) || address.selectedExistingLabel || ''}</p>)}</div>)}
                    </div>
                    <div className="space-y-2">
                      <h3 className="font-bold uppercase">RESPONDENT/s:</h3>
                      {participantsByColumn('Respondent').map((person) => <div key={person.id} className="leading-tight"><p className="text-base">{formatParticipantPreviewName(person)}</p>{person.participantKind === 'PERSON' ? <p>{[person.gender, person.age ? `Age ${person.age}` : null, formatBirthdatePreview(person.birthDate), formatParticipantFlags(person), cleanString(person.remarks)].filter(Boolean).join(' | ')}</p> : null}{(person.contactInformations ?? []).map((contact) => <p key={contact.id}>{contact.contactValue}</p>)}{(person.addresses ?? []).map((address, index) => <p key={address.id}>Address {index + 1}: {formatAddressLike(address) || address.selectedExistingLabel || ''}</p>)}</div>)}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-8 md:grid-cols-2">
                    <div className="space-y-2"><h3 className="font-bold uppercase">VIOLATIONS/s:</h3>{violations.map((violation) => <p key={violation.id} className="text-base">{violation.existingViolationId ? violation.selectedExistingTitle : (violation.newViolationTitle || violation.searchText || 'Untitled')}</p>)}</div>
                    <div className="space-y-2"><h3 className="font-bold uppercase">PLACE of COMMISSION:</h3>{placesOfCommission.map((place) => <p key={place.id} className="text-base">{formatAddressLike(place) || place.selectedExistingLabel || ''}</p>)}</div>
                  </div>
                </CardContent>
              </Card>

              <div className="flex flex-col-reverse gap-3 border-t pt-4 sm:flex-row sm:justify-between">
                <Button onClick={() => setActiveTab('persons')} variant="outline">Back to Participants</Button>
                <Button onClick={handleSubmit} className="sm:min-w-48" disabled={isSubmitting || isLoadingLookups || isLoadingNextDocket}>
                  {isSubmitting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                  Submit Docket Entry
                </Button>
              </div>
            </TabsContent>

          </Tabs>
        </CardContent>
      </Card>
      </div>
    </div>
  );
}
