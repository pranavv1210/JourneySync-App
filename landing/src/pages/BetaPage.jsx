import { useEffect, useMemo, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { isSupabaseConfigured, supabase } from '../lib/supabase';
import { trackBetaEvent } from '../utils/tracking';

const initialForm = {
  name: '',
  email: '',
  city: '',
  vehicle: '',
  platform: 'Android',
};

const fieldClasses = 'w-full rounded-2xl border border-white/60 bg-white/75 px-4 py-3.5 text-base font-semibold text-gray-900 shadow-inner shadow-white/30 outline-none backdrop-blur-md transition focus:border-primary focus:ring-4 focus:ring-primary/15';
const labelClasses = 'text-sm font-extrabold text-gray-900';

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

function validateForm(values) {
  const errors = {};
  if (!values.name) errors.name = 'Enter your full name.';
  if (!values.email) {
    errors.email = 'Enter your email address.';
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.email)) {
    errors.email = 'Enter a valid email address.';
  }
  if (!values.city) errors.city = 'Enter your city.';
  if (!values.vehicle) errors.vehicle = 'Enter your motorcycle or vehicle.';
  return errors;
}

function StatusCard({ mode, email }) {
  const isSuccess = mode === 'success';

  return (
    <motion.div
      initial={{ opacity: 0, y: 18, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      className="relative overflow-hidden rounded-[2rem] border border-white/70 bg-white/75 p-6 text-center shadow-2xl shadow-primary/10 backdrop-blur-2xl sm:p-8"
      role="status"
      aria-live="polite"
    >
      {isSuccess && (
        <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
          {[0, 1, 2, 3, 4, 5].map((item) => (
            <motion.span
              key={item}
              className="absolute h-2 w-2 rounded-full bg-primary"
              style={{ left: `${18 + item * 12}%`, top: `${20 + (item % 2) * 20}%` }}
              initial={{ opacity: 0, y: 0, scale: 0.6 }}
              animate={{ opacity: [0, 1, 0], y: [-6, -34, -60], scale: [0.6, 1, 0.8] }}
              transition={{ duration: 1.6, delay: item * 0.08, repeat: 1 }}
            />
          ))}
        </div>
      )}
      <motion.div
        initial={{ scale: 0.8 }}
        animate={{ scale: 1 }}
        transition={{ type: 'spring', stiffness: 260, damping: 18 }}
        className={`mx-auto mb-5 grid h-16 w-16 place-items-center rounded-full ${isSuccess ? 'bg-green-500 text-white' : 'bg-primary/10 text-primary'} shadow-lg`}
      >
        <span className="material-icons-round text-4xl">{isSuccess ? 'check' : 'mark_email_read'}</span>
      </motion.div>
      <h1 className="text-3xl font-extrabold tracking-tight text-gray-900 sm:text-4xl">
        {isSuccess ? "🎉 You're on the JourneySync Beta!" : "You're already registered for the JourneySync Beta."}
      </h1>
      <div className="mx-auto mt-4 max-w-xl space-y-3 text-base leading-relaxed text-gray-600 sm:text-lg">
        {isSuccess ? (
          <>
            <p>Thanks for joining us.</p>
            <p>We'll review your application and send your invitation to:</p>
            <p className="font-extrabold text-gray-900">{email}</p>
            <p>See you on the road.</p>
          </>
        ) : (
          <p>We'll notify you as soon as beta access becomes available.</p>
        )}
      </div>
      <a
        href="/"
        className="premium-btn mt-8 inline-flex min-h-14 items-center justify-center gap-2 rounded-xl bg-primary-dark px-6 py-3.5 font-extrabold text-white shadow-xl shadow-primary/25 transition hover:-translate-y-0.5 hover:bg-[#8f4a03] focus-visible:outline focus-visible:outline-4 focus-visible:outline-primary/40"
      >
        <span className="material-icons-round">home</span>
        Return Home
      </a>
    </motion.div>
  );
}

export default function BetaPage() {
  const shouldReduceMotion = useReducedMotion();
  const [form, setForm] = useState(initialForm);
  const [errors, setErrors] = useState({});
  const [submitError, setSubmitError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [status, setStatus] = useState('idle');
  const [submittedEmail, setSubmittedEmail] = useState('');
  const startedRef = useRef(false);

  const trimmedForm = useMemo(() => ({
    name: form.name.trim(),
    email: form.email.trim().toLowerCase(),
    city: form.city.trim(),
    vehicle: form.vehicle.trim(),
    platform: form.platform,
  }), [form]);

  function markStarted() {
    if (startedRef.current) return;
    startedRef.current = true;
    trackBetaEvent('beta_form_started');
  }

  function updateField(field, value) {
    markStarted();
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: undefined }));
    setSubmitError('');
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const nextErrors = validateForm(trimmedForm);
    setErrors(nextErrors);
    setSubmitError('');
    if (Object.keys(nextErrors).length > 0) return;

    if (!isSupabaseConfigured || !supabase) {
      setSubmitError('Beta registration is not configured yet. Please add the Supabase URL and anon key in the production environment.');
      return;
    }

    setSubmitting(true);
    trackBetaEvent('beta_submit', { platform: trimmedForm.platform, city: trimmedForm.city });

    const { error } = await supabase.from('beta_applications').insert({
      name: trimmedForm.name,
      email: trimmedForm.email,
      city: trimmedForm.city,
      vehicle: trimmedForm.vehicle,
      platform: trimmedForm.platform,
    });

    setSubmitting(false);
    setSubmittedEmail(trimmedForm.email);

    if (error) {
      const isDuplicate = error.code === '23505' || error.status === 409 || error.message?.toLowerCase().includes('duplicate');
      if (isDuplicate) {
        setStatus('duplicate');
        trackBetaEvent('beta_duplicate');
        return;
      }
      setSubmitError('Something went wrong while joining the beta. Please try again.');
      return;
    }

    setStatus('success');
    trackBetaEvent('beta_success', { platform: trimmedForm.platform });
  }

  return (
    <main className="relative min-h-screen overflow-hidden bg-background-light text-gray-900">
      <BetaSeo />
      <div className="absolute inset-0 map-texture opacity-50" aria-hidden="true" />
      <motion.div
        className="absolute -top-24 right-[-8rem] h-80 w-80 rounded-full bg-primary/20 blur-3xl"
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, 22, 0], x: [0, -16, 0] }}
        transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute bottom-[-9rem] left-[-7rem] h-96 w-96 rounded-full bg-orange-200/50 blur-3xl"
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, -24, 0], x: [0, 18, 0] }}
        transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
      />

      <section className="relative z-10 flex min-h-screen items-center justify-center px-4 py-10 sm:px-6 lg:px-8">
        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 24, filter: 'blur(10px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.65, ease: [0.22, 1, 0.36, 1] }}
          className="w-full max-w-2xl"
        >
          <a href="/" className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/60 bg-white/60 px-4 py-2 text-sm font-extrabold text-gray-700 shadow-sm backdrop-blur-xl transition hover:text-primary">
            <img src="/logo.png" alt="JourneySync" className="h-7 w-7 rounded-lg object-cover" />
            JourneySync
          </a>

          {status === 'success' || status === 'duplicate' ? (
            <StatusCard mode={status} email={submittedEmail} />
          ) : (
            <div className="relative overflow-hidden rounded-[2rem] border border-white/70 bg-white/70 p-5 shadow-2xl shadow-primary/10 backdrop-blur-2xl sm:p-8">
              <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_85%_0%,rgba(219,119,6,0.14),transparent_34%),linear-gradient(135deg,rgba(255,255,255,0.55),transparent_38%)]" aria-hidden="true" />
              <div className="relative">
                <div className="mb-8 text-center">
                  <span className="text-sm font-extrabold uppercase tracking-[0.18em] text-primary">Closed Beta</span>
                  <h1 className="mt-3 text-4xl font-extrabold tracking-tight text-gray-900 sm:text-5xl">Join the JourneySync Beta</h1>
                  <p className="mx-auto mt-4 max-w-xl text-base leading-relaxed text-gray-600 sm:text-lg">
                    Help shape the future of group motorcycle riding. Become one of our first JourneySync Beta riders.
                  </p>
                </div>

                <form className="space-y-5" onSubmit={handleSubmit} noValidate>
                  <div className="grid gap-5 sm:grid-cols-2">
                    <div className="space-y-2">
                      <label className={labelClasses} htmlFor="beta-name">Full Name *</label>
                      <input id="beta-name" className={fieldClasses} value={form.name} onFocus={markStarted} onChange={(event) => updateField('name', event.target.value)} autoComplete="name" aria-invalid={Boolean(errors.name)} />
                      {errors.name && <p className="text-sm font-semibold text-red-600">{errors.name}</p>}
                    </div>
                    <div className="space-y-2">
                      <label className={labelClasses} htmlFor="beta-email">Email Address *</label>
                      <input id="beta-email" type="email" className={fieldClasses} value={form.email} onFocus={markStarted} onChange={(event) => updateField('email', event.target.value)} autoComplete="email" aria-invalid={Boolean(errors.email)} />
                      {errors.email && <p className="text-sm font-semibold text-red-600">{errors.email}</p>}
                    </div>
                  </div>

                  <div className="grid gap-5 sm:grid-cols-2">
                    <div className="space-y-2">
                      <label className={labelClasses} htmlFor="beta-city">City *</label>
                      <input id="beta-city" className={fieldClasses} value={form.city} onFocus={markStarted} onChange={(event) => updateField('city', event.target.value)} autoComplete="address-level2" aria-invalid={Boolean(errors.city)} />
                      {errors.city && <p className="text-sm font-semibold text-red-600">{errors.city}</p>}
                    </div>
                    <div className="space-y-2">
                      <label className={labelClasses} htmlFor="beta-vehicle">Vehicle *</label>
                      <input id="beta-vehicle" className={fieldClasses} value={form.vehicle} onFocus={markStarted} onChange={(event) => updateField('vehicle', event.target.value)} placeholder="GT650, Classic 350, Himalayan, Duke 390, Honda CB350, Interceptor 650" aria-invalid={Boolean(errors.vehicle)} />
                      {errors.vehicle && <p className="text-sm font-semibold text-red-600">{errors.vehicle}</p>}
                    </div>
                  </div>

                  <fieldset className="space-y-3">
                    <legend className={labelClasses}>Platform</legend>
                    <div className="grid rounded-2xl border border-white/70 bg-white/55 p-1.5 shadow-inner shadow-white/30 backdrop-blur-xl sm:grid-cols-2" role="radiogroup" aria-label="Choose platform">
                      {['Android', 'iPhone'].map((platform) => {
                        const selected = form.platform === platform;
                        return (
                          <button
                            key={platform}
                            type="button"
                            className={`min-h-12 rounded-xl px-4 py-3 text-sm font-extrabold transition ${selected ? 'bg-primary text-white shadow-lg shadow-primary/25' : 'text-gray-600 hover:bg-white/70 hover:text-gray-900'}`}
                            role="radio"
                            aria-checked={selected}
                            onClick={() => updateField('platform', platform)}
                          >
                            {platform}
                          </button>
                        );
                      })}
                    </div>
                  </fieldset>

                  {submitError && (
                    <div className="rounded-2xl border border-red-200 bg-red-50/80 px-4 py-3 text-sm font-semibold text-red-700" role="alert">
                      {submitError}
                    </div>
                  )}

                  <motion.button
                    type="submit"
                    disabled={submitting}
                    whileTap={{ scale: submitting ? 1 : 0.98 }}
                    className="premium-btn flex min-h-14 w-full items-center justify-center gap-2 rounded-xl bg-primary-dark px-6 py-3.5 text-base font-extrabold text-white shadow-xl shadow-primary/25 transition hover:-translate-y-0.5 hover:bg-[#8f4a03] disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <span className="material-icons-round">{submitting ? 'progress_activity' : 'groups'}</span>
                    {submitting ? 'Submitting...' : 'Join Beta'}
                  </motion.button>
                </form>
              </div>
            </div>
          )}
        </motion.div>
      </section>
    </main>
  );
}
