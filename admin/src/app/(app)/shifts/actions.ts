'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

/** Force-close via existing close_shift (owner/manager can close any open shift). */
export async function forceCloseShift(formData: FormData) {
  const shiftId = String(formData.get('shift_id'));
  const declared = Number(formData.get('declared_cash') ?? 0);
  const reason = String(formData.get('variance_reason') || '').trim() || null;
  const notes = String(formData.get('notes') || '').trim() || null;
  if (!shiftId) throw new Error('shift required');
  if (!Number.isFinite(declared) || declared < 0) throw new Error('declared cash invalid');

  const supabase = await createClient();
  const { error } = await supabase.rpc('close_shift', {
    p_shift_id: shiftId,
    p_declared_cash: declared,
    p_variance_reason: reason,
    p_notes: notes ?? 'force closed from admin',
  });
  if (error) throw new Error(error.message);
  revalidatePath('/shifts');
  revalidatePath(`/shifts/${shiftId}`);
  revalidatePath('/exceptions');
}
