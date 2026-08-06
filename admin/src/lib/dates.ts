/** Calendar-day boundaries in a stall's own timezone.
 *
 * These used to use setHours(0,0,0,0), i.e. the *server's* timezone. Deployed
 * on UTC infrastructure that made "today" start at 05:30 IST, so the dashboard
 * disagreed with next_token(), which has always used stall.timezone.
 */

/** Offset of `tz` from UTC, in ms, at instant `at`. */
function tzOffsetMs(tz: string, at: Date): number {
  const s = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(at);
  // "MM/DD/YYYY, HH:mm:ss" — reread as if UTC to recover the offset.
  const [d, t] = s.split(', ');
  const [M, D, Y] = d.split('/');
  return Date.parse(`${Y}-${M}-${D}T${t}Z`) - at.getTime();
}

/** Local calendar date in `tz` as YYYY-MM-DD. */
export function tzDate(tz: string, d = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);
}

/** Midnight in `tz` on the calendar day containing `d`, plus `addDays`. */
export function dayStart(tz: string, d = new Date(), addDays = 0): string {
  const ymd = tzDate(tz, d);
  const naive = new Date(`${ymd}T00:00:00Z`);
  naive.setUTCDate(naive.getUTCDate() + addDays);
  // ponytail: offset sampled at the naive instant — off by an hour only for a
  // midnight falling inside a DST transition. India has none; revisit if a
  // stall ever runs in a DST zone.
  return new Date(naive.getTime() - tzOffsetMs(tz, naive)).toISOString();
}

/** Exclusive end: midnight in `tz` starting the next calendar day. */
export function dayEnd(tz: string, d = new Date()): string {
  return dayStart(tz, d, 1);
}

export function parseRange(tz: string, from?: string | null, to?: string | null) {
  const f = from ? new Date(from) : new Date();
  const t = to ? new Date(to) : new Date();
  if (Number.isNaN(f.getTime())) f.setTime(Date.now());
  if (Number.isNaN(t.getTime())) t.setTime(Date.now());
  return { from: dayStart(tz, f), to: dayEnd(tz, t) };
}
