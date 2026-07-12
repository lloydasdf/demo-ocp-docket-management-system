'use client';

import { useContext } from 'react';
import { AppAuthRoleContext } from '@/components/auth/app-auth-role-provider';

export function useAppAuthRole() {
  const context = useContext(AppAuthRoleContext);

  if (!context) {
    throw new Error('useAppAuthRole must be used within AppAuthRoleProvider.');
  }

  return context;
}
