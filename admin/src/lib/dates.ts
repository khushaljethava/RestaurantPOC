/** Calendar-day boundaries in a stall's own timezone.
 *
 * These used to use setHours(0,0,0,0), i.e. the *server's* timezone. Deployed
 * on UTC infrastructure that made "today" start at 05:30 IST, so the dashboard
 * disagreed with next_token(), which has always used stall.timezone.
 *
 * dayStartMinutes shifts the business-day boundary (e.g. 120 → 02:00 local).
 * Callers: dashboard, settlement, reports via activeStallDayContext.
 * User: Implement the plan as specified, it is attached for your reference.
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

/**
 * Business-day start in `tz`: local midnight of the calendar day containing `d`,
 * plus `dayStartMinutes`, then shifted by `addDays`.
 */
export function dayStart(
  tz: string,
  d = new Date(),
  addDays = 0,
  dayStartMinutes = 0
): string {
  const mins = Math.max(0, Math.min(1439, Math.floor(dayStartMinutes) || 0));
  // If we're before today's business-day open, we're still on yesterday's day.
  const probe = new Date(d.getTime() - mins * 60_000);
  const ymd = tzDate(tz, probe);
  const naive = new Date(`${ymd}T00:00:00Z`);
  naive.setUTCDate(naive.getUTCDate() + addDays);
  // ponytail: offset sampled at the naive instant — off by an hour only for a
  // midnight falling inside a DST transition. India has none; revisit if a
  // stall ever runs in a DST zone.
  const midnightUtc = new Date(naive.getTime() - tzOffsetMs(tz, naive));
  return new Date(midnightUtc.getTime() + mins * 60_000).toISOString();
}

/** Exclusive end: next business-day start. */
export function dayEnd(tz: string, d = new Date(), dayStartMinutes = 0): string {
  return dayStart(tz, d, 1, dayStartMinutes);
}

export function stallDayBounds(
  tz: string,
  dayStartMinutes = 0,
  d = new Date()
): { from: string; to: string } {
  return {
    from: dayStart(tz, d, 0, dayStartMinutes),
    to: dayEnd(tz, d, dayStartMinutes),
  };
}

export function parseRange(
  tz: string,
  from?: string | null,
  to?: string | null,
  dayStartMinutes = 0
) {
  const f = from ? new Date(from) : new Date();
  const t = to ? new Date(to) : new Date();
  if (Number.isNaN(f.getTime())) f.setTime(Date.now());
  if (Number.isNaN(t.getTime())) t.setTime(Date.now());
  return {
    from: dayStart(tz, f, 0, dayStartMinutes),
    to: dayEnd(tz, t, dayStartMinutes),
  };
}

/** Previous period of equal length ending where `from` starts. */
export function previousPeriod(
  fromIso: string,
  toIso: string
): { from: string; to: string } {
  const from = new Date(fromIso).getTime();
  const to = new Date(toIso).getTime();
  const len = Math.max(0, to - from);
  return {
    from: new Date(from - len).toISOString(),
    to: fromIso,
  };
}

/** Percent change vs previous; null if previous is 0 and current is 0. */
export function pctChange(current: number, previous: number): number | null {
  if (!Number.isFinite(current) || !Number.isFinite(previous)) return null;
  if (previous === 0) return current === 0 ? 0 : null;
  return ((current - previous) / Math.abs(previous)) * 100;
}

export function formatPctDelta(pct: number | null): string {
  if (pct == null) return 'n/a vs prior';
  const sign = pct > 0 ? '+' : '';
  return `${sign}${pct.toFixed(0)}% vs prior`;
}
