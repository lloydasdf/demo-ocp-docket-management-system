'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Search,
  FileText,
  Plus,
  Users,
  CheckCircle,
  BarChart3,
  Home,
} from 'lucide-react';
import { cn } from '@/lib/utils';

const navigation = [
  {
    name: 'Dashboard',
    href: '/',
    icon: Home,
    description: 'Overview and KPIs',
  },
  {
    name: 'Docket Search',
    href: '/docket-search',
    icon: Search,
    description: 'Search for dockets',
  },
  {
    name: 'New Docket Entry',
    href: '/new-docket',
    icon: Plus,
    description: 'Create new docket',
  },
  {
    name: 'Case Details',
    href: '/cases',
    icon: FileText,
    description: 'View case information',
  },
  {
    name: 'Prosecutor Assignment',
    href: '/prosecutor-assignment',
    icon: Users,
    description: 'Assign prosecutors',
  },
  {
    name: 'Status Update',
    href: '/status-update',
    icon: CheckCircle,
    description: 'Update case status',
  },
  {
    name: 'Clearance Search',
    href: '/clearance-search',
    icon: Search,
    description: 'Search clearance records',
  },
  {
    name: 'Reports',
    href: '/reports',
    icon: BarChart3,
    description: 'Analytics and reports',
  },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="h-screen w-64 shrink-0 bg-sidebar text-sidebar-foreground border-r border-sidebar-border flex flex-col">
      {/* Header */}
      <div className="p-6 border-b border-sidebar-border">
        <div className="flex items-center gap-2 mb-1">
          <div className="w-8 h-8 bg-sidebar-primary rounded flex items-center justify-center text-sidebar-primary-foreground font-bold">
            OCP
          </div>
          <h1 className="text-lg font-bold">Docket System</h1>
        </div>
        <p className="text-xs text-sidebar-foreground/70">
          Office of the City Prosecutor
        </p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto p-4 space-y-1">
        {navigation.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href;

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-4 py-3 rounded-md text-sm font-medium transition-colors',
                isActive
                  ? 'bg-sidebar-primary text-sidebar-primary-foreground'
                  : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
              )}
              title={item.description}
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              <span>{item.name}</span>
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-sidebar-border">
        <div className="text-xs text-sidebar-foreground/60 text-center">
          <p>Logged in as</p>
          <p className="font-medium text-sidebar-foreground">Admin User</p>
        </div>
      </div>
    </aside>
  );
}
