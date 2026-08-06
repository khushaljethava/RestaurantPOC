'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function updateStallSettings(formData: FormData) {
  const supabase = await createClient();
  const id = String(formData.get('id'));
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('role')
    .eq('stall_id', id)
    .limit(1);
  // Owner-only: rely on RLS + explicit check via role query
  const { data: mine } = await supabase
    .from('staff_membership')
    .select('role')
    .eq('stall_id', id);
  const role = mine?.find((m) => m.role === 'owner');
  if (!role) throw new Error('only owner may edit stall settings');

  const { error } = await supabase
    .from('stall')
    .update({
      name: String(formData.get('name')),
      currency: String(formData.get('currency') || 'INR'),
      timezone: String(formData.get('timezone') || 'Asia/Kolkata'),
      is_open: formData.get('is_open') === 'on',
      upi_vpa: String(formData.get('upi_vpa') || '') || null,
      upi_payee_name: String(formData.get('upi_payee_name') || '') || null,
    })
    .eq('id', id);
  if (error) throw new Error(error.message);
  revalidatePath('/settings');
  void memberships;
}
