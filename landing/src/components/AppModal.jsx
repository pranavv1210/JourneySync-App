import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useEffect } from 'react';

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
}) {
  const shouldReduceMotion = useReducedMotion();
  const maxWidth = explicitMaxWidth ?? (size === 'lg' ? '48rem' : '28rem');

  useEffect(() => {
    if (!isOpen) return undefined;

    const scrollState = {
      bodyOverflow: document.body.style.overflow,
      bodyPaddingRight: document.body.style.paddingRight,
      htmlOverflow: document.documentElement.style.overflow,
      htmlPaddingRight: document.documentElement.style.paddingRight,
    };

    document.body.style.overflow = 'hidden';
    document.body.style.paddingRight = '';
    document.body.classList.add('modal-open');
    document.documentElement.style.overflow = 'hidden';
    document.documentElement.style.paddingRight = '';

    const handleKeyDown = (event) => {
      if (event.key === 'Escape') onClose();
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      document.body.style.overflow = scrollState.bodyOverflow;
      document.body.style.paddingRight = scrollState.bodyPaddingRight;
      document.documentElement.style.overflow = scrollState.htmlOverflow;
      document.documentElement.style.paddingRight = scrollState.htmlPaddingRight;
      document.body.classList.remove('modal-open');
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, onClose]);

  return (
    <AnimatePresence>
      {isOpen ? (
        <div className="fixed inset-0 z-[99999] flex items-center justify-center p-4 sm:p-6">
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
            role="dialog"
            aria-modal="true"
            aria-labelledby={labelledBy}
            className={`app-modal-shell relative flex flex-col overflow-hidden rounded-2xl border shadow-2xl ${panelClassName}`}
            style={{
              boxSizing: 'border-box',
              maxWidth,
              width: 'min(100%, calc(100vw - 2rem))',
            }}
            initial={shouldReduceMotion ? false : { opacity: 0, scale: 0.96, y: 16 }}
            animate={shouldReduceMotion ? { opacity: 1 } : { opacity: 1, scale: 1, y: 0 }}
            exit={shouldReduceMotion ? { opacity: 0 } : { opacity: 0, scale: 0.96, y: 16 }}
            transition={{ duration: shouldReduceMotion ? 0 : 0.28, ease: 'easeOut' }}
          >
            {title ? (
              <header className={`sticky top-0 z-10 flex items-center gap-3 rounded-t-2xl border-b border-neutral-100 ${headerClassName}`}>
                  {Icon ? (
                    <span className="grid h-9 w-9 flex-none place-items-center rounded-full bg-orange-50 text-primary">
                      <Icon size={17} />
                    </span>
                  ) : null}
                  <h2 id={labelledBy} className="min-w-0 truncate text-lg font-extrabold sm:text-xl">
                    {title}
                  </h2>
              </header>
            ) : null}

            <div className={`app-modal-scroll overflow-y-auto ${contentClassName}`}>
              {children}
            </div>
          </motion.article>
        </div>
      ) : null}
    </AnimatePresence>
  );
}
