const analyticsConfig = {
  googleMeasurementId: 'G-NJSK647EK1',
  clarityProjectId: 'xfqpg5mipx',
};

export function trackEvent(name, payload = {}) {
  if (typeof window === 'undefined') return;

  const detail = {
    name,
    payload,
    timestamp: new Date().toISOString(),
  };

  window.dispatchEvent(new CustomEvent('journeysync:track', { detail }));

  if (typeof window.gtag === 'function') {
    window.gtag('event', name, payload);
  }

  if (typeof window.clarity === 'function') {
    window.clarity('event', name);
  }
}

export function trackBetaEvent(name, payload = {}) {
  trackEvent(name, {
    page: 'beta',
    ...payload,
  });
}

export { analyticsConfig };
