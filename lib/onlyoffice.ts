import 'server-only';

import { createHmac, timingSafeEqual } from 'node:crypto';

function base64url(value: string | Buffer) { return Buffer.from(value).toString('base64url'); }

export function getOnlyOfficeConfiguration() {
  const serverUrl = process.env.ONLYOFFICE_DOCUMENT_SERVER_URL?.replace(/\/$/, '');
  const jwtSecret = process.env.ONLYOFFICE_JWT_SECRET;
  const publicAppUrl = process.env.ONLYOFFICE_PUBLIC_APP_URL?.replace(/\/$/, '');
  if (!serverUrl || !jwtSecret || !publicAppUrl) throw new Error('ONLYOFFICE_DOCUMENT_SERVER_URL, ONLYOFFICE_JWT_SECRET, and ONLYOFFICE_PUBLIC_APP_URL are required.');
  return { serverUrl, jwtSecret, publicAppUrl };
}

export function signOnlyOfficeToken(payload: object, secret: string) {
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = base64url(JSON.stringify(payload));
  const signature = createHmac('sha256', secret).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${signature}`;
}

export function verifyOnlyOfficeToken(token: string, secret: string) {
  const [header, body, signature] = token.split('.');
  if (!header || !body || !signature) return false;
  const expected = createHmac('sha256', secret).update(`${header}.${body}`).digest();
  const actual = Buffer.from(signature, 'base64url');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
