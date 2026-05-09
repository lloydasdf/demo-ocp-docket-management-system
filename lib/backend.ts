/**
 * BACKEND INTEGRATION LAYER
 * 
 * This file is designed to be a clean abstraction between the UI and the backend API.
 * Currently uses dummy data, but can be easily swapped with real API calls.
 * 
 * When implementing the backend:
 * 1. Replace the dummy implementations with fetch() calls to your local API
 * 2. Keep the same function signatures
 * 3. The UI components don't need to change
 * 
 * Expected Backend Endpoints:
 * - POST   /api/dockets              - Create docket
 * - GET    /api/dockets              - List dockets
 * - GET    /api/dockets/:id          - Get docket details
 * - PUT    /api/dockets/:id          - Update docket
 * - POST   /api/clearance            - Search clearance
 * - GET    /api/persons              - List/search persons
 * - POST   /api/persons              - Create person
 * - POST   /api/duplicates/check     - Check for duplicates
 * - GET    /api/system/status        - System status (local, sync, etc)
 */

import { Docket, CaseDetails, CaseStatus, Person } from './types';
import { dockets, getCaseById } from './dummy-data';

// ============================================================================
// DOCKET OPERATIONS
// ============================================================================

export interface DocketCreateRequest {
  docketNumber: string;
  createdDate: string;
  caseIds: string[];
  status: CaseStatus;
  description?: string;
  // TODO: Add audit fields when backend ready
  // createdBy: string;
  // createdAt: Date;
  // lastModifiedBy: string;
  // lastModifiedAt: Date;
}

export interface DocketResponse extends Docket {
  // TODO: Backend will add
  // audit: AuditTrail;
  // syncStatus?: 'synced' | 'pending' | 'offline';
  // backupStatus?: 'backed_up' | 'pending';
}

/**
 * Create a new docket
 * 
 * DUMMY: Returns mock docket
 * BACKEND: POST /api/dockets
 */
export async function createDocket(request: DocketCreateRequest): Promise<DocketResponse> {
  // TODO: Replace with actual backend call
  // return fetch('/api/dockets', {
  //   method: 'POST',
  //   headers: { 'Content-Type': 'application/json' },
  //   body: JSON.stringify(request)
  // }).then(r => r.json());

  console.log('[Backend] Creating docket:', request);
  return {
    id: `docket-${Date.now()}`,
    docketNumber: request.docketNumber,
    createdDate: request.createdDate,
    cases: request.caseIds.map(id => getCaseById(id) as CaseDetails),
    status: request.status,
    description: request.description || ''
  };
}

/**
 * Get docket by ID
 * 
 * DUMMY: Searches dummy data
 * BACKEND: GET /api/dockets/:id
 */
export async function getDocket(docketId: string): Promise<DocketResponse | null> {
  // TODO: Replace with actual backend call
  // return fetch(`/api/dockets/${docketId}`).then(r => r.json());

  console.log('[Backend] Fetching docket:', docketId);
  return dockets.find(d => d.id === docketId) || null;
}

/**
 * List all dockets with optional filters
 * 
 * DUMMY: Filters dummy data
 * BACKEND: GET /api/dockets?status=pending&page=1
 */
export async function listDockets(filters?: {
  status?: CaseStatus;
  search?: string;
  prosecutor?: string;
  limit?: number;
  offset?: number;
}): Promise<DocketResponse[]> {
  // TODO: Replace with actual backend call
  // const params = new URLSearchParams();
  // if (filters?.status) params.append('status', filters.status);
  // if (filters?.search) params.append('search', filters.search);
  // return fetch(`/api/dockets?${params}`).then(r => r.json());

  console.log('[Backend] Listing dockets with filters:', filters);
  
  let result = [...dockets];
  if (filters?.status) {
    result = result.filter(d => d.status === filters.status);
  }
  if (filters?.search) {
    const s = filters.search.toLowerCase();
    result = result.filter(d => 
      d.docketNumber.toLowerCase().includes(s) ||
      (d.description ?? '').toLowerCase().includes(s)
    );
  }
  return result;
}

// ============================================================================
// CLEARANCE SEARCH OPERATIONS
// ============================================================================

export interface ClearanceSearchRequest {
  name: string;
  dateOfBirth?: string;
  address?: string;
  // TODO: Add user context
  // requestedBy: string;
  // requestDate: Date;
}

export interface ClearanceMatch {
  docketId: string;
  docketNumber: string;
  personId: string;
  personName: string;
  matchType: 'exact' | 'alias' | 'fuzzy' | 'address';
  confidence: number;
  lastUpdated: string;
}

export interface ClearanceSearchResponse {
  searchId: string;
  query: ClearanceSearchRequest;
  matches: ClearanceMatch[];
  totalMatches: number;
  performedAt: string;
  // TODO: Backend will add
  // performedBy: string;
  // reviewed: boolean;
  // reviewNotes?: string;
  // reviewedBy?: string;
  // reviewedAt?: string;
}

/**
 * Perform clearance search
 * 
 * DUMMY: Searches dummy data with fuzzy matching
 * BACKEND: POST /api/clearance/search
 */
export async function performClearanceSearch(
  request: ClearanceSearchRequest
): Promise<ClearanceSearchResponse> {
  // TODO: Replace with actual backend call
  // return fetch('/api/clearance/search', {
  //   method: 'POST',
  //   headers: { 'Content-Type': 'application/json' },
  //   body: JSON.stringify(request)
  // }).then(r => r.json());

  console.log('[Backend] Performing clearance search:', request);
  
  // DUMMY: Simple search implementation
  const matches: ClearanceMatch[] = [];
  
  return {
    searchId: `search-${Date.now()}`,
    query: request,
    matches,
    totalMatches: matches.length,
    performedAt: new Date().toISOString()
    // TODO: Add when backend ready
    // performedBy: 'officer-id',
    // reviewed: false
  };
}

// ============================================================================
// PERSON / DUPLICATE CHECKING
// ============================================================================

export interface DuplicateCheckRequest {
  firstName: string;
  lastName: string;
  middleName?: string;
  dateOfBirth?: string;
  address?: string;
}

export interface DuplicatePerson {
  personId: string;
  name: string;
  aliases: string[];
  dateOfBirth?: string;
  address?: string;
  dockets: string[];
  similarity: number; // 0-100%
  matchReasons: string[];
}

export interface DuplicateDocket {
  docketId: string;
  docketNumber: string;
  status: string;
  createdDate: string;
  similarity: number; // 0-100%
  matchReasons: string[];
}

/**
 * Check for duplicate persons in the system
 * 
 * DUMMY: Compares against dummy data
 * BACKEND: POST /api/duplicates/persons/check
 */
export async function checkDuplicatePersons(
  request: DuplicateCheckRequest
): Promise<DuplicatePerson[]> {
  // TODO: Replace with actual backend call
  // return fetch('/api/duplicates/persons/check', {
  //   method: 'POST',
  //   body: JSON.stringify(request)
  // }).then(r => r.json());

  console.log('[Backend] Checking for duplicate persons:', request);
  return [];
}

/**
 * Check for duplicate dockets
 * 
 * DUMMY: Compares against dummy data
 * BACKEND: POST /api/duplicates/dockets/check
 */
export async function checkDuplicateDockets(
  docketNumber: string
): Promise<DuplicateDocket[]> {
  // TODO: Replace with actual backend call
  // return fetch('/api/duplicates/dockets/check', {
  //   method: 'POST',
  //   body: JSON.stringify({ docketNumber })
  // }).then(r => r.json());

  console.log('[Backend] Checking for duplicate dockets:', docketNumber);
  return [];
}

// ============================================================================
// SYSTEM STATUS & LOCAL OPERATION
// ============================================================================

export interface SystemStatus {
  mode: 'local' | 'cloud_sync';
  localServerConnected: boolean;
  lastBackup?: string;
  pendingSyncCount: number;
  offlineReady: boolean;
  version: string;
  // TODO: Add when available
  // databaseVersion?: string;
  // apiVersion?: string;
  // syncLastAttempt?: string;
  // storageUsed?: number;
  // storageAvailable?: number;
}

/**
 * Get system status (local server, sync, backup, offline mode)
 * 
 * DUMMY: Returns hardcoded status
 * BACKEND: GET /api/system/status
 */
export async function getSystemStatus(): Promise<SystemStatus> {
  // TODO: Replace with actual backend call
  // return fetch('/api/system/status').then(r => r.json());

  console.log('[Backend] Fetching system status');
  
  return {
    mode: 'local',
    localServerConnected: true,
    lastBackup: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
    pendingSyncCount: 0,
    offlineReady: true,
    version: '1.0.0-local'
  };
}

// ============================================================================
// AUDIT & ACTIVITY LOGGING
// ============================================================================

export interface AuditLogEntry {
  id: string;
  timestamp: string;
  action: string;
  entityType: 'docket' | 'case' | 'person' | 'search' | 'system';
  entityId: string;
  changes?: Record<string, any>;
  // TODO: When auth ready
  // performedBy: string;
  // performedByRole: string;
}

/**
 * Create audit log entry
 * 
 * DUMMY: Logs to console
 * BACKEND: POST /api/audit/log
 */
export async function logAuditEntry(
  action: string,
  entityType: AuditLogEntry['entityType'],
  entityId: string,
  changes?: Record<string, any>
): Promise<AuditLogEntry> {
  // TODO: Replace with actual backend call
  // return fetch('/api/audit/log', {
  //   method: 'POST',
  //   body: JSON.stringify({ action, entityType, entityId, changes })
  // }).then(r => r.json());

  const entry: AuditLogEntry = {
    id: `audit-${Date.now()}`,
    timestamp: new Date().toISOString(),
    action,
    entityType,
    entityId,
    changes
  };

  console.log('[Backend] Audit log:', entry);
  return entry;
}

/**
 * Get audit logs for an entity
 * 
 * DUMMY: Returns empty array
 * BACKEND: GET /api/audit/logs/:entityType/:entityId
 */
export async function getAuditLogs(
  entityType: AuditLogEntry['entityType'],
  entityId: string
): Promise<AuditLogEntry[]> {
  // TODO: Replace with actual backend call
  // return fetch(`/api/audit/logs/${entityType}/${entityId}`).then(r => r.json());

  console.log('[Backend] Fetching audit logs for:', entityType, entityId);
  return [];
}

// ============================================================================
// READY FOR BACKEND INTEGRATION
// ============================================================================
// The above functions are structured to be easily swapped with real API calls.
// No changes needed in UI components - just replace implementations above.
