'use client';

import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Plus, X } from 'lucide-react';

interface PersonEntry {
  id: string;
  firstName: string;
  lastName: string;
  middleName: string;
  role: 'Complainant' | 'Respondent' | 'Witness';
  contactNumber: string;
  email: string;
}

interface AddressEntry {
  id: string;
  type: 'Residential' | 'Office' | 'Barangay';
  street: string;
  barangay: string;
  municipality: string;
  province: string;
  zipCode: string;
}

interface ViolationEntry {
  id: string;
  statute: string;
  description: string;
  dateCommitted: string;
  location: string;
}

export default function NewDocket() {
  const [activeTab, setActiveTab] = useState('case-info');
  const [caseNumber, setCaseNumber] = useState('');
  const [dateOfIncident, setDateOfIncident] = useState('');
  const [persons, setPersons] = useState<PersonEntry[]>([]);
  const [addresses, setAddresses] = useState<AddressEntry[]>([]);
  const [violations, setViolations] = useState<ViolationEntry[]>([]);
  const [formMessage, setFormMessage] = useState('');

  const addPerson = () => {
    const newPerson: PersonEntry = {
      id: `person-${Date.now()}`,
      firstName: '',
      lastName: '',
      middleName: '',
      role: 'Complainant',
      contactNumber: '',
      email: '',
    };
    setPersons([...persons, newPerson]);
  };

  const removePerson = (id: string) => {
    setPersons(persons.filter((p) => p.id !== id));
  };

  const updatePerson = (id: string, updates: Partial<PersonEntry>) => {
    setPersons(persons.map((p) => (p.id === id ? { ...p, ...updates } : p)));
  };

  const addAddress = () => {
    const newAddress: AddressEntry = {
      id: `addr-${Date.now()}`,
      type: 'Residential',
      street: '',
      barangay: '',
      municipality: '',
      province: '',
      zipCode: '',
    };
    setAddresses([...addresses, newAddress]);
  };

  const removeAddress = (id: string) => {
    setAddresses(addresses.filter((a) => a.id !== id));
  };

  const updateAddress = (id: string, updates: Partial<AddressEntry>) => {
    setAddresses(addresses.map((a) => (a.id === id ? { ...a, ...updates } : a)));
  };

  const addViolation = () => {
    const newViolation: ViolationEntry = {
      id: `vio-${Date.now()}`,
      statute: '',
      description: '',
      dateCommitted: '',
      location: '',
    };
    setViolations([...violations, newViolation]);
  };

  const removeViolation = (id: string) => {
    setViolations(violations.filter((v) => v.id !== id));
  };

  const updateViolation = (id: string, updates: Partial<ViolationEntry>) => {
    setViolations(violations.map((v) => (v.id === id ? { ...v, ...updates } : v)));
  };

  const handleSubmit = () => {
    if (!caseNumber || !dateOfIncident || persons.length === 0 || violations.length === 0) {
      setFormMessage('Please fill in all required fields');
      return;
    }
    setFormMessage('Docket entry created successfully!');
    setTimeout(() => {
      setCaseNumber('');
      setDateOfIncident('');
      setPersons([]);
      setAddresses([]);
      setViolations([]);
      setFormMessage('');
    }, 2000);
  };

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">New Docket Entry</h1>
        <p className="text-muted-foreground mt-1">Create a new docket and case record</p>
      </div>

      {/* Success Message */}
      {formMessage && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded">
          {formMessage}
        </div>
      )}

      {/* Form Card */}
      <Card>
        <CardHeader>
          <CardTitle>Case Information</CardTitle>
        </CardHeader>
        <CardContent>
          <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="case-info">Case Info</TabsTrigger>
              <TabsTrigger value="persons">Persons</TabsTrigger>
              <TabsTrigger value="addresses">Addresses</TabsTrigger>
              <TabsTrigger value="violations">Violations</TabsTrigger>
            </TabsList>

            {/* Case Information Tab */}
            <TabsContent value="case-info" className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <Label htmlFor="case-number">Case Number *</Label>
                  <Input
                    id="case-number"
                    placeholder="e.g., OCP-2025-011"
                    value={caseNumber}
                    onChange={(e) => setCaseNumber(e.target.value)}
                    className="mt-1"
                  />
                </div>
                <div>
                  <Label htmlFor="date-of-incident">Date of Incident *</Label>
                  <Input
                    id="date-of-incident"
                    type="date"
                    value={dateOfIncident}
                    onChange={(e) => setDateOfIncident(e.target.value)}
                    className="mt-1"
                  />
                </div>
              </div>
              <Button onClick={() => setActiveTab('persons')} className="mt-4">
                Continue to Persons
              </Button>
            </TabsContent>

            {/* Persons Tab */}
            <TabsContent value="persons" className="space-y-4">
              <div className="flex justify-between items-center mb-4">
                <div>
                  <h3 className="font-semibold">Involved Parties</h3>
                  <p className="text-sm text-muted-foreground">Add complainants, respondents, and witnesses</p>
                </div>
                <Button onClick={addPerson} variant="outline" size="sm">
                  <Plus className="w-4 h-4 mr-2" />
                  Add Person
                </Button>
              </div>

              {persons.length === 0 ? (
                <div className="text-center py-8 border border-dashed rounded-lg">
                  <p className="text-muted-foreground">No persons added yet</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {persons.map((person) => (
                    <div key={person.id} className="p-4 border border-border rounded-lg space-y-3">
                      <div className="flex justify-between items-start">
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 flex-1 mr-4">
                          <div>
                            <Label htmlFor={`${person.id}-first`} className="text-xs">
                              First Name
                            </Label>
                            <Input
                              id={`${person.id}-first`}
                              placeholder="First name"
                              value={person.firstName}
                              onChange={(e) => updatePerson(person.id, { firstName: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                          <div>
                            <Label htmlFor={`${person.id}-middle`} className="text-xs">
                              Middle Name
                            </Label>
                            <Input
                              id={`${person.id}-middle`}
                              placeholder="Middle name"
                              value={person.middleName}
                              onChange={(e) => updatePerson(person.id, { middleName: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                          <div>
                            <Label htmlFor={`${person.id}-last`} className="text-xs">
                              Last Name
                            </Label>
                            <Input
                              id={`${person.id}-last`}
                              placeholder="Last name"
                              value={person.lastName}
                              onChange={(e) => updatePerson(person.id, { lastName: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                        </div>
                        <Button
                          onClick={() => removePerson(person.id)}
                          variant="ghost"
                          size="sm"
                          className="text-destructive"
                        >
                          <X className="w-4 h-4" />
                        </Button>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                        <div>
                          <Label htmlFor={`${person.id}-role`} className="text-xs">
                            Role
                          </Label>
                          <Select value={person.role} onValueChange={(value) => updatePerson(person.id, { role: value as any })}>
                            <SelectTrigger id={`${person.id}-role`} className="mt-1">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="Complainant">Complainant</SelectItem>
                              <SelectItem value="Respondent">Respondent</SelectItem>
                              <SelectItem value="Witness">Witness</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                        <div>
                          <Label htmlFor={`${person.id}-contact`} className="text-xs">
                            Contact Number
                          </Label>
                          <Input
                            id={`${person.id}-contact`}
                            placeholder="09xx-xxx-xxxx"
                            value={person.contactNumber}
                            onChange={(e) => updatePerson(person.id, { contactNumber: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                        <div>
                          <Label htmlFor={`${person.id}-email`} className="text-xs">
                            Email
                          </Label>
                          <Input
                            id={`${person.id}-email`}
                            type="email"
                            placeholder="email@example.com"
                            value={person.email}
                            onChange={(e) => updatePerson(person.id, { email: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <Button onClick={() => setActiveTab('addresses')} className="mt-4">
                Continue to Addresses
              </Button>
            </TabsContent>

            {/* Addresses Tab */}
            <TabsContent value="addresses" className="space-y-4">
              <div className="flex justify-between items-center mb-4">
                <div>
                  <h3 className="font-semibold">Addresses</h3>
                  <p className="text-sm text-muted-foreground">Add residential, office, or barangay addresses</p>
                </div>
                <Button onClick={addAddress} variant="outline" size="sm">
                  <Plus className="w-4 h-4 mr-2" />
                  Add Address
                </Button>
              </div>

              {addresses.length === 0 ? (
                <div className="text-center py-8 border border-dashed rounded-lg">
                  <p className="text-muted-foreground">No addresses added yet</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {addresses.map((address) => (
                    <div key={address.id} className="p-4 border border-border rounded-lg space-y-3">
                      <div className="flex justify-between items-start">
                        <div>
                          <Label htmlFor={`${address.id}-type`} className="text-xs">
                            Type
                          </Label>
                          <Select value={address.type} onValueChange={(value) => updateAddress(address.id, { type: value as any })}>
                            <SelectTrigger id={`${address.id}-type`} className="mt-1 w-48">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              <SelectItem value="Residential">Residential</SelectItem>
                              <SelectItem value="Office">Office</SelectItem>
                              <SelectItem value="Barangay">Barangay</SelectItem>
                            </SelectContent>
                          </Select>
                        </div>
                        <Button
                          onClick={() => removeAddress(address.id)}
                          variant="ghost"
                          size="sm"
                          className="text-destructive"
                        >
                          <X className="w-4 h-4" />
                        </Button>
                      </div>

                      <div className="grid grid-cols-1 gap-3">
                        <div>
                          <Label htmlFor={`${address.id}-street`} className="text-xs">
                            Street
                          </Label>
                          <Input
                            id={`${address.id}-street`}
                            placeholder="Street address"
                            value={address.street}
                            onChange={(e) => updateAddress(address.id, { street: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        <div>
                          <Label htmlFor={`${address.id}-barangay`} className="text-xs">
                            Barangay
                          </Label>
                          <Input
                            id={`${address.id}-barangay`}
                            placeholder="Barangay"
                            value={address.barangay}
                            onChange={(e) => updateAddress(address.id, { barangay: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                        <div>
                          <Label htmlFor={`${address.id}-municipality`} className="text-xs">
                            Municipality
                          </Label>
                          <Input
                            id={`${address.id}-municipality`}
                            placeholder="Municipality"
                            value={address.municipality}
                            onChange={(e) => updateAddress(address.id, { municipality: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        <div>
                          <Label htmlFor={`${address.id}-province`} className="text-xs">
                            Province
                          </Label>
                          <Input
                            id={`${address.id}-province`}
                            placeholder="Province"
                            value={address.province}
                            onChange={(e) => updateAddress(address.id, { province: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                        <div>
                          <Label htmlFor={`${address.id}-zipcode`} className="text-xs">
                            Zip Code
                          </Label>
                          <Input
                            id={`${address.id}-zipcode`}
                            placeholder="Zip code"
                            value={address.zipCode}
                            onChange={(e) => updateAddress(address.id, { zipCode: e.target.value })}
                            className="mt-1"
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <Button onClick={() => setActiveTab('violations')} className="mt-4">
                Continue to Violations
              </Button>
            </TabsContent>

            {/* Violations Tab */}
            <TabsContent value="violations" className="space-y-4">
              <div className="flex justify-between items-center mb-4">
                <div>
                  <h3 className="font-semibold">Violations</h3>
                  <p className="text-sm text-muted-foreground">Add violations and statutory citations</p>
                </div>
                <Button onClick={addViolation} variant="outline" size="sm">
                  <Plus className="w-4 h-4 mr-2" />
                  Add Violation
                </Button>
              </div>

              {violations.length === 0 ? (
                <div className="text-center py-8 border border-dashed rounded-lg">
                  <p className="text-muted-foreground">No violations added yet</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {violations.map((violation) => (
                    <div key={violation.id} className="p-4 border border-border rounded-lg space-y-3">
                      <div className="flex justify-between items-start">
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 flex-1 mr-4">
                          <div>
                            <Label htmlFor={`${violation.id}-statute`} className="text-xs">
                              Statute
                            </Label>
                            <Input
                              id={`${violation.id}-statute`}
                              placeholder="e.g., RA 9165"
                              value={violation.statute}
                              onChange={(e) => updateViolation(violation.id, { statute: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                          <div>
                            <Label htmlFor={`${violation.id}-date`} className="text-xs">
                              Date Committed
                            </Label>
                            <Input
                              id={`${violation.id}-date`}
                              type="date"
                              value={violation.dateCommitted}
                              onChange={(e) => updateViolation(violation.id, { dateCommitted: e.target.value })}
                              className="mt-1"
                            />
                          </div>
                        </div>
                        <Button
                          onClick={() => removeViolation(violation.id)}
                          variant="ghost"
                          size="sm"
                          className="text-destructive"
                        >
                          <X className="w-4 h-4" />
                        </Button>
                      </div>

                      <div>
                        <Label htmlFor={`${violation.id}-description`} className="text-xs">
                          Description
                        </Label>
                        <Input
                          id={`${violation.id}-description`}
                          placeholder="Description of violation"
                          value={violation.description}
                          onChange={(e) => updateViolation(violation.id, { description: e.target.value })}
                          className="mt-1"
                        />
                      </div>

                      <div>
                        <Label htmlFor={`${violation.id}-location`} className="text-xs">
                          Location
                        </Label>
                        <Input
                          id={`${violation.id}-location`}
                          placeholder="Where did it occur?"
                          value={violation.location}
                          onChange={(e) => updateViolation(violation.id, { location: e.target.value })}
                          className="mt-1"
                        />
                      </div>
                    </div>
                  ))}
                </div>
              )}

              <div className="flex gap-4 mt-6">
                <Button onClick={handleSubmit} className="flex-1">
                  Submit Docket Entry
                </Button>
                <Button onClick={() => setActiveTab('case-info')} variant="outline">
                  Back
                </Button>
              </div>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
}
