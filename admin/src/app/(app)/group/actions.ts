'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function createStallInvite(stallId: string, role: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('create_stall_invite', {
    p_stall_id: stallId,
    p_role: role,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/staff');
  return data as string;
}

export async function leaveGroup(stallId: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('leave_group', {
    p_stall_id: stallId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/group');
}
