/** Display helper for rupee amounts already stored as numeric (not paise).
 * Callers: dashboard, settings/actions, settings/page. Matches DB/mobile float money.
 * User: Implement the plan as specified, it is attached for your reference.
 */
export function formatInr(n: number): string {
  if (!Number.isFinite(n)) return '₹0.00';
  return `₹${n.toFixed(2)}`;
}

/** Parse HH:MM (from <input type="time">) to minutes-from-midnight. */
export function timeToMinutes(hhmm: string): number {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
  if (!m) return 0;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h < 0 || h > 23 || min < 0 || min > 59) return 0;
  return h * 60 + min;
}

/** Minutes-from-midnight → HH:MM for <input type="time">. */
export function minutesToTime(minutes: number): string {
  const m = Math.max(0, Math.min(1439, Math.floor(minutes) || 0));
  const h = Math.floor(m / 60);
  const mm = m % 60;
  return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}
