'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlertCircle, CheckCircle2, Loader2, Plus, Search, Settings2, X } from 'lucide-react';

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
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
  const [violations, setViolations] = useState<ViolationEntry[]>([{ id: makeId('violation'), existingViolationId: null, violationOrder: 1, rawViolationText: '', searchText: '', createNew: true }]);
  const [personSuggestions, setPersonSuggestions] = useState<Record<string, PersonDetailsSearchRow[]>>({});
  const [organizationSuggestions, setOrganizationSuggestions] = useState<Record<string, OrganizationDetailsSearchRow[]>>({});
  const [addressSuggestions, setAddressSuggestions] = useState<Record<string, TableRow<'addresses'>[]>>({});
  const [violationSuggestions, setViolationSuggestions] = useState<Record<string, TableRow<'violations'>[]>>({});

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

  const addPerson = () => {
    setPersons((current) => [
      ...current,
      {
        id: makeId('person'),
        firstName: '',
        middleName: '',
        lastName: '',
        suffix: '',
        gender: 'Unspecified',
        age: '',
        birthDate: '',
        roleId: toNumber(defaultRoleId),
        participantOrder: current.length + 1,
        remarks: '',
        sourceDetail: '',
        participantKind: 'PERSON',
        aliases: [],
        addresses: [],
        contactInformations: [],
      },
    ]);
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

              <div className="space-y-4 rounded-lg border p-4">
                <h3 className="font-semibold">Docket information</h3>

                <div className="grid gap-4 md:grid-cols-2">
                  <div>
                    <Label htmlFor="docket-type">Docket Type *</Label>
                    <Select value={docketTypeId} onValueChange={setDocketTypeId} disabled={isLoadingLookups}>
                      <SelectTrigger id="docket-type" className="mt-1">
                        <SelectValue placeholder="Select docket type" />
                      </SelectTrigger>
                      <SelectContent>
                        {lookups.docketTypes.map((type) => (
                          <SelectItem key={type.id} value={type.id.toString()}>
                            {type.prefix} — {type.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label htmlFor="docket-year">Docket Year *</Label>
                    <Input id="docket-year" type="number" value={docketYear} onChange={(event) => setDocketYear(event.target.value)} className="mt-1" />
                  </div>
                  <div>
                    <Label htmlFor="date-received">Date Received *</Label>
                    <Input id="date-received" type="date" value={dateReceived} onChange={(event) => setDateReceived(event.target.value)} className="mt-1" />
                  </div>
                  <div>
                    <Label htmlFor="region-code">Region</Label>
                    <Input id="region-code" value={regionCode} onChange={(event) => setRegionCode(event.target.value)} className="mt-1" />
                  </div>
                  <div>
                    <Label htmlFor="case-classification">Case Classification</Label>
                    <Select value={caseClassificationId || 'none'} onValueChange={(value) => setCaseClassificationId(value === 'none' ? '' : value)} disabled={isLoadingLookups}>
                      <SelectTrigger id="case-classification" className="mt-1"><SelectValue placeholder="Select classification" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">No classification</SelectItem>
                        {lookups.caseClassifications.map((classification) => <SelectItem key={classification.id} value={classification.id.toString()}>{classification.display_label}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="md:col-span-2">
                    <Label htmlFor="case-received-description">Case Received Description</Label>
                    <Textarea
                      id="case-received-description"
                      value={caseReceivedDescription}
                      onChange={(event) => {
                        setIsCaseReceivedDescriptionEdited(true);
                        setCaseReceivedDescription(event.target.value);
                      }}
                      className="mt-1 min-h-20"
                      placeholder={formatCaseReceivedDefaultDescription(dateReceived)}
                    />
                  </div>

                  <div className="md:col-span-2">
                    <Label htmlFor="notes">Case notes</Label>
                    <Textarea id="notes" placeholder="Optional case note stored in notes table" value={notes} onChange={(event) => setNotes(event.target.value)} className="mt-1" />
                  </div>
                </div>
              </div>

              <div className="space-y-4 rounded-lg border p-4">
                <h3 className="font-semibold">Violations</h3>

                <div className="space-y-3">
                  {violations.map((violation, index) => (
                    <div key={violation.id} className="space-y-3 rounded-lg border p-4">
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex-1">
                          <Label className="text-xs">Violation #{index + 1} *</Label>
                          <Input value={violation.searchText} placeholder="Type a violation, law reference, or code" onChange={(event) => { updateViolation(violation.id, { searchText: event.target.value, existingViolationId: null, selectedExistingTitle: null, createNew: true, newViolationTitle: event.target.value }); loadViolationSuggestions(violation.id, event.target.value); }} className="mt-1" />
                        </div>
                        <Button onClick={() => setViolations((current) => current.filter((item) => item.id !== violation.id))} variant="ghost" size="sm" className="mt-5 text-destructive"><X className="h-4 w-4" /></Button>
                      </div>

                      {violationSuggestions[violation.id]?.length ? (
                        <div className="rounded-md border bg-background p-2 text-sm shadow-sm">
                          <p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Violation suggestions</p>
                          <div className="flex flex-wrap gap-2">
                            {violationSuggestions[violation.id].map((suggestion) => (
                              <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyViolationSuggestion(violation.id, suggestion)}>
                                {suggestion.title}
                              </Button>
                            ))}
                          </div>
                        </div>
                      ) : null}

                      {violation.existingViolationId ? <span className="inline-flex rounded-full bg-muted px-2 py-1 text-xs text-muted-foreground">Existing violation #{violation.existingViolationId}: {violation.selectedExistingTitle}</span> : null}
                    </div>
                  ))}
                </div>

                <Button onClick={addViolation} variant="outline" size="sm">
                  <Plus className="mr-2 h-4 w-4" /> Add another violation
                </Button>
              </div>

              <div className="space-y-4 rounded-lg border p-4">
                <h3 className="font-semibold">Procedure &amp; summary</h3>

                <label className="flex items-center gap-2 text-sm font-medium">
                  <Checkbox id="summary-procedure" checked={isSummaryProcedure} onCheckedChange={(checked) => setIsSummaryProcedure(checked === true)} />
                  Summary procedure case
                </label>

                <div className="grid gap-4 md:grid-cols-2">
                  <div>
                    <Label htmlFor="summary-text">Summary</Label>
                    <Textarea id="summary-text" placeholder="Case summary stored in summary_text" value={summaryText} onChange={(event) => setSummaryText(event.target.value)} className="mt-1" />
                  </div>

                  <div>
                    <Label htmlFor="remarks">Remarks</Label>
                    <Textarea id="remarks" placeholder="Optional summary procedure remarks" value={remarks} onChange={(event) => setRemarks(event.target.value)} className="mt-1" />
                  </div>
                </div>
              </div>


              <div className="space-y-4 rounded-lg border p-4">
                <div className="flex items-center justify-between">
                  <h3 className="font-semibold">Addresses (places of commission)</h3>
                  <Button onClick={addAddress} variant="outline" size="sm" disabled={!defaultAddressTypeId}>
                    <Plus className="mr-2 h-4 w-4" /> Add Place
                  </Button>
              </div>

              {placesOfCommission.length === 0 ? (
                <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No place of commission added yet</div>
              ) : (
                placesOfCommission.map((placeOfCommission, index) => (
                <div key={placeOfCommission.id} className="space-y-3 rounded-lg border p-4">
                  <div className="flex items-start justify-between gap-4">
                    <div className="grid flex-1 grid-cols-1 gap-3 md:grid-cols-[14rem_1fr]">
                      <p className="md:col-span-2 text-sm font-medium">Place #{index + 1}</p>
                      <div>
                        <Label className="text-xs">Address Type *</Label>
                        <Select value={placeOfCommission.addressTypeId ? placeOfCommission.addressTypeId.toString() : ''} onValueChange={(value) => updateAddress(placeOfCommission.id, { addressTypeId: toNumber(value) })}>
                          <SelectTrigger className="mt-1"><SelectValue placeholder="Select type" /></SelectTrigger>
                          <SelectContent>{lookups.addressTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.display_label}</SelectItem>)}</SelectContent>
                        </Select>
                      </div>
                      <div><Label className="text-xs">Search Existing Address</Label><Input value={placeOfCommission.suggestionQuery} placeholder="Type street, barangay, city, province, or region" onChange={(event) => { updateAddress(placeOfCommission.id, { suggestionQuery: event.target.value, existingAddressId: null }); loadAddressSuggestions(placeOfCommission.id, event.target.value); }} className="mt-1" /></div>
                    </div>
                    <Button onClick={() => setPlacesOfCommission((current) => current.filter((address) => address.id !== placeOfCommission.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                  </div>

                  {addressSuggestions[placeOfCommission.id]?.length ? (
                    <div className="rounded-md border bg-background p-2 text-sm shadow-sm">
                      <p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing address suggestions</p>
                      <div className="flex flex-wrap gap-2">
                        {addressSuggestions[placeOfCommission.id].map((suggestion) => (
                          <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyAddressSuggestion(placeOfCommission.id, suggestion)}>
                            {formatAddress(suggestion) || `Address #${suggestion.id}`}
                          </Button>
                        ))}
                      </div>
                    </div>
                  ) : null}

                  <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
                    <div><Label className="text-xs">Line 1</Label><Input value={placeOfCommission.line1 ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { line1: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">Line 2</Label><Input value={placeOfCommission.line2 ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { line2: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">Barangay</Label><Input value={placeOfCommission.barangay ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { barangay: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">City</Label><Input value={placeOfCommission.city ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { city: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">Province</Label><Input value={placeOfCommission.province ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { province: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">Region</Label><Input value={placeOfCommission.region ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { region: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">ZIP Code</Label><Input value={placeOfCommission.zipCode ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { zipCode: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div><Label className="text-xs">Country</Label><Input value={placeOfCommission.country ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { country: event.target.value, existingAddressId: null })} className="mt-1" /></div>
                    <div className="md:col-span-4"><Label className="text-xs">Remarks</Label><Input value={placeOfCommission.remarks ?? ''} onChange={(event) => updateAddress(placeOfCommission.id, { remarks: event.target.value })} className="mt-1" /></div>
                  </div>
                </div>
                ))
              )}
 
              </div>

              <div className="space-y-4 rounded-lg border p-4">
                <h3 className="font-semibold">Assignment</h3>

                <label className="flex items-center gap-2 text-sm font-medium">
                  <Checkbox id="case-also-raffled" checked={caseAlsoRaffled} onCheckedChange={(checked) => setCaseAlsoRaffled(checked === true)} />
                  Case also raffled
                </label>

                {caseAlsoRaffled ? (
                  <div className="grid gap-4 md:grid-cols-2">
                    <div>
                      <Label htmlFor="assigned-prosecutor">Prosecutor</Label>
                      <Select value={assignedProsecutorId || 'none'} onValueChange={(value) => setAssignedProsecutorId(value === 'none' ? '' : value)} disabled={isLoadingLookups}>
                        <SelectTrigger id="assigned-prosecutor" className="mt-1">
                          <SelectValue placeholder="Select prosecutor" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none">No prosecutor selected</SelectItem>
                          {lookups.prosecutors.map((prosecutor) => (
                            <SelectItem key={prosecutor.id} value={prosecutor.id.toString()}>
                              {prosecutor.short_name ?? prosecutor.full_name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <Label htmlFor="assignment-remarks">Assignment remarks</Label>
                      <Input
                        id="assignment-remarks"
                        value={assignmentRemarks}
                        onChange={(event) => setAssignmentRemarks(event.target.value)}
                        placeholder="Optional assignment remarks"
                        className="mt-1"
                      />
                      <p className="mt-1 text-xs text-muted-foreground">Leave blank to save no assignment remark. Assignment date defaults to the docket received date.</p>
                    </div>
                  </div>
                ) : (
                  <p className="text-xs text-muted-foreground">Enable &ldquo;Case also raffled&rdquo; to assign a prosecutor and add assignment remarks.</p>
                )}
              </div>

              <div className="flex justify-end border-t pt-4">
                <Button onClick={() => setActiveTab('persons')}>Continue to Participants</Button>
              </div>
            </TabsContent>

            <TabsContent value="persons" className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">Case Participants</h3>
                  <p className="text-sm text-muted-foreground">Search existing persons while typing, or enter a new person.</p>
                </div>
                <Button onClick={addPerson} variant="outline" size="sm" disabled={!defaultRoleId}>
                  <Plus className="mr-2 h-4 w-4" /> Add Participant
                </Button>
              </div>

              {persons.length === 0 ? (
                <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No participants added yet</div>
              ) : (
                <div className="space-y-4">
                  {persons.map((person) => (
                    <div key={person.id} className="space-y-3 rounded-lg border p-4">
                      <div className="flex items-start justify-between gap-4">
                        <div className="grid flex-1 grid-cols-1 gap-3 md:grid-cols-4">
                          <div><Label className="text-xs">Type</Label><Select value={person.participantKind ?? 'PERSON'} onValueChange={(value) => switchParticipantKind(person.id, value as 'PERSON' | 'ORGANIZATION')}><SelectTrigger className="mt-1"><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PERSON">Person</SelectItem><SelectItem value="ORGANIZATION">Organization</SelectItem></SelectContent></Select></div>
                          {person.participantKind !== 'ORGANIZATION' ? <>
                          <div><Label className="text-xs">First Name *</Label><Input value={person.firstName ?? ''} onChange={(event) => { updatePerson(person.id, clearSelectedPersonData(person, { firstName: event.target.value })); }} className="mt-1" /></div>
                          <div>
                            <div className="flex items-center justify-between gap-2">
                              <Label className="text-xs">Middle Name</Label>
                              <label className="flex items-center gap-1 text-[11px] text-muted-foreground">
                                <Checkbox checked={person.noMiddleName === true} onCheckedChange={(checked) => updatePerson(person.id, clearSelectedPersonData(person, { noMiddleName: checked === true, middleName: checked === true ? 'NMN' : '' }))} />
                                No Middle Name
                              </label>
                            </div>
                            <Input value={person.noMiddleName ? 'NMN' : (person.middleName ?? '')} disabled={person.noMiddleName === true} onChange={(event) => updatePerson(person.id, clearSelectedPersonData(person, { middleName: event.target.value, noMiddleName: false }))} className="mt-1" />
                          </div>
                          <div><Label className="text-xs">Last Name *</Label><Input value={person.lastName ?? ''} onChange={(event) => { updatePerson(person.id, clearSelectedPersonData(person, { lastName: event.target.value })); }} className="mt-1" /></div>
                          <div><Label className="text-xs">Suffix</Label><Input value={person.suffix ?? ''} onChange={(event) => updatePerson(person.id, clearSelectedPersonData(person, { suffix: event.target.value }))} className="mt-1" /></div>
                          </> : <>
                          <div className="md:col-span-3"><Label className="text-xs">Organization Name *</Label><Input value={person.organizationName ?? ''} onChange={(event) => { updatePerson(person.id, clearSelectedOrganizationData({ organizationName: event.target.value })); }} className="mt-1" /></div>
                          <div><Label className="text-xs">Contact Person</Label><Input value={person.contactPerson ?? ''} onChange={(event) => updatePerson(person.id, person.existingOrganizationId ? clearSelectedOrganizationData({ contactPerson: event.target.value }) : { contactPerson: event.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Contact Number</Label><Input value={person.contactNumber ?? ''} onChange={(event) => updatePerson(person.id, person.existingOrganizationId ? clearSelectedOrganizationData({ contactNumber: event.target.value }) : { contactNumber: event.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Email</Label><Input value={person.email ?? ''} onChange={(event) => updatePerson(person.id, person.existingOrganizationId ? clearSelectedOrganizationData({ email: event.target.value }) : { email: event.target.value })} className="mt-1" /></div>
                          <div className="md:col-span-4"><Button type="button" variant={person.showOrganizationDetails ? 'default' : 'outline'} size="sm" className="mt-1 w-full justify-start font-semibold" onClick={() => updatePerson(person.id, { showOrganizationDetails: !person.showOrganizationDetails, organizationDetails: person.organizationDetails?.length ? person.organizationDetails : [{ id: makeId('organization-detail'), fieldTitle: '', fieldValue: '' }] })}><Settings2 className="mr-2 h-4 w-4" /> Custom organization details</Button></div>
                          {person.showOrganizationDetails ? <div className="space-y-3 rounded-md bg-muted/40 p-3 md:col-span-4"><div className="flex items-center justify-between gap-2"><div><Label className="text-xs">Custom organization details</Label><p className="text-[11px] text-muted-foreground">Add field titles and values. These are saved to organizations.details_jsonb.</p></div><Button type="button" variant="outline" size="sm" onClick={() => updatePerson(person.id, { organizationDetails: [...(person.organizationDetails ?? []), { id: makeId('organization-detail'), fieldTitle: '', fieldValue: '' }] })}>+ Add custom field</Button></div>{(person.organizationDetails ?? []).length === 0 ? <p className="text-xs text-muted-foreground">No custom organization fields added.</p> : null}{(person.organizationDetails ?? []).map((detail) => <div key={detail.id} className="grid grid-cols-1 gap-2 rounded-md border bg-background p-3 md:grid-cols-[1fr_1fr_auto]"><div><Label className="text-xs">Field title</Label><Input value={detail.fieldTitle} placeholder="e.g. Accreditation" onChange={(event) => updatePerson(person.id, { organizationDetails: (person.organizationDetails ?? []).map((item) => item.id === detail.id ? { ...item, fieldTitle: event.target.value } : item) })} className="mt-1" /></div><div><Label className="text-xs">Field value</Label><Input value={detail.fieldValue} placeholder="e.g. ACC-12345" onChange={(event) => updatePerson(person.id, { organizationDetails: (person.organizationDetails ?? []).map((item) => item.id === detail.id ? { ...item, fieldValue: event.target.value } : item) })} className="mt-1" /></div><Button type="button" variant="ghost" size="sm" className="self-end text-destructive" onClick={() => updatePerson(person.id, { organizationDetails: (person.organizationDetails ?? []).filter((item) => item.id !== detail.id) })}><X className="h-4 w-4" /></Button></div>)}</div> : null}
                          </>}
                        </div>
                        <Button onClick={() => setPersons((current) => current.filter((item) => item.id !== person.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                      </div>

                      <p className="text-xs text-muted-foreground">
                        {person.participantKind === 'ORGANIZATION' ? (person.existingOrganizationId ? `Existing organization #${person.existingOrganizationId}: ${person.selectedExistingOrganizationName}` : `New organization preview: ${cleanString(person.organizationName) || 'Enter organization name'}`) : (person.existingPersonId ? `Existing person #${person.existingPersonId}: ${person.selectedExistingName}` : `New person preview: ${buildPersonFullName(person) || 'Enter at least one name component'}`)}
                      </p>

                      {organizationSuggestions[person.id]?.length ? (
                        <div className="rounded-md border bg-background p-2 text-sm shadow-sm">
                          <p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing organization suggestions</p>
                          <div className="flex flex-wrap gap-2">
                            {organizationSuggestions[person.id].map((suggestion) => (
                              <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyOrganizationSuggestion(person.id, suggestion)}>
                                {suggestion.organization_name}
                              </Button>
                            ))}
                          </div>
                        </div>
                      ) : null}

                      {personSuggestions[person.id]?.length ? (
                        <div className="rounded-md border bg-background p-2 text-sm shadow-sm">
                          <p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing person suggestions</p>
                          <div className="flex flex-wrap gap-2">
                            {personSuggestions[person.id].map((suggestion) => (
                              <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyPersonSuggestion(person.id, suggestion)}>
                                {suggestion.full_name}
                              </Button>
                            ))}
                          </div>
                        </div>
                      ) : null}

                      <div className="space-y-3 rounded-md bg-muted/40 p-3">
                        <div className="flex items-center justify-between"><Label className="text-xs">Contact numbers / email</Label><Button type="button" variant="outline" size="sm" onClick={() => addParticipantContact(person.id)}>+ Add Contact</Button></div>
                        {(person.contactInformations ?? []).length === 0 ? <p className="text-xs text-muted-foreground">No participant contacts added.</p> : null}
                        {(person.contactInformations ?? []).map((contact) => <div key={contact.id} className="grid grid-cols-1 gap-2 rounded-md border bg-background p-3 md:grid-cols-[9rem_1fr_1fr_auto]"><div><Label className="text-xs">Type</Label><Select value={contact.contactType} onValueChange={(value) => updateParticipantContact(person.id, contact.id, { contactType: value as 'PHONE' | 'EMAIL' | 'OTHER' })}><SelectTrigger className="mt-1"><SelectValue /></SelectTrigger><SelectContent><SelectItem value="PHONE">Phone</SelectItem><SelectItem value="EMAIL">Email</SelectItem><SelectItem value="OTHER">Other</SelectItem></SelectContent></Select></div><div><Label className="text-xs">Contact value</Label><Input value={contact.contactValue ?? ''} placeholder={contact.contactType === 'EMAIL' ? 'name@example.com' : 'Phone number'} onChange={(event) => updateParticipantContact(person.id, contact.id, { contactValue: event.target.value })} className="mt-1" /></div><div><Label className="text-xs">Label</Label><Input value={contact.label ?? ''} placeholder="Mobile, office, email" onChange={(event) => updateParticipantContact(person.id, contact.id, { label: event.target.value })} className="mt-1" /></div><Button type="button" variant="ghost" size="sm" className="self-end text-destructive" onClick={() => updatePerson(person.id, { contactInformations: (person.contactInformations ?? []).filter((item) => item.id !== contact.id) })}><X className="h-4 w-4" /></Button><label className="flex items-center gap-2 text-xs"><Checkbox checked={contact.isPrimary === true} onCheckedChange={(checked) => updateParticipantContact(person.id, contact.id, { isPrimary: checked === true })} /> Primary</label><div className="md:col-span-3"><Label className="text-xs">Remarks</Label><Input value={contact.remarks ?? ''} onChange={(event) => updateParticipantContact(person.id, contact.id, { remarks: event.target.value })} className="mt-1" /></div></div>)}
                      </div>

                      <div className="space-y-2 rounded-md bg-muted/40 p-3"><div className="flex items-center justify-between"><div><Label className="text-xs">Aliases</Label>{(person.existingAliases ?? []).length ? <p className="text-[11px] text-muted-foreground">Existing: {(person.existingAliases ?? []).map((alias) => alias.aliasName).filter(Boolean).join(', ')}</p> : null}</div><Button type="button" variant="outline" size="sm" onClick={() => updatePerson(person.id, { aliases: [...(person.aliases ?? []), { id: makeId('alias'), aliasName: '' }] })}>+ Add Alias</Button></div>{(person.aliases ?? []).map((alias) => <Input key={alias.id} placeholder="New alias name" value={alias.aliasName ?? ''} onChange={(event) => updatePerson(person.id, { aliases: (person.aliases ?? []).map((item) => item.id === alias.id ? { ...item, id: item.id ?? makeId('alias'), aliasName: event.target.value } : { ...item, id: item.id ?? makeId('alias') }) as AliasEntry[] })} />)}</div>

                      <div className="space-y-3 rounded-md bg-muted/40 p-3"><div className="flex items-center justify-between"><Label className="text-xs">{person.participantKind === 'ORGANIZATION' ? 'Organization Addresses' : 'Addresses'}</Label><Button type="button" variant="outline" size="sm" onClick={() => addParticipantAddress(person.id)}>+ Add Address</Button></div>{(person.addresses ?? []).length === 0 ? <p className="text-xs text-muted-foreground">No participant addresses added.</p> : null}{(person.addresses ?? []).map((address) => <div key={address.id} className="space-y-2 rounded-md border bg-background p-3"><div className="flex items-start justify-between gap-3"><div className="grid flex-1 grid-cols-1 gap-2 md:grid-cols-[12rem_1fr]"><div><Label className="text-xs">Address Type</Label><Select value={address.addressTypeId ? address.addressTypeId.toString() : ''} onValueChange={(value) => updateParticipantAddress(person.id, address.id, { addressTypeId: toNumber(value), existingRelation: false })}><SelectTrigger className="mt-1"><SelectValue placeholder="Select type" /></SelectTrigger><SelectContent>{lookups.addressTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.display_label}</SelectItem>)}</SelectContent></Select></div><div><Label className="text-xs">Existing address or new address</Label><Input value={address.suggestionQuery ?? ''} placeholder="Search existing address" onChange={(event) => { updateParticipantAddress(person.id, address.id, { suggestionQuery: event.target.value, existingAddressId: null, existingRelation: false }); loadAddressSuggestions(address.id, event.target.value); }} className="mt-1" /></div></div><Button type="button" variant="ghost" size="sm" className="text-destructive" onClick={() => updatePerson(person.id, { addresses: (person.addresses ?? []).filter((item) => item.id !== address.id) as AddressEntry[] })}><X className="h-4 w-4" /></Button></div>{addressSuggestions[address.id]?.length ? <div className="rounded-md border bg-background p-2 text-sm shadow-sm"><p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing address suggestions</p><div className="flex flex-wrap gap-2">{addressSuggestions[address.id].map((suggestion) => <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyParticipantAddressSuggestion(person.id, address.id, suggestion)}>{formatAddress(suggestion) || `Address #${suggestion.id}`}</Button>)}</div></div> : null}<div className="grid grid-cols-1 gap-2 md:grid-cols-4"><div><Label className="text-xs">Line 1</Label><Input value={address.line1 ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { line1: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">Line 2</Label><Input value={address.line2 ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { line2: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">Barangay</Label><Input value={address.barangay ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { barangay: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">City</Label><Input value={address.city ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { city: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">Province</Label><Input value={address.province ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { province: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">Region</Label><Input value={address.region ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { region: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">ZIP Code</Label><Input value={address.zipCode ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { zipCode: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><div><Label className="text-xs">Country</Label><Input value={address.country ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { country: event.target.value, existingAddressId: null, existingRelation: false })} className="mt-1" /></div><label className="flex items-center gap-2 text-xs"><Checkbox checked={address.isPrimary === true} onCheckedChange={(checked) => updateParticipantAddress(person.id, address.id, { isPrimary: checked === true })} /> Primary</label><div className="md:col-span-3"><Label className="text-xs">Remarks</Label><Input value={address.remarks ?? ''} onChange={(event) => updateParticipantAddress(person.id, address.id, { remarks: event.target.value })} className="mt-1" /></div></div></div>)}</div>

                      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
                        <div>
                          <Label className="text-xs">Role *</Label>
                          <Select value={person.roleId ? person.roleId.toString() : ''} onValueChange={(value) => updatePerson(person.id, { roleId: toNumber(value) })}>
                            <SelectTrigger className="mt-1"><SelectValue placeholder="Select role" /></SelectTrigger>
                            <SelectContent>{lookups.participantRoles.map((role) => <SelectItem key={role.id} value={role.id.toString()}>{role.display_label}</SelectItem>)}</SelectContent>
                          </Select>
                        </div>
                        {person.participantKind !== 'ORGANIZATION' ? <>
                        <div>
                          <Label className="text-xs">Gender</Label>
                          <Select value={person.gender ?? 'Unspecified'} onValueChange={(value) => updatePerson(person.id, { gender: value })}>
                            <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                            <SelectContent>{genderOptions.map((gender) => <SelectItem key={gender} value={gender}>{gender}</SelectItem>)}</SelectContent>
                          </Select>
                        </div>
                        <div><Label className="text-xs">Birth Date</Label><Input type="date" value={person.birthDate ?? ''} onChange={(event) => updatePerson(person.id, { birthDate: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Age</Label><Input value={person.age ?? ''} onChange={(event) => updatePerson(person.id, { age: event.target.value })} className="mt-1" /></div>
                        <label className="flex items-center gap-2 self-end text-xs"><Checkbox checked={person.attributes?.isMinorAtCase === true} onCheckedChange={(checked) => updatePerson(person.id, { attributes: { ...(person.attributes ?? {}), isMinorAtCase: checked === true, minorText: checked === true ? 'YES' : null } })} /> Minor</label>
                        <label className="flex items-center gap-2 self-end text-xs"><Checkbox checked={person.attributes?.isSeniorAtCase === true} onCheckedChange={(checked) => updatePerson(person.id, { attributes: { ...(person.attributes ?? {}), isSeniorAtCase: checked === true, seniorText: checked === true ? 'YES' : null } })} /> Senior</label>
                        <label className="flex items-center gap-2 self-end text-xs"><Checkbox checked={person.attributes?.isPwdAtCase === true} onCheckedChange={(checked) => updatePerson(person.id, { attributes: { ...(person.attributes ?? {}), isPwdAtCase: checked === true, pwdText: checked === true ? 'YES' : null } })} /> PWD</label>
                        </> : null}
                        <div><Label className="text-xs">Remarks</Label><Input value={person.remarks ?? ''} onChange={(event) => updatePerson(person.id, { remarks: event.target.value })} className="mt-1" /></div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

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
