import { useEffect, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { isSupabaseConfigured, supabase } from '../lib/supabase';
import { trackBetaEvent } from '../utils/tracking';

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

const glassCard = {
  background: 'linear-gradient(135deg, rgba(255,255,255,.72), rgba(255,255,255,.36))',
  backdropFilter: 'blur(22px) saturate(1.32)',
  WebkitBackdropFilter: 'blur(22px) saturate(1.32)',
  border: '1px solid rgba(255,255,255,.42)',
  boxShadow: '0 14px 45px rgba(31,25,18,.08), inset 0 1px 0 rgba(255,255,255,.58)',
};

const infoPill = {
  background: 'linear-gradient(135deg, rgba(255,255,255,.68), rgba(255,255,255,.32))',
  backdropFilter: 'blur(18px) saturate(1.2)',
  WebkitBackdropFilter: 'blur(18px) saturate(1.2)',
  border: '1px solid rgba(255,255,255,.5)',
  boxShadow: '0 8px 28px rgba(31,25,18,.05), inset 0 1px 0 rgba(255,255,255,.5)',
};

function StatusCard({ mode }) {
  const isSuccess = mode === 'success';
  const isDeviceBlocked = mode === 'device_blocked';

  return (
    <motion.div
      initial={{ opacity: 0, y: 18, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      className="relative overflow-hidden rounded-[2.5rem] p-10 text-center sm:p-12"
      style={glassCard}
      role="status"
      aria-live="polite"
    >
      <motion.div
        initial={{ scale: 0.8 }}
        animate={{ scale: 1 }}
        transition={{ type: 'spring', stiffness: 260, damping: 18 }}
        className={`mx-auto mb-6 grid h-20 w-20 place-items-center rounded-full ${isSuccess ? 'bg-green-500 text-white' : 'bg-primary/10 text-primary'} shadow-lg`}
      >
        <span className="material-icons-round text-5xl">{isSuccess ? 'check' : isDeviceBlocked ? 'devices' : 'mark_email_read'}</span>
      </motion.div>
      <h2 className="text-3xl font-extrabold tracking-tight text-gray-900 sm:text-4xl">
        {isSuccess ? "🎉 You're on the JourneySync Beta." : isDeviceBlocked ? "Device already registered." : "You're already on the list."}
      </h2>
      <div className="mx-auto mt-4 max-w-lg space-y-2 text-lg leading-relaxed text-gray-600">
        {isSuccess ? (
          <>
            <p className="font-semibold text-gray-800">Thanks for joining us.</p>
            <p className="text-sm">We'll notify you as soon as beta access becomes available.</p>
          </>
        ) : isDeviceBlocked ? (
          <>
            <p>This device has already joined the JourneySync Beta.</p>
            <p className="text-sm mt-4">If you need to update your email, please contact us.</p>
          </>
        ) : (
          <>
            <p>You're already on the JourneySync Beta waitlist.</p>
            <p className="text-sm mt-4">We'll email you when your invitation is ready.</p>
          </>
        )}
      </div>
    </motion.div>
  );
}

export default function BetaPage() {
  const shouldReduceMotion = useReducedMotion();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [status, setStatus] = useState('idle');

  useEffect(() => {
    // Generate persistent device id if it doesn't exist
    if (!localStorage.getItem('jsync_device_id')) {
      const newId = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2) + Date.now().toString(36);
      localStorage.setItem('jsync_device_id', newId);
    }
    
    // Check if this device is already registered
    if (localStorage.getItem('jsync_beta_registered') === 'true') {
      setStatus('device_blocked');
    }
  }, []);

  function triggerConfetti() {
    const duration = 2500;
    const end = Date.now() + duration;

    (function frame() {
      confetti({
        particleCount: 5,
        angle: 60,
        spread: 55,
        origin: { x: 0 },
        colors: ['#db7706', '#15803d', '#ffffff']
      });
      confetti({
        particleCount: 5,
        angle: 120,
        spread: 55,
        origin: { x: 1 },
        colors: ['#db7706', '#15803d', '#ffffff']
      });

      if (Date.now() < end) {
        requestAnimationFrame(frame);
      }
    }());
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const trimmedEmail = email.trim().toLowerCase();
    
    if (!trimmedEmail) {
      setError('Enter your email address.');
      return;
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      setError('Enter a valid email address.');
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Beta registration is not configured yet. (Missing Supabase credentials)');
      return;
    }

    const deviceId = localStorage.getItem('jsync_device_id');

    setSubmitting(true);
    setError('');
    trackBetaEvent('beta_submit');

    const { error: dbError } = await supabase.from('beta_applications').insert({
      email: trimmedEmail,
      device_id: deviceId
    });

    setSubmitting(false);

    if (dbError) {
      const isDuplicate = dbError.code === '23505' || dbError.status === 409 || dbError.message?.toLowerCase().includes('duplicate');
      if (isDuplicate) {
        setStatus('duplicate');
        trackBetaEvent('beta_duplicate');
      } else {
        setError('Something went wrong while joining the beta. Please try again.');
        return;
      }
    } else {
      localStorage.setItem('jsync_beta_registered', 'true');
      setStatus('success');
      trackBetaEvent('beta_success');
      triggerConfetti();
      
      // Auto redirect after 2.5s
      setTimeout(() => {
        window.location.href = '/beta/download';
      }, 2500);
    }
  }

  return (
    <main className="relative min-h-screen overflow-hidden text-gray-900" style={{
      background: 'radial-gradient(circle at 12% 8%, rgba(219,119,6,.16), transparent 30rem), radial-gradient(circle at 86% 16%, rgba(21,128,61,.11), transparent 28rem), linear-gradient(135deg, #fbf7f1 0%, #f4efea 42%, #fffaf3 100%)',
    }}>
      <BetaSeo />

      {/* Map texture overlay */}
      <div className="absolute inset-0 map-texture opacity-50" aria-hidden="true" />

      {/* Animated mesh blobs */}
      <motion.div
        className="absolute -top-28 right-[-10rem] h-[340px] w-[340px] rounded-full opacity-50 pointer-events-none"
        style={{ background: 'rgba(219,119,6,.30)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, 28, 0], x: [0, -20, 0] }}
        transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute bottom-[-10rem] left-[-8rem] h-[380px] w-[380px] rounded-full opacity-40 pointer-events-none"
        style={{ background: 'rgba(21,128,61,.22)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, -28, 0], x: [0, 20, 0] }}
        transition={{ duration: 14, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-[260px] w-[260px] rounded-full opacity-30 pointer-events-none"
        style={{ background: 'rgba(255,255,255,.85)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { scale: [1, 1.08, 1] }}
        transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
      />

      <section className="relative z-10 flex min-h-screen flex-col items-center justify-center px-4 py-12 sm:px-6 lg:px-8">
        
        {/* Logo Header */}
        <motion.a
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          href="/"
          className="mb-10 inline-flex items-center gap-2.5 rounded-full px-5 py-2.5 text-sm font-bold text-gray-700 transition-all duration-300 hover:text-primary hover:-translate-y-0.5"
          style={infoPill}
        >
          <img src="/logo.png" alt="JourneySync" className="h-8 w-8 rounded-lg object-cover shadow-sm" />
          JourneySync
        </motion.a>

        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 28, filter: 'blur(12px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          className="w-full max-w-[540px]"
        >
          {status === 'success' || status === 'duplicate' ? (
            <StatusCard mode={status} />
          ) : (
            <div className="relative overflow-hidden rounded-[2.5rem] p-8 sm:p-10 lg:p-12 text-center" style={glassCard}>
              {/* Decorative radial highlight */}
              <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_0%,rgba(219,119,6,0.1),transparent_40%),linear-gradient(135deg,rgba(255,255,255,0.4),transparent_50%)]" aria-hidden="true" />

              <div className="relative">
                <h1 className="text-3xl font-extrabold leading-[1.1] tracking-tight text-gray-900 sm:text-4xl lg:text-[2.75rem] mb-4">
                  Join the JourneySync <span className="text-primary">Beta</span>
                </h1>

                <p className="mx-auto max-w-sm text-base leading-relaxed text-gray-600 sm:text-lg mb-8">
                  Become one of the first riders helping shape the future of group motorcycle riding.
                </p>

                <form onSubmit={handleSubmit} noValidate className="space-y-4">
                  <div className="relative">
                    <input
                      type="email"
                      placeholder="Enter your email address"
                      value={email}
                      onChange={(e) => {
                        setEmail(e.target.value);
                        setError('');
                      }}
                      className="w-full rounded-2xl px-6 py-4 text-[17px] font-medium text-gray-900 outline-none transition-all duration-300 placeholder:text-gray-400"
                      style={{
                        background: 'linear-gradient(135deg, rgba(255,255,255,.9), rgba(255,255,255,.6))',
                        backdropFilter: 'blur(16px)',
                        border: `1.5px solid ${error ? 'rgba(239,68,68,.5)' : 'rgba(255,255,255,.6)'}`,
                        boxShadow: 'inset 0 2px 6px rgba(31,25,18,.04), 0 2px 8px rgba(31,25,18,.04)',
                      }}
                    />
                    <style dangerouslySetInnerHTML={{ __html: `
                      input[type="email"]:focus {
                        border-color: #db7706 !important;
                        box-shadow: 0 0 0 4px rgba(219,119,6,.15), inset 0 2px 6px rgba(31,25,18,.04) !important;
                      }
                    `}} />
                  </div>
                  
                  {error && (
                    <motion.p initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} className="text-sm font-semibold text-red-500 text-left px-2">
                      {error}
                    </motion.p>
                  )}

                  <motion.button
                    type="submit"
                    disabled={submitting}
                    whileHover={submitting ? {} : { scale: 1.02 }}
                    whileTap={submitting ? {} : { scale: 0.98 }}
                    className="premium-btn glow-pulse flex w-full items-center justify-center gap-2 rounded-2xl bg-primary-dark px-6 py-4 text-[17px] font-extrabold text-white shadow-xl shadow-primary/25 transition-all duration-300 hover:bg-[#8f4a03] hover:shadow-2xl hover:shadow-primary/30 disabled:cursor-not-allowed disabled:opacity-80 disabled:transform-none"
                  >
                    {submitting ? (
                      <span className="material-icons-round animate-spin">autorenew</span>
                    ) : (
                      <>
                        Join Beta <span className="material-icons-round text-lg">arrow_forward</span>
                      </>
                    )}
                  </motion.button>
                </form>

                {/* Features List */}
                <div className="mt-8 grid grid-cols-2 gap-3 text-left text-[13px] font-bold text-gray-600 sm:text-sm">
                  <div className="flex items-center gap-2">
                    <span className="material-icons-round text-primary text-base">verified</span>
                    Free during beta
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="material-icons-round text-primary text-base">shield</span>
                    No spam
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="material-icons-round text-green-600 text-base">android</span>
                    Android Available
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="material-icons-round text-gray-400 text-base">phone_iphone</span>
                    iOS Coming Soon
                  </div>
                </div>
              </div>
            </div>
          )}
        </motion.div>
      </section>
    </main>
  );
}
