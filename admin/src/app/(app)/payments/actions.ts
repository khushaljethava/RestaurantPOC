'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export async function verifyUpiPayment(paymentId: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc('verify_upi_payment', {
    p_payment_id: paymentId,
  });
  if (error) throw new Error(error.message);
  revalidatePath('/payments/verify');
  revalidatePath('/shifts');
  revalidatePath('/exceptions');
  revalidatePath('/bills');
}
