import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

const GUIDE_SEEN_KEY = 'journeysync_beta_guide_seen';
const REGISTERED_KEY = 'journeysync_beta_registered';

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function getTargetElement() {
  const isSmallViewport = window.innerWidth < 640;
  const selectors = isSmallViewport
    ? ['header a[href="/beta"]', '#hero-ctas a[href="/beta"]', 'a[href="/beta"]']
    : ['#hero-ctas a[href="/beta"]', 'header a[href="/beta"]', 'a[href="/beta"]'];

  for (const selector of selectors) {
    const element = document.querySelector(selector);
    if (element) return element;
  }

  return null;
}

function shouldResetGuideForDevelopment() {
  return import.meta.env.DEV && new URLSearchParams(window.location.search).has('resetBetaGuide');
}

function getPlacement(targetRect) {
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const margin = 16;
  const gap = viewportWidth < 640 ? 12 : 18;
  const isMobile = viewportWidth < 640;
  const calloutWidth = Math.min(isMobile ? 292 : 320, viewportWidth - margin * 2);
  const estimatedHeight = isMobile ? 158 : 176;

  if (isMobile) {
    const targetCenter = targetRect.left + targetRect.width / 2;
    const fitsBelow = targetRect.bottom + gap + estimatedHeight <= viewportHeight - margin;

    return {
      placement: fitsBelow ? 'mobile-bottom' : 'mobile-top',
      style: {
        left: clamp(targetCenter - calloutWidth / 2, margin, viewportWidth - calloutWidth - margin),
        top: fitsBelow
          ? targetRect.bottom + gap
          : clamp(targetRect.top - estimatedHeight - gap, margin, viewportHeight - estimatedHeight - margin),
        width: calloutWidth,
        maxWidth: 'calc(100vw - 32px)',
      },
    };
  }

  if (viewportWidth >= 768 && targetRect.right + gap + calloutWidth <= viewportWidth - margin) {
    return {
      placement: 'right',
      style: {
        left: targetRect.right + gap,
        top: clamp(targetRect.top + targetRect.height / 2 - estimatedHeight / 2, margin, viewportHeight - estimatedHeight - margin),
        width: calloutWidth,
      },
    };
  }

  const fitsBelow = targetRect.bottom + gap + estimatedHeight <= viewportHeight - margin;
  const top = fitsBelow
    ? targetRect.bottom + gap
    : clamp(targetRect.top - estimatedHeight - gap, margin, viewportHeight - estimatedHeight - margin);

  return {
    placement: fitsBelow ? 'bottom' : 'top',
    style: {
      left: clamp(targetRect.left + targetRect.width / 2 - calloutWidth / 2, margin, viewportWidth - calloutWidth - margin),
      top,
      width: calloutWidth,
    },
  };
}

export function JoinBetaGuide({ isBetaOpen, onJoin }) {
  const shouldReduceMotion = useReducedMotion();
  const [isVisible, setIsVisible] = useState(false);
  const [targetRect, setTargetRect] = useState(null);
  const [placement, setPlacement] = useState(null);
  const targetRef = useRef(null);
  const previousFocusRef = useRef(null);
  const closeButtonRef = useRef(null);
  const openedModalRef = useRef(false);

  const markSeen = useCallback(() => {
    try {
      window.localStorage.setItem(GUIDE_SEEN_KEY, 'true');
    } catch {
      // Ignore storage failures; the guide should still be dismissible.
    }
  }, []);

  const dismiss = useCallback(() => {
    markSeen();
    setIsVisible(false);
  }, [markSeen]);

  const join = useCallback(() => {
    openedModalRef.current = true;
    markSeen();
    setIsVisible(false);
    onJoin();
  }, [markSeen, onJoin]);

  const updateTarget = useCallback(() => {
    const target = getTargetElement();
    if (!target) return false;

    const rect = target.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return false;

    if (targetRef.current && targetRef.current !== target) {
      targetRef.current.classList.remove('beta-guide-target');
    }

    targetRef.current = target;
    if (isVisible) {
      target.classList.add('beta-guide-target');
    }
    setTargetRect(rect);
    setPlacement(getPlacement(rect));
    return true;
  }, [isVisible]);

  useEffect(() => {
    if (isBetaOpen) {
      setIsVisible(false);
      return undefined;
    }

    let shouldShow = false;
    try {
      if (shouldResetGuideForDevelopment()) {
        window.localStorage.removeItem(GUIDE_SEEN_KEY);
      }

      shouldShow =
        window.localStorage.getItem(GUIDE_SEEN_KEY) !== 'true' &&
        window.localStorage.getItem(REGISTERED_KEY) !== 'true';
    } catch {
      shouldShow = true;
    }

    if (!shouldShow || window.location.pathname.replace(/\/+$/, '') === '/beta/download') {
      return undefined;
    }

    const showTimer = window.setTimeout(() => {
      if (updateTarget()) setIsVisible(true);
    }, shouldReduceMotion ? 80 : 420);

    const retryTimer = window.setTimeout(() => {
      if (!targetRef.current && updateTarget()) setIsVisible(true);
    }, 1200);

    return () => {
      window.clearTimeout(showTimer);
      window.clearTimeout(retryTimer);
    };
  }, [isBetaOpen, shouldReduceMotion, updateTarget]);

  useEffect(() => {
    if (!isVisible) return undefined;

    previousFocusRef.current = document.activeElement;
    updateTarget();

    const target = targetRef.current;
    target?.classList.add('beta-guide-target');
    window.setTimeout(() => {
      closeButtonRef.current?.focus({ preventScroll: true });
    }, shouldReduceMotion ? 0 : 260);

    const scrollState = {
      bodyOverflow: document.body.style.overflow,
      htmlOverflow: document.documentElement.style.overflow,
    };

    document.body.style.overflow = 'hidden';
    document.documentElement.style.overflow = 'hidden';

    const onViewportChange = () => updateTarget();
    const onKeyDown = (event) => {
      if (event.key === 'Escape') dismiss();
    };
    const onClick = (event) => {
      const clickedTarget = event.target.closest?.('a[href="/beta"], button');
      if (!clickedTarget || clickedTarget.closest?.('[data-beta-guide-callout="true"]')) return;

      const text = clickedTarget.innerText?.trim() ?? '';
      const href = clickedTarget.getAttribute('href');
      if (href === '/beta' || text.includes('Join Beta') || text.includes('Join Closed Beta')) {
        event.preventDefault();
        event.stopPropagation();
        if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
        join();
      }
    };

    window.addEventListener('resize', onViewportChange, { passive: true });
    window.addEventListener('scroll', onViewportChange, { passive: true });
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('click', onClick, true);

    return () => {
      target?.classList.remove('beta-guide-target');
      document.body.style.overflow = scrollState.bodyOverflow;
      document.documentElement.style.overflow = scrollState.htmlOverflow;
      window.removeEventListener('resize', onViewportChange);
      window.removeEventListener('scroll', onViewportChange);
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('click', onClick, true);

      if (!openedModalRef.current && previousFocusRef.current instanceof HTMLElement) {
        previousFocusRef.current.focus?.({ preventScroll: true });
      }

      openedModalRef.current = false;
    };
  }, [dismiss, isVisible, join, shouldReduceMotion, updateTarget]);

  const spotlight = useMemo(() => {
    if (!targetRect) return null;

    const padding = window.innerWidth < 640 ? 8 : 12;
    const left = clamp(targetRect.left - padding, 8, window.innerWidth - 16);
    const top = clamp(targetRect.top - padding, 8, window.innerHeight - 16);
    const right = clamp(targetRect.right + padding, left + 1, window.innerWidth - 8);
    const bottom = clamp(targetRect.bottom + padding, top + 1, window.innerHeight - 8);

    return { left, top, right, bottom, width: right - left, height: bottom - top };
  }, [targetRect]);

  if (!spotlight || !placement) return null;

  const panelClassName = 'fixed bg-neutral-950/38 backdrop-blur-[1px]';
  const panelTransition = { duration: shouldReduceMotion ? 0 : 0.26, ease: 'easeOut' };
  const calloutTransition = { duration: shouldReduceMotion ? 0 : 0.32, delay: shouldReduceMotion ? 0 : 0.14, ease: 'easeOut' };

  return (
    <AnimatePresence>
      {isVisible ? (
        <div className="beta-guide fixed inset-0 z-[2147482500]" aria-label="Join Beta guide">
          <motion.button
            type="button"
            aria-label="Dismiss Join Beta guide"
            className={panelClassName}
            style={{ left: 0, top: 0, right: 0, height: spotlight.top }}
            onClick={dismiss}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={panelTransition}
          />
          <motion.button
            type="button"
            aria-label="Dismiss Join Beta guide"
            className={panelClassName}
            style={{ left: 0, top: spotlight.bottom, right: 0, bottom: 0 }}
            onClick={dismiss}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={panelTransition}
          />
          <motion.button
            type="button"
            aria-label="Dismiss Join Beta guide"
            className={panelClassName}
            style={{ left: 0, top: spotlight.top, width: spotlight.left, height: spotlight.height }}
            onClick={dismiss}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={panelTransition}
          />
          <motion.button
            type="button"
            aria-label="Dismiss Join Beta guide"
            className={panelClassName}
            style={{ left: spotlight.right, top: spotlight.top, right: 0, height: spotlight.height }}
            onClick={dismiss}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={panelTransition}
          />

          <motion.div
            aria-hidden="true"
            className="beta-guide-spotlight pointer-events-none fixed"
            style={{
              left: spotlight.left,
              top: spotlight.top,
              width: spotlight.width,
              height: spotlight.height,
            }}
            initial={shouldReduceMotion ? false : { opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.98 }}
            transition={calloutTransition}
          />

          <motion.aside
            role="dialog"
            aria-labelledby="beta-guide-title"
            aria-describedby="beta-guide-copy"
            data-beta-guide-callout="true"
            className={`beta-guide-callout fixed rounded-2xl border border-white/80 bg-white p-3.5 text-neutral-900 shadow-2xl sm:p-4 beta-guide-callout--${placement.placement}`}
            style={placement.style}
            initial={shouldReduceMotion ? false : { opacity: 0, y: placement.placement.includes('top') ? 8 : -8, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: placement.placement.includes('top') ? 8 : -8, scale: 0.98 }}
            transition={calloutTransition}
          >
            <button
              ref={closeButtonRef}
              type="button"
              aria-label="Close Join Beta guide"
              className="absolute right-2.5 top-2.5 grid h-7 w-7 place-items-center text-neutral-400 transition-colors hover:text-neutral-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
              onClick={dismiss}
            >
              <span className="material-icons-round text-[17px]" aria-hidden="true">close</span>
            </button>

            <p className="mb-1.5 text-[11px] font-extrabold uppercase tracking-[0.16em] text-primary">Start here</p>
            <h2 id="beta-guide-title" className="pr-8 text-base font-extrabold tracking-tight text-neutral-950 sm:text-lg">
              Join the beta
            </h2>
            <p id="beta-guide-copy" className="mt-1.5 text-sm font-medium leading-5 text-neutral-600 sm:leading-6">
              Get early access to JourneySync and the Android beta build.
            </p>

            <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-[1fr_auto]">
              <button
                type="button"
                className="inline-flex min-h-10 flex-1 items-center justify-center gap-2 rounded-xl bg-primary-dark px-4 py-2.5 text-sm font-extrabold text-white shadow-lg shadow-primary/20 transition-all hover:-translate-y-0.5 hover:bg-[#8f4a03] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                onClick={join}
              >
                Join Beta
                <span className="material-icons-round text-[18px]" aria-hidden="true">arrow_forward</span>
              </button>
              <button
                type="button"
                className="inline-flex min-h-10 items-center justify-center rounded-xl px-3 py-2 text-sm font-bold text-neutral-600 transition-colors hover:bg-neutral-100 hover:text-neutral-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                onClick={dismiss}
              >
                Explore first
              </button>
            </div>
          </motion.aside>
        </div>
      ) : null}
    </AnimatePresence>
  );
}
