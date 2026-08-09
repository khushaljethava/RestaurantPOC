import { Btn, Card, Field, Label } from '@/components/ui';

/** URL-driven from/to date form. Callers: reports/* pages. */
export function DateRangeForm({
  fromYmd,
  toYmd,
}: {
  fromYmd: string;
  toYmd: string;
}) {
  return (
    <Card>
      <form className="flex flex-wrap items-end gap-3">
        <div>
          <Label className="mb-1.5">From</Label>
          <Field type="date" name="from" defaultValue={fromYmd} className="w-auto" />
        </div>
        <div>
          <Label className="mb-1.5">To</Label>
          <Field type="date" name="to" defaultValue={toYmd} className="w-auto" />
        </div>
        <Btn type="submit" variant="primary">
          Apply
        </Btn>
      </form>
    </Card>
  );
}
