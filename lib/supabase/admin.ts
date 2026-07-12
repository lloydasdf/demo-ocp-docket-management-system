import 'server-only';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/lib/database.types';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

export type SupabaseAdminClient = SupabaseClient<Database>;

let adminClient: SupabaseAdminClient | null = null;

export function getSupabaseAdminClient(): SupabaseAdminClient {
  if (adminClient) return adminClient;

  if (!SUPABASE_URL) {
    throw new Error('Missing NEXT_PUBLIC_SUPABASE_URL. Configure it in the server environment.');
  }

  if (!SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY. Configure the server-only Supabase service-role key in deployment environment variables.');
  }

  adminClient = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  return adminClient;
}
