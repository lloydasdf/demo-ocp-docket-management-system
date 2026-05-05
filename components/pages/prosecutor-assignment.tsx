'use client';

import { useState, useMemo } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { dockets, prosecutors } from '@/lib/dummy-data';
import { Search as SearchIcon, CheckCircle } from 'lucide-react';

interface Assignment {
  id: string;
  caseNumber: string;
  prosecutorId: string;
  assignmentDate: string;
  status: 'Active' | 'Reassigned' | 'Completed';
}

export default function ProsecutorAssignment() {
  const [selectedCaseNumber, setSelectedCaseNumber] = useState('');
  const [selectedProsecutorId, setSelectedProsecutorId] = useState('');
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
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

  // Filter cases for assignment
  const availableCases = useMemo(() => {
    return allCases
      .filter(
        (c) =>
          !assignments.some((a) => a.caseNumber === c.caseNumber) &&
          c.prosecutor === undefined
      )
      .filter(
        (c) =>
          searchQuery === '' ||
          c.caseNumber.toLowerCase().includes(searchQuery.toLowerCase())
      );
  }, [allCases, assignments, searchQuery]);

  const handleAssign = () => {
    if (!selectedCaseNumber || !selectedProsecutorId) {
      return;
    }

    const prosecutor = prosecutors.find((p) => p.id === selectedProsecutorId);
    if (!prosecutor) return;

    const newAssignment: Assignment = {
      id: `assign-${Date.now()}`,
      caseNumber: selectedCaseNumber,
      prosecutorId: selectedProsecutorId,
      assignmentDate: new Date().toISOString().split('T')[0],
      status: 'Active',
    };

    setAssignments([...assignments, newAssignment]);
    setSelectedCaseNumber('');
    setSelectedProsecutorId('');
    setSuccessMessage('Prosecutor assigned successfully!');
    setTimeout(() => setSuccessMessage(''), 3000);
  };

  const handleRemoveAssignment = (id: string) => {
    setAssignments(assignments.filter((a) => a.id !== id));
  };

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Prosecutor Assignment</h1>
        <p className="text-muted-foreground mt-1">Assign prosecutors to cases</p>
      </div>

      {/* Success Message */}
      {successMessage && (
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded flex items-center gap-2">
          <CheckCircle className="w-5 h-5" />
          {successMessage}
        </div>
      )}

      {/* Assignment Form */}
      <Card>
        <CardHeader>
          <CardTitle>New Assignment</CardTitle>
          <CardDescription>Assign a prosecutor to a case</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <Label htmlFor="case-search">Select Case</Label>
              <div className="relative mt-1">
                <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  id="case-search"
                  placeholder="Search case number..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
              {searchQuery && availableCases.length > 0 && (
                <div className="absolute z-10 w-full mt-1 bg-background border border-border rounded-md shadow-lg max-h-48 overflow-y-auto">
                  {availableCases.slice(0, 5).map((c) => (
                    <button
                      key={c.caseNumber}
                      onClick={() => {
                        setSelectedCaseNumber(c.caseNumber);
                        setSearchQuery('');
                      }}
                      className="w-full text-left px-3 py-2 hover:bg-muted"
                    >
                      <p className="font-medium">{c.caseNumber}</p>
                      <p className="text-xs text-muted-foreground">{c.docketNumber}</p>
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div>
              <Label htmlFor="prosecutor">Prosecutor</Label>
              <Select value={selectedProsecutorId} onValueChange={setSelectedProsecutorId}>
                <SelectTrigger id="prosecutor" className="mt-1">
                  <SelectValue placeholder="Select prosecutor..." />
                </SelectTrigger>
                <SelectContent>
                  {prosecutors.map((p) => (
                    <SelectItem key={p.id} value={p.id}>
                      <div>
                        <p className="font-medium">{p.name}</p>
                        <p className="text-xs text-muted-foreground">{p.officeLocation}</p>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-end">
              <Button
                onClick={handleAssign}
                disabled={!selectedCaseNumber || !selectedProsecutorId}
                className="w-full"
              >
                Assign
              </Button>
            </div>
          </div>

          {selectedCaseNumber && (
            <div className="p-3 bg-muted rounded">
              <p className="text-sm">
                <span className="text-muted-foreground">Selected Case:</span>{' '}
                <span className="font-medium">{selectedCaseNumber}</span>
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Assignments Table */}
      <Card>
        <CardHeader>
          <CardTitle>Active Assignments</CardTitle>
          <CardDescription>
            {assignments.length === 0
              ? 'No assignments yet'
              : `${assignments.length} assignment${assignments.length === 1 ? '' : 's'}`}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {assignments.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground">No assignments created yet</p>
            </div>
          ) : (
            <div className="rounded-lg border border-border overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>Case Number</TableHead>
                    <TableHead>Prosecutor</TableHead>
                    <TableHead>Assignment Date</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Action</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {assignments.map((assignment) => {
                    const prosecutor = prosecutors.find((p) => p.id === assignment.prosecutorId);
                    return (
                      <TableRow key={assignment.id} className="hover:bg-muted/50">
                        <TableCell className="font-medium text-primary">{assignment.caseNumber}</TableCell>
                        <TableCell>{prosecutor?.name || '—'}</TableCell>
                        <TableCell className="text-sm">
                          {new Date(assignment.assignmentDate).toLocaleDateString()}
                        </TableCell>
                        <TableCell>
                          <Badge
                            className={
                              assignment.status === 'Active'
                                ? 'bg-green-100 text-green-800'
                                : assignment.status === 'Reassigned'
                                  ? 'bg-yellow-100 text-yellow-800'
                                  : 'bg-gray-100 text-gray-800'
                            }
                          >
                            {assignment.status}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleRemoveAssignment(assignment.id)}
                            className="text-destructive"
                          >
                            Remove
                          </Button>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Prosecutors Info */}
      <Card>
        <CardHeader>
          <CardTitle>Available Prosecutors</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {prosecutors.map((prosecutor) => (
              <div key={prosecutor.id} className="p-4 border border-border rounded-lg">
                <h4 className="font-semibold">{prosecutor.name}</h4>
                <p className="text-sm text-muted-foreground mt-1">{prosecutor.officeLocation}</p>
                <p className="text-sm text-muted-foreground">{prosecutor.contactNumber}</p>
                <p className="text-xs text-muted-foreground mt-2 break-all">{prosecutor.email}</p>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
