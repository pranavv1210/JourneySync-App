'use client';

import { useEffect, useState } from 'react';
import { navItems } from '@/data/site-content';
import { CtaButton } from '@/components/ui/CtaButton';

export function Header({ onJoinBeta }: { onJoinBeta: () => void }) {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 28);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    document.body.classList.toggle('menu-open', menuOpen);
    if (!menuOpen) return;

    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setMenuOpen(false);
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => {
      document.body.classList.remove('menu-open');
      window.removeEventListener('keydown', closeOnEscape);
    };
  }, [menuOpen]);

  return (
    <>
      <header className={`site-header ${scrolled ? 'is-scrolled' : ''}`}>
        <div className="container header-inner">
          <a href="#top" className="brand" aria-label="JourneySync home">
            <img src="/logo.png" alt="JourneySync logo" width={40} height={40} />
            <span>JourneySync</span>
          </a>

          <nav className="desktop-nav" aria-label="Primary">
            {navItems.map((item) => (
              <a key={item.href} href={item.href}>
                {item.label}
              </a>
            ))}
          </nav>

          <div className="header-actions">
            <CtaButton onClick={onJoinBeta} className="header-cta">
              Join beta
            </CtaButton>
            <button
              type="button"
              className="menu-toggle"
              aria-expanded={menuOpen}
              aria-controls="mobile-menu"
              onClick={() => setMenuOpen((value) => !value)}
            >
              <span className="material-icons-round">{menuOpen ? 'close' : 'menu'}</span>
            </button>
          </div>
        </div>
      </header>

      <div
        id="mobile-menu"
        className={`mobile-nav-overlay ${menuOpen ? 'open' : ''}`}
        role="dialog"
        aria-modal="true"
        aria-label="Mobile navigation"
      >
        <div className="mobile-nav-panel">
          <nav className="mobile-nav-links">
            {navItems.map((item) => (
              <a key={item.href} href={item.href} onClick={() => setMenuOpen(false)}>
                {item.label}
              </a>
            ))}
          </nav>
          <CtaButton
            onClick={() => {
              setMenuOpen(false);
              onJoinBeta();
            }}
            className="w-full"
          >
            Join beta
          </CtaButton>
        </div>
        <button
          type="button"
          className="mobile-nav-backdrop"
          aria-label="Close mobile navigation"
          onClick={() => setMenuOpen(false)}
        />
      </div>
    </>
  );
}
