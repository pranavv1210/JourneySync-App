'use client';

import { useEffect, useState } from 'react';
import { CtaButton } from '@/components/ui/CtaButton';

export function MobileStickyCta({ onJoinBeta }: { onJoinBeta: () => void }) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      const footer = document.querySelector('.site-footer');
      const footerTop = footer?.getBoundingClientRect().top ?? Number.POSITIVE_INFINITY;
      setVisible(window.scrollY > 420 && footerTop > window.innerHeight * 0.75);
    };

    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <div className={`mobile-sticky-cta ${visible ? 'visible' : ''}`} aria-hidden={!visible}>
      <CtaButton onClick={onJoinBeta} className="w-full">
        <span className="material-icons-round">groups</span>
        Join beta
      </CtaButton>
    </div>
  );
}
