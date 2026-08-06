import { cookies } from 'next/headers';
import { createClient } from '@/lib/supabase/server';

export type Membership = { stall_id: string; role: string };

/** Resolve active stall from cookie, falling back to first membership.
 * Gate: called from layout + menu/staff/group/settings. Glob: new file.
 * User: implement remaining v1 gaps.
 */
export async function resolveActiveStall(
  memberships: Membership[]
): Promise<Membership> {
  if (memberships.length === 0) {
    throw new Error('no memberships');
  }
  const jar = await cookies();
  const cookieId = jar.get('active_stall_id')?.value;
  const match = memberships.find((m) => m.stall_id === cookieId);
  return match ?? memberships[0];
}

/** IANA timezone of the active stall — the day boundary reports must use.
 * Falls back to Asia/Kolkata, the column default.
 */
export async function activeStallTimezone(): Promise<string> {
  const supabase = await createClient();
  const jar = await cookies();
  const cookieId = jar.get('active_stall_id')?.value;
  const { data } = await supabase
    .from('stall')
    .select('id, timezone')
    .order('created_at');
  const rows = data ?? [];
  const match = rows.find((s: { id: string }) => s.id === cookieId) ?? rows[0];
  return match?.timezone ?? 'Asia/Kolkata';
}
