import { cookies } from 'next/headers';
import { createClient } from '@/lib/supabase/server';

export type Membership = { stall_id: string; role: string };

/** Resolve active stall from cookie, falling back to first membership.
 * Callers: layout + menu/staff/group/settings.
 * User: Implement the plan as specified, it is attached for your reference.
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

export type StallDayContext = {
  timezone: string;
  dayStartMinutes: number;
};

/** Timezone + business-day offset for the active stall. */
export async function activeStallDayContext(): Promise<StallDayContext> {
  const supabase = await createClient();
  const jar = await cookies();
  const cookieId = jar.get('active_stall_id')?.value;
  const { data } = await supabase
    .from('stall')
    .select('id, timezone, day_start_minutes')
    .order('created_at');
  const rows = data ?? [];
  const match = rows.find((s: { id: string }) => s.id === cookieId) ?? rows[0];
  return {
    timezone: match?.timezone ?? 'Asia/Kolkata',
    dayStartMinutes: Number(match?.day_start_minutes ?? 0),
  };
}

/** IANA timezone of the active stall — the day boundary reports must use.
 * Falls back to Asia/Kolkata, the column default.
 */
export async function activeStallTimezone(): Promise<string> {
  return (await activeStallDayContext()).timezone;
}
