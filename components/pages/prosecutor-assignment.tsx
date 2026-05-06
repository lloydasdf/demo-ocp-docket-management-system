'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getDockets, getProsecutors, getProsecutorAssignments } from '@/lib/supabase-queries';
import { Badge } from '@/components/ui/badge';
import { User, Scale, AlertTriangle } from 'lucide-react';

export default function ProsecutorAssignment() {
  const [dockets, setDockets] = useState<any[]>([]);
  const [prosecutors, setProsecutors] = useState<any[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);

        const [docketsData, prosecutorsData] = await Promise.all([
          getDockets(),
          getProsecutors(),
        ]);

        setDockets(docketsData);
        setProsecutors(prosecutorsData);
      } catch (err) {
        console.error('[v0] Error loading assignment data:', err);
        setError('Failed to load assignment data');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  const filteredDockets = dockets.filter(
    (d) =>
      d.docket_number.toLowerCase().includes(searchQuery.toLowerCase()) ||
      d.description?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <Spinner className="w-12 h-12 mx-auto mb-4" />
          <p className="text-muted-foreground">Loading assignments...</p>
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
        <h1 className="text-3xl font-bold text-foreground">Prosecutor Assignments</h1>
        <p className="text-muted-foreground mt-1">View docket assignments to prosecutors</p>
      </div>

      {/* Prosecutors Overview */}
      <Card>
        <CardHeader>
          <CardTitle>Active Prosecutors</CardTitle>
          <CardDescription>{prosecutors.length} prosecutor{prosecutors.length !== 1 ? 's' : ''} in system</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {prosecutors.map((prosecutor) => (
              <Card key={prosecutor.id} className="bg-muted/50">
                <CardContent className="pt-6">
                  <div className="flex items-start gap-3">
                    <User className="w-5 h-5 text-muted-foreground mt-1 flex-shrink-0" />
                    <div>
                      <p className="font-semibold">{prosecutor.full_name}</p>
                      <p className="text-xs text-muted-foreground mt-1">{prosecutor.email}</p>
                      <Badge variant="outline" className="mt-2 text-xs">
                        {prosecutor.role}
                      </Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Docket Assignments */}
      <Card>
        <CardHeader>
          <CardTitle>Docket Assignments by Prosecutor</CardTitle>
          <CardDescription>All active assignments</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Search */}
          <div>
            <label className="text-sm font-medium">Search Dockets</label>
            <Input
              placeholder="Search by docket number or description..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="mt-2"
            />
          </div>

          {/* Assignments Grid */}
          <div className="space-y-4 pt-4">
            {filteredDockets.length === 0 ? (
              <p className="text-center text-muted-foreground py-8">No dockets found matching your search.</p>
            ) : (
              filteredDockets.map((docket) => (
                <Card key={docket.id} className="bg-background border">
                  <CardContent className="pt-6">
                    <div className="space-y-3">
                      <div className="flex items-start justify-between">
                        <div>
                          <p className="font-mono font-semibold text-sm">{docket.docket_number}</p>
                          <p className="text-sm text-muted-foreground mt-1">{docket.description}</p>
                        </div>
                        <Badge>{docket.case_count || 0} case{(docket.case_count || 0) !== 1 ? 's' : ''}</Badge>
                      </div>

                      {/* Prosecutor Info */}
                      <div className="pt-3 border-t">
                        <p className="text-xs font-semibold text-muted-foreground mb-2">ASSIGNED PROSECUTOR</p>
                        {docket.prosecutor_name ? (
                          <div className="flex items-center gap-2">
                            <Scale className="w-4 h-4 text-primary" />
                            <span className="font-medium text-sm">{docket.prosecutor_name}</span>
                            <span className="text-xs text-muted-foreground">
                              Since {new Date(docket.prosecutor_assigned_at).toLocaleDateString()}
                            </span>
                          </div>
                        ) : (
                          <p className="text-sm text-muted-foreground italic">Not yet assigned</p>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </CardContent>
      </Card>

      {/* Read-Only Notice */}
      <Alert>
        <AlertDescription>
          Prosecutor assignments are managed during the New Docket Entry workflow. This view is read-only.
        </AlertDescription>
      </Alert>
    </div>
  );
}
