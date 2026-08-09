export function toCsv(headers: string[], rows: (string | number | null | undefined)[][]): string {
  const esc = (v: string | number | null | undefined) => {
    const s = v == null ? '' : String(v);
    if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  };
  return [headers.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))].join('\n');
}

/** Minimal RFC4180-ish CSV parse. First row = headers. */
export function parseCsv(text: string): { headers: string[]; rows: string[][] } {
  const lines: string[][] = [];
  let row: string[] = [];
  let cur = '';
  let inQ = false;
  const pushCell = () => {
    row.push(cur);
    cur = '';
  };
  const pushRow = () => {
    pushCell();
    if (row.some((c) => c.trim() !== '')) lines.push(row);
    row = [];
  };
  const s = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (inQ) {
      if (ch === '"') {
        if (s[i + 1] === '"') {
          cur += '"';
          i++;
        } else inQ = false;
      } else cur += ch;
    } else if (ch === '"') inQ = true;
    else if (ch === ',') pushCell();
    else if (ch === '\n') pushRow();
    else if (ch === '\r') {
      /* ignore */
    } else cur += ch;
  }
  if (cur.length || row.length) pushRow();
  if (lines.length === 0) return { headers: [], rows: [] };
  const headers = lines[0].map((h) => h.trim().toLowerCase());
  return { headers, rows: lines.slice(1) };
}
