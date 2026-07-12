import type { LucideIcon } from 'lucide-react';

export type AppRoleCode = 'DEVELOPER' | 'CHIEF' | 'ADMIN' | 'PROSECUTOR' | 'STAFF' | (string & {});
export type NavigationKey = 'new-docket' | 'cases' | 'clearance-search' | 'user-management' | 'admin-reports';

export type NavigationDefinition = {
  key: NavigationKey;
  name: string;
  href: string;
  icon: LucideIcon;
  description: string;
};

export function normalizeRoleCode(role: string | null | undefined): AppRoleCode | null {
  const normalized = role?.trim().toUpperCase();
  return normalized ? normalized : null;
}

export function isChief(role: string | null | undefined) {
  return normalizeRoleCode(role) === 'CHIEF';
}

export function isAdmin(role: string | null | undefined) {
  return normalizeRoleCode(role) === 'ADMIN';
}

const ROLE_NAVIGATION: Record<string, NavigationKey[]> = {
  CHIEF: ['cases', 'clearance-search', 'user-management'],
  ADMIN: ['new-docket', 'cases', 'clearance-search', 'admin-reports'],
  PROSECUTOR: ['cases'],
  DEVELOPER: ['new-docket', 'cases', 'clearance-search', 'user-management'],
};

const ROLE_ROUTES: Record<string, string[]> = {
  CHIEF: ['/cases', '/clearance-search', '/user-management'],
  ADMIN: ['/new-docket', '/cases', '/clearance-search', '/admin-reports'],
  PROSECUTOR: ['/cases'],
  DEVELOPER: ['/new-docket', '/cases', '/clearance-search', '/user-management'],
};

export function getNavigationForRole<T extends NavigationDefinition>(role: string | null | undefined, navigation: T[]): T[] {
  const allowedKeys = ROLE_NAVIGATION[normalizeRoleCode(role) ?? ''] ?? [];
  return navigation.filter((item) => allowedKeys.includes(item.key));
}

export function canAccessRoute(role: string | null | undefined, route: string) {
  const normalizedRole = normalizeRoleCode(role);
  const allowedRoutes = ROLE_ROUTES[normalizedRole ?? ''] ?? [];
  return allowedRoutes.some((allowedRoute) => route === allowedRoute || (allowedRoute === '/cases' && route.startsWith('/cases/')));
}

export function canShowCaseManagementActions(role: string | null | undefined) {
  const normalizedRole = normalizeRoleCode(role);
  return Boolean(normalizedRole) && normalizedRole !== 'CHIEF';
}
