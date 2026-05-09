'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import {
  Search,
  FileText,
  Plus,
  Users,
  CheckCircle,
  BarChart3,
  Home,
  PanelLeftClose,
  PanelLeftOpen,
} from 'lucide-react';
import { cn } from '@/lib/utils';

const SIDEBAR_AUTO_COLLAPSE_QUERY = '(max-width: 1024px)';

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
  const [isCollapsed, setIsCollapsed] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia(SIDEBAR_AUTO_COLLAPSE_QUERY);
    const syncCollapsedState = () => setIsCollapsed(mediaQuery.matches);

    syncCollapsedState();
    mediaQuery.addEventListener('change', syncCollapsedState);

    return () => mediaQuery.removeEventListener('change', syncCollapsedState);
  }, []);

  const ToggleIcon = isCollapsed ? PanelLeftOpen : PanelLeftClose;
  const toggleLabel = isCollapsed ? 'Expand sidebar' : 'Collapse sidebar';

  return (
    <aside
      className={cn(
        'h-screen shrink-0 bg-sidebar text-sidebar-foreground border-r border-sidebar-border flex flex-col transition-[width] duration-200 ease-in-out',
        isCollapsed ? 'w-20' : 'w-64',
      )}
    >
      {/* Header */}
      <div className={cn('border-b border-sidebar-border', isCollapsed ? 'p-3' : 'p-6')}>
        <div className={cn('flex gap-2', isCollapsed ? 'flex-col items-center' : 'items-center justify-between')}>
          <div className={cn('flex min-w-0 items-center gap-2', isCollapsed && 'justify-center')}>
            <div className="w-8 h-8 bg-sidebar-primary rounded flex items-center justify-center text-sidebar-primary-foreground font-bold">
              OCP
            </div>
            {!isCollapsed ? <h1 className="truncate text-lg font-bold">Docket System</h1> : null}
          </div>
          <button
            type="button"
            className="flex h-8 w-8 items-center justify-center rounded-md text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring"
            onClick={() => setIsCollapsed((current) => !current)}
            aria-label={toggleLabel}
            title={toggleLabel}
            aria-pressed={isCollapsed}
          >
            <ToggleIcon className="h-4 w-4" />
          </button>
        </div>
        {!isCollapsed ? (
          <p className="mt-1 text-xs text-sidebar-foreground/70">
            Office of the City Prosecutor
          </p>
        ) : null}
      </div>

      {/* Navigation */}
      <nav className={cn('flex-1 overflow-y-auto p-4 space-y-1', isCollapsed && 'px-3')}>
        {navigation.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href || (item.href === '/cases' && pathname.startsWith('/cases/'));

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 rounded-md py-3 text-sm font-medium transition-colors',
                isCollapsed ? 'justify-center px-3' : 'px-4',
                isActive
                  ? 'bg-sidebar-primary text-sidebar-primary-foreground'
                  : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
              )}
              title={item.description}
              aria-label={isCollapsed ? item.name : undefined}
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              {!isCollapsed ? <span>{item.name}</span> : null}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-sidebar-border">
        {isCollapsed ? (
          <div className="mx-auto flex h-9 w-9 items-center justify-center rounded-full border border-sidebar-border text-sm font-semibold text-sidebar-foreground">
            AU
          </div>
        ) : (
          <div className="text-xs text-sidebar-foreground/60 text-center">
            <p>Logged in as</p>
            <p className="font-medium text-sidebar-foreground">Admin User</p>
          </div>
        )}
      </div>
    </aside>
  );
}
