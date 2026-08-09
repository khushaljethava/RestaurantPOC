import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { revokeDevice } from './actions';
import {
  Btn,
  Card,
  EmptyState,
  PageTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function DevicesPage() {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);
  const canManage = active.role === 'owner' || active.role === 'manager';
  if (!canManage) {
    return <p className="text-on-surface-variant">Owner or manager only.</p>;
  }

  const { data: tokens } = await supabase
    .from('device_push_token')
    .select('id, user_id, platform, token, updated_at')
    .eq('stall_id', active.stall_id)
    .order('updated_at', { ascending: false });

  return (
    <div className="space-y-6">
      <PageTitle
        subtitle={
          <Link href="/settings" className="text-surface-tint hover:underline">
            ← Settings
          </Link>
        }
      >
        Devices
      </PageTitle>
      <p className="text-sm text-on-surface-variant">
        Registered FCM push tokens. Revoke to stop push to a lost device (Realtime still works).
      </p>
      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>Platform</Th>
              <Th>User</Th>
              <Th>Token</Th>
              <Th>Updated</Th>
              <Th />
            </tr>
          </thead>
          <tbody>
            {(tokens ?? []).map((t) => (
              <Tr key={t.id}>
                <Td className="capitalize">{t.platform}</Td>
                <Td className="font-mono text-xs">{t.user_id.slice(0, 8)}</Td>
                <Td className="max-w-[12rem] truncate font-mono text-xs">{t.token}</Td>
                <Td className="text-xs">{new Date(t.updated_at).toLocaleString()}</Td>
                <Td className="text-right">
                  <form action={revokeDevice}>
                    <input type="hidden" name="id" value={t.id} />
                    <Btn type="submit" variant="danger" className="h-8 px-2 text-xs">
                      Revoke
                    </Btn>
                  </form>
                </Td>
              </Tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
      {(tokens ?? []).length === 0 && (
        <Card className="p-0">
          <EmptyState icon="smartphone" title="No devices registered">
            Tokens appear after mobile push registration.
          </EmptyState>
        </Card>
      )}
    </div>
  );
}
