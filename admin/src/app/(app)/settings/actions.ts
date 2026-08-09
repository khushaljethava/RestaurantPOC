'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { timeToMinutes } from '@/lib/money';

export async function updateStallSettings(formData: FormData) {
  const supabase = await createClient();
  const id = String(formData.get('id'));
  const { data: mine } = await supabase
    .from('staff_membership')
    .select('role')
    .eq('stall_id', id);
  const role = mine?.find((m) => m.role === 'owner');
  if (!role) throw new Error('only owner may edit stall settings');

  const dayStartRaw = String(formData.get('day_start_time') || '00:00');
  const day_start_minutes = timeToMinutes(dayStartRaw);

  const patch = {
    name: String(formData.get('name')),
    currency: String(formData.get('currency') || 'INR'),
    timezone: String(formData.get('timezone') || 'Asia/Kolkata'),
    is_open: formData.get('is_open') === 'on',
    upi_vpa: String(formData.get('upi_vpa') || '') || null,
    packaging_charge: Number(formData.get('packaging_charge') ?? 0),
    packaging_charge_mode: String(formData.get('packaging_charge_mode') ?? 'none'),
    rounding_rule: String(formData.get('rounding_rule') ?? 'rupee_1'),
    upi_payee_name: String(formData.get('upi_payee_name') || '') || null,
    logo_url: String(formData.get('logo_url') || '') || null,
    receipt_footer: String(formData.get('receipt_footer') || '') || null,
    discount_staff_cap_pct: Number(formData.get('discount_staff_cap_pct') ?? 10),
    discount_staff_cap_flat: Number(formData.get('discount_staff_cap_flat') ?? 100),
    discount_manager_cap_pct: Number(formData.get('discount_manager_cap_pct') ?? 50),
    variance_reason_threshold: Number(formData.get('variance_reason_threshold') ?? 50),
    day_start_minutes,
  };

  const { error } = await supabase.from('stall').update(patch).eq('id', id);
  if (error) throw new Error(error.message);

  try {
    await supabase.rpc('write_audit', {
      p_stall_id: id,
      p_action: 'stall.settings',
      p_entity_type: 'stall',
      p_entity_id: id,
      p_reason: null,
      p_payload: {
        day_start_minutes,
        discount_staff_cap_pct: patch.discount_staff_cap_pct,
        discount_staff_cap_flat: patch.discount_staff_cap_flat,
        discount_manager_cap_pct: patch.discount_manager_cap_pct,
        variance_reason_threshold: patch.variance_reason_threshold,
      },
    });
  } catch {
    // best-effort audit
  }

  revalidatePath('/settings');
  revalidatePath('/');
}
