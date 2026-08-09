import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { createAdminClient, isPlatformAdminEmail } from '@/lib/supabase/admin';
import { Card, EmptyState, PageTitle, TableWrap, Td, Th, Tr } from '@/components/ui';

export default async function PlatformTenantsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  if (!isPlatformAdminEmail(user.email)) {
    return (
      <Card className="p-0">
        <EmptyState icon="lock" title="Not authorized">
          Add your email to PLATFORM_ADMIN_EMAILS and set SUPABASE_SERVICE_ROLE_KEY.
        </EmptyState>
      </Card>
    );
  }

  const admin = createAdminClient();
  if (!admin) {
    return (
      <Card className="p-0">
        <EmptyState icon="key" title="Service role not configured">
          Set SUPABASE_SERVICE_ROLE_KEY to list tenants.
        </EmptyState>
      </Card>
    );
  }

  const { data: stalls } = await admin
    .from('stall')
    .select('id, name, currency, timezone, created_at, is_open')
    .order('created_at', { ascending: false })
    .limit(200);

  return (
    <div className="space-y-6">
      <PageTitle subtitle="Platform console · all stalls">Tenants</PageTitle>
      <TableWrap>
        <table className="w-full">
          <thead>
            <tr>
              <Th>Name</Th>
              <Th>Currency</Th>
              <Th>Timezone</Th>
              <Th>Open</Th>
              <Th>Created</Th>
            </tr>
          </thead>
          <tbody>
            {(stalls ?? []).map((s) => (
              <Tr key={s.id}>
                <Td className="font-medium">{s.name}</Td>
                <Td>{s.currency}</Td>
                <Td className="text-xs">{s.timezone}</Td>
                <Td>{s.is_open ? 'yes' : 'no'}</Td>
                <Td className="text-xs">{new Date(s.created_at).toLocaleDateString()}</Td>
              </Tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
      {(stalls ?? []).length === 0 && (
        <Card className="p-0">
          <EmptyState icon="storefront" title="No stalls">
            Empty database.
          </EmptyState>
        </Card>
      )}
    </div>
  );
}
