import type { LucideIcon } from 'lucide-react';

export type AppRoleCode = 'DEVELOPER' | 'CHIEF' | 'ADMIN' | 'PROSECUTOR' | 'STAFF' | (string & {});
export type NavigationKey = 'new-docket' | 'cases' | 'clearance-search' | 'user-management' | 'admin-reports' | 'audit-logs' | 'case-stage-monitor' | 'gdrive-configuration';
export type RoleInput = string | string[] | null | undefined;

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

export function normalizeRoleCodes(roleInput: RoleInput): AppRoleCode[] {
  const roleValues = Array.isArray(roleInput) ? roleInput : [roleInput];
  return Array.from(new Set(roleValues.map((role) => normalizeRoleCode(role)).filter((role): role is AppRoleCode => Boolean(role))));
}

export function isChief(role: RoleInput) {
  return normalizeRoleCodes(role).includes('CHIEF');
}

export function isAdmin(role: RoleInput) {
  return normalizeRoleCodes(role).includes('ADMIN');
}

const ROLE_NAVIGATION: Record<string, NavigationKey[]> = {
  CHIEF: ['cases', 'clearance-search', 'user-management'],
  ADMIN: ['new-docket', 'cases', 'clearance-search', 'admin-reports'],
  PROSECUTOR: ['cases'],
  DEVELOPER: ['new-docket', 'cases', 'clearance-search', 'user-management', 'case-stage-monitor', 'audit-logs', 'gdrive-configuration'],
};

const ROLE_ROUTES: Record<string, string[]> = {
  CHIEF: ['/cases', '/clearance-search', '/user-management'],
  ADMIN: ['/new-docket', '/cases', '/clearance-search', '/admin-reports'],
  PROSECUTOR: ['/cases'],
  DEVELOPER: ['/new-docket', '/cases', '/clearance-search', '/user-management', '/developer/case-stage-monitor', '/developer/audit-logs', '/developer/gdrive-configuration'],
};

function getAllowedNavigationKeys(roleInput: RoleInput) {
  return Array.from(new Set(normalizeRoleCodes(roleInput).flatMap((role) => ROLE_NAVIGATION[role] ?? [])));
}

function getAllowedRoutes(roleInput: RoleInput) {
  return Array.from(new Set(normalizeRoleCodes(roleInput).flatMap((role) => ROLE_ROUTES[role] ?? [])));
}

export function getNavigationForRole<T extends NavigationDefinition>(role: RoleInput, navigation: T[]): T[] {
  const allowedKeys = getAllowedNavigationKeys(role);
  return navigation.filter((item) => allowedKeys.includes(item.key));
}

export function canAccessRoute(role: RoleInput, route: string) {
  const allowedRoutes = getAllowedRoutes(role);
  return allowedRoutes.some((allowedRoute) => route === allowedRoute || (allowedRoute === '/cases' && route.startsWith('/cases/')));
}

export function canShowCaseManagementActions(role: RoleInput) {
  const roles = normalizeRoleCodes(role);
  return roles.length > 0 && !roles.includes('CHIEF');
}

export function canExportCasesToExcel(role: RoleInput) {
  const roles = normalizeRoleCodes(role);
  return roles.length > 0 && !roles.includes('PROSECUTOR');
}

export function canViewLinkedDocket(role: RoleInput) {
  const roles = normalizeRoleCodes(role);
  return roles.includes('ADMIN') || roles.includes('DEVELOPER');
}

export function canViewCriminalCaseNumbers(role: RoleInput) {
  const roles = normalizeRoleCodes(role);
  return roles.includes('ADMIN') || roles.includes('DEVELOPER');
}

export function canViewCaseAging(role: RoleInput) {
  const roles = normalizeRoleCodes(role);
  return roles.includes('ADMIN') || roles.includes('DEVELOPER') || roles.includes('CHIEF');
}
