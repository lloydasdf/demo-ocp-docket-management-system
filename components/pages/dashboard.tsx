'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getAllCases, getRecentCases, getDashboardStats, getCaseStatuses } from '@/lib/supabase-queries';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import Link from 'next/link';
import { ArrowRight, AlertTriangle } from 'lucide-react';

export default function Dashboard() {
  const [cases, setCases] = useState<any[]>([]);
  const [recentCases, setRecentCases] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [statuses, setStatuses] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const [allCases, dashStats, recent, statusList] = await Promise.all([
          getAllCases(),
          getDashboardStats(),
          getRecentCases(5),
          getCaseStatuses(),
        ]);

        setCases(allCases);
        setRecentCases(recent);
        setStats(dashStats);
        setStatuses(statusList);
      } catch (err) {
        console.error('[v0] Dashboard load error:', err);
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, []);

  if (loading) {
    return (
      <div className="p-8 flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <Spinner className="w-12 h-12 mx-auto mb-4" />
          <p className="text-muted-foreground">Loading dashboard...</p>
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

  // Build status color map
  const colorMap: Record<number, string> = {
    1: 'hsl(130, 72%, 40%)',    // Resolved - Green
    2: 'hsl(250, 47%, 42%)',    // Filed - Purple
    3: 'hsl(35, 84%, 52%)',     // Pending - Orange
    4: 'hsl(29, 100%, 52%)',    // Archived - Red-Orange
    5: 'hsl(0, 84%, 60%)',      // Dismissed - Red
    6: 'hsl(200, 75%, 50%)',    // In Progress - Blue
    7: 'hsl(280, 75%, 50%)',    // On Hold - Purple
    8: 'hsl(50, 100%, 50%)',    // For Review - Yellow
    9: 'hsl(160, 75%, 50%)',    // Remanded - Teal
    10: 'hsl(300, 75%, 50%)',   // Appealed - Magenta
  };

  // Status distribution data
  const statusData = statuses
    .filter(s => stats?.byStatus?.[s.id] > 0)
    .map(s => ({
      name: s.status_name,
      value: stats.byStatus[s.id] || 0,
      fill: colorMap[s.id] || 'hsl(0, 0%, 50%)',
    }));

  // Total cases
  const totalCases = stats?.total || 0;

  // Monthly trend (dummy for now)
  const monthlyData = [
    { month: 'Jan', cases: 8 },
    { month: 'Feb', cases: 12 },
    { month: 'Mar', cases: 15 },
  ];

  // Violation distribution (dummy for now)
  const violationData = [
    { statute: 'RA 9165', count: 3 },
    { statute: 'RPC Art. 308', count: 2 },
    { statute: 'RA 9262', count: 1 },
    { statute: 'RPC Art. 315', count: 1 },
  ];

  return (
    <div className="p-8 space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Dashboard</h1>
        <p className="text-muted-foreground mt-1">Welcome to the OCP Docket Management System</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Cases</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{totalCases}</div>
            <p className="text-xs text-muted-foreground mt-1">All dockets in system</p>
          </CardContent>
        </Card>

        {statuses.slice(0, 3).map(status => (
          <Card key={status.id}>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">{status.status_name}</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">{stats?.byStatus?.[status.id] || 0}</div>
              <p className="text-xs text-muted-foreground mt-1">Current status</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Status Distribution */}
        {statusData.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle>Case Status Distribution</CardTitle>
              <CardDescription>Current breakdown by status</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <PieChart>
                  <Pie
                    data={statusData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, value }) => `${name}: ${value}`}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {statusData.map((entry, i) => (
                      <Cell key={`cell-${i}`} fill={entry.fill} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        )}

        {/* Violation Types */}
        <Card>
          <CardHeader>
            <CardTitle>Top Violations</CardTitle>
            <CardDescription>Most common statutes cited</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={violationData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="statute" angle={-45} textAnchor="end" height={80} tick={{ fontSize: 12 }} />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="hsl(250, 47%, 42%)" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Monthly Trend */}
      <Card>
        <CardHeader>
          <CardTitle>Monthly Intake Trend</CardTitle>
          <CardDescription>Number of new cases per month</CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={monthlyData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="month" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="cases" stroke="hsl(250, 47%, 42%)" strokeWidth={2} dot={{ fill: 'hsl(250, 47%, 42%)', r: 6 }} />
            </LineChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      {/* Recent Entries */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold">Recent Entries</h2>
          <Link href="/docket-search" className="flex items-center gap-2 text-primary hover:underline">
            View All <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        {recentCases.length === 0 ? (
          <Card>
            <CardContent className="pt-8 text-center">
              <p className="text-muted-foreground">No recent cases found</p>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-2">
            {recentCases.map((caseItem) => (
              <Link
                key={caseItem.id}
                href={`/case-details?caseId=${caseItem.id}`}
                className="block p-4 border border-border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-semibold">{caseItem.docket_display_number || caseItem.docket_number}</p>
                    <p className="text-sm text-muted-foreground">Type: {caseItem.docket_types?.code}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="px-2 py-1 rounded text-xs bg-primary/10 text-primary font-medium">
                      {caseItem.case_statuses?.status_name || 'Unknown'}
                    </span>
                    <span className="text-xs text-muted-foreground">{new Date(caseItem.created_at).toLocaleDateString()}</span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
