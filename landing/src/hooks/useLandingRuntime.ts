'use client';

import { useEffect } from 'react';
import { trackEvent } from '@/lib/tracking';

export function useLandingRuntime() {
  useEffect(() => {
    if ('scrollRestoration' in window.history) {
      window.history.scrollRestoration = 'manual';
    }

    if (!window.location.hash || window.location.hash === '#top') {
      window.setTimeout(() => window.scrollTo({ top: 0, left: 0, behavior: 'auto' }), 0);
    }

    const header = document.querySelector<HTMLElement>('.site-header');

    const onScroll = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const ratio = max > 0 ? window.scrollY / max : 0;

      header?.classList.toggle('is-scrolled', window.scrollY > 36);

      [25, 50, 75, 90].forEach((milestone) => {
        const key = `m${milestone}` as const;
        const store = (window as Window & { __jsScrollMilestones?: Record<string, boolean> }).__jsScrollMilestones ?? {};
        if (ratio * 100 >= milestone && !store[key]) {
          (window as Window & { __jsScrollMilestones?: Record<string, boolean> }).__jsScrollMilestones = {
            ...store,
            [key]: true,
          };
          trackEvent('scroll_milestone', { milestone });
        }
      });
    };

    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    const sections = Array.from(document.querySelectorAll<HTMLElement>('section[id]'));
    const navLinks = Array.from(document.querySelectorAll<HTMLAnchorElement>('.desktop-nav a[href^="#"]'));

    const updateActiveNav = () => {
      let active = '';
      for (const section of sections) {
        const rect = section.getBoundingClientRect();
        if (rect.top <= 120 && rect.bottom >= 120) {
          active = `#${section.id}`;
          break;
        }
      }
      navLinks.forEach((link) => {
        link.classList.toggle('active', link.getAttribute('href') === active);
      });
    };

    updateActiveNav();
    window.addEventListener('scroll', updateActiveNav, { passive: true });

    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('scroll', updateActiveNav);
    };
  }, []);
}
