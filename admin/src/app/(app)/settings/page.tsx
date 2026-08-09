import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { minutesToTime } from '@/lib/money';
import { updateStallSettings } from './actions';
import { Btn, Card, Field, Label, PageTitle, SectionTitle } from '@/components/ui';

export default async function SettingsPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const stallId = active.stall_id;
  const isOwner = active.role === 'owner';

  const { data: stall } = stallId
    ? await supabase
        .from('stall')
        .select(
          'id, name, currency, timezone, is_open, upi_vpa, upi_payee_name, logo_url, receipt_footer, packaging_charge, packaging_charge_mode, rounding_rule, discount_staff_cap_pct, discount_staff_cap_flat, discount_manager_cap_pct, variance_reason_threshold, day_start_minutes'
        )
        .eq('id', stallId)
        .single()
    : { data: null };

  if (!stall) return <p className="text-on-surface-variant">No stall</p>;

  const dayStartTime = minutesToTime(Number(stall.day_start_minutes ?? 0));

  return (
    <div className="mx-auto max-w-[640px]">
      <PageTitle subtitle="Profile, payments and money rules">Stall settings</PageTitle>
      <p className="mb-4 flex flex-wrap gap-3 text-sm">
        <Link href="/settings/devices" className="text-surface-tint hover:underline">
          Devices
        </Link>
        <Link href="/audit" className="text-surface-tint hover:underline">
          Audit log
        </Link>
      </p>
      {!isOwner && (
        <p className="mb-4 text-sm text-on-surface-variant">View only — owner can edit.</p>
      )}
      <Card>
        <form action={updateStallSettings} className="space-y-4">
          <input type="hidden" name="id" value={stall.id} />

          <SectionTitle className="mb-1">Profile</SectionTitle>
          <Label>
            Stall name
            <Field
              name="name"
              defaultValue={stall.name}
              required
              disabled={!isOwner}
              className="mt-1"
            />
          </Label>
          <Label>
            Currency
            <Field
              name="currency"
              defaultValue={stall.currency}
              disabled={!isOwner}
              className="mt-1"
            />
          </Label>
          <Label>
            Timezone
            <Field
              name="timezone"
              defaultValue={stall.timezone}
              disabled={!isOwner}
              className="mt-1"
            />
          </Label>
          <Label>
            Business day starts
            <Field
              name="day_start_time"
              type="time"
              defaultValue={dayStartTime}
              disabled={!isOwner}
              className="mt-1"
            />
          </Label>
          <label className="flex h-11 items-center gap-3 text-sm text-on-surface">
            <input
              type="checkbox"
              name="is_open"
              defaultChecked={stall.is_open}
              disabled={!isOwner}
              className="h-4 w-4 rounded border-border accent-surface-tint"
            />
            Accepting orders
          </label>

          <div className="border-t border-border pt-4">
            <SectionTitle className="mb-1">Receipt</SectionTitle>
            <div className="space-y-3">
              <Label>
                Logo URL
                <Field
                  name="logo_url"
                  defaultValue={stall.logo_url ?? ''}
                  placeholder="https://…"
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
              <Label>
                Footer text
                <textarea
                  name="receipt_footer"
                  defaultValue={stall.receipt_footer ?? ''}
                  disabled={!isOwner}
                  rows={3}
                  className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm disabled:opacity-60"
                  placeholder="Thank you / GSTIN / address"
                />
              </Label>
            </div>
          </div>

          <div className="border-t border-border pt-4">
            <SectionTitle className="mb-1">Payments</SectionTitle>
            <div className="space-y-3">
              <Label>
                Packaging charge (₹)
                <Field
                  name="packaging_charge"
                  type="number"
                  step="0.01"
                  defaultValue={String(stall.packaging_charge ?? 0)}
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
              <Label>
                Packaging mode
                <select
                  name="packaging_charge_mode"
                  defaultValue={stall.packaging_charge_mode ?? 'none'}
                  disabled={!isOwner}
                  className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm"
                >
                  <option value="none">None</option>
                  <option value="per_order">Per order</option>
                  <option value="per_item">Per item</option>
                </select>
              </Label>
              <Label>
                Rounding
                <select
                  name="rounding_rule"
                  defaultValue={stall.rounding_rule ?? 'rupee_1'}
                  disabled={!isOwner}
                  className="mt-1 w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm"
                >
                  <option value="none">None</option>
                  <option value="rupee_1">Nearest ₹1</option>
                  <option value="rupee_5">Nearest ₹5</option>
                </select>
              </Label>
              <Label>
                UPI VPA
                <Field
                  name="upi_vpa"
                  defaultValue={stall.upi_vpa ?? ''}
                  placeholder="merchant@paytm"
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
              <Label>
                Payee name
                <Field
                  name="upi_payee_name"
                  defaultValue={stall.upi_payee_name ?? ''}
                  placeholder="Stall display name"
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
            </div>
          </div>

          <div className="border-t border-border pt-4">
            <SectionTitle className="mb-1">Rules</SectionTitle>
            <p className="mb-3 text-xs text-on-surface-variant">
              Enforced on mobile for discounts and cash variance.
            </p>
            <div className="space-y-3">
              <Label>
                Staff discount cap (%)
                <Field
                  name="discount_staff_cap_pct"
                  type="number"
                  step="0.01"
                  defaultValue={String(stall.discount_staff_cap_pct ?? 10)}
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
              <Label>
                Staff discount cap (₹ flat)
                <Field
                  name="discount_staff_cap_flat"
                  type="number"
                  step="0.01"
                  defaultValue={String(stall.discount_staff_cap_flat ?? 100)}
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
              <Label>
                Manager discount cap (%)
                <Field
                  name="discount_manager_cap_pct"
                  type="number"
                  step="0.01"
                  defaultValue={String(stall.discount_manager_cap_pct ?? 50)}
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
              <Label>
                Variance reason threshold (₹)
                <Field
                  name="variance_reason_threshold"
                  type="number"
                  step="0.01"
                  defaultValue={String(stall.variance_reason_threshold ?? 50)}
                  disabled={!isOwner}
                  className="mt-1"
                />
              </Label>
            </div>
          </div>

          {isOwner && <Btn type="submit">Save changes</Btn>}
        </form>
      </Card>
    </div>
  );
}
