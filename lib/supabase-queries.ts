import { supabase } from './supabase-client';

// CASES QUERIES - Using actual cases table with docket info embedded

export async function getAllCases() {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      docket_types(id, code, description),
      case_statuses(id, status_code, status_name),
      persons!current_prosecutor_id(id, first_name, last_name, middle_name)
    `)
    .order('id', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching cases:', error);
    return [];
  }
  return data || [];
}

export async function getCaseById(id: string) {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      docket_types(id, code, description),
      case_statuses(id, status_code, status_name),
      persons!current_prosecutor_id(id, first_name, last_name, middle_name, email),
      case_participants(*),
      case_status_history(*)
    `)
    .eq('id', id)
    .single();

  if (error) {
    console.error('[v0] Error fetching case:', error);
    return null;
  }
  return data;
}

export async function searchCases(query: string) {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      docket_types(code),
      case_statuses(status_name),
      persons!current_prosecutor_id(first_name, last_name)
    `)
    .or(`docket_display_number.ilike.%${query}%,docket_number.ilike.%${query}%`)
    .order('id', { ascending: false });

  if (error) {
    console.error('[v0] Error searching cases:', error);
    return [];
  }
  return data || [];
}

export async function getCasesByYear(year: number) {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      docket_types(code),
      case_statuses(status_name)
    `)
    .eq('docket_year', year)
    .order('docket_number', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching cases by year:', error);
    return [];
  }
  return data || [];
}

export async function getCasesByStatus(statusId: number) {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      docket_types(code),
      case_statuses(status_name),
      persons!current_prosecutor_id(first_name, last_name)
    `)
    .eq('current_status', statusId)
    .order('id', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching cases by status:', error);
    return [];
  }
  return data || [];
}

// PERSONS QUERIES

export async function searchPersons(query: string) {
  const { data, error } = await supabase
    .from('persons')
    .select(`
      *,
      person_aliases(*),
      person_addresses(*)
    `)
    .or(
      `first_name.ilike.%${query}%,` +
      `last_name.ilike.%${query}%,` +
      `middle_name.ilike.%${query}%`
    )
    .limit(20);

  if (error) {
    console.error('[v0] Error searching persons:', error);
    return [];
  }
  return data || [];
}

export async function getPersonById(id: string) {
  const { data, error } = await supabase
    .from('persons')
    .select(`
      *,
      person_aliases(*),
      person_addresses(*)
    `)
    .eq('id', id)
    .single();

  if (error) {
    console.error('[v0] Error fetching person:', error);
    return null;
  }
  return data;
}

// CASE PARTICIPANTS QUERIES

export async function getCaseParticipants(caseId: string) {
  const { data, error } = await supabase
    .from('case_participants')
    .select(`
      *,
      persons(id, first_name, last_name, middle_name),
      participant_roles(id, role_name)
    `)
    .eq('case_id', caseId);

  if (error) {
    console.error('[v0] Error fetching participants:', error);
    return [];
  }
  return data || [];
}

// CASE STATUS HISTORY

export async function getCaseStatusHistory(caseId: string) {
  const { data, error } = await supabase
    .from('case_status_history')
    .select(`
      *,
      case_statuses(status_name),
      persons(id, first_name, last_name)
    `)
    .eq('case_id', caseId)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching status history:', error);
    return [];
  }
  return data || [];
}

// DASHBOARD STATISTICS

export async function getDashboardStats() {
  const { data, error } = await supabase
    .from('cases')
    .select('id, current_status');

  if (error) {
    console.error('[v0] Error fetching dashboard stats:', error);
    return null;
  }

  // Count by status
  const stats: Record<number, number> = {};
  (data || []).forEach((c: any) => {
    stats[c.current_status] = (stats[c.current_status] || 0) + 1;
  });

  return {
    total: data?.length || 0,
    byStatus: stats,
  };
}

export async function getRecentCases(limit: number = 5) {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      docket_types(code),
      case_statuses(status_name)
    `)
    .order('id', { ascending: false })
    .limit(limit);

  if (error) {
    console.error('[v0] Error fetching recent cases:', error);
    return [];
  }
  return data || [];
}

// DOCKET TYPES

export async function getDocketTypes() {
  const { data, error } = await supabase
    .from('docket_types')
    .select('*')
    .order('code');

  if (error) {
    console.error('[v0] Error fetching docket types:', error);
    return [];
  }
  return data || [];
}

// CASE STATUSES

export async function getCaseStatuses() {
  const { data, error } = await supabase
    .from('case_statuses')
    .select('*')
    .order('status_code');

  if (error) {
    console.error('[v0] Error fetching case statuses:', error);
    return [];
  }
  return data || [];
}

// PROSECUTORS

export async function getProsecutors() {
  const { data, error } = await supabase
    .from('persons')
    .select('*')
    .order('last_name, first_name');

  if (error) {
    console.error('[v0] Error fetching prosecutors:', error);
    return [];
  }
  return data || [];
}

// CASE ASSIGNMENTS

export async function getCaseAssignments(caseId: string) {
  const { data, error } = await supabase
    .from('case_assignments')
    .select(`
      *,
      persons(id, first_name, last_name, email)
    `)
    .eq('case_id', caseId)
    .order('assigned_date', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching assignments:', error);
    return [];
  }
  return data || [];
}

// ADDRESSES

export async function getAddresses(personId: string) {
  const { data, error } = await supabase
    .from('person_addresses')
    .select(`
      *,
      address_types(id, address_type)
    `)
    .eq('person_id', personId);

  if (error) {
    console.error('[v0] Error fetching addresses:', error);
    return [];
  }
  return data || [];
}

// AUDIT LOGS

export async function getAuditLogs(limit: number = 20) {
  const { data, error } = await supabase
    .from('audit_logs')
    .select(`
      *,
      persons(first_name, last_name)
    `)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    console.error('[v0] Error fetching audit logs:', error);
    return [];
  }
  return data || [];
}

// DUPLICATE CHECKING

export async function checkPersonDuplicates(
  firstName: string,
  lastName: string,
  middleName?: string
) {
  const { data, error } = await supabase
    .from('persons')
    .select('*,person_aliases(*)')
    .or(
      `first_name.ilike.${firstName},` +
      `last_name.ilike.${lastName}`
    )
    .limit(5);

  if (error) {
    console.error('[v0] Error checking duplicates:', error);
    return [];
  }
  return data || [];
}

// VIOLATIONS / CHARGES

export async function getCaseCharges(caseId: string) {
  const { data, error } = await supabase
    .from('case_charges')
    .select('*')
    .eq('case_id', caseId);

  if (error) {
    console.error('[v0] Error fetching charges:', error);
    return [];
  }
  return data || [];
}

// REPORTS

export async function getCasesByType() {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      docket_type_id,
      docket_types(code, description)
    `)
    .order('docket_type_id');

  if (error) {
    console.error('[v0] Error fetching cases by type:', error);
    return [];
  }

  // Group by type
  const grouped: Record<string, any> = {};
  (data || []).forEach((c: any) => {
    const type = c.docket_types?.code || 'Unknown';
    grouped[type] = (grouped[type] || 0) + 1;
  });

  return Object.entries(grouped).map(([type, count]) => ({
    type,
    count,
  }));
}

export async function getCasesByYearReport() {
  const { data, error } = await supabase
    .from('cases')
    .select('docket_year, id');

  if (error) {
    console.error('[v0] Error fetching cases by year:', error);
    return [];
  }

  // Group by year
  const grouped: Record<number, number> = {};
  (data || []).forEach((c: any) => {
    const year = c.docket_year || 2026;
    grouped[year] = (grouped[year] || 0) + 1;
  });

  return Object.entries(grouped)
    .map(([year, count]) => ({
      year: parseInt(year),
      count,
    }))
    .sort((a, b) => b.year - a.year);
}

export async function getProsecutorCaseCount(prosecutorId: string) {
  const { data, error } = await supabase
    .from('cases')
    .select('id')
    .eq('current_prosecutor_id', prosecutorId);

  if (error) {
    console.error('[v0] Error fetching prosecutor cases:', error);
    return 0;
  }
  return data?.length || 0;
}
