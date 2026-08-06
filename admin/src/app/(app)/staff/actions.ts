'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function revokeInvite(code: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from('stall_invite')
    .update({ revoked_at: new Date().toISOString() })
    .eq('code', code);
  if (error) throw new Error(error.message);
  revalidatePath('/staff');
}

export async function changeRole(membershipId: string, role: string) {
  if (!['owner', 'manager', 'staff'].includes(role)) {
    throw new Error('invalid role');
  }
  const supabase = await createClient();
  const { data: row } = await supabase
    .from('staff_membership')
    .select('id, stall_id, role')
    .eq('id', membershipId)
    .single();
  if (!row) throw new Error('membership not found');

  if (row.role === 'owner' && role !== 'owner') {
    const { count } = await supabase
      .from('staff_membership')
      .select('id', { count: 'exact', head: true })
      .eq('stall_id', row.stall_id)
      .eq('role', 'owner');
    if ((count ?? 0) <= 1) throw new Error('cannot demote the last owner');
  }

  const { error } = await supabase
    .from('staff_membership')
    .update({ role })
    .eq('id', membershipId);
  if (error) throw new Error(error.message);
  revalidatePath('/staff');
}

export async function removeMember(membershipId: string) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { data: row } = await supabase
    .from('staff_membership')
    .select('id, stall_id, user_id, role')
    .eq('id', membershipId)
    .single();
  if (!row) throw new Error('membership not found');

  if (row.role === 'owner') {
    const { count } = await supabase
      .from('staff_membership')
      .select('id', { count: 'exact', head: true })
      .eq('stall_id', row.stall_id)
      .eq('role', 'owner');
    if ((count ?? 0) <= 1) throw new Error('cannot remove the last owner');
  }

  if (row.user_id === user?.id) {
    const { count } = await supabase
      .from('staff_membership')
      .select('id', { count: 'exact', head: true })
      .eq('stall_id', row.stall_id)
      .eq('role', 'owner');
    if (row.role === 'owner' && (count ?? 0) <= 1) {
      throw new Error('cannot remove yourself as sole owner');
    }
  }

  const { error } = await supabase
    .from('staff_membership')
    .delete()
    .eq('id', membershipId);
  if (error) throw new Error(error.message);
  revalidatePath('/staff');
}
