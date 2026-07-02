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

const glassInput = {
  background: 'linear-gradient(135deg, rgba(255,255,255,.9), rgba(255,255,255,.6))',
  backdropFilter: 'blur(24px) saturate(1.2)',
  WebkitBackdropFilter: 'blur(24px) saturate(1.2)',
  border: '1.5px solid rgba(255,255,255,.6)',
  boxShadow: 'inset 0 2px 6px rgba(31,25,18,.04), 0 4px 16px rgba(31,25,18,.03)',
};

const glassCard = {
  background: 'linear-gradient(135deg, rgba(255,255,255,.72), rgba(255,255,255,.36))',
  backdropFilter: 'blur(22px) saturate(1.32)',
  WebkitBackdropFilter: 'blur(22px) saturate(1.32)',
  border: '1px solid rgba(255,255,255,.42)',
  boxShadow: '0 14px 45px rgba(31,25,18,.08), inset 0 1px 0 rgba(255,255,255,.58)',
};

function StatusCard({ mode }) {
  const isSuccess = mode === 'success';
  const isDeviceBlocked = mode === 'device_blocked';

  return (
    <motion.div
      initial={{ opacity: 0, y: 18, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      className="relative mx-auto max-w-[520px] overflow-hidden rounded-[2rem] p-10 text-center"
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
      <h2 className="text-2xl font-extrabold tracking-tight text-gray-900 sm:text-3xl">
        {isSuccess ? "🎉 You're on the JourneySync Beta." : isDeviceBlocked ? "Device already registered." : "You're already on the list."}
      </h2>
      <div className="mx-auto mt-4 max-w-sm space-y-2 text-base leading-relaxed text-gray-600">
        {isSuccess ? (
          <>
            <p className="font-medium text-gray-800">We'll notify you as soon as beta access becomes available.</p>
            <p className="text-sm mt-3 text-gray-500">Thanks for helping us build JourneySync.</p>
          </>
        ) : isDeviceBlocked ? (
          <>
            <p>This device has already joined the JourneySync Beta.</p>
            <p className="text-sm mt-3">If you need to update your email, please contact us.</p>
          </>
        ) : (
          <>
            <p>You're already on the JourneySync Beta waitlist.</p>
            <p className="text-sm mt-3">We'll email you when your invitation is ready.</p>
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
      setError('Enter your email address');
      return;
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmedEmail)) {
      setError('Enter a valid email address');
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Beta registration is not configured yet.');
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
        setError('Something went wrong. Please try again.');
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
    <main className="relative min-h-screen overflow-hidden text-gray-900 flex flex-col justify-center items-center" style={{
      background: 'radial-gradient(circle at 12% 8%, rgba(219,119,6,.12), transparent 30rem), radial-gradient(circle at 86% 16%, rgba(21,128,61,.08), transparent 28rem), linear-gradient(135deg, #fbf7f1 0%, #f4efea 42%, #fffaf3 100%)',
    }}>
      <BetaSeo />

      {/* Map texture overlay */}
      <div className="absolute inset-0 map-texture opacity-30 mix-blend-overlay" aria-hidden="true" />

      {/* Animated mesh blobs */}
      <motion.div
        className="absolute -top-28 right-[-10rem] h-[340px] w-[340px] rounded-full opacity-40 pointer-events-none"
        style={{ background: 'rgba(219,119,6,.20)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, 28, 0], x: [0, -20, 0] }}
        transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute bottom-[-10rem] left-[-8rem] h-[380px] w-[380px] rounded-full opacity-30 pointer-events-none"
        style={{ background: 'rgba(21,128,61,.15)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, -28, 0], x: [0, 20, 0] }}
        transition={{ duration: 14, repeat: Infinity, ease: 'easeInOut' }}
      />

      <section className="relative z-10 w-full max-w-[560px] px-6 py-12 flex flex-col items-center">
        
        <motion.a
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          href="/"
          className="mb-10 block"
        >
          <img src="/logo.png" alt="JourneySync" className="h-12 w-12 rounded-xl object-cover shadow-sm mx-auto transition-transform hover:scale-105" />
        </motion.a>

        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
          className="w-full text-center"
        >
          {status === 'success' || status === 'duplicate' || status === 'device_blocked' ? (
            <StatusCard mode={status} />
          ) : (
            <div className="w-full">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-3 py-1 text-[11px] font-extrabold uppercase tracking-[0.18em] text-primary mb-5">
                Beta Access
              </span>

              <h1 className="text-[2.25rem] font-extrabold leading-[1.1] tracking-tight text-gray-900 sm:text-4xl mb-4">
                Join the JourneySync <span className="text-primary">Beta</span>
              </h1>

              <p className="mx-auto max-w-[400px] text-[15px] leading-relaxed text-gray-500 mb-8">
                Become one of the first riders helping shape the future of group motorcycle riding.
              </p>

              <form onSubmit={handleSubmit} noValidate className="w-full max-w-[520px] mx-auto flex flex-col items-center">
                <div className="relative w-full mb-4">
                  <input
                    type="email"
                    placeholder="Enter your email address"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      setError('');
                    }}
                    className="w-full rounded-2xl px-6 py-[18px] text-[16px] font-medium text-gray-900 outline-none transition-all duration-300 placeholder:text-gray-400"
                    style={{
                      ...glassInput,
                      border: error ? '1.5px solid rgba(239,68,68,.5)' : glassInput.border,
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
                  <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="text-[13px] font-semibold text-red-500 mb-4 self-start pl-2">
                    {error}
                  </motion.p>
                )}

                <motion.button
                  type="submit"
                  disabled={submitting}
                  whileHover={submitting ? {} : { scale: 1.02, y: -2 }}
                  whileTap={submitting ? {} : { scale: 0.98 }}
                  className="flex w-full h-[54px] items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-[#e67e22] to-[#d35400] text-[16px] font-bold text-white shadow-lg shadow-primary/25 transition-all duration-300 hover:shadow-xl hover:shadow-primary/30 disabled:cursor-not-allowed disabled:opacity-80"
                >
                  {submitting ? (
                    <>
                      <span className="material-icons-round animate-spin text-[20px]">autorenew</span>
                      Joining...
                    </>
                  ) : (
                    <>
                      Join Beta <span className="material-icons-round text-[20px]">arrow_forward</span>
                    </>
                  )}
                </motion.button>
              </form>

              {/* Trust Row */}
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.6, delay: 0.3 }}
                className="mt-6 flex flex-row flex-wrap items-center justify-center gap-x-4 gap-y-2 text-[13px] font-semibold text-gray-500 max-w-[520px] mx-auto"
              >
                <div className="flex items-center gap-1.5">
                  <span className="material-icons-round text-primary text-[14px]">check</span>
                  Free during beta
                </div>
                <span className="text-gray-300">•</span>
                <div className="flex items-center gap-1.5">
                  <span className="material-icons-round text-primary text-[14px]">check</span>
                  Android Available
                </div>
                <span className="text-gray-300">•</span>
                <div className="flex items-center gap-1.5">
                  <span className="material-icons-round text-primary text-[14px]">check</span>
                  No Spam
                </div>
              </motion.div>
            </div>
          )}
        </motion.div>
      </section>
    </main>
  );
}
