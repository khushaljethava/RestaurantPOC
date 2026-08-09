'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function markSettlement(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('mark_settlement', {
    p_from_stall: String(formData.get('from_stall')),
    p_to_stall: String(formData.get('to_stall')),
    p_day: String(formData.get('day')),
    p_amount: Number(formData.get('amount')),
    p_method: String(formData.get('method') || 'cash'),
    p_note: String(formData.get('note') || '') || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/settlement');
  revalidatePath('/group');
}

export async function confirmSettlement(id: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('confirm_settlement', { p_id: id });
  if (error) throw new Error(error.message);
  revalidatePath('/settlement');
  revalidatePath('/exceptions');
}

export async function disputeSettlement(formData: FormData) {
  const id = String(formData.get('id'));
  const note = String(formData.get('note') || '').trim();
  const supabase = await createClient();
  const { error } = await supabase.rpc('dispute_settlement', {
    p_id: id,
    p_note: note,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/settlement');
  revalidatePath('/exceptions');
}
