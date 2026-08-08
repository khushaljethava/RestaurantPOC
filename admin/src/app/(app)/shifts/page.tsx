import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export default async function ShiftsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: memberships } = await supabase
    .from("staff_membership")
    .select("stall_id, role, stall:stall_id(name)")
    .eq("user_id", user.id)
    .in("role", ["owner", "manager"]);

  const stallIds = (memberships ?? []).map((m) => m.stall_id as string);
  const { data: shifts } = stallIds.length
    ? await supabase
        .from("shifts")
        .select(
          "id, stall_id, staff_id, opened_at, closed_at, opening_float, declared_cash, expected_cash, variance, variance_reason",
        )
        .in("stall_id", stallIds)
        .order("opened_at", { ascending: false })
        .limit(50)
    : { data: [] as never[] };

  const { data: upi } = stallIds.length
    ? await supabase
        .from("payment")
        .select("id, amount, upi_ref, created_at, bill:bill_id(collected_by_stall_id, status)")
        .eq("method", "upi")
        .eq("upi_verified", false)
        .order("created_at", { ascending: false })
        .limit(30)
    : { data: [] as never[] };

  return (
    <main className="mx-auto max-w-3xl space-y-8 p-6">
      <h1 className="text-2xl font-semibold">Shifts & UPI verify</h1>
      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent shifts</h2>
        <ul className="divide-y rounded border">
          {(shifts ?? []).map((s) => (
            <li key={s.id} className="flex justify-between gap-4 p-3 text-sm">
              <span>
                {new Date(s.opened_at).toLocaleString()}
                {s.closed_at ? " → closed" : " (open)"}
              </span>
              <span>
                var {String(s.variance ?? "—")}
                {s.variance_reason ? ` · ${s.variance_reason}` : ""}
              </span>
            </li>
          ))}
          {(shifts ?? []).length === 0 && (
            <li className="p-3 text-sm text-neutral-500">No shifts yet</li>
          )}
        </ul>
      </section>
      <section className="space-y-2">
        <h2 className="text-lg font-medium">Unverified UPI</h2>
        <ul className="divide-y rounded border">
          {(upi ?? []).map((p) => (
            <li key={p.id} className="flex justify-between gap-4 p-3 text-sm">
              <span>₹{String(p.amount)}</span>
              <span>{(p.upi_ref as string | null) ?? "no ref"}</span>
            </li>
          ))}
          {(upi ?? []).length === 0 && (
            <li className="p-3 text-sm text-neutral-500">None</li>
          )}
        </ul>
      </section>
    </main>
  );
}
