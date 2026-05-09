'use client';

import { useState, useMemo } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { CaseStatus } from '@/lib/types';
import { Search as SearchIcon, CheckCircle } from 'lucide-react';

interface StatusUpdateRecord {
  id: string;
  caseNumber: string;
  newStatus: CaseStatus;
  remarks: string;
  updateDate: string;
  updatedBy: string;
}

export default function StatusUpdate() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCaseNumber, setSelectedCaseNumber] = useState('');
  const [newStatus, setNewStatus] = useState<CaseStatus>('Pending');
  const [remarks, setRemarks] = useState('');
  const [updatedBy, setUpdatedBy] = useState('Admin User');
  const [statusUpdates, setStatusUpdates] = useState<StatusUpdateRecord[]>([]);
  const [successMessage, setSuccessMessage] = useState('');

  // Get all cases from dockets
  const allCases = useMemo(() => {
    return dockets.flatMap((d) =>
      d.cases.map((c) => ({
        ...c,
        docketNumber: d.docketNumber,
      }))
    );
  }, []);

  // Filter cases for status update
  const filteredCases = useMemo(() => {
    return allCases.filter(
      (c) =>
        searchQuery === '' ||
        c.caseNumber.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.docketNumber.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [allCases, searchQuery]);

  const selectedCase = allCases.find((c) => c.caseNumber === selectedCaseNumber);

  const handleStatusUpdate = () => {
    if (!selectedCaseNumber || !newStatus || !remarks.trim()) {
      return;
    }

    const update: StatusUpdateRecord = {
      id: `update-${Date.now()}`,
      caseNumber: selectedCaseNumber,
      newStatus,
      remarks,
      updateDate: new Date().toISOString().split('T')[0],
      updatedBy,
    };

    setStatusUpdates([update, ...statusUpdates]);
    setSelectedCaseNumber('');
    setNewStatus('Pending');
    setRemarks('');
    setSuccessMessage('Status updated successfully!');
    setTimeout(() => setSuccessMessage(''), 3000);
  };

  const statuses: CaseStatus[] = ['Pending', 'Filed', 'Dismissed', 'Resolved', 'RFI'];

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Status Update</h1>
        <p className="text-muted-foreground mt-1">Update case status and add remarks</p>
      </div>

      {/* Success Message */}
      {successMessage && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded flex items-center gap-2">
          <CheckCircle className="w-5 h-5" />
          {successMessage}
        </div>
      )}

      {/* Status Update Form */}
      <Card>
        <CardHeader>
          <CardTitle>Update Case Status</CardTitle>
          <CardDescription>Change case status and add remarks</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Case Selection */}
          <div>
            <Label htmlFor="case-search">Select Case</Label>
            <div className="relative mt-1">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                id="case-search"
                placeholder="Search by case number or docket..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>

            {/* Search Results Dropdown */}
            {searchQuery && filteredCases.length > 0 && (
              <div className="absolute z-10 w-full mt-1 bg-background border border-border rounded-md shadow-lg max-h-48 overflow-y-auto">
                {filteredCases.slice(0, 5).map((c) => (
                  <button
                    key={c.caseNumber}
                    onClick={() => {
                      setSelectedCaseNumber(c.caseNumber);
                      setSearchQuery('');
                    }}
                    className="w-full text-left px-4 py-3 hover:bg-muted border-b border-border last:border-b-0"
                  >
                    <p className="font-medium">{c.caseNumber}</p>
                    <p className="text-xs text-muted-foreground">{c.docketNumber}</p>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Selected Case Info */}
          {selectedCase && (
            <div className="p-4 bg-muted rounded-lg">
              <h4 className="font-semibold mb-2">Selected Case</h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-muted-foreground">Case Number:</span>
                  <p className="font-medium">{selectedCase.caseNumber}</p>
                </div>
                <div>
                  <span className="text-muted-foreground">Current Status:</span>
                  <div className="mt-1">
                    <StatusBadge status={selectedCase.status} size="sm" />
                  </div>
                </div>
                <div>
                  <span className="text-muted-foreground">Prosecutor:</span>
                  <p className="font-medium">{selectedCase.prosecutor || 'Unassigned'}</p>
                </div>
              </div>
            </div>
          )}

          {/* Status and Remarks */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="new-status">New Status *</Label>
              <Select value={newStatus} onValueChange={(value) => setNewStatus(value as CaseStatus)}>
                <SelectTrigger id="new-status" className="mt-1">
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
              <Label htmlFor="updated-by">Updated By</Label>
              <Input
                id="updated-by"
                value={updatedBy}
                onChange={(e) => setUpdatedBy(e.target.value)}
                className="mt-1"
                placeholder="Your name or title"
              />
            </div>
          </div>

          <div>
            <Label htmlFor="remarks">Remarks *</Label>
            <Textarea
              id="remarks"
              placeholder="Add remarks or notes about this status change..."
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              className="mt-1"
              rows={4}
            />
          </div>

          <Button
            onClick={handleStatusUpdate}
            disabled={!selectedCaseNumber || !newStatus || !remarks.trim()}
            className="w-full"
          >
            Update Status
          </Button>
        </CardContent>
      </Card>

      {/* Status Update History */}
      <Card>
        <CardHeader>
          <CardTitle>Status Update History</CardTitle>
          <CardDescription>
            {statusUpdates.length === 0
              ? 'No updates yet'
              : `${statusUpdates.length} update${statusUpdates.length === 1 ? '' : 's'}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {statusUpdates.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No status updates yet</p>
            </div>
          ) : (
            <div className="space-y-4">
              {statusUpdates.map((update) => (
                <div key={update.id} className="p-4 border border-border rounded-lg">
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <p className="font-semibold">{update.caseNumber}</p>
                      <p className="text-sm text-muted-foreground">
                        {new Date(update.updateDate).toLocaleDateString()}
                      </p>
                    </div>
                    <StatusBadge status={update.newStatus} size="sm" />
                  </div>
                  <p className="text-sm mb-2">{update.remarks}</p>
                  <p className="text-xs text-muted-foreground">By: {update.updatedBy}</p>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
