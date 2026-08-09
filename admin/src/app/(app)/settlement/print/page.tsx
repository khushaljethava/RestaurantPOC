import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { parseRange } from '@/lib/dates';
import { activeStallDayContext } from '@/lib/active-stall';
import { formatInr } from '@/lib/money';
import { PrintButton } from './print-button';

type Pair = { stall_a: string; stall_b: string; a_owes_b: number };

/** Printable settlement sheet — browser Print → Save as PDF. */
export default async function SettlementPrintPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const sp = await searchParams;
  const { timezone: tz, dayStartMinutes } = await activeStallDayContext();
  const { from, to } = parseRange(tz, sp.from, sp.to, dayStartMinutes);
  const toYmd = new Date(new Date(to).getTime() - 86400000).toISOString().slice(0, 10);
  const supabase = await createClient();
  const [{ data: pairs }, { data: stalls }] = await Promise.all([
    supabase.rpc('settlement_pairs', { p_from: from, p_to: to }),
    supabase.from('stall').select('id, name'),
  ]);
  const nameOf = (id: string) => stalls?.find((s) => s.id === id)?.name ?? id.slice(0, 8);
  const list = (pairs as Pair[]) ?? [];

  return (
    <div className="mx-auto max-w-2xl bg-white p-8 text-black print:max-w-none print:p-0">
      <div className="mb-6 flex items-start justify-between gap-4 print:hidden">
        <Link href={`/settlement?from=${from.slice(0, 10)}&to=${toYmd}`} className="text-sm underline">
          ← Back
        </Link>
        <PrintButton />
      </div>

      <header className="mb-8 border-b border-neutral-300 pb-4">
        <h1 className="text-2xl font-semibold tracking-tight">Settlement sheet</h1>
        <p className="mt-1 text-sm text-neutral-600">
          {from.slice(0, 10)} → {toYmd} · generated {new Date().toLocaleString()}
        </p>
      </header>

      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-neutral-300 text-left">
            <th className="py-2">Payer</th>
            <th className="py-2">Payee</th>
            <th className="py-2 text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          {list.map((p) => {
            const payer = Number(p.a_owes_b) > 0 ? p.stall_a : p.stall_b;
            const payee = Number(p.a_owes_b) > 0 ? p.stall_b : p.stall_a;
            const amt = Math.abs(Number(p.a_owes_b));
            return (
              <tr key={`${p.stall_a}-${p.stall_b}`} className="border-b border-neutral-200">
                <td className="py-2">{nameOf(payer)}</td>
                <td className="py-2">{nameOf(payee)}</td>
                <td className="py-2 text-right tabular-nums">{formatInr(amt)}</td>
              </tr>
            );
          })}
          {list.length === 0 && (
            <tr>
              <td colSpan={3} className="py-6 text-neutral-500">
                No balances in this range.
              </td>
            </tr>
          )}
        </tbody>
      </table>

      <p className="mt-10 text-xs text-neutral-500">StreetStall settlement export.</p>
      <div className="mt-12 grid grid-cols-2 gap-8 text-sm">
        <div>
          <div className="mb-10 border-b border-neutral-400" />
          Payer signature
        </div>
        <div>
          <div className="mb-10 border-b border-neutral-400" />
          Payee signature
        </div>
      </div>
    </div>
  );
}
