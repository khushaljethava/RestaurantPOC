'use client';

import { toCsv } from '@/lib/csv';
import { Btn } from '@/components/ui';

/** Called by reports/page.tsx and settlement/page.tsx for CSV download. */
export function ReportCsv({
  filename,
  headers,
  rows,
}: {
  filename: string;
  headers: string[];
  rows: (string | number | null | undefined)[][];
}) {
  function download() {
    const blob = new Blob([toCsv(headers, rows)], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }
  return (
    <Btn type="button" variant="outlined" onClick={download} className="h-9 px-3 text-xs">
      Export CSV
    </Btn>
  );
}
