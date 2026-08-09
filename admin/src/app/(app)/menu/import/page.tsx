import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { resolveActiveStall } from '@/lib/active-stall';
import { importMenuCsv } from './actions';
import { Btn, Card, Field, PageTitle, SectionTitle } from '@/components/ui';
import { ReportCsv } from '../../reports/report-csv';

export default async function MenuImportPage({
  searchParams,
}: {
  searchParams: Promise<{ created?: string; updated?: string; errors?: string }>;
}) {
  const sp = await searchParams;
  const supabase = await createClient();
  const { data: memberships } = await supabase.from('staff_membership').select('stall_id, role');
  if (!memberships?.length) return <p className="text-on-surface-variant">No stall</p>;
  const active = await resolveActiveStall(memberships);

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <PageTitle
        subtitle={
          <Link href="/menu" className="text-surface-tint hover:underline">
            ← Menu
          </Link>
        }
      >
        CSV import
      </PageTitle>

      <Card className="space-y-3 text-sm">
        <SectionTitle className="mb-0">Format</SectionTitle>
        <p className="text-on-surface-variant">
          Header row required:{' '}
          <code className="text-xs">name,price,category,quick_code,description,available</code>
        </p>
        <ReportCsv
          filename="menu-template.csv"
          headers={['name', 'price', 'category', 'quick_code', 'description', 'available']}
          rows={[
            ['Masala dosa', 80, 'South Indian', '21', 'Crispy', 'true'],
            ['Filter coffee', 30, 'Beverages', '91', '', 'true'],
          ]}
        />
      </Card>

      {(sp.created || sp.updated || sp.errors) && (
        <Card className="text-sm">
          Imported: {sp.created ?? 0} new, {sp.updated ?? 0} updated
          {sp.errors && Number(sp.errors) > 0 ? `, ${sp.errors} errors` : ''}.
        </Card>
      )}

      <Card>
        <form
          action={async (fd) => {
            'use server';
            const result = await importMenuCsv(fd);
            const { redirect } = await import('next/navigation');
            redirect(
              `/menu/import?created=${result.created}&updated=${result.updated}&errors=${result.errors.length}`
            );
          }}
          className="space-y-3"
        >
          <input type="hidden" name="stall_id" value={active.stall_id} />
          <Field name="file" type="file" accept=".csv,text/csv" required />
          <Btn type="submit">Upload & apply</Btn>
        </form>
      </Card>
    </div>
  );
}
