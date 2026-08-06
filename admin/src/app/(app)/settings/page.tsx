import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { updateStallSettings } from './actions';
import { Btn, Field, Label, PageTitle } from '@/components/ui';

export default async function SettingsPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const stallId = active.stall_id;
  const isOwner = active.role === 'owner';

  const { data: stall } = stallId
    ? await supabase
        .from('stall')
        .select('id, name, currency, timezone, is_open, upi_vpa, upi_payee_name')
        .eq('id', stallId)
        .single()
    : { data: null };

  if (!stall) return <p className="text-on-surface-variant">No stall</p>;

  return (
    <div className="mx-auto max-w-[640px]">
      <PageTitle>Stall settings</PageTitle>
      {!isOwner && (
        <p className="mb-4 text-sm text-on-surface-variant">View only — owner can edit.</p>
      )}
      <form action={updateStallSettings} className="space-y-4">
        <input type="hidden" name="id" value={stall.id} />
        <Label>
          Stall name
          <Field name="name" defaultValue={stall.name} required disabled={!isOwner} className="mt-1" />
        </Label>
        <Label>
          Currency
          <Field name="currency" defaultValue={stall.currency} disabled={!isOwner} className="mt-1" />
        </Label>
        <Label>
          Timezone
          <Field name="timezone" defaultValue={stall.timezone} disabled={!isOwner} className="mt-1" />
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
          <h2 className="mb-1 text-base font-medium text-on-surface">UPI collection</h2>
          <p className="mb-3 text-xs text-on-surface-variant">
            From Paytm Business or any UPI app, e.g. merchant@paytm
          </p>
          <div className="space-y-3">
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

        {isOwner && <Btn type="submit">Save changes</Btn>}
      </form>
    </div>
  );
}
