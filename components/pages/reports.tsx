'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Spinner } from '@/components/ui/spinner';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { getViolationStats, getProsecutorStats, getStatusStats, getDockets } from '@/lib/supabase-queries';
import { BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, LineChart, Line } from 'recharts';
import { AlertTriangle } from 'lucide-react';

export default function Reports() {
  const [dockets, setDockets] = useState<any[]>([]);
  const [statusStats, setStatusStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadData = async () => {
      try {
        setLoading(true);
        setError(null);

        const [docketsData, stats] = await Promise.all([
          getDockets(),
          getStatusStats(),
        ]);

        setDockets(docketsData);
        setStatusStats(stats);
      } catch (err) {
        console.error('[v0] Error loading reports:', err);
        setError('Failed to load reports data');
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
          <p className="text-muted-foreground">Loading reports...</p>
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

  // Prepare data for charts
  const statusData = [
    { name: 'Pending', value: statusStats?.pending || 0, fill: 'hsl(35, 84%, 52%)' },
    { name: 'Filed', value: statusStats?.filed || 0, fill: 'hsl(250, 47%, 42%)' },
    { name: 'Dismissed', value: statusStats?.dismissed || 0, fill: 'hsl(0, 0%, 75%)' },
    { name: 'Resolved', value: statusStats?.resolved || 0, fill: 'hsl(130, 72%, 40%)' },
  ].filter(item => item.value > 0);

  // Monthly trend (dummy for now)
  const monthlyData = [
    { month: 'Jan', dockets: 8 },
    { month: 'Feb', dockets: 12 },
    { month: 'Mar', dockets: 15 },
    { month: 'Apr', dockets: 10 },
    { month: 'May', dockets: 18 },
  ];

  // Violation distribution
  const violationStats = [
    { statute: 'RA 9165', count: 3, fill: 'hsl(35, 84%, 52%)' },
    { statute: 'RPC Art. 308', count: 2, fill: 'hsl(250, 47%, 42%)' },
    { statute: 'RA 9262', count: 1, fill: 'hsl(200, 75%, 50%)' },
    { statute: 'RPC Art. 315', count: 1, fill: 'hsl(130, 72%, 40%)' },
    { statute: 'RA 10175', count: 1, fill: 'hsl(29, 100%, 52%)' },
    { statute: 'Other', count: 2, fill: 'hsl(0, 0%, 75%)' },
  ];

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Reports</h1>
        <p className="text-muted-foreground mt-1">System statistics and analytics</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Dockets</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{dockets.length}</div>
            <p className="text-xs text-muted-foreground mt-1">All cases</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pending</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-[hsl(35,84%,52%)]">{statusStats?.pending || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">Awaiting action</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Filed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-[hsl(250,47%,42%)]">{statusStats?.filed || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">In court</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Resolved</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-[hsl(130,72%,40%)]">{statusStats?.resolved || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">Completed</p>
          </CardContent>
        </Card>
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Status Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Case Status Distribution</CardTitle>
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
                  {statusData.map((entry) => (
                    <Cell key={`cell-${entry.name}`} fill={entry.fill} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Violation Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Violations by Statute</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={violationStats}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="statute" angle={-45} textAnchor="end" height={80} />
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
          <CardTitle>Monthly Docket Trend</CardTitle>
          <CardDescription>Dockets filed per month</CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={monthlyData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="month" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line
                type="monotone"
                dataKey="dockets"
                stroke="hsl(250, 47%, 42%)"
                strokeWidth={2}
                dot={{ fill: 'hsl(250, 47%, 42%)', r: 4 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      {/* Summary Statistics */}
      <Card>
        <CardHeader>
          <CardTitle>System Summary</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            <div className="border-l-4 border-primary pl-4">
              <p className="text-sm text-muted-foreground">Average Cases per Docket</p>
              <p className="text-2xl font-bold">
                {dockets.length > 0
                  ? (dockets.reduce((sum, d) => sum + (d.case_count || 0), 0) / dockets.length).toFixed(1)
                  : 0}
              </p>
            </div>
            <div className="border-l-4 border-[hsl(35,84%,52%)] pl-4">
              <p className="text-sm text-muted-foreground">Pending Rate</p>
              <p className="text-2xl font-bold">
                {dockets.length > 0
                  ? (((statusStats?.pending || 0) / dockets.length) * 100).toFixed(0)
                  : 0}
                %
              </p>
            </div>
            <div className="border-l-4 border-[hsl(130,72%,40%)] pl-4">
              <p className="text-sm text-muted-foreground">Resolution Rate</p>
              <p className="text-2xl font-bold">
                {dockets.length > 0
                  ? (((statusStats?.resolved || 0) / dockets.length) * 100).toFixed(0)
                  : 0}
                %
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Read-Only Notice */}
      <Alert>
        <AlertDescription>
          Reports are automatically generated from live docket data. All data is read-only.
        </AlertDescription>
      </Alert>
    </div>
  );
}
