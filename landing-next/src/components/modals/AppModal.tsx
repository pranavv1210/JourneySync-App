'use client';

import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useEffect, useRef } from 'react';
import type { LucideIcon } from 'lucide-react';

interface AppModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  icon?: LucideIcon;
  children?: React.ReactNode;
  labelledBy?: string;
  size?: 'md' | 'lg';
  maxWidth?: string;
  contentClassName?: string;
  panelClassName?: string;
  headerClassName?: string;
}

export function AppModal({
  isOpen,
  onClose,
  title,
  icon: Icon,
  children,
  labelledBy = 'app-modal-title',
  size = 'md',
  maxWidth: explicitMaxWidth,
  contentClassName = '',
  panelClassName = 'border-neutral-200 bg-white text-neutral-900',
  headerClassName = 'bg-white/95 text-neutral-950',
}: AppModalProps) {
  const shouldReduceMotion = useReducedMotion();
  const shellRef = useRef<HTMLElement>(null);
  const maxWidth = explicitMaxWidth ?? (size === 'lg' ? '48rem' : '28rem');

  useEffect(() => {
    if (!isOpen) return;

    const prev = {
      bodyOverflow: document.body.style.overflow,
      bodyPR: document.body.style.paddingRight,
      htmlOverflow: document.documentElement.style.overflow,
      htmlPR: document.documentElement.style.paddingRight,
    };

    document.body.style.overflow = 'hidden';
    document.body.style.paddingRight = '';
    document.body.classList.add('modal-open');
    document.documentElement.style.overflow = 'hidden';
    document.documentElement.style.paddingRight = '';

    const target = shellRef.current;
    const active = document.activeElement as HTMLElement | null;
    const firstFocusable = target?.querySelector<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    );
    firstFocusable?.focus();

    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key !== 'Tab' || !target) return;

      const focusables = Array.from(
        target.querySelectorAll<HTMLElement>(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
        ),
      ).filter((node) => !node.hasAttribute('disabled'));

      if (focusables.length === 0) return;

      const first = focusables[0];
      const last = focusables[focusables.length - 1];

      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };

    window.addEventListener('keydown', handleKey);
    return () => {
      document.body.style.overflow = prev.bodyOverflow;
      document.body.style.paddingRight = prev.bodyPR;
      document.documentElement.style.overflow = prev.htmlOverflow;
      document.documentElement.style.paddingRight = prev.htmlPR;
      document.body.classList.remove('modal-open');
      window.removeEventListener('keydown', handleKey);
      active?.focus();
    };
  }, [isOpen, onClose]);

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="app-modal-overlay fixed inset-0 flex items-center justify-center p-4 sm:p-6">
          <motion.button
            type="button"
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            aria-label="Close modal"
            onClick={onClose}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.28, ease: 'easeOut' }}
          />

          <motion.article
            ref={shellRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby={labelledBy}
            className={`app-modal-shell relative flex flex-col overflow-hidden rounded-2xl border shadow-2xl ${panelClassName}`}
            style={{ boxSizing: 'border-box', maxWidth, width: 'min(100%, calc(100vw - 2rem))' }}
            initial={shouldReduceMotion ? false : { opacity: 0, scale: 0.96, y: 16 }}
            animate={shouldReduceMotion ? { opacity: 1 } : { opacity: 1, scale: 1, y: 0 }}
            exit={shouldReduceMotion ? { opacity: 0 } : { opacity: 0, scale: 0.96, y: 16 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.28, ease: 'easeOut' }}
          >
            {title && (
              <header className={`app-modal-header sticky top-0 flex items-center gap-3 rounded-t-2xl border-b border-neutral-100 ${headerClassName}`}>
                {Icon && (
                  <span className="grid h-9 w-9 flex-none place-items-center rounded-full bg-orange-50 text-[#d97706]">
                    <Icon size={17} />
                  </span>
                )}
                <h2 id={labelledBy} className="min-w-0 truncate text-lg font-extrabold sm:text-xl">
                  {title}
                </h2>
                <button
                  type="button"
                  onClick={onClose}
                  className="ml-auto inline-flex h-9 w-9 items-center justify-center rounded-full border border-black/8 bg-black/3 text-neutral-700 transition hover:bg-black/8"
                  aria-label="Close modal"
                >
                  <span className="material-icons-round text-base">close</span>
                </button>
              </header>
            )}

            <div className={`app-modal-scroll overflow-y-auto ${contentClassName}`}>
              {children}
            </div>
          </motion.article>
        </div>
      )}
    </AnimatePresence>
  );
}
