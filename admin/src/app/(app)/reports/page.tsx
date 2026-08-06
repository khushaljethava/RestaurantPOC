import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallTimezone } from '@/lib/active-stall';
import { ReportCsv } from './report-csv';
import {
  Btn,
  Card,
  Field,
  Label,
  PageTitle,
  SectionTitle,
  TableWrap,
  Td,
  Th,
  Tr,
} from '@/components/ui';

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const tz = await activeStallTimezone();
  const { from, to } = parseRange(tz, sp.from, sp.to);
  const supabase = await createClient();

  const [byStall, byItem, byMode, byCollector, stalls] = await Promise.all([
    supabase.rpc('sales_by_stall', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_item', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_payment_mode', { p_from: from, p_to: to }),
    supabase.rpc('sales_by_collector', { p_from: from, p_to: to }),
    supabase.from('stall').select('id, name'),
  ]);

  const nameOf = (id: string) => stalls.data?.find((s) => s.id === id)?.name ?? id.slice(0, 8);

  const toDateDefault = new Date(new Date(to).getTime() - 86400000).toISOString().slice(0, 10);

  return (
    <div className="space-y-8">
      <PageTitle subtitle="Sales breakdowns for the selected date range">Reports</PageTitle>
      <Card>
        <form className="flex flex-wrap items-end gap-3">
          <div>
            <Label className="mb-1.5">From</Label>
            <Field type="date" name="from" defaultValue={from.slice(0, 10)} className="w-auto" />
          </div>
          <div>
            <Label className="mb-1.5">To</Label>
            <Field type="date" name="to" defaultValue={toDateDefault} className="w-auto" />
          </div>
          <Btn type="submit" variant="primary">
            Apply
          </Btn>
        </form>
      </Card>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Sales by stall</SectionTitle>
          <ReportCsv
            filename="sales-by-stall.csv"
            headers={['stall', 'revenue', 'orders']}
            rows={(byStall.data ?? []).map(
              (r: { stall_id: string; revenue: number; order_count: number }) => [
                nameOf(r.stall_id),
                r.revenue,
                r.order_count,
              ],
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Stall</Th>
                <Th className="text-right">Revenue</Th>
                <Th className="text-right">Orders</Th>
              </tr>
            </thead>
            <tbody>
              {(byStall.data ?? []).map(
                (r: { stall_id: string; revenue: number; order_count: number }) => (
                  <Tr key={r.stall_id}>
                    <Td>{nameOf(r.stall_id)}</Td>
                    <Td className="text-right tabular-nums">₹{Number(r.revenue).toFixed(2)}</Td>
                    <Td className="text-right tabular-nums">{r.order_count}</Td>
                  </Tr>
                ),
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Sales by item</SectionTitle>
          <ReportCsv
            filename="sales-by-item.csv"
            headers={['item', 'stall', 'qty', 'revenue']}
            rows={(byItem.data ?? []).map(
              (r: { item_name: string; stall_id: string; qty: number; revenue: number }) => [
                r.item_name,
                nameOf(r.stall_id),
                r.qty,
                r.revenue,
              ],
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Item</Th>
                <Th>Stall</Th>
                <Th className="text-right">Qty</Th>
                <Th className="text-right">Revenue</Th>
              </tr>
            </thead>
            <tbody>
              {(byItem.data ?? []).map(
                (r: {
                  menu_item_id: string;
                  item_name: string;
                  stall_id: string;
                  qty: number;
                  revenue: number;
                }) => (
                  <Tr key={`${r.menu_item_id}-${r.stall_id}`}>
                    <Td>{r.item_name}</Td>
                    <Td>{nameOf(r.stall_id)}</Td>
                    <Td className="text-right tabular-nums">{Number(r.qty)}</Td>
                    <Td className="text-right tabular-nums">₹{Number(r.revenue).toFixed(2)}</Td>
                  </Tr>
                ),
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Sales by payment mode</SectionTitle>
          <ReportCsv
            filename="sales-by-payment.csv"
            headers={['method', 'amount', 'count']}
            rows={(byMode.data ?? []).map(
              (r: { method: string; amount: number; payment_count: number }) => [
                r.method,
                r.amount,
                r.payment_count,
              ],
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Method</Th>
                <Th className="text-right">Amount</Th>
                <Th className="text-right">Payments</Th>
              </tr>
            </thead>
            <tbody>
              {(byMode.data ?? []).map(
                (r: { method: string; amount: number; payment_count: number }) => (
                  <Tr key={r.method}>
                    <Td className="capitalize">{r.method}</Td>
                    <Td className="text-right tabular-nums">₹{Number(r.amount).toFixed(2)}</Td>
                    <Td className="text-right tabular-nums">{r.payment_count}</Td>
                  </Tr>
                ),
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>

      <section className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <SectionTitle className="mb-0">Sales by collector</SectionTitle>
          <ReportCsv
            filename="sales-by-collector.csv"
            headers={['collector', 'amount', 'bills']}
            rows={(byCollector.data ?? []).map(
              (r: { collected_by_stall_id: string; amount: number; bill_count: number }) => [
                nameOf(r.collected_by_stall_id),
                r.amount,
                r.bill_count,
              ],
            )}
          />
        </div>
        <TableWrap>
          <table className="w-full">
            <thead>
              <tr>
                <Th>Collector</Th>
                <Th className="text-right">Amount</Th>
                <Th className="text-right">Bills</Th>
              </tr>
            </thead>
            <tbody>
              {(byCollector.data ?? []).map(
                (r: { collected_by_stall_id: string; amount: number; bill_count: number }) => (
                  <Tr key={r.collected_by_stall_id}>
                    <Td>{nameOf(r.collected_by_stall_id)}</Td>
                    <Td className="text-right tabular-nums">₹{Number(r.amount).toFixed(2)}</Td>
                    <Td className="text-right tabular-nums">{r.bill_count}</Td>
                  </Tr>
                ),
              )}
            </tbody>
          </table>
        </TableWrap>
      </section>
    </div>
  );
}
