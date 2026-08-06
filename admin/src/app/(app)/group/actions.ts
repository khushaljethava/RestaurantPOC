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

export async function requestJoinGroup(code: string, stallId: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('request_join_group', {
    p_code: code,
    p_stall_id: stallId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/group');
}

export async function approveJoinRequest(requestId: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('approve_join_request', {
    p_request_id: requestId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/group');
}

export async function rejectJoinRequest(requestId: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('reject_join_request', {
    p_request_id: requestId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/group');
}

export async function createFoodCourt(name: string, stallId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('create_food_court', {
    p_name: name,
    p_stall_id: stallId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/group');
  return data as { group_id: string; invite_code: string };
}

export async function createGroupInvite(groupId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('create_group_invite', {
    p_group_id: groupId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/group');
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
