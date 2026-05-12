'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlertCircle, CheckCircle2, Loader2, Plus, X } from 'lucide-react';

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
  getActiveUsers,
  getAddressTypes,
  getCaseStatuses,
  getDocketTypes,
  getParticipantRoles,
  getViolations,
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
  users: Pick<TableRow<'users'>, 'email' | 'id'>[];
};

type MessageState =
  | { type: 'success'; text: string; caseId?: number }
  | { type: 'error'; text: string }
  | null;

type PersonEntry = NewDocketPersonInput & { id: string };
type AddressEntry = NewDocketAddressInput & { id: string };
type ViolationEntry = NewDocketViolationInput & { id: string };

const emptyLookups: LookupState = {
  docketTypes: [],
  participantRoles: [],
  addressTypes: [],
  violations: [],
  statuses: [],
  users: [],
};

const thisYear = new Date().getFullYear();
const monthCodes = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const genderOptions = ['Female', 'Male', 'Other', 'Unspecified'];

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

export default function NewDocket() {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState('case-info');
  const [lookups, setLookups] = useState<LookupState>(emptyLookups);
  const [isLoadingLookups, setIsLoadingLookups] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState<MessageState>(null);

  const [docketTypeId, setDocketTypeId] = useState('');
  const [docketYear, setDocketYear] = useState(String(thisYear));
  const [docketNumber, setDocketNumber] = useState('');
  const [docketMonthCode, setDocketMonthCode] = useState('');
  const [dateReceived, setDateReceived] = useState(new Date().toISOString().slice(0, 10));
  const [createdByUserId, setCreatedByUserId] = useState('');
  const [initialStatusId, setInitialStatusId] = useState('');
  const [regionCode, setRegionCode] = useState('');
  const [summaryText, setSummaryText] = useState('');
  const [remarks, setRemarks] = useState('');
  const [isSummaryProcedure, setIsSummaryProcedure] = useState(false);

  const [persons, setPersons] = useState<PersonEntry[]>([]);
  const [addresses, setAddresses] = useState<AddressEntry[]>([]);
  const [violations, setViolations] = useState<ViolationEntry[]>([]);

  useEffect(() => {
    let isMounted = true;

    async function loadLookups() {
      setIsLoadingLookups(true);
      const [docketTypes, participantRoles, addressTypes, violationsResult, statuses, users] = await Promise.all([
        getDocketTypes(),
        getParticipantRoles(),
        getAddressTypes(),
        getViolations(500),
        getCaseStatuses(),
        getActiveUsers(),
      ]);

      if (!isMounted) {
        return;
      }

      const firstError = [docketTypes, participantRoles, addressTypes, violationsResult, statuses, users].find(
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
        users: users.data ?? [],
      };

      setLookups(nextLookups);
      setDocketTypeId((current) => current || getFirstId(nextLookups.docketTypes));
      setCreatedByUserId((current) => current || getFirstId(nextLookups.users));
      setInitialStatusId((current) => current || getFirstId(nextLookups.statuses));
      setIsLoadingLookups(false);
    }

    loadLookups();

    return () => {
      isMounted = false;
    };
  }, []);

  const defaultRoleId = useMemo(() => getFirstId(lookups.participantRoles), [lookups.participantRoles]);
  const defaultAddressTypeId = useMemo(() => getFirstId(lookups.addressTypes), [lookups.addressTypes]);
  const defaultViolationId = useMemo(() => getFirstId(lookups.violations), [lookups.violations]);

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
        region: '',
        zipCode: '',
        country: 'Philippines',
        remarks: '',
      },
    ]);
  };

  const addViolation = () => {
    setViolations((current) => [
      ...current,
      {
        id: makeId('violation'),
        violationId: toNumber(defaultViolationId),
        rawViolationText: '',
      },
    ]);
  };

  const resetForm = () => {
    setDocketNumber('');
    setDocketMonthCode('');
    setRegionCode('');
    setSummaryText('');
    setRemarks('');
    setIsSummaryProcedure(false);
    setPersons([]);
    setAddresses([]);
    setViolations([]);
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

  const validateForm = () => {
    if (!docketTypeId || !docketYear || !docketNumber || !dateReceived || !createdByUserId) {
      return 'Docket type, year, number, date received, and created-by user are required.';
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
      return 'Each violation entry must select a database violation.';
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
      docketNumber: toNumber(docketNumber),
      dateReceived,
      createdByUserId: toNumber(createdByUserId),
      initialStatusId: initialStatusId ? toNumber(initialStatusId) : null,
      docketMonthCode: docketMonthCode || null,
      regionCode: regionCode || null,
      source: 'manual',
      summaryText: summaryText || null,
      remarks: remarks || null,
      isSummaryProcedure,
      persons: persons.map(({ id: _id, ...person }) => person),
      addresses: addresses.map(({ id: _id, ...address }) => address),
      violations: violations.map(({ id: _id, ...violation }) => violation),
    };

    const result = await createNewDocketEntry(payload);
    setIsSubmitting(false);

    if (result.error) {
      setMessage({ type: 'error', text: result.error.message });
      return;
    }

    setMessage({ type: 'success', text: `Docket entry created as case #${result.data.caseId}.`, caseId: result.data.caseId });
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
              <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
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
                  <Input id="docket-year" type="number" value={docketYear} onChange={(e) => setDocketYear(e.target.value)} className="mt-1" />
                </div>
                <div>
                  <Label htmlFor="docket-number">Docket Number *</Label>
                  <Input id="docket-number" type="number" placeholder="Sequential number" value={docketNumber} onChange={(e) => setDocketNumber(e.target.value)} className="mt-1" />
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
                <div>
                  <Label htmlFor="date-received">Date Received *</Label>
                  <Input id="date-received" type="date" value={dateReceived} onChange={(e) => setDateReceived(e.target.value)} className="mt-1" />
                </div>
                <div>
                  <Label htmlFor="docket-month">Docket Month Code</Label>
                  <Select value={docketMonthCode} onValueChange={setDocketMonthCode}>
                    <SelectTrigger id="docket-month" className="mt-1">
                      <SelectValue placeholder="Optional" />
                    </SelectTrigger>
                    <SelectContent>
                      {monthCodes.map((month) => (
                        <SelectItem key={month} value={month}>{month}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="region-code">Region Code</Label>
                  <Input id="region-code" placeholder="e.g., NCR" value={regionCode} onChange={(e) => setRegionCode(e.target.value)} className="mt-1" />
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                <div>
                  <Label htmlFor="created-by">Created By User *</Label>
                  <Select value={createdByUserId} onValueChange={setCreatedByUserId} disabled={isLoadingLookups}>
                    <SelectTrigger id="created-by" className="mt-1">
                      <SelectValue placeholder="Select database user" />
                    </SelectTrigger>
                    <SelectContent>
                      {lookups.users.map((user) => (
                        <SelectItem key={user.id} value={user.id.toString()}>{user.email}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label htmlFor="initial-status">Initial Status</Label>
                  <Select value={initialStatusId} onValueChange={setInitialStatusId} disabled={isLoadingLookups}>
                    <SelectTrigger id="initial-status" className="mt-1">
                      <SelectValue placeholder="Optional" />
                    </SelectTrigger>
                    <SelectContent>
                      {lookups.statuses.map((status) => (
                        <SelectItem key={status.id} value={status.id.toString()}>{status.display_label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="flex items-center space-x-2">
                <Checkbox id="summary-procedure" checked={isSummaryProcedure} onCheckedChange={(checked) => setIsSummaryProcedure(checked === true)} />
                <Label htmlFor="summary-procedure">Summary procedure case</Label>
              </div>

              <div>
                <Label htmlFor="summary-text">Summary</Label>
                <Textarea id="summary-text" placeholder="Case summary stored in summary_text" value={summaryText} onChange={(e) => setSummaryText(e.target.value)} className="mt-1" />
              </div>

              <div>
                <Label htmlFor="remarks">Remarks</Label>
                <Textarea id="remarks" placeholder="Optional remarks" value={remarks} onChange={(e) => setRemarks(e.target.value)} className="mt-1" />
              </div>

              <Button onClick={() => setActiveTab('persons')} className="mt-2">Continue to Participants</Button>
            </TabsContent>

            <TabsContent value="persons" className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">Case Participants</h3>
                  <p className="text-sm text-muted-foreground">Creates persons and links them through case_participants.</p>
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
                          <div><Label className="text-xs">First Name *</Label><Input value={person.firstName} onChange={(e) => updatePerson(person.id, { firstName: e.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Middle Name</Label><Input value={person.middleName ?? ''} onChange={(e) => updatePerson(person.id, { middleName: e.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Last Name *</Label><Input value={person.lastName} onChange={(e) => updatePerson(person.id, { lastName: e.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Suffix</Label><Input value={person.suffix ?? ''} onChange={(e) => updatePerson(person.id, { suffix: e.target.value })} className="mt-1" /></div>
                        </div>
                        <Button onClick={() => setPersons((current) => current.filter((item) => item.id !== person.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                      </div>
                      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
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
                        <div><Label className="text-xs">Age</Label><Input value={person.age ?? ''} onChange={(e) => updatePerson(person.id, { age: e.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Remarks</Label><Input value={person.remarks ?? ''} onChange={(e) => updatePerson(person.id, { remarks: e.target.value })} className="mt-1" /></div>
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
                  <p className="text-sm text-muted-foreground">Optional locations linked through case_addresses.</p>
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
                        <div className="grid flex-1 grid-cols-1 gap-3 md:grid-cols-3">
                          <div>
                            <Label className="text-xs">Address Type *</Label>
                            <Select value={address.addressTypeId ? address.addressTypeId.toString() : ''} onValueChange={(value) => updateAddress(address.id, { addressTypeId: toNumber(value) })}>
                              <SelectTrigger className="mt-1"><SelectValue placeholder="Select type" /></SelectTrigger>
                              <SelectContent>{lookups.addressTypes.map((type) => <SelectItem key={type.id} value={type.id.toString()}>{type.display_label}</SelectItem>)}</SelectContent>
                            </Select>
                          </div>
                          <div><Label className="text-xs">Line 1</Label><Input value={address.line1 ?? ''} onChange={(e) => updateAddress(address.id, { line1: e.target.value })} className="mt-1" /></div>
                          <div><Label className="text-xs">Line 2</Label><Input value={address.line2 ?? ''} onChange={(e) => updateAddress(address.id, { line2: e.target.value })} className="mt-1" /></div>
                        </div>
                        <Button onClick={() => setAddresses((current) => current.filter((item) => item.id !== address.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                      </div>
                      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
                        <div><Label className="text-xs">Barangay</Label><Input value={address.barangay ?? ''} onChange={(e) => updateAddress(address.id, { barangay: e.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">City</Label><Input value={address.city ?? ''} onChange={(e) => updateAddress(address.id, { city: e.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Province</Label><Input value={address.province ?? ''} onChange={(e) => updateAddress(address.id, { province: e.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Region</Label><Input value={address.region ?? ''} onChange={(e) => updateAddress(address.id, { region: e.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">ZIP Code</Label><Input value={address.zipCode ?? ''} onChange={(e) => updateAddress(address.id, { zipCode: e.target.value })} className="mt-1" /></div>
                        <div><Label className="text-xs">Country</Label><Input value={address.country ?? ''} onChange={(e) => updateAddress(address.id, { country: e.target.value })} className="mt-1" /></div>
                        <div className="md:col-span-2"><Label className="text-xs">Remarks</Label><Input value={address.remarks ?? ''} onChange={(e) => updateAddress(address.id, { remarks: e.target.value })} className="mt-1" /></div>
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
                  <p className="text-sm text-muted-foreground">Select existing violations and store optional raw text on case_violations.</p>
                </div>
                <Button onClick={addViolation} variant="outline" size="sm" disabled={!defaultViolationId}>
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
                          <Label className="text-xs">Violation *</Label>
                          <Select value={violation.violationId ? violation.violationId.toString() : ''} onValueChange={(value) => updateViolation(violation.id, { violationId: toNumber(value) })}>
                            <SelectTrigger className="mt-1"><SelectValue placeholder="Select violation" /></SelectTrigger>
                            <SelectContent>{lookups.violations.map((item) => <SelectItem key={item.id} value={item.id.toString()}>{item.title}</SelectItem>)}</SelectContent>
                          </Select>
                        </div>
                        <Button onClick={() => setViolations((current) => current.filter((item) => item.id !== violation.id))} variant="ghost" size="sm" className="text-destructive"><X className="h-4 w-4" /></Button>
                      </div>
                      <div>
                        <Label className="text-xs">Raw Violation Text</Label>
                        <Textarea value={violation.rawViolationText ?? ''} onChange={(e) => updateViolation(violation.id, { rawViolationText: e.target.value })} className="mt-1" placeholder="Optional original text from complaint or intake document" />
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div className="mt-6 flex gap-4">
                <Button onClick={handleSubmit} className="flex-1" disabled={isSubmitting || isLoadingLookups}>
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
