import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import type { TableRow } from '@/lib/supabase/types';

export type CreateProsecutorInput = {
  firstName: string;
  middleName?: string;
  lastName: string;
  suffix?: string;
  shortName?: string;
};

export async function createProsecutor(input: CreateProsecutorInput): Promise<TableRow<'prosecutors'>> {
  const supabase = await getSupabaseBrowserClient();
  const { data: sessionData } = await supabase.auth.getSession();
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error('Your session has expired. Sign in and try again.');

  const response = await fetch('/api/prosecutors', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(input),
  });
  const result = await response.json() as { data?: TableRow<'prosecutors'>; error?: { message?: string } };
  if (!response.ok || !result.data) throw new Error(result.error?.message ?? 'Unable to add prosecutor.');
  return result.data;
}
