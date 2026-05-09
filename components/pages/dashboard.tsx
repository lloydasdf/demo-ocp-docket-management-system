'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { StatusBadge } from '@/components/status-badge';
import { dockets } from '@/lib/dummy-data';
import { BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import Link from 'next/link';
import { ArrowRight } from 'lucide-react';

export default function Dashboard() {
  // Calculate KPIs
  const totalDockets = dockets.length;
  const pendingCount = dockets.filter((d) => d.status === 'Pending').length;
  const filedCount = dockets.filter((d) => d.status === 'Filed').length;
  const resolvedCount = dockets.filter((d) => d.status === 'Resolved').length;

  // Recent entries
  const recentEntries = [...dockets].sort((a, b) => new Date(b.createdDate).getTime() - new Date(a.createdDate).getTime()).slice(0, 5);

  // Status distribution data
  const statusData = [
    { name: 'Pending', value: pendingCount, fill: 'hsl(35, 84%, 52%)' },
    { name: 'Filed', value: filedCount, fill: 'hsl(250, 47%, 42%)' },
    { name: 'Dismissed', value: dockets.filter((d) => d.status === 'Dismissed').length, fill: 'hsl(0, 0%, 75%)' },
    { name: 'Resolved', value: resolvedCount, fill: 'hsl(130, 72%, 40%)' },
    { name: 'RFI', value: dockets.filter((d) => d.status === 'RFI').length, fill: 'hsl(29, 100%, 52%)' },
  ];

  // Violation distribution
  const violationCounts: Record<string, number> = {};
  dockets.forEach((docket) => {
    docket.cases.forEach((c) => {
      c.violations.forEach((v) => {
        violationCounts[v.statute] = (violationCounts[v.statute] || 0) + 1;
      });
    });
  });

  const violationData = Object.entries(violationCounts)
    .map(([statute, count]) => ({ statute, count }))
    .sort((a, b) => b.count - a.count);

  // Monthly trend (dummy)
  const monthlyData = [
    { month: 'Jan', cases: 8 },
    { month: 'Feb', cases: 12 },
    { month: 'Mar', cases: 15 },
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
      <Card>
        <CardHeader>
          <CardTitle>Recent Dockets</CardTitle>
          <CardDescription>Latest entries in the system</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {recentEntries.map((docket) => (
              <div key={docket.id} className="flex items-center justify-between p-3 border border-border rounded-lg hover:bg-muted/50 transition-colors">
                <div className="flex-1">
                  <p className="font-medium text-foreground">{docket.docketNumber}</p>
                  <p className="text-sm text-muted-foreground">{docket.description || `${docket.cases.length} case(s)`}</p>
                </div>
                <div className="flex items-center gap-4">
                  <StatusBadge status={docket.status} size="sm" />
                  <Link href={`/docket-search?id=${docket.id}`} className="text-primary hover:text-primary/80">
                    <ArrowRight className="w-4 h-4" />
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
