import { NextResponse } from 'next/server';

import { getAuthenticatedSupabase } from '@/lib/supabase/server-user';

type CreateProsecutorBody = {
  firstName?: unknown;
  middleName?: unknown;
  lastName?: unknown;
  suffix?: unknown;
  shortName?: unknown;
};

const textValue = (value: unknown) => typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : '';

const errorResponse = (status: number, code: string, message: string) =>
  NextResponse.json({ error: { code, message } }, { status });

export async function POST(request: Request) {
  const auth = await getAuthenticatedSupabase(request);
  if (!auth) return errorResponse(401, 'unauthenticated', 'Authentication is required.');

  let body: CreateProsecutorBody;
  try {
    body = await request.json();
  } catch {
    return errorResponse(400, 'invalid_json', 'A valid JSON body is required.');
  }

  const firstName = textValue(body.firstName);
  const middleName = textValue(body.middleName);
  const lastName = textValue(body.lastName);
  const suffix = textValue(body.suffix);
  const suppliedShortName = textValue(body.shortName);

  if (!firstName || !lastName) {
    return errorResponse(400, 'invalid_name', 'First name and last name are required.');
  }
  if ([firstName, middleName, lastName, suffix, suppliedShortName].some((value) => value.length > 100)) {
    return errorResponse(400, 'name_too_long', 'Each name field must be 100 characters or fewer.');
  }

  const fullName = [firstName, middleName, lastName, suffix].filter(Boolean).join(' ');
  const shortName = suppliedShortName || `${firstName.charAt(0)}. ${lastName}${suffix ? ` ${suffix}` : ''}`;

  const { data: existing } = await auth.client
    .from('prosecutors')
    .select('id')
    .eq('is_active', true)
    .ilike('full_name', fullName)
    .limit(1)
    .maybeSingle();
  if (existing) return errorResponse(409, 'duplicate_prosecutor', 'An active prosecutor with this full name already exists.');

  const { data: defaultPosition } = await auth.client
    .from('positions')
    .select('id')
    .eq('is_active', true)
    .eq('group_type', 'PROSECUTOR')
    .eq('code', 'PROSECUTOR')
    .limit(1)
    .maybeSingle();

  const { data, error } = await auth.client
    .from('prosecutors')
    .insert({
      first_name: firstName,
      middle_name: middleName || null,
      last_name: lastName,
      suffix: suffix || null,
      full_name: fullName,
      short_name: shortName,
      position_id: defaultPosition?.id ?? null,
      is_active: true,
    })
    .select('*')
    .single();

  if (error) {
    const forbidden = error.code === '42501';
    return errorResponse(forbidden ? 403 : 400, error.code ?? 'create_failed', forbidden ? 'You do not have permission to add prosecutors.' : error.message);
  }

  return NextResponse.json({ data }, { status: 201 });
}
