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

  if (!memberships || memberships.length === 0) redirect('/onboarding');

  const mine = (stalls ?? []).filter((s) =>
    memberships.some((m) => m.stall_id === s.id)
  );
  const active = await resolveActiveStall(memberships);
  const role = memberships.find((m) => m.stall_id === active.stall_id)?.role ?? 'staff';
  const isOwner = role === 'owner';
  const activeName = mine.find((s) => s.id === active.stall_id)?.name ?? 'Stall';

  return (
    <div className="min-h-screen bg-background">
      <ShellSidebar
        stalls={mine.map((s) => ({ id: s.id, name: s.name }))}
        activeId={active.stall_id}
        activeName={activeName}
        role={role}
        isOwner={isOwner}
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
