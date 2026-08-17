import type { ReactNode } from 'react';

type CtaButtonProps = {
  children: ReactNode;
  onClick?: () => void;
  href?: string;
  variant?: 'primary' | 'ghost' | 'outline';
  className?: string;
};

export function CtaButton({
  children,
  onClick,
  href,
  variant = 'primary',
  className = '',
}: CtaButtonProps) {
  const styles = {
    primary: 'cta-primary',
    ghost: 'cta-ghost',
    outline: 'cta-outline',
  }[variant];

  const baseClassName = `cta-button ${styles} ${className}`.trim();

  if (href) {
    return (
      <a className={baseClassName} href={href}>
        {children}
      </a>
    );
  }

  return (
    <button type="button" className={baseClassName} onClick={onClick}>
      {children}
    </button>
  );
}
