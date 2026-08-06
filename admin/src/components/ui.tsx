import Link from 'next/link';
import { type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from 'react';
import { Icon } from './icon';

const focus =
  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-surface-tint';

export function PageTitle({
  children,
  subtitle,
  trailing,
}: {
  children: ReactNode;
  subtitle?: ReactNode;
  trailing?: ReactNode;
}) {
  return (
    <div className="mb-8 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-[28px] font-semibold leading-tight tracking-tight text-on-surface">
          {children}
        </h1>
        {subtitle ? <p className="mt-1 text-sm text-on-surface-variant">{subtitle}</p> : null}
      </div>
      {trailing}
    </div>
  );
}

export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <div className={`rounded-md border border-border bg-surface p-5 shadow-card ${className}`}>
      {children}
    </div>
  );
}

export function SectionTitle({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <h2 className={`mb-3 text-base font-semibold tracking-tight text-on-surface ${className}`}>
      {children}
    </h2>
  );
}

/** Stat tile — dashboard/reports/settlement each hand-rolled this. */
export function Stat({
  label,
  value,
  icon,
  tone = 'neutral',
  href,
  hrefLabel,
}: {
  label: ReactNode;
  value: ReactNode;
  icon?: string;
  tone?: 'success' | 'warning' | 'error' | 'neutral';
  href?: string;
  hrefLabel?: string;
}) {
  const tones = {
    success: 'bg-primary-container text-primary',
    warning: 'bg-warning-container text-warning',
    error: 'bg-error-container text-on-error-container',
    neutral: 'bg-secondary-container text-on-secondary-container',
  };
  return (
    <Card className="flex flex-col transition-shadow hover:shadow-card-hover">
      <div className="flex items-start justify-between gap-3">
        <div className="text-xs font-medium uppercase tracking-wide text-on-surface-variant">
          {label}
        </div>
        {icon ? (
          <span
            className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full ${tones[tone]}`}
          >
            <Icon name={icon} />
          </span>
        ) : null}
      </div>
      <div className="mt-3 text-[34px] font-semibold leading-none tabular-nums text-on-surface">
        {value}
      </div>
      {href ? (
        <Link
          href={href}
          className={`mt-4 inline-flex items-center gap-1 rounded-sm text-sm font-medium text-surface-tint hover:underline ${focus}`}
        >
          {hrefLabel ?? 'View'}
          <Icon name="arrow_forward" className="!text-base" />
        </Link>
      ) : null}
    </Card>
  );
}

export function EmptyState({
  icon = 'inbox',
  title,
  children,
}: {
  icon?: string;
  title: ReactNode;
  children?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-14 text-center">
      <span className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant">
        <Icon name={icon} />
      </span>
      <p className="text-sm font-medium text-on-surface">{title}</p>
      {children ? <p className="max-w-sm text-sm text-on-surface-variant">{children}</p> : null}
    </div>
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
    primary: 'bg-surface-tint text-on-primary shadow-card hover:bg-primary',
    tonal: 'bg-primary-container text-primary hover:brightness-95',
    outlined: 'border border-border bg-surface text-primary hover:bg-surface-container-high',
    text: 'bg-transparent text-primary hover:bg-surface-container-high',
    danger: 'bg-transparent text-error hover:bg-error-container',
  };
  return (
    <button
      className={`inline-flex h-11 items-center justify-center gap-2 rounded-lg px-4 text-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-50 ${focus} ${variants[variant]} ${className}`}
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
      className={`h-11 w-full rounded-lg border border-border bg-surface px-3 text-sm text-on-surface transition-colors placeholder:text-on-surface-variant hover:border-outline ${focus} disabled:opacity-50 ${className}`}
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
      className={`h-11 rounded-lg border border-border bg-surface px-3 text-sm text-on-surface transition-colors hover:border-outline ${focus} disabled:opacity-50 ${className}`}
      {...props}
    >
      {children}
    </select>
  );
}

export function Label({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <label className={`block text-sm font-medium text-on-surface-variant ${className}`}>
      {children}
    </label>
  );
}

export function TableWrap({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-md border border-border bg-surface shadow-card">
      {children}
    </div>
  );
}

export function Th({ children, className = '' }: { children?: ReactNode; className?: string }) {
  return (
    <th
      className={`h-11 border-b border-border bg-surface-container-low px-4 text-left text-xs font-semibold uppercase tracking-wide text-on-surface-variant ${className}`}
    >
      {children}
    </th>
  );
}

export function Td({ children, className = '' }: { children?: ReactNode; className?: string }) {
  return (
    <td
      className={`h-12 border-t border-border px-4 text-sm text-on-surface first:font-medium ${className}`}
    >
      {children}
    </td>
  );
}

/** Row with hover affordance — tables read as scannable, not as a spreadsheet dump. */
export function Tr({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <tr className={`transition-colors hover:bg-surface-container-low ${className}`}>{children}</tr>;
}
