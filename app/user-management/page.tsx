'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { Sidebar } from '@/components/sidebar';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { RefreshCw, ShieldAlert, Trash2 } from 'lucide-react';
import {
  assignUserManagementRole,
  getUserManagementRoles,
  getUserManagementUsers,
  removeUserManagementUser,
  setUserManagementBlocked,
  type UserManagementRoleRecord,
  type UserManagementUserRecord,
} from '@/lib/supabase/queries';

type PendingAction =
  | { type: 'role'; user: UserManagementUserRecord; roleId: number; roleLabel: string }
  | { type: 'block'; user: UserManagementUserRecord }
  | { type: 'unblock'; user: UserManagementUserRecord }
  | { type: 'remove'; user: UserManagementUserRecord };

function formatDate(value: string | null) {
  if (!value) return 'Never';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

function getOfficeIdentity(user: UserManagementUserRecord) {
  return user.prosecutor_full_name ?? user.prosecutor_short_name ?? user.staff_full_name ?? user.staff_short_name ?? 'Not linked';
}

function getActionText(action: PendingAction | null) {
  if (!action) return { title: '', description: '', confirm: '' };

  if (action.type === 'role') {
    return {
      title: 'Confirm role change',
      description: `Change ${action.user.email}'s role to ${action.roleLabel}?`,
      confirm: 'Change role',
    };
  }

  if (action.type === 'block') {
    return {
      title: 'Confirm user block',
      description: `Block ${action.user.email}? The application user will be marked inactive.`,
      confirm: 'Block user',
    };
  }

  if (action.type === 'unblock') {
    return {
      title: 'Confirm user unblock',
      description: `Unblock ${action.user.email}? The application user will be marked active again.`,
      confirm: 'Unblock user',
    };
  }

  return {
    title: 'Confirm user removal',
    description: `Remove ${action.user.email} from application access? This soft-removes the app user by disabling it and clearing assigned roles.`,
    confirm: 'Remove user',
  };
}

export default function UserManagementPage() {
  const [users, setUsers] = useState<UserManagementUserRecord[]>([]);
  const [roles, setRoles] = useState<UserManagementRoleRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);

  const actionText = useMemo(() => getActionText(pendingAction), [pendingAction]);

  const loadData = useCallback(async () => {
    setIsLoading(true);
    const [userResult, roleResult] = await Promise.all([getUserManagementUsers(), getUserManagementRoles()]);

    if (userResult.error || roleResult.error) {
      setMessage({ type: 'error', text: userResult.error?.message ?? roleResult.error?.message ?? 'Unable to load user management data.' });
    } else {
      setUsers(userResult.data ?? []);
      setRoles(roleResult.data ?? []);
    }

    setIsLoading(false);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function confirmAction() {
    if (!pendingAction) return;

    setIsSaving(true);
    setMessage(null);

    const result = pendingAction.type === 'role'
      ? await assignUserManagementRole(pendingAction.user.id, pendingAction.roleId)
      : pendingAction.type === 'block'
        ? await setUserManagementBlocked(pendingAction.user.id, true)
        : pendingAction.type === 'unblock'
          ? await setUserManagementBlocked(pendingAction.user.id, false)
          : await removeUserManagementUser(pendingAction.user.id);

    if (result.error) {
      setMessage({ type: 'error', text: result.error.message });
    } else {
      setMessage({ type: 'success', text: `${actionText.confirm} completed successfully.` });
      setPendingAction(null);
      await loadData();
    }

    setIsSaving(false);
  }

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar />
      <main className="min-w-0 flex-1 overflow-auto p-6">
        <div className="mx-auto max-w-7xl space-y-6">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h1 className="text-3xl font-bold tracking-tight">User Management</h1>
              <p className="text-muted-foreground">View users, assign roles, block access, and soft-remove application users.</p>
            </div>
            <Button variant="outline" onClick={loadData} disabled={isLoading || isSaving}>
              <RefreshCw className="mr-2 h-4 w-4" />
              Refresh
            </Button>
          </div>

          {message ? (
            <Alert variant={message.type === 'error' ? 'destructive' : 'default'}>
              <AlertTitle>{message.type === 'error' ? 'Action failed' : 'Success'}</AlertTitle>
              <AlertDescription>{message.text}</AlertDescription>
            </Alert>
          ) : null}

          <Card>
            <CardHeader>
              <CardTitle>Application users</CardTitle>
              <CardDescription>Actions use the User Management database view and RPCs only.</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Email</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Role</TableHead>
                    <TableHead>Office identity</TableHead>
                    <TableHead>Last login</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {isLoading ? (
                    <TableRow><TableCell colSpan={7} className="py-8 text-center text-muted-foreground">Loading users...</TableCell></TableRow>
                  ) : users.length === 0 ? (
                    <TableRow><TableCell colSpan={7} className="py-8 text-center text-muted-foreground">No users found.</TableCell></TableRow>
                  ) : users.map((user) => (
                    <TableRow key={user.id}>
                      <TableCell className="font-medium">{user.email}</TableCell>
                      <TableCell>
                        <Badge variant={user.is_active ? 'secondary' : 'destructive'}>{user.is_active ? 'Active' : 'Blocked'}</Badge>
                      </TableCell>
                      <TableCell>
                        <Select
                          value={user.role_id ? String(user.role_id) : ''}
                          onValueChange={(value) => {
                            const role = roles.find((item) => item.id === Number(value));
                            if (!role || role.id === user.role_id) return;
                            setPendingAction({ type: 'role', user, roleId: role.id, roleLabel: role.display_label });
                          }}
                          disabled={isSaving}
                        >
                          <SelectTrigger className="w-44"><SelectValue placeholder="Assign role" /></SelectTrigger>
                          <SelectContent>
                            {roles.map((role) => <SelectItem key={role.id} value={String(role.id)}>{role.display_label}</SelectItem>)}
                          </SelectContent>
                        </Select>
                      </TableCell>
                      <TableCell>{getOfficeIdentity(user)}</TableCell>
                      <TableCell>{formatDate(user.last_login_at)}</TableCell>
                      <TableCell>{formatDate(user.created_at)}</TableCell>
                      <TableCell className="space-x-2 text-right">
                        <Button size="sm" variant="outline" onClick={() => setPendingAction({ type: user.is_active ? 'block' : 'unblock', user })} disabled={isSaving}>
                          <ShieldAlert className="mr-2 h-4 w-4" />
                          {user.is_active ? 'Block' : 'Unblock'}
                        </Button>
                        <Button size="sm" variant="destructive" onClick={() => setPendingAction({ type: 'remove', user })} disabled={isSaving}>
                          <Trash2 className="mr-2 h-4 w-4" />
                          Remove
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </div>
      </main>

      <AlertDialog open={pendingAction !== null} onOpenChange={(open) => !open && !isSaving && setPendingAction(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{actionText.title}</AlertDialogTitle>
            <AlertDialogDescription>{actionText.description}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isSaving}>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={confirmAction} disabled={isSaving}>{isSaving ? 'Saving...' : actionText.confirm}</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
