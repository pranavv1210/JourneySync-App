import { useEffect, useRef, useState } from 'react';
import confetti from 'canvas-confetti';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { isSupabaseConfigured, supabase } from '../lib/supabase';
import { trackBetaEvent } from '../utils/tracking';

const DEVICE_ID_KEY = 'journeysync_beta_device_id';
const REGISTERED_KEY = 'journeysync_beta_registered';

function setMetaTag(name, content) {
  let tag = document.querySelector(`meta[name="${name}"]`);
  if (!tag) {
    tag = document.createElement('meta');
    tag.setAttribute('name', name);
    document.head.appendChild(tag);
  }
  tag.setAttribute('content', content);
}

function setCanonical(href) {
  let link = document.querySelector('link[rel="canonical"]');
  if (!link) {
    link = document.createElement('link');
    link.setAttribute('rel', 'canonical');
    document.head.appendChild(link);
  }
  link.setAttribute('href', href);
}

function getDeviceId() {
  const existing = window.localStorage.getItem(DEVICE_ID_KEY);
  if (existing) return existing;

  const next = window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  window.localStorage.setItem(DEVICE_ID_KEY, next);
  return next;
}

function BetaSeo() {
  useEffect(() => {
    const canonical = 'https://journeysyncrideapp.in/beta';
    document.title = 'Join the JourneySync Beta';
    setMetaTag('description', 'Apply for the official JourneySync Beta and help shape the future of motorcycle group riding.');
    setCanonical(canonical);

    const existing = document.getElementById('beta-page-schema');
    if (existing) existing.remove();

    const script = document.createElement('script');
    script.id = 'beta-page-schema';
    script.type = 'application/ld+json';
    script.textContent = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Join the JourneySync Beta',
      description: 'Apply for the official JourneySync Beta and help shape the future of motorcycle group riding.',
      url: canonical,
      isPartOf: {
        '@type': 'WebSite',
        name: 'JourneySync',
        url: 'https://journeysyncrideapp.in/',
      },
      potentialAction: {
        '@type': 'RegisterAction',
        target: canonical,
        name: 'Apply for the JourneySync Beta',
      },
    });
    document.head.appendChild(script);
    trackBetaEvent('beta_page_view');

    return () => {
      script.remove();
    };
  }, []);

  return null;
}

function TrustRow() {
  return (
    <div className="flex flex-wrap items-center justify-center gap-x-3 gap-y-2 text-xs font-semibold text-gray-500">
      <span className="inline-flex items-center gap-1.5">
        <span className="material-icons-round text-[14px] text-primary">check</span>
        Free during beta
      </span>
      <span className="text-gray-300">•</span>
      <span className="inline-flex items-center gap-1.5">
        <span className="material-icons-round text-[14px] text-primary">check</span>
        Android available
      </span>
      <span className="text-gray-300">•</span>
      <span className="inline-flex items-center gap-1.5">
        <span className="material-icons-round text-[14px] text-primary">check</span>
        No spam
      </span>
    </div>
  );
}

function SuccessState({ duplicate = false, deviceBlocked = false }) {
  const title = duplicate || deviceBlocked ? "You're already on the list." : "You're on the JourneySync Beta!";
  const text = duplicate || deviceBlocked
    ? "We'll email you as soon as beta access becomes available."
    : "Thanks for joining. We'll email you as soon as beta access becomes available.";

  return (
    <motion.div
      key="success"
      initial={{ opacity: 0, y: 18, scale: 0.97, filter: 'blur(10px)' }}
      animate={{ opacity: 1, y: 0, scale: 1, filter: 'blur(0px)' }}
      exit={{ opacity: 0, y: -12, scale: 0.98, filter: 'blur(8px)' }}
      transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
      className="text-center"
      role="status"
      aria-live="polite"
    >
      <motion.div
        className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-green-500 text-white shadow-2xl shadow-green-500/20"
        initial={{ scale: 0.72 }}
        animate={{ scale: 1 }}
        transition={{ type: 'spring', stiffness: 260, damping: 18 }}
      >
        <span className="material-icons-round text-5xl">check</span>
      </motion.div>
      <h1 className="mt-8 text-3xl font-extrabold leading-tight tracking-tight text-gray-900 sm:text-4xl">{title}</h1>
      <p className="mx-auto mt-4 max-w-sm text-base leading-relaxed text-gray-600">{text}</p>
    </motion.div>
  );
}

export default function BetaPage() {
  const shouldReduceMotion = useReducedMotion();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState('idle');
  const [submitting, setSubmitting] = useState(false);
  const startedRef = useRef(false);

  useEffect(() => {
    getDeviceId();
  }, []);

  function markStarted() {
    if (startedRef.current) return;
    startedRef.current = true;
    trackBetaEvent('beta_form_started');
  }

  function fireSuccessConfetti() {
    if (shouldReduceMotion) return;

    confetti({
      particleCount: 48,
      spread: 58,
      startVelocity: 30,
      scalar: 0.72,
      origin: { y: 0.58 },
      colors: ['#db7706', '#f59e0b', '#22c55e', '#ffffff'],
    });
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) {
      setError('Enter your email address.');
      return;
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      setError('Enter a valid email address.');
      return;
    }

    if (window.localStorage.getItem(REGISTERED_KEY) === 'true') {
      setStatus('device');
      trackBetaEvent('beta_duplicate', { reason: 'device_local' });
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Beta registration is not configured yet.');
      return;
    }

    setSubmitting(true);
    setError('');
    trackBetaEvent('beta_submit');

    const { error: dbError } = await supabase.from('beta_applications').insert({
      email: normalizedEmail,
      device_id: getDeviceId(),
      status: 'pending',
    });

    setSubmitting(false);

    if (dbError) {
      const message = dbError.message?.toLowerCase() ?? '';
      const isDuplicate = dbError.code === '23505' || dbError.status === 409 || message.includes('duplicate');
      if (isDuplicate) {
        const reason = message.includes('device') ? 'device' : 'email';
        setStatus(reason === 'device' ? 'device' : 'duplicate');
        trackBetaEvent('beta_duplicate', { reason });
        return;
      }

      setError('Something went wrong. Please try again.');
      return;
    }

    window.localStorage.setItem(REGISTERED_KEY, 'true');
    setStatus('success');
    trackBetaEvent('beta_success');
    fireSuccessConfetti();

    window.setTimeout(() => {
      window.location.href = '/beta/download';
    }, 2500);
  }

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#fbf7f1] px-6 py-10 text-gray-900">
      <BetaSeo />

      <div className="absolute inset-0 map-texture opacity-35" aria-hidden="true" />
      <div className="absolute left-1/2 top-[-12rem] h-[28rem] w-[28rem] -translate-x-1/2 rounded-full bg-primary/12 blur-3xl" aria-hidden="true" />
      <motion.div
        className="absolute -right-28 top-28 h-72 w-72 rounded-full bg-orange-200/45 blur-3xl"
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, 18, 0], x: [0, -12, 0] }}
        transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute -bottom-32 -left-24 h-80 w-80 rounded-full bg-green-200/35 blur-3xl"
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, -18, 0], x: [0, 12, 0] }}
        transition={{ duration: 11, repeat: Infinity, ease: 'easeInOut' }}
      />

      <section className="beta-signup-wrapper relative z-10 flex flex-col items-center text-center">
        <motion.a
          href="/"
          aria-label="Return to JourneySync home"
          initial={shouldReduceMotion ? false : { opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="inline-flex h-12 items-center gap-3 rounded-full border border-white/70 bg-white/62 px-4 text-sm font-extrabold text-gray-800 shadow-lg shadow-gray-900/5 backdrop-blur-2xl transition hover:-translate-y-0.5 hover:text-primary"
        >
          <img src="/logo.png" alt="" className="h-7 w-7 rounded-lg object-cover" />
          JourneySync
        </motion.a>

        <AnimatePresence mode="wait">
          {status === 'success' || status === 'duplicate' || status === 'device' ? (
            <SuccessState duplicate={status === 'duplicate'} deviceBlocked={status === 'device'} />
          ) : (
            <motion.div
              key="form"
              initial={shouldReduceMotion ? false : { opacity: 0, y: 18, filter: 'blur(10px)' }}
              animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
              exit={{ opacity: 0, y: -12, filter: 'blur(8px)' }}
              transition={{ duration: 0.5, delay: 0.08, ease: [0.22, 1, 0.36, 1] }}
              className="mt-6 w-full"
            >
              <div className="inline-flex rounded-full border border-primary/15 bg-primary/10 px-3 py-1 text-[11px] font-extrabold uppercase tracking-[0.18em] text-primary backdrop-blur-xl">
                Beta Access
              </div>

              <h1 className="mt-5 text-4xl font-extrabold leading-[1.08] tracking-tight text-gray-900 sm:text-[2.75rem]">
                Join the JourneySync <span className="text-primary">Beta</span>
              </h1>

              <p className="mx-auto mt-4 max-w-[420px] text-[15px] leading-6 text-gray-600">
                Become one of the first riders helping shape the future of group motorcycle riding.
              </p>

              <form className="mt-9 w-full" onSubmit={handleSubmit} noValidate>
                <label className="sr-only" htmlFor="beta-email">Email address</label>
                <div className="relative">
                  <span className="material-icons-round pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[21px] text-gray-400">mail</span>
                  <input
                    id="beta-email"
                    type="email"
                    value={email}
                    onFocus={markStarted}
                    onChange={(event) => {
                      setEmail(event.target.value);
                      setError('');
                    }}
                    placeholder="Enter your email address"
                    autoComplete="email"
                    aria-invalid={Boolean(error)}
                    aria-describedby={error ? 'beta-email-error' : undefined}
                    className="h-14 w-full rounded-2xl border border-white/75 bg-white/72 pl-12 pr-4 text-[15px] font-semibold text-gray-900 shadow-[0_14px_35px_rgba(31,25,18,0.08),inset_0_1px_0_rgba(255,255,255,0.75)] outline-none backdrop-blur-2xl transition duration-200 placeholder:text-gray-400 focus:border-primary/70 focus:bg-white/86 focus:shadow-[0_0_0_4px_rgba(219,119,6,0.14),0_16px_38px_rgba(31,25,18,0.09)]"
                  />
                </div>

                {error && (
                  <motion.p
                    id="beta-email-error"
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="mt-2 text-left text-sm font-semibold text-red-600"
                  >
                    {error}
                  </motion.p>
                )}

                <motion.button
                  type="submit"
                  disabled={submitting}
                  whileHover={submitting || shouldReduceMotion ? undefined : { y: -2, scale: 1.01 }}
                  whileTap={submitting || shouldReduceMotion ? undefined : { scale: 0.985 }}
                  className="mt-[18px] flex h-14 w-full items-center justify-center gap-2 rounded-2xl bg-gradient-to-b from-[#ea8508] to-[#bd6100] text-[15px] font-extrabold text-white shadow-[0_18px_40px_rgba(189,97,0,0.28)] transition disabled:cursor-not-allowed disabled:opacity-75"
                >
                  {submitting ? (
                    <>
                      <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/45 border-t-white" aria-hidden="true" />
                      Joining...
                    </>
                  ) : (
                    <>
                      Join Beta
                      <span className="material-icons-round text-[19px]">arrow_forward</span>
                    </>
                  )}
                </motion.button>
              </form>

              <div className="mt-6">
                <TrustRow />
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </section>
    </main>
  );
}
