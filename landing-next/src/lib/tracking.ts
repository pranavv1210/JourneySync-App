export const analyticsConfig = {
  googleMeasurementId: 'G-NJSK647EK1',
  clarityProjectId: 'xfqpg5mipx',
};

export function trackEvent(name: string, payload: Record<string, unknown> = {}) {
  if (typeof window === 'undefined') return;

  try {
    window.dispatchEvent(
      new CustomEvent('journeysync:track', {
        detail: {
          name,
          payload,
          timestamp: new Date().toISOString(),
        },
      }),
    );

    const analyticsWindow = window as typeof window & {
      gtag?: (...args: unknown[]) => void;
      clarity?: (...args: unknown[]) => void;
    };

    if (typeof analyticsWindow.gtag === 'function') {
      analyticsWindow.gtag('event', name, payload);
    }

    if (typeof analyticsWindow.clarity === 'function') {
      analyticsWindow.clarity('event', name);
    }
  } catch {
    // no-op by design
  }
}

export function trackBetaEvent(name: string, payload: Record<string, unknown> = {}) {
  trackEvent(name, {
    page: 'beta',
    ...payload,
  });
}
