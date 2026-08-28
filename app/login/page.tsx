'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { LockKeyhole, ShieldCheck } from 'lucide-react';

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { getSupabaseBrowserClient, getSupabaseEnvironmentStatus } from '@/lib/supabase/client';

const demoAccounts = [
  { role: 'Admin', email: 'admin@ocp.com', password: 'ocpadmin123' },
  { role: 'Chief', email: 'chief@ocp.com', password: 'ocpchief123' },
  { role: 'Prosecutor', email: 'prosecutor@ocp.com', password: 'ocpprosecutor123' },
  { role: 'Developer', email: 'developer@ocp.com', password: 'ocpdeveloper123' },
] as const;

function getSafeReturnPath() {
  if (typeof window === 'undefined') {
    return '/cases';
  }

  const params = new URLSearchParams(window.location.search);
  const returnTo = params.get('returnTo');

  if (!returnTo || !returnTo.startsWith('/') || returnTo.startsWith('//')) {
    return '/cases';
  }

  return returnTo;
}

export default function LoginPage() {
  const router = useRouter();
  const supabaseStatus = useMemo(() => getSupabaseEnvironmentStatus(), []);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isCheckingSession, setIsCheckingSession] = useState(true);

  useEffect(() => {
    let isMounted = true;

    async function redirectAuthenticatedUser() {
      if (!supabaseStatus.isConfigured) {
        setIsCheckingSession(false);
        return;
      }

      const supabase = await getSupabaseBrowserClient();
      const { data } = await supabase.auth.getSession();

      if (!isMounted) {
        return;
      }

      if (data.session) {
        router.replace(getSafeReturnPath());
        return;
      }

      setIsCheckingSession(false);
    }

    redirectAuthenticatedUser();

    return () => {
      isMounted = false;
    };
  }, [router, supabaseStatus.isConfigured]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (!supabaseStatus.isConfigured) {
      setError('PostgreSQL connection is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY first.');
      return;
    }

    setIsSubmitting(true);

    const supabase = await getSupabaseBrowserClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    setIsSubmitting(false);

    if (signInError) {
      setError(signInError.message);
      return;
    }

    router.replace(getSafeReturnPath());
    router.refresh();
  }

  function selectDemoAccount(account: (typeof demoAccounts)[number]) {
    setEmail(account.email);
    setPassword(account.password);
    setError(null);
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/30 px-4 py-10">
      <div className="w-full max-w-md space-y-6">
        <div className="text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-sm">
            <ShieldCheck className="h-7 w-7" />
          </div>
          <h1 className="mt-4 text-3xl font-bold tracking-tight text-foreground">OCP Docket System</h1>
        </div>

        <Card className="shadow-lg">
          <CardHeader className="gap-0">
            <CardTitle className="flex items-center gap-2">
              <LockKeyhole className="h-5 w-5" />
              Secure login
            </CardTitle>
          </CardHeader>
          <CardContent>
            {!supabaseStatus.isConfigured ? (
              <Alert variant="destructive" className="mb-4">
                <AlertTitle>PostgreSQL connection is not configured</AlertTitle>
                <AlertDescription>
                  Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY, then restart the app.
                </AlertDescription>
              </Alert>
            ) : null}

            {error ? (
              <Alert variant="destructive" className="mb-4">
                <AlertTitle>Unable to sign in</AlertTitle>
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            ) : null}

            <form className="space-y-4" onSubmit={handleSubmit}>
              <div className="space-y-2">
                <Label htmlFor="email">Email address</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  placeholder="admin@ocp.com"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  disabled={isSubmitting || isCheckingSession}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  autoComplete="current-password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  disabled={isSubmitting || isCheckingSession}
                  required
                />
              </div>

              <Button className="w-full" type="submit" disabled={isSubmitting || isCheckingSession || !supabaseStatus.isConfigured}>
                {isCheckingSession ? 'Checking session...' : isSubmitting ? 'Signing in...' : 'Sign in'}
              </Button>
            </form>

            <div className="mt-6 border-t pt-6">
              <div className="mb-3">
                <h2 className="text-sm font-semibold text-foreground">Demo accounts</h2>
                <p className="mt-1 text-xs text-muted-foreground">Select an account to fill in the login form.</p>
              </div>

              <div className="space-y-2">
                {demoAccounts.map((account) => (
                  <button
                    key={account.role}
                    type="button"
                    className="flex w-full items-center justify-between gap-3 rounded-md border bg-background px-3 py-2.5 text-left transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"
                    onClick={() => selectDemoAccount(account)}
                    disabled={isSubmitting || isCheckingSession}
                  >
                    <span className="min-w-0">
                      <span className="block text-sm font-medium text-foreground">{account.role}</span>
                      <span className="block truncate font-mono text-xs text-muted-foreground">{account.email}</span>
                    </span>
                    <span className="shrink-0 font-mono text-xs text-muted-foreground">{account.password}</span>
                  </button>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
