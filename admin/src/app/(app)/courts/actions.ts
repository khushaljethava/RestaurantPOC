'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

/**
 * Called by: courts/page.tsx, courts/[id]/page.tsx.
 * Court-operator side. Stall owners join via mobile (join_court_as_owner);
 * leave stays in group/actions.ts.
 *
 * Authorization lives in the RPCs (is_court_owner), not here. These wrappers
 * surface errors and revalidate; they are not a security boundary.
 */

export async function createCourt(name: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('create_court', { p_name: name });
  if (error) throw new Error(error.message);
  revalidatePath('/courts');
  return data as string;
}

export async function renameCourt(groupId: string, name: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('rename_court', {
    p_group_id: groupId,
    p_name: name,
  });
  if (error) throw new Error(error.message);
  revalidatePath(`/courts/${groupId}`);
  revalidatePath('/courts');
}

export async function removeStallFromCourt(groupId: string, stallId: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('remove_stall_from_court', {
    p_group_id: groupId,
    p_stall_id: stallId,
  });
  if (error) throw new Error(error.message);
  revalidatePath(`/courts/${groupId}`);
}

export async function createCourtInvite(groupId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('create_group_invite', {
    p_group_id: groupId,
  });
  if (error) throw new Error(error.message);
  revalidatePath(`/courts/${groupId}`);
  return data as string;
}

export async function revokeCourtInvite(groupId: string, code: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from('group_invite')
    .update({ revoked_at: new Date().toISOString() })
    .eq('code', code);
  if (error) throw new Error(error.message);
  revalidatePath(`/courts/${groupId}`);
}
