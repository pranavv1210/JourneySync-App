'use client';

import { useEffect } from 'react';
import { trackEvent } from '@/lib/tracking';

export function useLandingRuntime() {
  useEffect(() => {
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const progress = document.getElementById('scroll-progress');
    const header = document.querySelector<HTMLElement>('.site-header');
    const cursorGlow = document.getElementById('cursor-glow');

    const onScroll = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const ratio = max > 0 ? window.scrollY / max : 0;

      if (progress) {
        progress.style.width = `${(ratio * 100).toFixed(2)}%`;
      }

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

    const onPointerMove = (event: PointerEvent) => {
      if (!cursorGlow) return;
      cursorGlow.style.opacity = '0.85';
      cursorGlow.style.left = `${event.clientX}px`;
      cursorGlow.style.top = `${event.clientY}px`;
    };

    if (!prefersReduced && cursorGlow && window.matchMedia('(pointer: fine)').matches) {
      window.addEventListener('pointermove', onPointerMove, { passive: true });
    }

    const heroWrap = document.querySelector<HTMLElement>('.hero-visual');
    const phone = document.querySelector<HTMLElement>('.hero-phone');

    const onHeroMove = (event: PointerEvent) => {
      if (!heroWrap || !phone || prefersReduced) return;
      const rect = heroWrap.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width - 0.5;
      const y = (event.clientY - rect.top) / rect.height - 0.5;
      phone.style.transform = `rotateY(${x * 12}deg) rotateX(${-y * 8}deg) translate3d(${x * 6}px, ${y * 6}px, 0)`;
    };

    const onHeroLeave = () => {
      if (phone) phone.style.transform = '';
    };

    if (!prefersReduced && heroWrap && phone && window.matchMedia('(pointer: fine)').matches) {
      heroWrap.addEventListener('pointermove', onHeroMove);
      heroWrap.addEventListener('pointerleave', onHeroLeave);
    }

    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('scroll', updateActiveNav);
      window.removeEventListener('pointermove', onPointerMove);
      heroWrap?.removeEventListener('pointermove', onHeroMove);
      heroWrap?.removeEventListener('pointerleave', onHeroLeave);
    };
  }, []);
}
