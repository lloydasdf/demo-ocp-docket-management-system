'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { StatusBadge } from '@/components/status-badge';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getDockets, getRecentDockets, getStatusStats } from '@/lib/supabase-queries';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import Link from 'next/link';
import { ArrowRight, AlertTriangle } from 'lucide-react';

export default function Dashboard() {
  const [dockets, setDockets] = useState<any[]>([]);
  const [recentDockets, setRecentDockets] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const [dockets, recent, statusStats] = await Promise.all([
          getDockets(),
          getRecentDockets(5),
          getStatusStats(),
        ]);

        setDockets(dockets);
        setRecentDockets(recent);
        setStats(statusStats);
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

  // Calculate KPIs
  const totalDockets = dockets.length;
  const pendingCount = stats?.pending || 0;
  const filedCount = stats?.filed || 0;
  const resolvedCount = stats?.resolved || 0;

  // Status distribution data
  const statusData = [
    { name: 'Pending', value: pendingCount, fill: 'hsl(35, 84%, 52%)' },
    { name: 'Filed', value: filedCount, fill: 'hsl(250, 47%, 42%)' },
    { name: 'Dismissed', value: stats?.dismissed || 0, fill: 'hsl(0, 0%, 75%)' },
    { name: 'Resolved', value: resolvedCount, fill: 'hsl(130, 72%, 40%)' },
  ].filter(item => item.value > 0);

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
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Dockets</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{totalDockets}</div>
            <p className="text-xs text-muted-foreground mt-1">All cases in system</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pending</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-[hsl(35,84%,52%)]">{pendingCount}</div>
            <p className="text-xs text-muted-foreground mt-1">Awaiting action</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Filed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-[hsl(250,47%,42%)]">{filedCount}</div>
            <p className="text-xs text-muted-foreground mt-1">In court</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Resolved</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-[hsl(130,72%,40%)]">{resolvedCount}</div>
            <p className="text-xs text-muted-foreground mt-1">Completed cases</p>
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Status Distribution */}
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
                  {statusData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.fill} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

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

        {recentDockets.length === 0 ? (
          <Card>
            <CardContent className="pt-8 text-center">
              <p className="text-muted-foreground">No recent dockets found</p>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-2">
            {recentDockets.map((docket) => (
              <Link
                key={docket.id}
                href={`/case-details?docketId=${docket.id}`}
                className="block p-4 border border-border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-semibold">{docket.docket_number}</p>
                    <p className="text-sm text-muted-foreground">{docket.case_count || 0} case{(docket.case_count || 0) !== 1 ? 's' : ''}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <StatusBadge status={docket.status} size="sm" />
                    <span className="text-xs text-muted-foreground">{new Date(docket.date_received).toLocaleDateString()}</span>
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
