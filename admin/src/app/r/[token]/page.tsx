import { createClient } from '@/lib/supabase/server';

export default async function PublicReceiptPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('get_public_receipt', {
    p_token: token,
  });

  if (error || !data) {
    return (
      <main className="mx-auto max-w-md px-4 py-16 text-center">
        <h1 className="text-xl font-semibold">Receipt not found</h1>
        <p className="mt-2 text-sm text-on-surface-variant">
          This link may be invalid or expired.
        </p>
      </main>
    );
  }

  const receipt = data as {
    total: number;
    discount: number;
    token_no: number | null;
    table_label: string | null;
    status: string;
    stall_name?: string | null;
    logo_url?: string | null;
    receipt_footer?: string | null;
    items: { name: string; qty: number; line_total: number }[];
    payments: { method: string; amount: number }[];
  };

  return (
    <main className="mx-auto max-w-md px-4 py-10">
      {receipt.logo_url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={receipt.logo_url}
          alt=""
          className="mb-3 h-12 w-auto object-contain"
        />
      ) : null}
      <h1 className="text-2xl font-semibold tracking-tight">
        {receipt.stall_name || 'Receipt'}
      </h1>
      <p className="mt-1 text-sm text-on-surface-variant">
        Token #{receipt.token_no ?? '—'}
        {receipt.table_label ? ` · ${receipt.table_label}` : ''} · {receipt.status}
      </p>
      <ul className="mt-6 space-y-2 border-t border-border pt-4">
        {(receipt.items ?? []).map((it, i) => (
          <li key={i} className="flex justify-between text-sm">
            <span>
              {it.name} × {it.qty}
            </span>
            <span className="tabular-nums">₹{Number(it.line_total).toFixed(2)}</span>
          </li>
        ))}
      </ul>
      <div className="mt-4 flex justify-between border-t border-border pt-4 text-base font-semibold">
        <span>Total</span>
        <span className="tabular-nums">
          ₹{(Number(receipt.total) - Number(receipt.discount || 0)).toFixed(2)}
        </span>
      </div>
      <ul className="mt-3 space-y-1 text-sm text-on-surface-variant">
        {(receipt.payments ?? []).map((p, i) => (
          <li key={i} className="flex justify-between">
            <span>{p.method}</span>
            <span className="tabular-nums">₹{Number(p.amount).toFixed(2)}</span>
          </li>
        ))}
      </ul>
      {receipt.receipt_footer ? (
        <p className="mt-8 text-center text-xs text-on-surface-variant whitespace-pre-wrap">
          {receipt.receipt_footer}
        </p>
      ) : null}
    </main>
  );
}
