'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

async function writeAuditBestEffort(
  stallId: string,
  action: string,
  entityId: string,
  payload: Record<string, unknown> = {}
) {
  const supabase = await createClient();
  try {
    await supabase.rpc('write_audit', {
      p_stall_id: stallId,
      p_action: action,
      p_entity_type: 'staff_membership',
      p_entity_id: entityId,
      p_reason: null,
      p_payload: payload,
    });
  } catch {
    // best-effort
  }
}

function staffErrorRedirect(message: string): never {
  redirect(`/staff?error=${encodeURIComponent(message)}`);
}

/** Form fields: stall_id, role (staff|manager). */
export async function generateInvite(formData: FormData) {
  const stallId = String(formData.get('stall_id') ?? '');
  const role = String(formData.get('role') ?? '');
  if (!stallId) staffErrorRedirect('No active stall');
  if (role !== 'staff' && role !== 'manager') staffErrorRedirect('Invalid role');

  const supabase = await createClient();
  const { error } = await supabase.rpc('create_stall_invite', {
    p_stall_id: stallId,
    p_role: role,
  });
  if (error) staffErrorRedirect(error.message);
  revalidatePath('/staff');
}

export async function revokeInvite(code: string) {
  const supabase = await createClient();
  const { error } = await supabase
    .from('stall_invite')
    .update({ revoked_at: new Date().toISOString() })
    .eq('code', code);
  if (error) staffErrorRedirect(error.message);
  revalidatePath('/staff');
}

export async function changeRole(membershipId: string, role: string) {
  if (!['owner', 'manager', 'staff'].includes(role)) {
    staffErrorRedirect('invalid role');
  }
  const supabase = await createClient();
  const { data: row } = await supabase
    .from('staff_membership')
    .select('id, stall_id, role')
    .eq('id', membershipId)
    .single();
  if (!row) staffErrorRedirect('membership not found');

  if (row.role === 'owner' && role !== 'owner') {
    const { count } = await supabase
      .from('staff_membership')
      .select('id', { count: 'exact', head: true })
      .eq('stall_id', row.stall_id)
      .eq('role', 'owner');
    if ((count ?? 0) <= 1) staffErrorRedirect('cannot demote the last owner');
  }

  const { error } = await supabase
    .from('staff_membership')
    .update({ role })
    .eq('id', membershipId);
  if (error) staffErrorRedirect(error.message);
  await writeAuditBestEffort(row.stall_id, 'staff.role_change', membershipId, {
    from: row.role,
    to: role,
  });
  revalidatePath('/staff');
  revalidatePath(`/staff/${membershipId}`);
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
  if (!row) staffErrorRedirect('membership not found');

  if (row.role === 'owner') {
    const { count } = await supabase
      .from('staff_membership')
      .select('id', { count: 'exact', head: true })
      .eq('stall_id', row.stall_id)
      .eq('role', 'owner');
    if ((count ?? 0) <= 1) staffErrorRedirect('cannot remove the last owner');
  }

  if (row.user_id === user?.id) {
    const { count } = await supabase
      .from('staff_membership')
      .select('id', { count: 'exact', head: true })
      .eq('stall_id', row.stall_id)
      .eq('role', 'owner');
    if (row.role === 'owner' && (count ?? 0) <= 1) {
      staffErrorRedirect('cannot remove yourself as sole owner');
    }
  }

  const { error } = await supabase
    .from('staff_membership')
    .delete()
    .eq('id', membershipId);
  if (error) staffErrorRedirect(error.message);
  await writeAuditBestEffort(row.stall_id, 'staff.remove', membershipId, {
    user_id: row.user_id,
    role: row.role,
  });
  revalidatePath('/staff');
}

/** Owner/manager resets another member's PIN. Returns the PIN for one-time display. */
export async function resetStaffPin(
  stallId: string,
  userId: string,
  pin: string
): Promise<string> {
  if (!/^\d{4}$/.test(pin)) throw new Error('PIN must be 4 digits');
  const supabase = await createClient();
  const { error } = await supabase.rpc('admin_set_staff_pin', {
    p_stall_id: stallId,
    p_user_id: userId,
    p_pin: pin,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/staff');
  return pin;
}
