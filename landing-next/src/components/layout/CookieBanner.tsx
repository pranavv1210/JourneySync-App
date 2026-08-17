'use client';

import { useState } from 'react';
import { CtaButton } from '@/components/ui/CtaButton';

const CONSENT_KEY = 'journeysync_cookie_consent';

export function CookieBanner() {
  const [visible, setVisible] = useState(
    () =>
      typeof window !== 'undefined' &&
      !window.localStorage.getItem(CONSENT_KEY),
  );

  const accept = () => {
    window.localStorage.setItem(CONSENT_KEY, 'accepted');
    setVisible(false);
  };

  if (!visible) return null;

  return (
    <div className="cookie-banner" role="dialog" aria-label="Cookie consent">
      <p>
        JourneySync uses analytics to understand how riders explore the beta site. Accept to
        help us improve the experience.
      </p>
      <div className="cookie-actions">
        <button type="button" className="cookie-decline" onClick={accept}>
          Dismiss
        </button>
        <CtaButton onClick={accept} className="cookie-accept">
          Accept
        </CtaButton>
      </div>
    </div>
  );
}
