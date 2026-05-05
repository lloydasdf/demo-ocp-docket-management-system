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

type NavItem = {
  name: string;
  href: string;
  icon: any;
  description: string;
  featured?: boolean;
};

const navigation: NavItem[] = [
  {
    name: 'Dashboard',
    href: '/',
    icon: Home,
    description: 'Overview and KPIs',
  },
  {
    name: 'Clearance Search',
    href: '/clearance-search',
    icon: Search,
    description: 'Search records by name & aliases',
    featured: true,
  },
  {
    name: 'Docket Search',
    href: '/docket-search',
    icon: Search,
    description: 'Search for dockets',
  },
  {
    name: 'Case Details',
    href: '/cases',
    icon: FileText,
    description: 'View case information',
  },
  {
    name: 'New Docket Entry',
    href: '/new-docket',
    icon: Plus,
    description: 'Create new docket',
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
    name: 'Reports',
    href: '/reports',
    icon: BarChart3,
    description: 'Analytics and reports',
  },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-64 bg-sidebar text-sidebar-foreground border-r border-sidebar-border min-h-screen flex flex-col shadow-lg">
      {/* Header */}
      <div className="p-6 border-b border-sidebar-border/50 bg-gradient-to-br from-sidebar to-sidebar/80">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-9 h-9 bg-sidebar-accent rounded-lg flex items-center justify-center text-sidebar-accent-foreground font-bold text-sm">
            OCP
          </div>
          <div>
            <h1 className="text-base font-bold leading-tight">Docket System</h1>
            <p className="text-xs text-sidebar-foreground/70">Official Records</p>
          </div>
        </div>
        <p className="text-xs text-sidebar-foreground/60 pl-12 mt-1">
          Office of the City Prosecutor
        </p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto p-4 space-y-2">
        {navigation.map((item, index) => {
          const Icon = item.icon;
          const isActive = pathname === item.href;
          const isFeatured = item.featured || false;

          return (
            <div key={item.href}>
              {isFeatured && index > 0 && <div className="my-3 border-t border-sidebar-border/30" />}
              <Link
                href={item.href}
                className={cn(
                  'flex items-center gap-3 px-4 py-3 rounded-md text-sm font-medium transition-colors',
                  isFeatured && 'ring-1 ring-sidebar-accent',
                  isActive
                    ? 'bg-sidebar-primary text-sidebar-primary-foreground'
                    : isFeatured
                    ? 'bg-sidebar-accent/20 text-sidebar-foreground hover:bg-sidebar-accent/30'
                    : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
                )}
                title={item.description}
              >
                <Icon className="w-5 h-5 flex-shrink-0" />
                <div className="flex-1">
                  <div>{item.name}</div>
                  {isFeatured && <div className="text-xs opacity-70">{item.description}</div>}
                </div>
                {isFeatured && isActive && <div className="w-2 h-2 bg-sidebar-accent rounded-full" />}
              </Link>
            </div>
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
