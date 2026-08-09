'use client';

export function PrintButton() {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="rounded border border-neutral-300 px-3 py-1.5 text-sm hover:bg-neutral-50"
    >
      Print / Save as PDF
    </button>
  );
}
