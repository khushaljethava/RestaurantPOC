'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function revokeDevice(formData: FormData) {
  const id = String(formData.get('id') || '');
  if (!id) throw new Error('missing id');
  const supabase = await createClient();
  const { error } = await supabase.rpc('revoke_device_push_token', { p_id: id });
  if (error) throw new Error(error.message);
  revalidatePath('/settings/devices');
}
