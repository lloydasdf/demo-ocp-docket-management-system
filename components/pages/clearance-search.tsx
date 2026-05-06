'use client';

import { useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { searchPersons } from '@/lib/supabase-queries';
import { Search as SearchIcon, AlertTriangle, CheckCircle, AlertCircle } from 'lucide-react';

export default function ClearanceSearch() {
  const [searchQuery, setSearchQuery] = useState('');
  const [results, setResults] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searched, setSearched] = useState(false);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!searchQuery.trim()) {
      setError('Please enter a name to search');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      setSearched(true);

      const data = await searchPersons(searchQuery);
      setResults(data);

      if (data.length === 0) {
        setError(null); // No error, just no results
      }
    } catch (err) {
      console.error('[v0] Search error:', err);
      setError('Failed to search clearance records');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Clearance Search</h1>
        <p className="text-muted-foreground mt-1">Search for existing docket records to prevent duplicates</p>
      </div>

      {/* Search Form */}
      <Card>
        <CardHeader>
          <CardTitle>Search by Person Name</CardTitle>
          <CardDescription>Enter full name or partial name to search</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSearch} className="space-y-4">
            <div>
              <label className="text-sm font-medium">Full Name or Partial Name</label>
              <div className="flex gap-2 mt-2">
                <div className="flex-1 flex items-center gap-2 border border-input rounded-lg px-3">
                  <SearchIcon className="w-4 h-4 text-muted-foreground" />
                  <Input
                    type="text"
                    placeholder="e.g., Carlos Santos, Maria Garcia..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="border-0 focus:ring-0"
                  />
                </div>
                <Button type="submit" disabled={loading}>
                  {loading ? <Spinner className="w-4 h-4" /> : 'Search'}
                </Button>
              </div>
            </div>

            {error && (
              <Alert variant="destructive">
                <AlertTriangle className="h-4 w-4" />
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            )}
          </form>
        </CardContent>
      </Card>

      {/* Results */}
      {searched && (
        <div className="space-y-4">
          {results.length === 0 ? (
            <Card className="border-green-200 bg-green-50">
              <CardContent className="pt-6">
                <div className="flex items-center gap-3">
                  <CheckCircle className="w-5 h-5 text-green-600" />
                  <div>
                    <p className="font-semibold text-green-900">No matching docket record found</p>
                    <p className="text-sm text-green-700">This person does not have an existing docket record. Safe to create new entry.</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ) : (
            <>
              <Alert className="border-orange-200 bg-orange-50">
                <AlertCircle className="h-4 w-4 text-orange-600" />
                <AlertDescription className="text-orange-800">
                  Found {results.length} possible match{results.length !== 1 ? 'es' : ''}. Staff review required to confirm.
                </AlertDescription>
              </Alert>

              <div className="space-y-4">
                {results.map((person) => (
                  <Card key={person.id}>
                    <CardHeader>
                      <div className="flex items-start justify-between">
                        <div>
                          <CardTitle className="text-lg">
                            {person.first_name} {person.middle_name ? person.middle_name + ' ' : ''}
                            {person.last_name}
                          </CardTitle>
                          <CardDescription className="mt-1">
                            {person.gender === 'M' ? 'Male' : 'Female'} • DOB:{' '}
                            {person.date_of_birth
                              ? new Date(person.date_of_birth).toLocaleDateString()
                              : 'Not provided'}
                          </CardDescription>
                        </div>
                        <Badge variant="outline">Possible Match</Badge>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      {/* Aliases */}
                      {person.person_aliases && person.person_aliases.length > 0 && (
                        <div>
                          <h4 className="font-semibold text-sm mb-2">Known Aliases</h4>
                          <div className="flex flex-wrap gap-2">
                            {person.person_aliases.map((alias: any) => (
                              <Badge key={alias.id} variant="secondary">
                                {alias.alias_name}
                              </Badge>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* Addresses */}
                      {person.person_addresses && person.person_addresses.length > 0 && (
                        <div>
                          <h4 className="font-semibold text-sm mb-2">Addresses</h4>
                          <div className="space-y-2">
                            {person.person_addresses.map((addr: any) => (
                              <p key={addr.id} className="text-sm">
                                {addr.address_line1}
                                {addr.address_line2 && <>, {addr.address_line2}</>}
                                {addr.barangay && <>, {addr.barangay}</>}
                                {addr.city && <>, {addr.city}</>}
                              </p>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* Associated Cases Count */}
                      <div className="pt-2 border-t">
                        <p className="text-sm">
                          <span className="font-medium">Associated Records:</span> Multiple dockets on file
                        </p>
                        <p className="text-xs text-muted-foreground mt-1">
                          Staff review required before creating duplicate entry.
                        </p>
                      </div>

                      <div className="flex gap-2">
                        <Button size="sm" variant="outline">
                          View Existing Dockets
                        </Button>
                        <Button size="sm" variant="outline">
                          Compare Records
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>

              {/* Review Section */}
              <Card className="border-blue-200 bg-blue-50">
                <CardHeader>
                  <CardTitle className="text-blue-900">Staff Review Process</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3 text-sm text-blue-900">
                  <p>
                    <span className="font-semibold">✓ Search performed</span> - Possible matches reviewed
                  </p>
                  <p>
                    <span className="font-semibold">→ Next: Staff verification</span> - Confirm identity match
                  </p>
                  <p>
                    <span className="font-semibold">Decision options:</span>
                  </p>
                  <ul className="ml-6 space-y-2 list-disc">
                    <li>Matched - Link to existing docket</li>
                    <li>Not matched - Create new entry</li>
                    <li>Requires supervisor - Flag for review</li>
                  </ul>
                </CardContent>
              </Card>
            </>
          )}
        </div>
      )}
    </div>
  );
}
