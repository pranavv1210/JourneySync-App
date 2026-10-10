'use client';

import { useSyncExternalStore } from 'react';
import { CtaButton } from '@/components/ui/CtaButton';

const CONSENT_KEY = 'journeysync_cookie_consent';
const CONSENT_EVENT = 'journeysync-consent-change';

function subscribeToConsent(onStoreChange: () => void) {
  window.addEventListener('storage', onStoreChange);
  window.addEventListener(CONSENT_EVENT, onStoreChange);
  return () => {
    window.removeEventListener('storage', onStoreChange);
    window.removeEventListener(CONSENT_EVENT, onStoreChange);
  };
}

function getConsentSnapshot() {
  return !window.localStorage.getItem(CONSENT_KEY);
}

export function CookieBanner() {
  // The server snapshot is always hidden, so hydration matches. React then
  // reads localStorage through the external-store contract in the browser.
  const visible = useSyncExternalStore(subscribeToConsent, getConsentSnapshot, () => false);

  const accept = () => {
    window.localStorage.setItem(CONSENT_KEY, 'accepted');
    window.dispatchEvent(new Event(CONSENT_EVENT));
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
