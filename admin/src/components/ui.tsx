import { type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from 'react';

const focus =
  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-surface-tint';

export function PageTitle({ children, trailing }: { children: ReactNode; trailing?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
      <h1 className="text-2xl font-normal tracking-tight text-on-surface">{children}</h1>
      {trailing}
    </div>
  );
}

export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-md bg-surface p-4 ${className}`}>{children}</div>
  );
}

export function StatusPill({
  tone = 'neutral',
  children,
}: {
  tone?: 'success' | 'warning' | 'error' | 'neutral';
  children: ReactNode;
}) {
  const tones = {
    success: 'bg-primary-container text-primary',
    warning: 'bg-warning-container text-warning',
    error: 'bg-error-container text-on-error-container',
    neutral: 'bg-secondary-container text-on-secondary-container',
  };
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-medium ${tones[tone]}`}
    >
      {children}
    </span>
  );
}

export function Btn({
  variant = 'primary',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'tonal' | 'outlined' | 'text' | 'danger';
}) {
  const variants = {
    primary: 'bg-surface-tint text-on-primary hover:opacity-90',
    tonal: 'bg-primary-container text-primary hover:opacity-90',
    outlined: 'border border-border bg-transparent text-primary hover:bg-surface-container-highest',
    text: 'bg-transparent text-primary hover:bg-surface-container-highest',
    danger: 'bg-transparent text-error hover:bg-error-container',
  };
  return (
    <button
      className={`inline-flex h-11 items-center justify-center gap-2 rounded-lg px-4 text-sm font-medium disabled:opacity-50 ${focus} ${variants[variant]} ${className}`}
      {...props}
    />
  );
}

export function Field({
  className = '',
  ...props
}: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={`h-11 w-full rounded-lg border border-border bg-surface-container-lowest px-3 text-sm text-on-surface placeholder:text-on-surface-variant ${focus} disabled:opacity-50 ${className}`}
      {...props}
    />
  );
}

export function Select({
  className = '',
  children,
  ...props
}: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={`h-11 rounded-lg border border-border bg-surface-container-lowest px-3 text-sm text-on-surface ${focus} disabled:opacity-50 ${className}`}
      {...props}
    >
      {children}
    </select>
  );
}

export function Label({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <label className={`block text-sm text-on-surface ${className}`}>{children}</label>;
}

export function TableWrap({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-md border border-border bg-surface-container-lowest">
      {children}
    </div>
  );
}

export function Th({ children, className = '' }: { children?: ReactNode; className?: string }) {
  return (
    <th
      className={`sticky top-0 h-11 bg-surface px-3 text-left text-sm font-medium text-on-surface-variant ${className}`}
    >
      {children}
    </th>
  );
}

export function Td({ children, className = '' }: { children?: ReactNode; className?: string }) {
  return <td className={`h-11 border-t border-border px-3 text-sm text-on-surface ${className}`}>{children}</td>;
}
