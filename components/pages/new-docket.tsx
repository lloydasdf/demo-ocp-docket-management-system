'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlertCircle, CheckCircle2, Loader2, Plus, Search, X } from 'lucide-react';

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
  getCurrentDatabaseUser,
  getDocketTypes,
  getNextDocketNumber,
  getParticipantRoles,
  getViolations,
  searchAddressSuggestions,
  searchPersons,
  searchViolationSuggestions,
  type DatabaseUserSummary,
  type NewDocketAddressInput,
  type NewDocketEntryInput,
  type NewDocketPersonInput,
  type NewDocketViolationInput,
} from '@/lib/supabase/queries';
import type { TableRow } from '@/lib/supabase/types';

type LookupState = {
  docketTypes: TableRow<'docket_types'>[];
  participantRoles: TableRow<'participant_roles'>[];
  addressTypes: TableRow<'address_types'>[];
  violations: TableRow<'violations'>[];
  statuses: TableRow<'case_statuses'>[];
};

type MessageState =
  | { type: 'success'; text: string; caseId?: number }
  | { type: 'error'; text: string }
  | null;

type PersonEntry = NewDocketPersonInput & { id: string };
type AddressEntry = NewDocketAddressInput & { id: string; suggestionQuery: string };
type ViolationEntry = NewDocketViolationInput & { id: string; searchText: string };

const emptyLookups: LookupState = {
  docketTypes: [],
  participantRoles: [],
  addressTypes: [],
  violations: [],
  statuses: [],
};

const thisYear = new Date().getFullYear();
const genderOptions = ['Female', 'Male', 'Other', 'Unspecified'];
const defaultRegionCode = 'IV-A';

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

  return date.toLocaleString('en-US', { month: 'short' }).toUpperCase();
}

function formatDocketNumber(prefix: string | undefined, year: string, number: number | null) {
  if (!prefix || !year || !number) {
    return 'Select docket type and date to preview';
  }

  return `${prefix}-${year}-${String(number).padStart(4, '0')}`;
}

function formatAddress(address: TableRow<'addresses'>) {
  return [address.line1, address.line2, address.barangay, address.city, address.province, address.region]
    .filter(Boolean)
    .join(', ');
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
  const [initialStatusId, setInitialStatusId] = useState('');
  const [regionCode, setRegionCode] = useState(defaultRegionCode);
  const [summaryText, setSummaryText] = useState('');
  const [remarks, setRemarks] = useState('');
  const [isSummaryProcedure, setIsSummaryProcedure] = useState(false);

  const [persons, setPersons] = useState<PersonEntry[]>([]);
  const [addresses, setAddresses] = useState<AddressEntry[]>([]);
  const [violations, setViolations] = useState<ViolationEntry[]>([]);
  const [personSuggestions, setPersonSuggestions] = useState<Record<string, TableRow<'persons'>[]>>({});
  const [addressSuggestions, setAddressSuggestions] = useState<Record<string, TableRow<'addresses'>[]>>({});
  const [violationSuggestions, setViolationSuggestions] = useState<Record<string, TableRow<'violations'>[]>>({});

  useEffect(() => {
    let isMounted = true;

    async function loadLookups() {
      setIsLoadingLookups(true);
      const [docketTypes, participantRoles, addressTypes, violationsResult, statuses, userResult] = await Promise.all([
        getDocketTypes(),
        getParticipantRoles(),
        getAddressTypes(),
        getViolations(500),
        getCaseStatuses(),
        getCurrentDatabaseUser(),
      ]);

      if (!isMounted) {
        return;
      }

      const firstError = [docketTypes, participantRoles, addressTypes, violationsResult, statuses, userResult].find(
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
  const selectedDocketType = useMemo(
    () => lookups.docketTypes.find((type) => type.id.toString() === docketTypeId),
    [docketTypeId, lookups.docketTypes],
  );
  const selectedStatus = useMemo(
    () => lookups.statuses.find((status) => status.id.toString() === initialStatusId),
    [initialStatusId, lookups.statuses],
  );
  const generatedDocketNumber = formatDocketNumber(selectedDocketType?.prefix, docketYear, nextDocketNumber);
  const docketMonthCode = getDocketMonthCode(dateReceived);

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
        remarks: '',
      },
    ]);
  };

  const addAddress = () => {
    setAddresses((current) => [
      ...current,
      {
        id: makeId('address'),
        addressTypeId: toNumber(defaultAddressTypeId),
        line1: '',
        line2: '',
        barangay: '',
        city: '',
        province: '',
        region: defaultRegionCode,
        zipCode: '',
        country: 'Philippines',
        remarks: '',
        suggestionQuery: '',
      },
    ]);
  };

  const addViolation = () => {
    setViolations((current) => [
      ...current,
      {
        id: makeId('violation'),
        violationId: 0,
        rawViolationText: '',
        searchText: '',
      },
    ]);
  };

  const resetForm = () => {
    setRegionCode(defaultRegionCode);
    setSummaryText('');
    setRemarks('');
    setIsSummaryProcedure(false);
    setPersons([]);
    setAddresses([]);
    setViolations([]);
    setPersonSuggestions({});
    setAddressSuggestions({});
    setViolationSuggestions({});
    setActiveTab('case-info');
  };

  const updatePerson = (id: string, updates: Partial<PersonEntry>) => {
    setPersons((current) => current.map((person) => (person.id === id ? { ...person, ...updates } : person)));
  };

  const updateAddress = (id: string, updates: Partial<AddressEntry>) => {
    setAddresses((current) => current.map((address) => (address.id === id ? { ...address, ...updates } : address)));
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

  const applyPersonSuggestion = (entryId: string, person: TableRow<'persons'>) => {
    updatePerson(entryId, {
      age: person.age ?? '',
      birthDate: person.birth_date ?? '',
      firstName: person.first_name ?? '',
      gender: person.gender ?? 'Unspecified',
      lastName: person.last_name ?? '',
      middleName: person.middle_name ?? '',
      suffix: person.suffix ?? '',
    });
    setPersonSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const applyAddressSuggestion = (entryId: string, address: TableRow<'addresses'>) => {
    updateAddress(entryId, {
      barangay: address.barangay ?? '',
      city: address.city ?? '',
      country: address.country ?? 'Philippines',
      line1: address.line1 ?? '',
      line2: address.line2 ?? '',
      province: address.province ?? '',
      region: address.region ?? defaultRegionCode,
      suggestionQuery: formatAddress(address),
      zipCode: address.zip_code ?? '',
    });
    setAddressSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const applyViolationSuggestion = (entryId: string, violation: TableRow<'violations'>) => {
    updateViolation(entryId, {
      rawViolationText: violation.law_reference ?? violation.short_label ?? violation.title,
      searchText: violation.title,
      violationId: violation.id,
    });
    setViolationSuggestions((current) => ({ ...current, [entryId]: [] }));
  };

  const validateForm = () => {
    if (!docketTypeId || !docketYear || !dateReceived || !nextDocketNumber) {
      return 'Docket type, year, date received, and generated docket number are required.';
    }

    if (!currentUser) {
      return 'No current database user was found for the created_by_user_id column.';
    }

    if (!initialStatusId) {
      return 'The default Received status could not be found.';
    }

    if (persons.length === 0) {
      return 'Add at least one complainant, respondent, or other participant.';
    }

    if (persons.some((person) => !person.firstName.trim() || !person.lastName.trim() || !person.roleId)) {
      return 'Each participant needs a first name, last name, and database role.';
    }

    if (violations.length === 0) {
      return 'Add at least one violation from the database violations table.';
    }

    if (violations.some((violation) => !violation.violationId)) {
      return 'Each violation entry must select a database violation suggestion.';
    }

    if (addresses.some((address) => !address.addressTypeId)) {
      return 'Each address entry must select a database address type.';
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
      source: 'manual',
      summaryText: summaryText || null,
      remarks: remarks || null,
      isSummaryProcedure,
      persons: persons.map(({ id: _id, ...person }) => person),
      addresses: addresses.map(({ id: _id, suggestionQuery: _suggestionQuery, ...address }) => address),
      violations: violations.map(({ id: _id, searchText: _searchText, ...violation }) => violation),
    };

    const result = await createNewDocketEntry(payload);
    setIsSubmitting(false);

    if (result.error) {
      setMessage({ type: 'error', text: result.error.message });
      return;
    }

    const createdDisplayNumber = formatDocketNumber(
      selectedDocketType?.prefix,
      String(result.data.docketYear),
      result.data.docketNumber,
    );

    setMessage({ type: 'success', text: `Docket ${createdDisplayNumber} created as case #${result.data.caseId}.`, caseId: result.data.caseId });
    setNextDocketNumber((current) => (current ? current + 1 : current));
    resetForm();
  };

  return (
    <div className="p-8 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">New Docket Entry</h1>
        <p className="text-muted-foreground mt-1">
          Create a live case record using the current Supabase docket schema.
        </p>
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
        <CardHeader>
          <CardTitle>Case Information</CardTitle>
          <CardDescription>
            Fields match the cases, participants, addresses, status history, and violations tables.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="case-info">Case</TabsTrigger>
              <TabsTrigger value="persons">Participants</TabsTrigger>
              <TabsTrigger value="addresses">Addresses</TabsTrigger>
              <TabsTrigger value="violations">Violations</TabsTrigger>
            </TabsList>

            <TabsContent value="case-info" className="space-y-4">
              <div className="rounded-lg border bg-muted/30 p-4">
                <p className="text-sm font-medium text-muted-foreground">Generated Docket No.</p>
                <div className="mt-1 flex flex-wrap items-center gap-3">
                  <p className="text-2xl font-bold tracking-tight text-primary">
                    {isLoadingNextDocket ? 'Detecting next number…' : generatedDocketNumber}
                  </p>
                  <span className="rounded-full bg-background px-3 py-1 text-xs text-muted-foreground">
                    Month code: {docketMonthCode}
                  </span>
                  <span className="rounded-full bg-background px-3 py-1 text-xs text-muted-foreground">
                    Initial status: {selectedStatus?.display_label ?? 'Received'}
                  </span>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-[1fr_10rem_10rem_7rem]">
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
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-[10rem_1fr]">
                <div>
                  <Label htmlFor="next-docket-number">Next No.</Label>
                  <Input id="next-docket-number" value={nextDocketNumber ?? ''} readOnly disabled className="mt-1" />
                </div>
                <p className="self-end text-xs text-muted-foreground">
                  The numeric docket sequence is automatically detected from docket_sequence_counters or the latest matching case and is saved with the current database user.
                </p>
              </div>

              <div className="flex items-center space-x-2">
                <Checkbox id="summary-procedure" checked={isSummaryProcedure} onCheckedChange={(checked) => setIsSummaryProcedure(checked === true)} />
                <Label htmlFor="summary-procedure">Summary procedure case</Label>
              </div>

              <div>
                <Label htmlFor="summary-text">Summary</Label>
                <Textarea id="summary-text" placeholder="Case summary stored in summary_text" value={summaryText} onChange={(event) => setSummaryText(event.target.value)} className="mt-1" />
              </div>

              <div>
                <Label htmlFor="remarks">Remarks</Label>
                <Textarea id="remarks" placeholder="Optional remarks" value={remarks} onChange={(event) => setRemarks(event.target.value)} className="mt-1" />
              </div>

              <Button onClick={() => setActiveTab('persons')} className="mt-2">Continue to Participants</Button>
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
                          <div><Label className="text-xs">First Name *</Label><Input value={person.firstName} onChange={(event) => { updatePerson(person.id, { firstName: event.target.value }); loadPersonSuggestions(person.id, `${event.target.value} ${person.lastName}`); }} className="mt-1" /></div>
                          <div><Label className="text-xs">Middle Name</Label><Input value={person.middleName ?? ''} onChange={(event) => updatePerson(person.id, { middleName: event.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Last Name *</Label><Input value={person.lastName} onChange={(event) => { updatePerson(person.id, { lastName: event.target.value }); loadPersonSuggestions(person.id, `${person.firstName} ${event.target.value}`); }} className="mt-1" /></div>
                          <div><Label className="text-xs">Suffix</Label><Input value={person.suffix ?? ''} onChange={(event) => updatePerson(person.id, { suffix: event.target.value })} className="mt-1" /></div>
                        </div>
                        <Button onClick={() => setPersons((current) => current.filter((item) => item.id !== person.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                      </div>

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

                      <div className="grid grid-cols-1 gap-3 md:grid-cols-5">
                        <div>
                          <Label className="text-xs">Role *</Label>
                          <Select value={person.roleId ? person.roleId.toString() : ''} onValueChange={(value) => updatePerson(person.id, { roleId: toNumber(value) })}>
                            <SelectTrigger className="mt-1"><SelectValue placeholder="Select role" /></SelectTrigger>
                            <SelectContent>{lookups.participantRoles.map((role) => <SelectItem key={role.id} value={role.id.toString()}>{role.display_label}</SelectItem>)}</SelectContent>
                          </Select>
                        </div>
                        <div>
                          <Label className="text-xs">Gender</Label>
                          <Select value={person.gender ?? 'Unspecified'} onValueChange={(value) => updatePerson(person.id, { gender: value })}>
                            <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                            <SelectContent>{genderOptions.map((gender) => <SelectItem key={gender} value={gender}>{gender}</SelectItem>)}</SelectContent>
                          </Select>
                        </div>
                        <div><Label className="text-xs">Birth Date</Label><Input type="date" value={person.birthDate ?? ''} onChange={(event) => updatePerson(person.id, { birthDate: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Age</Label><Input value={person.age ?? ''} onChange={(event) => updatePerson(person.id, { age: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Remarks</Label><Input value={person.remarks ?? ''} onChange={(event) => updatePerson(person.id, { remarks: event.target.value })} className="mt-1" /></div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <Button onClick={() => setActiveTab('addresses')} className="mt-2">Continue to Addresses</Button>
            </TabsContent>

            <TabsContent value="addresses" className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">Case Addresses</h3>
                  <p className="text-sm text-muted-foreground">Search reusable addresses with Postgres-backed suggestions while typing.</p>
                </div>
                <Button onClick={addAddress} variant="outline" size="sm" disabled={!defaultAddressTypeId}>
                  <Plus className="mr-2 h-4 w-4" /> Add Address
                </Button>
              </div>

              {addresses.length === 0 ? (
                <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No addresses added yet</div>
              ) : (
                <div className="space-y-4">
                  {addresses.map((address) => (
                    <div key={address.id} className="space-y-3 rounded-lg border p-4">
                      <div className="flex items-start justify-between gap-4">
                        <div className="grid flex-1 grid-cols-1 gap-3 md:grid-cols-[14rem_1fr_1fr]">
                          <div>
                            <Label className="text-xs">Address Type *</Label>
                            <Select value={address.addressTypeId ? address.addressTypeId.toString() : ''} onValueChange={(value) => updateAddress(address.id, { addressTypeId: toNumber(value) })}>
                              <SelectTrigger className="mt-1"><SelectValue placeholder="Select type" /></SelectTrigger>
                              <SelectContent>{lookups.addressTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.display_label}</SelectItem>)}</SelectContent>
                            </Select>
                          </div>
                          <div className="md:col-span-2"><Label className="text-xs">Search Existing Address</Label><Input value={address.suggestionQuery} placeholder="Type street, barangay, city, province, or region" onChange={(event) => { updateAddress(address.id, { suggestionQuery: event.target.value }); loadAddressSuggestions(address.id, event.target.value); }} className="mt-1" /></div>
                        </div>
                        <Button onClick={() => setAddresses((current) => current.filter((item) => item.id !== address.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                      </div>

                      {addressSuggestions[address.id]?.length ? (
                        <div className="rounded-md border bg-background p-2 text-sm shadow-sm">
                          <p className="mb-1 flex items-center gap-1 text-xs text-muted-foreground"><Search className="h-3 w-3" /> Existing address suggestions</p>
                          <div className="flex flex-wrap gap-2">
                            {addressSuggestions[address.id].map((suggestion) => (
                              <Button key={suggestion.id} type="button" variant="secondary" size="sm" onClick={() => applyAddressSuggestion(address.id, suggestion)}>
                                {formatAddress(suggestion) || `Address #${suggestion.id}`}
                              </Button>
                            ))}
                          </div>
                        </div>
                      ) : null}

                      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
                        <div><Label className="text-xs">Line 1</Label><Input value={address.line1 ?? ''} onChange={(event) => updateAddress(address.id, { line1: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Line 2</Label><Input value={address.line2 ?? ''} onChange={(event) => updateAddress(address.id, { line2: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Barangay</Label><Input value={address.barangay ?? ''} onChange={(event) => updateAddress(address.id, { barangay: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">City</Label><Input value={address.city ?? ''} onChange={(event) => updateAddress(address.id, { city: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Province</Label><Input value={address.province ?? ''} onChange={(event) => updateAddress(address.id, { province: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Region</Label><Input value={address.region ?? ''} onChange={(event) => updateAddress(address.id, { region: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">ZIP Code</Label><Input value={address.zipCode ?? ''} onChange={(event) => updateAddress(address.id, { zipCode: event.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Country</Label><Input value={address.country ?? ''} onChange={(event) => updateAddress(address.id, { country: event.target.value })} className="mt-1" /></div>
                        <div className="md:col-span-4"><Label className="text-xs">Remarks</Label><Input value={address.remarks ?? ''} onChange={(event) => updateAddress(address.id, { remarks: event.target.value })} className="mt-1" /></div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <Button onClick={() => setActiveTab('violations')} className="mt-2">Continue to Violations</Button>
            </TabsContent>

            <TabsContent value="violations" className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">Case Violations</h3>
                  <p className="text-sm text-muted-foreground">Search the violations table by title, short label, reference code, law reference, or description.</p>
                </div>
                <Button onClick={addViolation} variant="outline" size="sm">
                  <Plus className="mr-2 h-4 w-4" /> Add Violation
                </Button>
              </div>

              {violations.length === 0 ? (
                <div className="rounded-lg border border-dashed py-8 text-center text-muted-foreground">No violations added yet</div>
              ) : (
                <div className="space-y-4">
                  {violations.map((violation) => (
                    <div key={violation.id} className="space-y-3 rounded-lg border p-4">
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex-1">
                          <Label className="text-xs">Search Violation *</Label>
                          <Input value={violation.searchText} placeholder="Type a violation, law reference, or code" onChange={(event) => { updateViolation(violation.id, { searchText: event.target.value, violationId: 0 }); loadViolationSuggestions(violation.id, event.target.value); }} className="mt-1" />
                        </div>
                        <Button onClick={() => setViolations((current) => current.filter((item) => item.id !== violation.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
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

                      <div>
                        <Label className="text-xs">Raw Violation Text</Label>
                        <Textarea value={violation.rawViolationText ?? ''} onChange={(event) => updateViolation(violation.id, { rawViolationText: event.target.value })} className="mt-1" placeholder="Optional original text from complaint or intake document" />
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div className="mt-6 flex gap-4">
                <Button onClick={handleSubmit} className="flex-1" disabled={isSubmitting || isLoadingLookups || isLoadingNextDocket}>
                  {isSubmitting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                  Submit Docket Entry
                </Button>
                <Button onClick={() => setActiveTab('case-info')} variant="outline">Back to Case</Button>
              </div>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
}
