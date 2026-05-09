import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import type { Database } from '@/lib/database.types';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export type SupabaseBrowserClient = SupabaseClient<Database>;

export function getSupabaseEnvironmentStatus() {
  return {
    hasUrl: Boolean(SUPABASE_URL),
    hasAnonKey: Boolean(SUPABASE_ANON_KEY),
    isConfigured: Boolean(SUPABASE_URL && SUPABASE_ANON_KEY),
  };
}

export async function createSupabaseBrowserClient(): Promise<SupabaseBrowserClient> {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error(
      'Missing Supabase environment variables. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.',
    );
  }

  return createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

export async function getSupabaseBrowserClient(): Promise<SupabaseBrowserClient> {
  return createSupabaseBrowserClient();
}

export const supabase = new Proxy({} as SupabaseBrowserClient, {
  get() {
    throw new Error(
      'The shared supabase export is kept only for migration compatibility. Use await getSupabaseBrowserClient() instead.',
    );
  },
});
