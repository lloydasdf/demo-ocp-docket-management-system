'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { StatusBadge } from '@/components/status-badge';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getDockets, searchDockets } from '@/lib/supabase-queries';
import { CaseStatus } from '@/lib/types';
import { Search as SearchIcon, AlertTriangle } from 'lucide-react';

export default function DocketSearch() {
  const [allDockets, setAllDockets] = useState<any[]>([]);
  const [filteredDockets, setFilteredDockets] = useState<any[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<string>('All');
  const [sortBy, setSortBy] = useState<'date' | 'number'>('date');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load all dockets on mount
  useEffect(() => {
    const loadDockets = async () => {
      try {
        setLoading(true);
        setError(null);
        const data = await getDockets();
        setAllDockets(data);
        setFilteredDockets(data);
      } catch (err) {
        console.error('[v0] Error loading dockets:', err);
        setError('Failed to load dockets');
      } finally {
        setLoading(false);
      }
    };

    loadDockets();
  }, []);

  // Filter and search
  useEffect(() => {
    let filtered = allDockets;

    // Filter by status
    if (selectedStatus !== 'All') {
      filtered = filtered.filter((d) => d.status === selectedStatus);
    }

    // Search
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (d) =>
          d.docket_number.toLowerCase().includes(query) ||
          d.description?.toLowerCase().includes(query)
      );
    }

    // Sort
    filtered.sort((a, b) => {
      if (sortBy === 'date') {
        return new Date(b.date_received).getTime() - new Date(a.date_received).getTime();
      }
      return a.docket_number.localeCompare(b.docket_number);
    });

    setFilteredDockets(filtered);
  }, [searchQuery, selectedStatus, sortBy, allDockets]);

  const statuses = ['All', 'Pending', 'Filed', 'Dismissed', 'Resolved', 'For Review'];

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <Spinner className="w-12 h-12 mx-auto mb-4" />
          <p className="text-muted-foreground">Loading dockets...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8">
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Docket Search</h1>
        <p className="text-muted-foreground mt-1">Search and filter dockets by various criteria</p>
      </div>

      {/* Search and Filters */}
      <Card>
        <CardHeader>
          <CardTitle>Search Filters</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Search Input */}
            <div className="md:col-span-2">
              <label className="text-sm font-medium">Search Docket Number or Description</label>
              <div className="flex items-center gap-2 mt-2">
                <SearchIcon className="w-4 h-4 text-muted-foreground" />
                <Input
                  placeholder="e.g., DK-2025-001, Drug possession..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1"
                />
              </div>
            </div>

            {/* Status Filter */}
            <div>
              <label className="text-sm font-medium">Status</label>
              <Select value={selectedStatus} onValueChange={setSelectedStatus}>
                <SelectTrigger className="mt-2">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {statuses.map((status) => (
                    <SelectItem key={status} value={status}>
                      {status}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Sort */}
          <div>
            <label className="text-sm font-medium">Sort By</label>
            <div className="flex gap-2 mt-2">
              <Button
                variant={sortBy === 'date' ? 'default' : 'outline'}
                onClick={() => setSortBy('date')}
                className="flex-1"
              >
                Date Received
              </Button>
              <Button
                variant={sortBy === 'number' ? 'default' : 'outline'}
                onClick={() => setSortBy('number')}
                className="flex-1"
              >
                Docket Number
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Results */}
      <Card>
        <CardHeader>
          <CardTitle>Results</CardTitle>
          <CardDescription>{filteredDockets.length} docket{filteredDockets.length !== 1 ? 's' : ''} found</CardDescription>
        </CardHeader>
        <CardContent>
          {filteredDockets.length === 0 ? (
            <div className="py-8 text-center text-muted-foreground">
              No dockets found matching your search criteria.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Docket Number</TableHead>
                    <TableHead>Description</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Cases</TableHead>
                    <TableHead>Date Received</TableHead>
                    <TableHead>Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredDockets.map((docket) => (
                    <TableRow key={docket.id}>
                      <TableCell className="font-mono font-semibold">{docket.docket_number}</TableCell>
                      <TableCell className="max-w-md truncate">{docket.description || '—'}</TableCell>
                      <TableCell>
                        <StatusBadge status={docket.status} size="sm" />
                      </TableCell>
                      <TableCell className="text-center">
                        <Badge variant="secondary">{docket.case_count || 0}</Badge>
                      </TableCell>
                      <TableCell className="text-sm">
                        {new Date(docket.date_received).toLocaleDateString()}
                      </TableCell>
                      <TableCell className="text-right">
                        <Button size="sm" asChild>
                          <a href={`/case-details?docketId=${docket.id}`}>
                            View Cases ({docket.case_count || 0})
                          </a>
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
