'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
  import { AlertCircle, CheckCircle2, ClipboardList, FileText, Gavel, Loader2, MapPin, Plus, Search, Settings2, UserCog, Users, X } from 'lucide-react';

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Textarea } from '@/components/ui/textarea';
import {
  createNewDocketEntry,
  getAddressTypes,
  getCaseStatuses,
  getCaseClassifications,
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

type AliasEntry = { id: string; aliasName: string };
type ExistingAliasEntry = { aliasName: string };
type AddressEntry = NewDocketAddressInput & { id: string; suggestionQuery: string; selectedExistingLabel?: string | null; existingRelation?: boolean };
type CustomOrganizationDetailEntry = { id: string; fieldTitle: string; fieldValue: string };
type ContactInformationEntry = { id: string; contactType: "PHONE" | "EMAIL" | "OTHER"; contactValue: string; label?: string | null; isPrimary?: boolean | null; remarks?: string | null };
type ParticipantColumnRole = 'Complainant' | 'Respondent';
type ParticipantDialogState = { role: ParticipantColumnRole; step: number; entry: PersonEntry } | null;
type AddOnDialogState = { personId: string; kind: 'alias' | 'address' | 'contact'; step: number; alias: AliasEntry; address: AddressEntry; contact: ContactInformationEntry } | null;
type CaseModalState = { kind: 'docket' | 'violation' | 'procedure' | 'place' | 'assignment'; step: number; id?: string; violation?: ViolationEntry; place?: AddressEntry } | null;
type PersonEntry = NewDocketParticipantInput & { id: string; selectedExistingName?: string | null; selectedExistingOrganizationName?: string | null; fullNamePreview?: string | null; aliases?: AliasEntry[]; existingAliases?: ExistingAliasEntry[]; addresses?: AddressEntry[]; organizationDetails?: CustomOrganizationDetailEntry[]; showOrganizationDetails?: boolean };
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

const thisYear = new Date().getFullYear();
const genderOptions = ['Female', 'Male', 'Other', 'Unspecified'];
const personWorkflowSteps = ['Participant Type', 'First Name', 'Middle Name', 'Surname', 'Suffix', 'Role', 'Gender', 'Birthdate', 'Age', 'Case Flags', 'Remarks'];
const organizationWorkflowSteps = ['Participant Type', 'Organization Name', 'Contact Person', 'Contact Number', 'Email', 'Custom Details', 'Role', 'Case Flags', 'Remarks'];
const aliasWorkflowSteps = ['Alias Name', 'Remarks'];
const addressWorkflowSteps = ['Address Type', 'Existing Address Search', 'Line 1', 'Line 2', 'Barangay', 'City', 'Province', 'Region', 'ZIP Code', 'Country', 'Primary', 'Remarks'];
const contactWorkflowSteps = ['Contact Type', 'Contact Value', 'Label', 'Primary', 'Remarks'];
const docketWorkflowSteps = ['Docket Type', 'Docket Year', 'Date Received', 'Region', 'Case Classification', 'Case Received Description', 'Case Notes'];
const violationWorkflowSteps = ['Violation Search', 'Raw Text / Law Reference', 'Remarks / Description'];
const procedureWorkflowSteps = ['Summary Procedure Case', 'Summary', 'Remarks'];
const placeWorkflowSteps = ['Address Type', 'Search Existing Address', 'Line 1', 'Line 2', 'Barangay', 'City', 'Province', 'Region', 'ZIP Code', 'Country', 'Remarks'];
const assignmentWorkflowSteps = ['Case Also Raffled', 'Prosecutor', 'Assignment Remarks'];
const defaultRegionCode = 'IV-31';
const defaultAddressRegionCode = 'IV-A';
const isDevelopment = process.env.NODE_ENV !== 'production';

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
  const surname = cleanString(person.lastName);
  const given = [cleanString(person.firstName), person.noMiddleName ? 'NMN' : cleanString(person.middleName)].filter(Boolean).join(' ');
  const suffix = cleanString(person.suffix);
  const body = [given, suffix].filter(Boolean).join(' ');
  if (surname && body) return `${surname}, ${body}`;
  return surname || body || 'Unnamed person';
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
  const [activeTab, setActiveTab] = useState('case-info');
  const [lookups, setLookups] = useState<LookupState>(emptyLookups);
  const [currentUser, setCurrentUser] = useState<DatabaseUserSummary | null>(null);
  const [isLoadingLookups, setIsLoadingLookups] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState<MessageState>(null);

  const [docketTypeId, setDocketTypeId] = useState('');
  const [docketYear, setDocketYear] = useState(String(thisYear));
  const [nextDocketNumber, setNextDocketNumber] = useState<number | null>(null);
  const [isLoadingNextDocket, setIsLoadingNextDocket] = useState(false);
  const [dateReceived, setDateReceived] = useState(new Date().toISOString().slice(0, 10));
  const [caseReceivedDescription, setCaseReceivedDescription] = useState(() => formatCaseReceivedDefaultDescription(new Date().toISOString().slice(0, 10)));
  const [isCaseReceivedDescriptionEdited, setIsCaseReceivedDescriptionEdited] = useState(false);
  const [initialStatusId, setInitialStatusId] = useState('');
  const [caseClassificationId, setCaseClassificationId] = useState('');
  const [caseAlsoRaffled, setCaseAlsoRaffled] = useState(false);
  const [assignedProsecutorId, setAssignedProsecutorId] = useState('');
  const [assignmentRemarks, setAssignmentRemarks] = useState('Assigned during manual docket creation');
  const [regionCode, setRegionCode] = useState(defaultRegionCode);
  const [summaryText, setSummaryText] = useState('');
  const [remarks, setRemarks] = useState('');
  const [notes, setNotes] = useState('');
  const [isSummaryProcedure, setIsSummaryProcedure] = useState(false);

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
      setDocketTypeId((current) => current || getFirstId(nextLookups.docketTypes));
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
  const docketMonthCode = getDocketMonthCode(dateReceived);
  const generatedDocketNumber = formatDocketNumber(selectedDocketType?.prefix, docketYear, nextDocketNumber, docketMonthCode === '—' ? null : docketMonthCode, regionCode);

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
    setRegionCode(defaultRegionCode);
    setSummaryText('');
    setRemarks('');
    setNotes('');
    setCaseClassificationId('');
    setIsSummaryProcedure(false);
    setCaseAlsoRaffled(false);
    setAssignedProsecutorId('');
    setPersons([]);
    setPlacesOfCommission([]);
    setViolations([]);
    setPersonSuggestions({});
    setOrganizationSuggestions({});
    setAddressSuggestions({});
    setViolationSuggestions({});
    setActiveTab('case-info');
  };

  const fillTestData = () => {
    const unique = crypto.randomUUID().slice(0, 8);
    const roleId = toNumber(defaultRoleId);
    const caseAddressTypeId = toNumber(defaultCaseAddressTypeId);
    const personAddressTypeId = toNumber(defaultPersonAddressTypeId);
    const prosecutor = lookups.prosecutors[0];

    setCaseClassificationId(lookups.caseClassifications[0]?.id?.toString() ?? '');
    setSummaryText(`Test summary ${unique}`);
    setRemarks(`Test remarks ${unique}`);
    setNotes(`Test notes ${unique}`);
    setCaseAlsoRaffled(Boolean(prosecutor));
    setAssignedProsecutorId(prosecutor?.id?.toString() ?? '');

    setPersons([
      {
        id: makeId('person'),
        participantKind: 'PERSON',
        roleId,
        participantOrder: 1,
        firstName: `Juan${unique}`,
        middleName: 'Dela',
        lastName: `Cruz${unique}`,
        suffix: '',
        gender: 'Male',
        age: '17',
        birthDate: '',
        remarks: `Person remarks ${unique}`,
        aliases: [{ id: makeId('alias'), aliasName: `Person Alias ${unique}` }],
        existingAliases: [],
        addresses: [{
          ...makeEmptyAddress(defaultPersonAddressTypeId, 'participant-address'),
          addressTypeId: personAddressTypeId,
          line1: `Person Address ${unique}`,
          barangay: 'Sample Barangay',
          city: 'General Trias',
          province: 'Cavite',
          region: defaultAddressRegionCode,
          country: 'Philippines',
          isPrimary: true,
        }],
        attributes: {
          ageText: '17',
          ageYears: 17,
          genderText: 'Male',
          genderNormalized: 'MALE',
          minorText: 'YES',
          isMinorAtCase: true,
          seniorText: 'NO',
          isSeniorAtCase: false,
          pwdText: 'YES',
          isPwdAtCase: true,
        },
      },
      {
        id: makeId('organization'),
        participantKind: 'ORGANIZATION',
        roleId,
        participantOrder: 2,
        organizationName: `Test Organization ${unique}`,
        contactPerson: `Contact ${unique}`,
        contactNumber: '09170000000',
        email: `org-${unique}@example.test`,
        showOrganizationDetails: true,
        organizationDetails: [
          { id: makeId('organization-detail'), fieldTitle: 'Accreditation', fieldValue: `ACC-${unique}` },
          { id: makeId('organization-detail'), fieldTitle: 'Office Hours', fieldValue: 'Monday-Friday 8:00 AM-5:00 PM' },
          { id: makeId('organization-detail'), fieldTitle: 'Intake Desk', fieldValue: `Desk ${unique}` },
        ],
        remarks: `Organization remarks ${unique}`,
        aliases: [{ id: makeId('alias'), aliasName: `Org Alias ${unique}` }],
        existingAliases: [],
        addresses: [],
      },
    ]);

    setPlacesOfCommission([{
      ...makeEmptyAddress(defaultCaseAddressTypeId, 'place'),
      addressTypeId: caseAddressTypeId,
      line1: `Place of Commission ${unique}`,
      barangay: 'Sample Barangay',
      city: 'General Trias',
      province: 'Cavite',
      region: defaultAddressRegionCode,
      country: 'Philippines',
      isPrimary: true,
      remarks: `Place remarks ${unique}`,
    }]);

    setViolations([{ id: makeId('violation'), existingViolationId: null, violationOrder: 1, rawViolationText: '', searchText: `Test Violation ${unique}`, createNew: true, newViolationTitle: `Test Violation ${unique}` }]);
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
      docketTypeId: toNumber(docketTypeId),
      docketYear: toNumber(docketYear),
      dateReceived,
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
      assignedProsecutorId: caseAlsoRaffled && assignedProsecutorId ? toNumber(assignedProsecutorId) : null,
      caseClassificationId: caseClassificationId ? toNumber(caseClassificationId) : null,
      placesOfCommission: placesOfCommission.map(({ id: _id, suggestionQuery: _sq, selectedExistingLabel: _sel, ...address }, index) => ({ ...address, isPrimary: address.isPrimary ?? index === 0, newAddress: address.existingAddressId ? undefined : { line1: address.line1, line2: address.line2, barangay: address.barangay, city: address.city, province: address.province, region: address.region, zipCode: address.zipCode, country: address.country } })),
      participants: persons.map(({ id: _id, selectedExistingName: _selectedExistingName, selectedExistingOrganizationName: _selectedExistingOrganizationName, fullNamePreview: _fullNamePreview, age, gender, aliases, addresses: participantAddresses, contactInformations, ...person }, index) => ({
        ...person,
        participantOrder: person.participantOrder ?? index + 1,
        aliases: aliases?.map(({ id: _aliasId, ...alias }) => alias),
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

    const result = await createNewDocketEntry(payload);
    setIsSubmitting(false);

    if (result.error) {
      setMessage({ type: 'error', text: result.error.message });
      return;
    }

    setMessage({ type: 'success', text: `Docket ${result.data.docketDisplayNumber} created as case #${result.data.caseId}.`, caseId: result.data.caseId });
    router.push(`/cases/${result.data.caseId}`);
  };


  const updateParticipantDraft = (updates: Partial<PersonEntry>) => {
    setParticipantDialog((current) => current ? { ...current, entry: { ...current.entry, ...updates } } : current);
  };

  const participantSteps = participantDialog?.entry.participantKind === 'ORGANIZATION' ? organizationWorkflowSteps : personWorkflowSteps;
  const isParticipantFinalStep = Boolean(participantDialog && participantDialog.step >= participantSteps.length - 1);
  const participantsByColumn = (role: ParticipantColumnRole) => persons.filter((person) => person.sourceDetail === role || lookups.participantRoles.find((item) => item.id === person.roleId)?.display_label?.toLowerCase().includes(role.toLowerCase()));

  const openAddOnDialog = (personId: string, kind: 'alias' | 'address' | 'contact') => {
    setAddOnDialog({
      personId,
      kind,
      step: 0,
      alias: { id: makeId('alias'), aliasName: '' },
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

  const renderParticipantDraftField = () => {
    if (!participantDialog) return null;
    const entry = participantDialog.entry;
    const stepName = participantSteps[participantDialog.step];
    if (stepName === 'Participant Type') return <Select value={entry.participantKind ?? 'PERSON'} onValueChange={(value) => updateParticipantDraft({ participantKind: value as 'PERSON' | 'ORGANIZATION' })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PERSON">Person</SelectItem><SelectItem value="ORGANIZATION">Organization</SelectItem></SelectContent></Select>;
    if (stepName === 'First Name') return <Input value={entry.firstName ?? ''} onChange={(event) => updateParticipantDraft({ firstName: event.target.value })} placeholder="First name or skip" />;
    if (stepName === 'Middle Name') return <div className="space-y-3"><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.noMiddleName === true} onCheckedChange={(checked) => updateParticipantDraft({ noMiddleName: checked === true, middleName: checked === true ? 'NMN' : '' })} /> NMN (No Middle Name)</label><Input value={entry.noMiddleName ? 'NMN' : (entry.middleName ?? '')} disabled={entry.noMiddleName === true} onChange={(event) => updateParticipantDraft({ middleName: event.target.value, noMiddleName: false })} placeholder="Middle name or skip" /></div>;
    if (stepName === 'Surname') return <Input value={entry.lastName ?? ''} onChange={(event) => updateParticipantDraft({ lastName: event.target.value })} placeholder="Surname or skip" />;
    if (stepName === 'Suffix') return <div className="space-y-3"><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.suffix === ''} onCheckedChange={(checked) => updateParticipantDraft({ suffix: checked === true ? '' : entry.suffix })} /> No Suffix</label><Input value={entry.suffix ?? ''} onChange={(event) => updateParticipantDraft({ suffix: event.target.value })} placeholder="Suffix or skip" /></div>;
    if (stepName === 'Role') return <Select value={entry.roleId ? entry.roleId.toString() : ''} onValueChange={(value) => updateParticipantDraft({ roleId: toNumber(value) })}><SelectTrigger><SelectValue placeholder="Select role" /></SelectTrigger><SelectContent>{lookups.participantRoles.map((role) => <SelectItem key={role.id} value={role.id.toString()}>{role.display_label}</SelectItem>)}</SelectContent></Select>;
    if (stepName === 'Gender') return <div className="flex flex-wrap gap-2">{genderOptions.map((gender) => <Button key={gender} type="button" variant={entry.gender === gender ? 'default' : 'outline'} onClick={() => updateParticipantDraft({ gender })}>{gender}</Button>)}</div>;
    if (stepName === 'Birthdate') return <Input type="date" value={entry.birthDate ?? ''} onChange={(event) => updateParticipantDraft({ birthDate: event.target.value })} />;
    if (stepName === 'Age') return <Input value={entry.age ?? ''} onChange={(event) => updateParticipantDraft({ age: event.target.value })} placeholder="Age or skip" />;
    if (stepName === 'Case Flags') return <div className="flex flex-wrap gap-4"><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.attributes?.isMinorAtCase === true} onCheckedChange={(checked) => updateParticipantDraft({ attributes: { ...(entry.attributes ?? {}), isMinorAtCase: checked === true, minorText: checked === true ? 'YES' : null } })} /> Minor</label><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.attributes?.isSeniorAtCase === true} onCheckedChange={(checked) => updateParticipantDraft({ attributes: { ...(entry.attributes ?? {}), isSeniorAtCase: checked === true, seniorText: checked === true ? 'YES' : null } })} /> Senior</label><label className="flex items-center gap-2 text-sm"><Checkbox checked={entry.attributes?.isPwdAtCase === true} onCheckedChange={(checked) => updateParticipantDraft({ attributes: { ...(entry.attributes ?? {}), isPwdAtCase: checked === true, pwdText: checked === true ? 'YES' : null } })} /> PWD</label></div>;
    if (stepName === 'Organization Name') return <Input value={entry.organizationName ?? ''} onChange={(event) => updateParticipantDraft({ organizationName: event.target.value })} placeholder="Organization name or skip" />;
    if (stepName === 'Contact Person') return <Input value={entry.contactPerson ?? ''} onChange={(event) => updateParticipantDraft({ contactPerson: event.target.value })} placeholder="Contact person or skip" />;
    if (stepName === 'Contact Number') return <Input value={entry.contactNumber ?? ''} onChange={(event) => updateParticipantDraft({ contactNumber: event.target.value })} placeholder="Contact number or skip" />;
    if (stepName === 'Email') return <Input value={entry.email ?? ''} onChange={(event) => updateParticipantDraft({ email: event.target.value })} placeholder="Email or skip" />;
    if (stepName === 'Custom Details') return <Textarea value={entry.organizationDetails?.[0]?.fieldValue ?? ''} onChange={(event) => updateParticipantDraft({ organizationDetails: [{ id: entry.organizationDetails?.[0]?.id ?? makeId('organization-detail'), fieldTitle: 'Details', fieldValue: event.target.value }] })} placeholder="Organization details or skip" />;
    return <Textarea value={entry.remarks ?? ''} onChange={(event) => updateParticipantDraft({ remarks: event.target.value })} placeholder="Remarks or skip" />;
  };

  const renderAddOnField = () => {
    if (!addOnDialog) return null;
    const steps = addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps;
    const stepName = steps[addOnDialog.step];
    const updateAddOn = (updates: Partial<AddOnDialogState>) => setAddOnDialog((current) => current ? { ...current, ...updates } as AddOnDialogState : current);
    if (addOnDialog.kind === 'alias') return <Input value={addOnDialog.alias.aliasName} onChange={(event) => updateAddOn({ alias: { ...addOnDialog.alias, aliasName: event.target.value } })} placeholder="Alias or skip" />;
    if (addOnDialog.kind === 'contact') {
      if (stepName === 'Contact Type') return <Select value={addOnDialog.contact.contactType} onValueChange={(value) => updateAddOn({ contact: { ...addOnDialog.contact, contactType: value as 'PHONE' | 'EMAIL' | 'OTHER' } })}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PHONE">Phone</SelectItem><SelectItem value="EMAIL">Email</SelectItem><SelectItem value="OTHER">Other</SelectItem></SelectContent></Select>;
      if (stepName === 'Primary') return <label className="flex items-center gap-2 text-sm"><Checkbox checked={addOnDialog.contact.isPrimary === true} onCheckedChange={(checked) => updateAddOn({ contact: { ...addOnDialog.contact, isPrimary: checked === true } })} /> Primary contact</label>;
      const key = stepName === 'Contact Value' ? 'contactValue' : stepName.toLowerCase() as 'label' | 'remarks';
      return <Input value={(addOnDialog.contact as any)[key] ?? ''} onChange={(event) => updateAddOn({ contact: { ...addOnDialog.contact, [key]: event.target.value } })} placeholder={`${stepName} or skip`} />;
    }
    if (stepName === 'Address Type') return <Select value={addOnDialog.address.addressTypeId ? addOnDialog.address.addressTypeId.toString() : ''} onValueChange={(value) => updateAddOn({ address: { ...addOnDialog.address, addressTypeId: toNumber(value) } })}><SelectTrigger><SelectValue placeholder="Select type" /></SelectTrigger><SelectContent>{lookups.addressTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.display_label}</SelectItem>)}</SelectContent></Select>;
    if (stepName === 'Primary') return <label className="flex items-center gap-2 text-sm"><Checkbox checked={addOnDialog.address.isPrimary === true} onCheckedChange={(checked) => updateAddOn({ address: { ...addOnDialog.address, isPrimary: checked === true } })} /> Primary address</label>;
    const addressKey = stepName === 'Existing Address Search' ? 'suggestionQuery' : stepName === 'Line 1' ? 'line1' : stepName === 'Line 2' ? 'line2' : stepName === 'ZIP Code' ? 'zipCode' : stepName.toLowerCase() as keyof AddressEntry;
    return <Input value={(addOnDialog.address as any)[addressKey] ?? ''} onChange={(event) => updateAddOn({ address: { ...addOnDialog.address, [addressKey]: event.target.value } })} placeholder={`${stepName} or skip`} />;
  };


  const openCaseModal = (kind: NonNullable<CaseModalState>['kind'], id?: string) => {
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
    if (!caseAlsoRaffled && caseModal.step === 0) return ['Case Also Raffled'];
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
      if (stepName === 'Docket Type') return <Select value={docketTypeId} onValueChange={setDocketTypeId} disabled={isLoadingLookups}><SelectTrigger><SelectValue placeholder="Select docket type" /></SelectTrigger><SelectContent>{lookups.docketTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.prefix} — {type.name}</SelectItem>)}</SelectContent></Select>;
      if (stepName === 'Docket Year') return <Input type="number" value={docketYear} onChange={(event) => setDocketYear(event.target.value)} />;
      if (stepName === 'Date Received') return <Input type="date" value={dateReceived} onChange={(event) => setDateReceived(event.target.value)} />;
      if (stepName === 'Region') return <Input value={regionCode} onChange={(event) => setRegionCode(event.target.value)} placeholder="Region or skip" />;
      if (stepName === 'Case Classification') return <Select value={caseClassificationId || 'none'} onValueChange={(value) => setCaseClassificationId(value === 'none' ? '' : value)} disabled={isLoadingLookups}><SelectTrigger><SelectValue placeholder="Select classification" /></SelectTrigger><SelectContent><SelectItem value="none">No classification</SelectItem>{lookups.caseClassifications.map((classification) => <SelectItem key={classification.id} value={classification.id.toString()}>{classification.display_label}</SelectItem>)}</SelectContent></Select>;
      if (stepName === 'Case Received Description') return <Textarea value={caseReceivedDescription} onChange={(event) => { setIsCaseReceivedDescriptionEdited(true); setCaseReceivedDescription(event.target.value); }} placeholder={formatCaseReceivedDefaultDescription(dateReceived)} />;
      return <Textarea value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Optional case note stored in notes table" />;
    }
    if (caseModal.kind === 'procedure') {
      if (stepName === 'Summary Procedure Case') return <label className="flex items-center gap-2 text-sm"><Checkbox checked={isSummaryProcedure} onCheckedChange={(checked) => setIsSummaryProcedure(checked === true)} /> Summary procedure case</label>;
      if (stepName === 'Summary') return <Textarea value={summaryText} onChange={(event) => setSummaryText(event.target.value)} placeholder="Case summary stored in summary_text" />;
      return <Textarea value={remarks} onChange={(event) => setRemarks(event.target.value)} placeholder="Optional summary procedure remarks" />;
    }
    if (caseModal.kind === 'assignment') {
      if (stepName === 'Case Also Raffled') return <label className="flex items-center gap-2 text-sm"><Checkbox checked={caseAlsoRaffled} onCheckedChange={(checked) => { setCaseAlsoRaffled(checked === true); if (checked !== true) setAssignedProsecutorId(''); }} /> Case also raffled</label>;
      if (stepName === 'Prosecutor') return <Select value={assignedProsecutorId || 'none'} onValueChange={(value) => setAssignedProsecutorId(value === 'none' ? '' : value)} disabled={isLoadingLookups}><SelectTrigger><SelectValue placeholder="Select prosecutor" /></SelectTrigger><SelectContent><SelectItem value="none">No prosecutor selected</SelectItem>{lookups.prosecutors.map((prosecutor) => <SelectItem key={prosecutor.id} value={prosecutor.id.toString()}>{prosecutor.short_name ?? prosecutor.full_name}</SelectItem>)}</SelectContent></Select>;
      return <Input value={assignmentRemarks} onChange={(event) => setAssignmentRemarks(event.target.value)} placeholder="Optional assignment remarks" />;
    }
    if (caseModal.kind === 'violation' && caseModal.violation) {
      const violation = caseModal.violation;
      if (stepName === 'Violation Search') return <div className="space-y-3"><Input value={violation.searchText} placeholder="Type a violation, law reference, or code" onChange={(event) => { updateViolationDraft({ searchText: event.target.value, existingViolationId: null, selectedExistingTitle: null, createNew: true, newViolationTitle: event.target.value }); loadViolationSuggestions(violation.id, event.target.value); }} />{violationSuggestions[violation.id]?.length ? <div className="rounded-md border bg-background p-2 text-sm shadow-sm"><p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Violation suggestions</p><div className="flex flex-wrap gap-2">{violationSuggestions[violation.id].map((suggestion) => <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyViolationDraftSuggestion(suggestion)}>{suggestion.title}</Button>)}</div></div> : null}</div>;
      if (stepName === 'Raw Text / Law Reference') return <Input value={violation.rawViolationText ?? violation.lawReference ?? ''} onChange={(event) => updateViolationDraft({ rawViolationText: event.target.value, lawReference: event.target.value })} placeholder="Raw text or law reference, if needed" />;
      return <Textarea value={violation.description ?? ''} onChange={(event) => updateViolationDraft({ description: event.target.value })} placeholder="Remarks or description, if needed" />;
    }
    if (caseModal.kind === 'place' && caseModal.place) {
      const place = caseModal.place;
      if (stepName === 'Address Type') return <Select value={place.addressTypeId ? place.addressTypeId.toString() : ''} onValueChange={(value) => updatePlaceDraft({ addressTypeId: toNumber(value) })}><SelectTrigger><SelectValue placeholder="Select type" /></SelectTrigger><SelectContent>{lookups.addressTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.display_label}</SelectItem>)}</SelectContent></Select>;
      if (stepName === 'Search Existing Address') return <div className="space-y-3"><Input value={place.suggestionQuery} placeholder="Type street, barangay, city, province, or region" onChange={(event) => { updatePlaceDraft({ suggestionQuery: event.target.value, existingAddressId: null }); loadAddressSuggestions(place.id, event.target.value); }} />{addressSuggestions[place.id]?.length ? <div className="rounded-md border bg-background p-2 text-sm shadow-sm"><p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing address suggestions</p><div className="flex flex-wrap gap-2">{addressSuggestions[place.id].map((suggestion) => <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyPlaceDraftSuggestion(suggestion)}>{formatAddress(suggestion) || `Address #${suggestion.id}`}</Button>)}</div></div> : null}</div>;
      const key = stepName === 'Line 1' ? 'line1' : stepName === 'Line 2' ? 'line2' : stepName === 'ZIP Code' ? 'zipCode' : stepName.toLowerCase() as keyof AddressEntry;
      return <Input value={(place as any)[key] ?? ''} onChange={(event) => updatePlaceDraft({ [key]: event.target.value } as Partial<AddressEntry>)} placeholder={`${stepName} or skip`} />;
    }
    return null;
  };

  const caseModalTitle = caseModal?.kind === 'docket' ? 'Docket Information' : caseModal?.kind === 'violation' ? 'Violation' : caseModal?.kind === 'procedure' ? 'Procedure and Summary' : caseModal?.kind === 'place' ? 'Place of Commission' : 'Assignment';

  return (
    <div className="p-4 md:p-8">
      <div className="mx-auto flex w-full max-w-4xl flex-col gap-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-foreground">New Docket Entry</h1>
            <p className="mt-1 text-muted-foreground">Register a new docket with its case details, participants, and violations.</p>
          </div>
          {/* TODO: Remove debug Fill Test Data button before production hardening. */}
          {isDevelopment ? (
            <Button type="button" variant="outline" size="sm" onClick={fillTestData} disabled={isLoadingLookups || !defaultRoleId || !defaultAddressTypeId}>
              Fill Test Data
            </Button>
          ) : null}
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
              <div className="rounded-lg border border-primary/20 bg-primary/5 p-4">
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Generated docket number</p>
                <p className="mt-1 text-2xl font-bold tracking-tight text-primary">
                  {isLoadingNextDocket ? 'Detecting next number…' : generatedDocketNumber}
                </p>
              </div>

              <section className="overflow-hidden rounded-lg border">
                <header className="flex items-center gap-2 border-b bg-muted/40 px-4 py-3">
                  <FileText className="h-4 w-4 text-primary" />
                  <h3 className="text-sm font-semibold uppercase tracking-wide">Docket information</h3>
                </header>
                <div className="space-y-3 p-4">
                  <div className="rounded-lg border p-4 text-sm">
                    <div className="grid gap-2 md:grid-cols-2">
                      <p><strong>Docket type:</strong> {selectedDocketType ? `${selectedDocketType.prefix} — ${selectedDocketType.name}` : '—'}</p>
                      <p><strong>Docket year:</strong> {docketYear || '—'}</p>
                      <p><strong>Date received:</strong> {dateReceived || '—'}</p>
                      <p><strong>Region:</strong> {regionCode || '—'}</p>
                      <p><strong>Case classification:</strong> {selectedCaseClassification?.display_label ?? '—'}</p>
                      <p><strong>Received description:</strong> {shortPreview(caseReceivedDescription)}</p>
                      <p className="md:col-span-2"><strong>Case notes:</strong> {shortPreview(notes)}</p>
                    </div>
                  </div>
                  <Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('docket')}>
                    {docketTypeId && docketYear && dateReceived ? 'Edit Docket Information' : 'Add Docket Information'}
                  </Button>
                </div>
              </section>

              <section className="overflow-hidden rounded-lg border">
                <header className="flex items-center justify-between gap-2 border-b bg-muted/40 px-4 py-3">
                  <div className="flex items-center gap-2"><Gavel className="h-4 w-4 text-primary" /><h3 className="text-sm font-semibold uppercase tracking-wide">Violations</h3></div>
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

              <section className="overflow-hidden rounded-lg border">
                <header className="flex items-center gap-2 border-b bg-muted/40 px-4 py-3">
                  <ClipboardList className="h-4 w-4 text-primary" />
                  <h3 className="text-sm font-semibold uppercase tracking-wide">Procedure &amp; summary</h3>
                </header>
                <div className="space-y-3 p-4">
                  <div className="rounded-lg border p-4 text-sm">
                    <p><strong>Summary procedure case:</strong> {isSummaryProcedure ? 'Yes' : 'No'}</p>
                    <p><strong>Summary:</strong> {shortPreview(summaryText)}</p>
                    <p><strong>Remarks:</strong> {shortPreview(remarks)}</p>
                  </div>
                  <Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('procedure')}>
                    {summaryText || remarks || isSummaryProcedure ? 'Edit Procedure and Summary' : 'Add Procedure and Summary'}
                  </Button>
                </div>
              </section>

              <section className="overflow-hidden rounded-lg border">
                <header className="flex items-center justify-between gap-2 border-b bg-muted/40 px-4 py-3">
                  <div className="flex items-center gap-2"><MapPin className="h-4 w-4 text-primary" /><h3 className="text-sm font-semibold uppercase tracking-wide">Places of commission</h3></div>
                  <Button type="button" onClick={() => openCaseModal('place')} variant="outline" size="sm" disabled={!defaultAddressTypeId}><Plus className="mr-2 h-4 w-4" /> Add place</Button>
                </header>
                <div className="space-y-3 p-4">
                  {placesOfCommission.length === 0 ? <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No place of commission added yet</div> : null}
                  {placesOfCommission.map((place) => <div key={place.id} className="rounded-lg border p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div><p className="font-medium">{formatAddressLike(place) || place.selectedExistingLabel || 'Unspecified address'}</p>{place.remarks ? <p className="mt-1 text-xs text-muted-foreground">{place.remarks}</p> : null}</div>
                      <div className="flex gap-2"><Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('place', place.id)}>Edit</Button><Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => setPlacesOfCommission((current) => current.filter((item) => item.id !== place.id))}>Remove</Button></div>
                    </div>
                  </div>)}
                </div>
              </section>

              <section className="overflow-hidden rounded-lg border">
                <header className="flex items-center gap-2 border-b bg-muted/40 px-4 py-3">
                  <UserCog className="h-4 w-4 text-primary" />
                  <h3 className="text-sm font-semibold uppercase tracking-wide">Assignment</h3>
                </header>
                <div className="space-y-3 p-4">
                  <div className="rounded-lg border p-4 text-sm">
                    <p><strong>Case also raffled:</strong> {caseAlsoRaffled ? 'Yes' : 'No'}</p>
                    <p><strong>Assigned prosecutor:</strong> {selectedProsecutor?.short_name ?? selectedProsecutor?.full_name ?? '—'}</p>
                    <p><strong>Assignment remarks:</strong> {shortPreview(caseAlsoRaffled ? assignmentRemarks : '')}</p>
                  </div>
                  <Button type="button" variant="outline" size="sm" onClick={() => openCaseModal('assignment')}>
                    {caseAlsoRaffled || assignedProsecutorId ? 'Edit Assignment' : 'Add Assignment'}
                  </Button>
                </div>
              </section>

              <Dialog open={Boolean(caseModal)} onOpenChange={(open) => !open && setCaseModal(null)}>
                <DialogContent>
                  <DialogHeader><DialogTitle>{caseModalTitle}</DialogTitle><DialogDescription>Step {(caseModal?.step ?? 0) + 1} of {caseModalSteps.length}: {caseModalSteps[caseModal?.step ?? 0]}. Nullable fields can be skipped.</DialogDescription></DialogHeader>
                  <div className="space-y-2"><Label>{caseModalSteps[caseModal?.step ?? 0]}</Label>{renderCaseModalField()}</div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={() => setCaseModal(null)}>Cancel</Button>
                    {caseModal && caseModal.step > 0 ? <Button type="button" variant="outline" onClick={() => setCaseModal((current) => current ? { ...current, step: current.step - 1 } : current)}>Back</Button> : null}
                    {isCaseModalFinalStep ? <Button type="button" onClick={saveCaseModal}>OK</Button> : <Button type="button" onClick={() => setCaseModal((current) => current ? { ...current, step: Math.min(current.step + 1, caseModalSteps.length - 1) } : current)}>Next / Skip</Button>}
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <div className="flex justify-end border-t pt-4">
                <Button onClick={() => setActiveTab('persons')}>Continue to Participants</Button>
              </div>
            </TabsContent>

            <TabsContent value="persons" className="space-y-4">
              <section className="overflow-hidden rounded-lg border">
                <header className="border-b bg-muted/40 px-4 py-3">
                  <div className="flex items-center gap-2">
                    <Users className="h-4 w-4 text-primary" />
                    <div>
                      <h3 className="text-sm font-semibold uppercase tracking-wide">Case participants</h3>
                      <p className="text-xs font-normal normal-case text-muted-foreground">Add participants through progressive dialogs. No participant fields appear directly on this tab.</p>
                    </div>
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
                                <div><p className="font-medium">{person.participantKind === 'ORGANIZATION' ? (cleanString(person.organizationName) || 'Unnamed organization') : buildLegalNamePreview(person)}</p><p className="text-xs text-muted-foreground">{person.participantKind === 'ORGANIZATION' ? 'Organization participant' : 'Person participant'}</p></div>
                                <Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => setPersons((current) => current.filter((item) => item.id !== person.id))}><X className="h-4 w-4" /></Button>
                              </div>
                              <div className="mt-3 flex flex-wrap gap-2">
                                <Button type="button" variant="outline" size="sm" onClick={() => openAddOnDialog(person.id, 'alias')}>Add Alias</Button>
                                <Button type="button" variant="outline" size="sm" onClick={() => openAddOnDialog(person.id, 'address')}>Add Address</Button>
                                <Button type="button" variant="outline" size="sm" onClick={() => openAddOnDialog(person.id, 'contact')}>Add Contact Info</Button>
                              </div>
                              {(person.aliases?.length || person.addresses?.length || person.contactInformations?.length) ? <p className="mt-2 text-xs text-muted-foreground">{person.aliases?.length ?? 0} aliases · {person.addresses?.length ?? 0} addresses · {person.contactInformations?.length ?? 0} contacts</p> : null}
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </section>

              <Dialog open={Boolean(participantDialog)} onOpenChange={(open) => !open && setParticipantDialog(null)}>
                <DialogContent>
                  <DialogHeader><DialogTitle>Add {participantDialog?.role}</DialogTitle><DialogDescription>Step {(participantDialog?.step ?? 0) + 1} of {participantSteps.length}: {participantSteps[participantDialog?.step ?? 0]}. Nullable fields can be skipped.</DialogDescription></DialogHeader>
                  <div className="space-y-2"><Label>{participantSteps[participantDialog?.step ?? 0]}</Label>{renderParticipantDraftField()}</div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={() => setParticipantDialog(null)}>Cancel</Button>
                    {participantDialog && participantDialog.step > 0 ? <Button type="button" variant="outline" onClick={() => setParticipantDialog((current) => current ? { ...current, step: current.step - 1 } : current)}>Back</Button> : null}
                    {isParticipantFinalStep ? <Button type="button" onClick={saveParticipantDialog}>OK</Button> : <Button type="button" onClick={() => setParticipantDialog((current) => current ? { ...current, step: Math.min(current.step + 1, participantSteps.length - 1) } : current)}>Next / Skip</Button>}
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <Dialog open={Boolean(addOnDialog)} onOpenChange={(open) => !open && setAddOnDialog(null)}>
                <DialogContent>
                  <DialogHeader><DialogTitle>Add {addOnDialog?.kind === 'alias' ? 'Alias' : addOnDialog?.kind === 'address' ? 'Address' : 'Contact Info'}</DialogTitle><DialogDescription>Progressive entry with one nullable field at a time.</DialogDescription></DialogHeader>
                  <div className="space-y-2"><Label>{addOnDialog ? (addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps)[addOnDialog.step] : ''}</Label>{renderAddOnField()}</div>
                  <DialogFooter>
                    <Button type="button" variant="outline" onClick={() => setAddOnDialog(null)}>Cancel</Button>
                    {addOnDialog && addOnDialog.step > 0 ? <Button type="button" variant="outline" onClick={() => setAddOnDialog((current) => current ? { ...current, step: current.step - 1 } : current)}>Back</Button> : null}
                    {addOnDialog && addOnDialog.step >= (addOnDialog.kind === 'alias' ? aliasWorkflowSteps : addOnDialog.kind === 'address' ? addressWorkflowSteps : contactWorkflowSteps).length - 1 ? <Button type="button" onClick={saveAddOnDialog}>OK</Button> : <Button type="button" onClick={() => setAddOnDialog((current) => current ? { ...current, step: current.step + 1 } : current)}>Next / Skip</Button>}
                  </DialogFooter>
                </DialogContent>
              </Dialog>

              <div className="flex flex-col-reverse gap-3 border-t pt-4 sm:flex-row sm:justify-between">
                <Button onClick={() => setActiveTab('case-info')} variant="outline">Back to Case</Button>
                <Button onClick={() => setActiveTab('review')}>Continue to Review</Button>
              </div>
            </TabsContent>

            <TabsContent value="review" className="space-y-4">
              <Card className="bg-muted/20">
                <CardHeader>
                  <CardTitle className="text-base">Review before submission</CardTitle>
                  <CardDescription>Preview only: the official docket number is returned by the database after save.</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3 text-sm">
                  <p><strong>Preview docket:</strong> {generatedDocketNumber}</p>
                  <p><strong>Case:</strong> Received {dateReceived}; region {regionCode || '—'}; month {docketMonthCode}; prosecutor {selectedProsecutor?.short_name ?? selectedProsecutor?.full_name ?? 'Not assigned'}</p>
                  <div><strong>Participants:</strong>{persons.length ? persons.map((person) => <div key={person.id}>• {person.participantKind === 'ORGANIZATION' ? (person.existingOrganizationId ? `Existing organization #${person.existingOrganizationId}: ${person.selectedExistingOrganizationName}` : `New organization: ${person.organizationName || 'Unnamed'}${(person.organizationDetails ?? []).some((detail) => detail.fieldTitle.trim() || detail.fieldValue.trim()) ? ' (custom details included)' : ''}`) : (person.existingPersonId ? `Existing person #${person.existingPersonId}: ${person.selectedExistingName}` : `New person: ${buildPersonFullName(person)}`)}</div>) : ' none'}</div>
                  <div><strong>Places of commission:</strong>{placesOfCommission.length ? placesOfCommission.map((placeOfCommission) => <div key={placeOfCommission.id}>• {placeOfCommission.existingAddressId ? `Existing #${placeOfCommission.existingAddressId}: ${placeOfCommission.selectedExistingLabel}` : ['New', placeOfCommission.line1, placeOfCommission.barangay, placeOfCommission.city].filter(Boolean).join(' — ')}</div>) : ' none'}</div>
                  <div><strong>Violations:</strong>{violations.length ? violations.map((violation) => <div key={violation.id}>• {violation.existingViolationId ? `Existing #${violation.existingViolationId}: ${violation.selectedExistingTitle}` : `New: ${violation.newViolationTitle || violation.searchText || 'Untitled'}`}</div>) : ' none'}</div>
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
