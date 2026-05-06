import { supabase } from './supabase-client';

// DOCKET QUERIES

export async function getDockets() {
  const { data, error } = await supabase
    .from('docket_list_view')
    .select('*')
    .order('date_received', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching dockets:', error);
    return [];
  }
  return data || [];
}

export async function getDocketById(id: string) {
  const { data, error } = await supabase
    .from('dockets')
    .select(`
      *,
      cases(*),
      prosecutor_assignments(*),
      case_status_updates(*)
    `)
    .eq('id', id)
    .single();

  if (error) {
    console.error('[v0] Error fetching docket:', error);
    return null;
  }
  return data;
}

export async function searchDockets(query: string) {
  const { data, error } = await supabase
    .from('docket_list_view')
    .select('*')
    .or(`docket_number.ilike.%${query}%,description.ilike.%${query}%`)
    .order('date_received', { ascending: false });

  if (error) {
    console.error('[v0] Error searching dockets:', error);
    return [];
  }
  return data || [];
}

// CASE QUERIES

export async function getCases() {
  const { data, error } = await supabase
    .from('case_list_view')
    .select('*')
    .order('date_received', { ascending: false });

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
      case_participants(*, persons(*)),
      case_violations(*, violations(*)),
      case_status_updates(*),
      attachments(*)
    `)
    .eq('id', id)
    .single();

  if (error) {
    console.error('[v0] Error fetching case:', error);
    return null;
  }
  return data;
}

export async function getCasesByDocketId(docketId: string) {
  const { data, error } = await supabase
    .from('cases')
    .select(`
      *,
      case_participants(*, persons(*)),
      case_violations(*, violations(*)),
      case_status_updates(*)
    `)
    .eq('docket_id', docketId)
    .order('date_received', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching cases by docket:', error);
    return [];
  }
  return data || [];
}

// PERSON QUERIES

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
      person_addresses(*),
      case_participants(*)
    `)
    .eq('id', id)
    .single();

  if (error) {
    console.error('[v0] Error fetching person:', error);
    return null;
  }
  return data;
}

// CLEARANCE SEARCH QUERIES

export async function searchClearance(personName: string) {
  const { data: persons, error: searchError } = await supabase
    .from('persons')
    .select(`
      *,
      person_aliases(*),
      case_participants(count)
    `)
    .or(
      `first_name.ilike.%${personName}%,` +
      `last_name.ilike.%${personName}%`
    )
    .limit(10);

  if (searchError) {
    console.error('[v0] Error searching clearance:', searchError);
    return { persons: [], searches: [] };
  }

  // Check for existing clearance search record
  const { data: searches } = await supabase
    .from('clearance_searches')
    .select('*')
    .ilike('search_name', `%${personName}%`)
    .limit(3);

  return { persons: persons || [], searches: searches || [] };
}

// DASHBOARD STATISTICS

export async function getDashboardStats() {
  const { data: dockets, error: docketError } = await supabase
    .from('dockets')
    .select('id, status');

  if (docketError) {
    console.error('[v0] Error fetching docket stats:', docketError);
    return null;
  }

  const stats = {
    totalDockets: dockets?.length || 0,
    pending: dockets?.filter((d: any) => d.status === 'Pending').length || 0,
    filed: dockets?.filter((d: any) => d.status === 'Filed').length || 0,
    resolved: dockets?.filter((d: any) => d.status === 'Resolved').length || 0,
  };

  return stats;
}

export async function getRecentDockets(limit: number = 5) {
  const { data, error } = await supabase
    .from('docket_list_view')
    .select('*')
    .order('date_received', { ascending: false })
    .limit(limit);

  if (error) {
    console.error('[v0] Error fetching recent dockets:', error);
    return [];
  }
  return data || [];
}

// STATUS HISTORY

export async function getCaseStatusHistory(caseId: string) {
  const { data, error } = await supabase
    .from('case_status_updates')
    .select(`
      *,
      app_users(full_name)
    `)
    .eq('case_id', caseId)
    .order('updated_at', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching status history:', error);
    return [];
  }
  return data || [];
}

// PROSECUTOR ASSIGNMENT

export async function getProsecutorAssignments(docketId: string) {
  const { data, error } = await supabase
    .from('prosecutor_assignments')
    .select(`
      *,
      app_users(full_name, email)
    `)
    .eq('docket_id', docketId)
    .order('assigned_at', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching assignments:', error);
    return [];
  }
  return data || [];
}

export async function getProsecutors() {
  const { data, error } = await supabase
    .from('app_users')
    .select('*')
    .eq('role', 'Prosecutor')
    .order('full_name');

  if (error) {
    console.error('[v0] Error fetching prosecutors:', error);
    return [];
  }
  return data || [];
}

// ATTACHMENTS

export async function getAttachmentsByCaseId(caseId: string) {
  const { data, error } = await supabase
    .from('attachments')
    .select('*')
    .eq('case_id', caseId)
    .order('uploaded_at', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching attachments:', error);
    return [];
  }
  return data || [];
}

export async function getAttachmentsByDocketId(docketId: string) {
  const { data, error } = await supabase
    .from('attachments')
    .select('*')
    .eq('docket_id', docketId)
    .order('uploaded_at', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching docket attachments:', error);
    return [];
  }
  return data || [];
}

// VIOLATIONS

export async function getViolations() {
  const { data, error } = await supabase
    .from('violations')
    .select('*')
    .order('statute_code');

  if (error) {
    console.error('[v0] Error fetching violations:', error);
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
    .select(`*,person_aliases(*)`)
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

// REPORTS DATA

export async function getViolationStats() {
  const { data, error } = await supabase
    .from('cases')
    .select('case_violations(violations(statute_code))');

  if (error) {
    console.error('[v0] Error fetching violation stats:', error);
    return [];
  }
  return data || [];
}

export async function getProsecutorStats() {
  const { data, error } = await supabase
    .from('prosecutor_assignments')
    .select(`
      app_users(full_name),
      cases(count)
    `);

  if (error) {
    console.error('[v0] Error fetching prosecutor stats:', error);
    return [];
  }
  return data || [];
}

export async function getStatusStats() {
  const { data, error } = await supabase
    .from('cases')
    .select('status');

  if (error) {
    console.error('[v0] Error fetching status stats:', error);
    return [];
  }

  const stats = {
    pending: data?.filter((c: any) => c.status === 'Pending').length || 0,
    filed: data?.filter((c: any) => c.status === 'Filed').length || 0,
    resolved: data?.filter((c: any) => c.status === 'Resolved').length || 0,
    dismissed: data?.filter((c: any) => c.status === 'Dismissed').length || 0,
  };

  return stats;
}

export async function getCasesByStatus(status: string) {
  const { data, error } = await supabase
    .from('cases')
    .select('*')
    .eq('status', status)
    .order('date_received', { ascending: false });

  if (error) {
    console.error('[v0] Error fetching cases by status:', error);
    return [];
  }
  return data || [];
}
