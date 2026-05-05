'use client';

import { useState, useMemo } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { CaseStatus } from '@/lib/types';
import { Search as SearchIcon } from 'lucide-react';

export default function DocketSearch() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState<CaseStatus | 'All'>('All');
  const [sortBy, setSortBy] = useState<'date' | 'number'>('date');

  // Filter and search
  const filteredDockets = useMemo(() => {
    let filtered = dockets;

    // Filter by status
    if (selectedStatus !== 'All') {
      filtered = filtered.filter((d) => d.status === selectedStatus);
    }

    // Search by docket number, case number, or description
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (d) =>
          d.docketNumber.toLowerCase().includes(query) ||
          d.cases.some((c) => c.caseNumber.toLowerCase().includes(query)) ||
          d.description?.toLowerCase().includes(query)
      );
    }

    // Sort
    filtered.sort((a, b) => {
      if (sortBy === 'date') {
        return new Date(b.createdDate).getTime() - new Date(a.createdDate).getTime();
      }
      return a.docketNumber.localeCompare(b.docketNumber);
    });

    return filtered;
  }, [searchQuery, selectedStatus, sortBy]);

  const statuses: (CaseStatus | 'All')[] = ['All', 'Pending', 'Filed', 'Dismissed', 'Resolved', 'RFI'];

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Docket Search</h1>
        <p className="text-muted-foreground mt-1">Search and filter dockets by various criteria</p>
      </div>

      {/* Search and Filters Card */}
      <Card>
        <CardHeader>
          <CardTitle>Search Criteria</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex gap-4">
            <div className="flex-1 relative">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                placeholder="Search by docket #, case #, or description..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-sm font-medium text-foreground block mb-2">Status</label>
              <Select value={selectedStatus} onValueChange={(value) => setSelectedStatus(value as CaseStatus | 'All')}>
                <SelectTrigger>
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

            <div>
              <label className="text-sm font-medium text-foreground block mb-2">Sort By</label>
              <Select value={sortBy} onValueChange={(value) => setSortBy(value as 'date' | 'number')}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="date">Date (Newest)</SelectItem>
                  <SelectItem value="number">Docket Number</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <label className="text-sm font-medium text-foreground block mb-2">Results</label>
              <div className="flex items-center h-10 px-3 border border-input rounded-md bg-background">
                <span className="text-sm font-medium">{filteredDockets.length} found</span>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Results Table */}
      <Card>
        <CardHeader>
          <CardTitle>Search Results</CardTitle>
          <CardDescription>
            {filteredDockets.length === 0
              ? 'No dockets found matching your criteria'
              : `Showing ${filteredDockets.length} docket${filteredDockets.length === 1 ? '' : 's'}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {filteredDockets.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No dockets match your search criteria</p>
            </div>
          ) : (
            <div className="rounded-lg border border-border overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>Docket #</TableHead>
                    <TableHead>Cases</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead>Description</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredDockets.map((docket) => (
                    <TableRow key={docket.id} className="hover:bg-muted/50">
                      <TableCell className="font-medium text-primary">{docket.docketNumber}</TableCell>
                      <TableCell>
                        <Badge variant="outline">{docket.cases.length} case{docket.cases.length === 1 ? '' : 's'}</Badge>
                      </TableCell>
                      <TableCell className="text-sm">
                        {new Date(docket.createdDate).toLocaleDateString()}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground max-w-xs truncate">
                        {docket.description || '—'}
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={docket.status} size="sm" />
                      </TableCell>
                      <TableCell className="text-right">
                        <Button size="sm" asChild>
                          <a href={`/case-details?docketId=${docket.id}`}>
                            View Cases ({docket.cases.length})
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
