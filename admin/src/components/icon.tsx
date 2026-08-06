import { type HTMLAttributes } from 'react';

export function Icon({
  name,
  filled,
  className = '',
  ...rest
}: {
  name: string;
  filled?: boolean;
  className?: string;
} & HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={`material-symbols-outlined ${filled ? 'filled' : ''} ${className}`}
      aria-hidden
      {...rest}
    >
      {name}
    </span>
  );
}
