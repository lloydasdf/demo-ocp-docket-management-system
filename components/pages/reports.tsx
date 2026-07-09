'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { dockets, prosecutors } from '@/lib/dummy-data';
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { Badge } from '@/components/ui/badge';

export default function Reports() {
  // Calculate statistics
  const statusDistribution = {
    Pending: dockets.filter((d) => d.status === 'Pending').length,
    Filed: dockets.filter((d) => d.status === 'Filed').length,
    Dismissed: dockets.filter((d) => d.status === 'Dismissed').length,
    MixedResult: dockets.filter((d) => d.status === 'Mixed Result').length,
  };

  // Violations by statute
  const violationsByStatute: Record<string, number> = {};
  dockets.forEach((docket) => {
    docket.cases.forEach((c) => {
      c.violations.forEach((v) => {
        violationsByStatute[v.statute] = (violationsByStatute[v.statute] || 0) + 1;
      });
    });
  });

  const violationData = Object.entries(violationsByStatute)
    .map(([statute, count]) => ({ statute, count }))
    .sort((a, b) => b.count - a.count);

  // Prosecutor caseload
  const prosecutorCaseload: Record<string, number> = {};
  dockets.forEach((docket) => {
    docket.cases.forEach((c) => {
      if (c.prosecutor) {
        prosecutorCaseload[c.prosecutor] = (prosecutorCaseload[c.prosecutor] || 0) + 1;
      }
    });
  });

  const caseloadData = Object.entries(prosecutorCaseload)
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count);

  // Monthly trend (simulated)
  const monthlyData = [
    { month: 'Jan', cases: 8, mixedResult: 2, pending: 3, filed: 3 },
    { month: 'Feb', cases: 12, mixedResult: 4, pending: 5, filed: 3 },
    { month: 'Mar', cases: 15, mixedResult: 6, pending: 6, filed: 3 },
  ];

  // Chart colors
  const chartColors = {
    Pending: '#d4a574',
    Filed: '#3d5a80',
    Dismissed: '#bfbfbf',
    MixedResult: '#e67e22',
  };

  const statusChartData = [
    { name: 'Pending', value: statusDistribution.Pending, fill: chartColors.Pending },
    { name: 'Filed', value: statusDistribution.Filed, fill: chartColors.Filed },
    { name: 'Dismissed', value: statusDistribution.Dismissed, fill: chartColors.Dismissed },
    { name: 'Mixed Result', value: statusDistribution.MixedResult, fill: chartColors.MixedResult },
  ];

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Reports & Analytics</h1>
        <p className="text-muted-foreground mt-1">System-wide statistics and insights</p>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Cases</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">{dockets.length}</div>
            <p className="text-xs text-muted-foreground mt-1">Across all dockets</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Avg. Per Prosecutor</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {caseloadData.length > 0 ? Math.round(dockets.length / prosecutors.length) : 0}
            </div>
            <p className="text-xs text-muted-foreground mt-1">{prosecutors.length} prosecutors</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Resolution Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {Math.round((statusDistribution.MixedResult / dockets.length) * 100)}%
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              {statusDistribution.MixedResult} mixed result
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pending Cases</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-yellow-600">{statusDistribution.Pending}</div>
            <p className="text-xs text-muted-foreground mt-1">Awaiting action</p>
          </CardContent>
        </Card>
      </div>

      {/* Charts Tabs */}
      <Tabs defaultValue="status" className="w-full">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="status">Status</TabsTrigger>
          <TabsTrigger value="violations">Violations</TabsTrigger>
          <TabsTrigger value="prosecutors">Prosecutors</TabsTrigger>
          <TabsTrigger value="trends">Trends</TabsTrigger>
        </TabsList>

        {/* Status Distribution */}
        <TabsContent value="status">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Pie Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Status Distribution (Pie)</CardTitle>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={statusChartData}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={({ name, value }) => `${name}: ${value}`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {statusChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.fill} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Bar Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Status Distribution (Bar)</CardTitle>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={statusChartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="value" fill="#3d5a80" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Summary Table */}
            <Card className="lg:col-span-2">
              <CardHeader>
                <CardTitle>Status Breakdown</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {Object.entries(statusDistribution).map(([status, count]) => (
                    <div key={status} className="flex items-center justify-between p-3 border border-border rounded">
                      <div className="flex items-center gap-3">
                        <div
                          className="w-4 h-4 rounded"
                          style={{ backgroundColor: chartColors[status as keyof typeof chartColors] }}
                        ></div>
                        <span className="font-medium">{status}</span>
                      </div>
                      <div className="flex items-center gap-4">
                        <Badge variant="outline">{count}</Badge>
                        <span className="text-sm text-muted-foreground w-16 text-right">
                          {Math.round((count / dockets.length) * 100)}%
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Violations */}
        <TabsContent value="violations">
          <Card>
            <CardHeader>
              <CardTitle>Violations by Statute</CardTitle>
              <CardDescription>{violationData.length} different statutes cited</CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <ResponsiveContainer width="100%" height={400}>
                <BarChart data={violationData} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis type="number" />
                  <YAxis dataKey="statute" type="category" width={100} />
                  <Tooltip />
                  <Bar dataKey="count" fill="#3d5a80" />
                </BarChart>
              </ResponsiveContainer>

              <div className="space-y-2">
                <h4 className="font-semibold">Top Violations</h4>
                {violationData.slice(0, 10).map((item, index) => (
                  <div key={item.statute} className="flex items-center justify-between p-2 border-b border-border">
                    <div className="flex items-center gap-3">
                      <span className="text-lg font-bold text-muted-foreground">{index + 1}.</span>
                      <span className="font-medium">{item.statute}</span>
                    </div>
                    <Badge>{item.count} case{item.count === 1 ? '' : 's'}</Badge>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Prosecutors */}
        <TabsContent value="prosecutors">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Prosecutor Caseload</CardTitle>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={caseloadData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} tick={{ fontSize: 12 }} />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="count" fill="#3d5a80" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Prosecutor Details</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {prosecutors.map((prosecutor) => {
                    const caseCount = prosecutorCaseload[prosecutor.name] || 0;
                    return (
                      <div key={prosecutor.id} className="p-3 border border-border rounded">
                        <p className="font-semibold">{prosecutor.name}</p>
                        <p className="text-sm text-muted-foreground">{prosecutor.officeLocation}</p>
                        <div className="mt-2 flex items-center justify-between">
                          <p className="text-sm">Cases assigned:</p>
                          <Badge>{caseCount}</Badge>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Trends */}
        <TabsContent value="trends">
          <Card>
            <CardHeader>
              <CardTitle>Monthly Trends</CardTitle>
              <CardDescription>Cases by status over time</CardDescription>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={400}>
                <LineChart data={monthlyData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="month" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="cases" stroke="#3d5a80" strokeWidth={2} name="Total Cases" />
                  <Line
                    type="monotone"
                    dataKey="mixedResult"
                    stroke="#52a552"
                    strokeWidth={2}
                    name="Mixed Result"
                  />
                  <Line type="monotone" dataKey="pending" stroke="#d4a574" strokeWidth={2} name="Pending" />
                  <Line type="monotone" dataKey="filed" stroke="#3d5a80" strokeWidth={2} name="Filed" />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
