import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { ShellSidebar } from '@/components/shell-sidebar';
import { ShellTopbar } from '@/components/shell-topbar';

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const { data: stalls } = await supabase
    .from('stall')
    .select('id, name, group_id');

  const { data: memberships } = await supabase
    .from('staff_membership')
    .select('stall_id, role');

  // A food court operator owns no stall. Without this they would be bounced to
  // /onboarding forever, and resolveActiveStall would throw 'no memberships'.
  const { data: courtMemberships } = await supabase
    .from('food_court_membership')
    .select('food_court_id');

  const hasStalls = (memberships?.length ?? 0) > 0;
  const isOperator = (courtMemberships?.length ?? 0) > 0;

  if (!hasStalls && !isOperator) redirect('/onboarding');

  const mine = (stalls ?? []).filter((s) =>
    (memberships ?? []).some((m) => m.stall_id === s.id)
  );
  const active = hasStalls ? await resolveActiveStall(memberships!) : null;
  const role = active
    ? (memberships!.find((m) => m.stall_id === active.stall_id)?.role ?? 'staff')
    : 'operator';
  const isOwner = role === 'owner';
  const activeName = active
    ? (mine.find((s) => s.id === active.stall_id)?.name ?? 'Stall')
    : 'Food courts';

  return (
    <div className="min-h-screen bg-background">
      <ShellSidebar
        stalls={mine.map((s) => ({ id: s.id, name: s.name }))}
        activeId={active?.stall_id ?? ''}
        activeName={activeName}
        role={role}
        isOwner={isOwner}
        hasStalls={hasStalls}
        isOperator={isOperator}
      />
      <div className="ml-sidebar-width flex min-h-screen flex-col">
        <ShellTopbar />
        <main className="flex-1 p-page-padding">
          <div className="mx-auto w-full max-w-6xl">{children}</div>
        </main>
      </div>
    </div>
  );
}
