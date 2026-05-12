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
const SIDEBAR_HIDE_QUERY = '(max-width: 768px)';

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
    name: 'Cases',
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
  const [isCompactScreen, setIsCompactScreen] = useState(false);
  const [isCompactOpen, setIsCompactOpen] = useState(false);

  useEffect(() => {
    const collapseQuery = window.matchMedia(SIDEBAR_AUTO_COLLAPSE_QUERY);
    const hideQuery = window.matchMedia(SIDEBAR_HIDE_QUERY);

    const syncResponsiveState = () => {
      setIsCompactScreen(hideQuery.matches);
      setIsCollapsed(collapseQuery.matches);

      if (hideQuery.matches) {
        setIsCompactOpen(false);
      }
    };

    syncResponsiveState();
    collapseQuery.addEventListener('change', syncResponsiveState);
    hideQuery.addEventListener('change', syncResponsiveState);

    return () => {
      collapseQuery.removeEventListener('change', syncResponsiveState);
      hideQuery.removeEventListener('change', syncResponsiveState);
    };
  }, []);

  const isIconOnly = !isCompactScreen && isCollapsed;
  const ToggleIcon = isCompactScreen || !isCollapsed ? PanelLeftClose : PanelLeftOpen;
  const toggleLabel = isCompactScreen ? 'Hide sidebar' : isCollapsed ? 'Expand sidebar' : 'Collapse sidebar';

  function handleToggleSidebar() {
    if (isCompactScreen) {
      setIsCompactOpen((current) => !current);
      return;
    }

    setIsCollapsed((current) => !current);
  }

  return (
    <>
      {isCompactScreen && !isCompactOpen ? (
        <button
          type="button"
          className="fixed left-3 top-3 z-50 flex h-10 w-10 items-center justify-center rounded-md border border-border bg-background text-foreground shadow-md transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          onClick={() => setIsCompactOpen(true)}
          aria-label="Show sidebar"
          title="Show sidebar"
        >
          <PanelLeftOpen className="h-5 w-5" />
        </button>
      ) : null}

      {isCompactScreen && isCompactOpen ? (
        <button
          type="button"
          className="fixed inset-0 z-30 cursor-default bg-black/40"
          onClick={() => setIsCompactOpen(false)}
          aria-label="Close sidebar overlay"
        />
      ) : null}

      <aside
        className={cn(
          'h-screen shrink-0 bg-sidebar text-sidebar-foreground border-r border-sidebar-border flex flex-col transition-all duration-200 ease-in-out',
          isCompactScreen
            ? 'fixed inset-y-0 left-0 z-40 w-64 shadow-xl'
            : isIconOnly
              ? 'w-20'
              : 'w-64',
          isCompactScreen && (isCompactOpen ? 'translate-x-0' : '-translate-x-full'),
        )}
      >
      {/* Header */}
      <div className={cn('border-b border-sidebar-border', isIconOnly ? 'p-3' : 'p-6')}>
        <div className={cn('flex gap-2', isIconOnly ? 'flex-col items-center' : 'items-center justify-between')}>
          <div className={cn('flex min-w-0 items-center gap-2', isIconOnly && 'justify-center')}>
            <div className="w-8 h-8 bg-sidebar-primary rounded flex items-center justify-center text-sidebar-primary-foreground font-bold">
              OCP
            </div>
            {!isIconOnly ? <h1 className="truncate text-lg font-bold">Docket System</h1> : null}
          </div>
          <button
            type="button"
            className="flex h-8 w-8 items-center justify-center rounded-md text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring"
            onClick={handleToggleSidebar}
            aria-label={toggleLabel}
            title={toggleLabel}
            aria-expanded={isCompactScreen ? isCompactOpen : !isCollapsed}
          >
            <ToggleIcon className="h-4 w-4" />
          </button>
        </div>
        {!isIconOnly ? (
          <p className="mt-1 text-xs text-sidebar-foreground/70">
            Office of the City Prosecutor
          </p>
        ) : null}
      </div>

      {/* Navigation */}
      <nav className={cn('flex-1 overflow-y-auto p-4 space-y-1', isIconOnly && 'px-3')}>
        {navigation.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href || (item.href === '/cases' && pathname.startsWith('/cases/'));

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 rounded-md py-3 text-sm font-medium transition-colors',
                isIconOnly ? 'justify-center px-3' : 'px-4',
                isActive
                  ? 'bg-sidebar-primary text-sidebar-primary-foreground'
                  : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground'
              )}
              title={item.description}
              aria-label={isIconOnly ? item.name : undefined}
              onClick={() => {
                if (isCompactScreen) {
                  setIsCompactOpen(false);
                }
              }}
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              {!isIconOnly ? <span>{item.name}</span> : null}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-sidebar-border">
        {isIconOnly ? (
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
    </>
  );
}
