import { createClient } from '@supabase/supabase-js';

/** Service-role client for platform console only. Never import in stall-tenant UI. */
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) return null;
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function isPlatformAdminEmail(email: string | undefined | null): boolean {
  if (!email) return false;
  const raw = process.env.PLATFORM_ADMIN_EMAILS || '';
  const allow = raw
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  return allow.includes(email.toLowerCase());
}
