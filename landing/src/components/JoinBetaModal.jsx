import { useEffect, useState, useRef } from 'react';
import confetti from 'canvas-confetti';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { Mail, ArrowRight, Check, X, Shield, Smartphone } from 'lucide-react';
import { isSupabaseConfigured, supabase } from '../lib/supabase';
import { trackBetaEvent } from '../utils/tracking';

const DEVICE_ID_KEY = 'journeysync_beta_device_id';
const REGISTERED_KEY = 'journeysync_beta_registered';

function getDeviceId() {
  const existing = window.localStorage.getItem(DEVICE_ID_KEY);
  if (existing) return existing;

  const next = window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  window.localStorage.setItem(DEVICE_ID_KEY, next);
  return next;
}

export function JoinBetaModal({ isOpen, onClose }) {
  const shouldReduceMotion = useReducedMotion();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState('idle'); // 'idle' | 'submitting' | 'success' | 'duplicate_email' | 'duplicate_device'
  const startedRef = useRef(false);
  const modalRef = useRef(null);

  // Track modal open/close
  useEffect(() => {
    if (isOpen) {
      trackBetaEvent('beta_modal_open');
      setStatus('idle');
      setEmail('');
      setError('');
      startedRef.current = false;
      
      // Prevent body scrolling
      const originalStyle = window.getComputedStyle(document.body).overflow;
      document.body.style.overflow = 'hidden';
      
      // Focus trapping
      const handleKeyDown = (e) => {
        if (e.key === 'Escape') {
          onClose();
        }
      };
      window.addEventListener('keydown', handleKeyDown);
      return () => {
        document.body.style.overflow = originalStyle;
        window.removeEventListener('keydown', handleKeyDown);
      };
    } else {
      if (startedRef.current) {
        trackBetaEvent('beta_modal_close');
      }
    }
  }, [isOpen, onClose]);

  const markStarted = () => {
    if (startedRef.current) return;
    startedRef.current = true;
  };

  const fireSuccessConfetti = () => {
    if (shouldReduceMotion) return;
    confetti({
      particleCount: 50,
      spread: 50,
      startVelocity: 25,
      scalar: 0.75,
      origin: { y: 0.5 },
      colors: ['#ea580c', '#f97316', '#ffedd5'],
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const normalizedEmail = email.trim().toLowerCase();

    if (!normalizedEmail) {
      setError('Enter your email address');
      return;
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      setError('Enter a valid email address');
      return;
    }

    // Device check
    if (window.localStorage.getItem(REGISTERED_KEY) === 'true') {
      setStatus('duplicate_device');
      trackBetaEvent('beta_duplicate_device');
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Supabase is not configured.');
      return;
    }

    setStatus('submitting');
    setError('');
    trackBetaEvent('beta_submit');

    const deviceId = getDeviceId();

    const { error: dbError } = await supabase.from('beta_applications').insert({
      email: normalizedEmail,
      device_id: deviceId,
      status: 'pending',
    });

    if (dbError) {
      const message = dbError.message?.toLowerCase() ?? '';
      const isDuplicate = dbError.code === '23505' || dbError.status === 409 || message.includes('duplicate');
      
      if (isDuplicate) {
        const isDeviceDuplicate = message.includes('device_id') || dbError.details?.includes('device_id');
        if (isDeviceDuplicate) {
          setStatus('duplicate_device');
          trackBetaEvent('beta_duplicate_device');
        } else {
          setStatus('duplicate_email');
          trackBetaEvent('beta_duplicate_email');
        }
        return;
      }

      setError('Something went wrong. Please try again.');
      setStatus('idle');
      return;
    }

    // Success
    window.localStorage.setItem(REGISTERED_KEY, 'true');
    setStatus('success');
    trackBetaEvent('beta_success');
    fireSuccessConfetti();

    setTimeout(() => {
      onClose();
    }, 2800);
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-[99999] flex items-center justify-center p-4">
          {/* Dark translucent overlay + backdrop blur */}
          <motion.div
            className="absolute inset-0 bg-black/50 backdrop-blur-md"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3, ease: 'easeOut' }}
            onClick={onClose}
          />

          {/* Premium Modal Wrapper */}
          <motion.div
            ref={modalRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby="modal-title"
            className="relative w-full overflow-hidden rounded-[28px] border border-white/20 bg-white/95 p-6 sm:p-8 shadow-2xl backdrop-blur-2xl flex flex-col items-center justify-center"
            style={{
              maxWidth: '420px',
              width: '100%',
              boxSizing: 'border-box',
              display: 'flex',
              flexDirection: 'column',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.15), inset 0 1px 0 rgba(255, 255, 255, 0.6), 0 0 40px rgba(249, 115, 22, 0.04)',
            }}
            initial={{ opacity: 0, scale: 0.92, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.92, y: 16 }}
            transition={{ duration: 0.3, ease: 'easeOut' }}
          >
            {/* Ambient orange reflection */}
            <div className="pointer-events-none absolute -top-24 left-1/2 h-40 w-40 -translate-x-1/2 rounded-full bg-orange-500/10 blur-3xl" />

            {/* Close Button */}
            <button
              onClick={onClose}
              className="absolute right-4 top-4 p-1.5 rounded-full text-neutral-400 hover:text-neutral-600 hover:bg-neutral-100 transition-colors z-50 cursor-pointer"
              style={{ background: 'transparent', border: 'none' }}
              aria-label="Close modal"
            >
              <X size={16} />
            </button>

            {/* Content Container */}
            <div className="w-full relative z-10 flex flex-col items-center text-center" style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <AnimatePresence mode="wait">
                {status === 'success' || status === 'duplicate_email' || status === 'duplicate_device' ? (
                  <motion.div
                    key="status-state"
                    initial={{ opacity: 0, scale: 0.96 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.2 }}
                    className="flex flex-col items-center py-4"
                  >
                    {/* Glass success checkmark */}
                    <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-orange-50 border border-orange-100 text-orange-600 shadow-inner">
                      <Check size={24} className="animate-bounce" />
                    </div>

                    {status === 'success' && (
                      <>
                        <h3 className="mb-2 text-lg font-bold tracking-tight text-neutral-900 px-4">
                          🎉 You're officially on the JourneySync Beta!
                        </h3>
                        <p className="text-neutral-500 text-xs max-w-[280px]">
                          We'll notify you when beta access becomes available.
                        </p>
                      </>
                    )}

                    {status === 'duplicate_email' && (
                      <>
                        <h3 className="mb-2 text-lg font-bold tracking-tight text-neutral-900">
                          Already Waitlisted
                        </h3>
                        <p className="text-neutral-500 text-xs max-w-[280px]">
                          You're already on the JourneySync Beta waitlist.
                        </p>
                      </>
                    )}

                    {status === 'duplicate_device' && (
                      <>
                        <h3 className="mb-2 text-lg font-bold tracking-tight text-neutral-900">
                          Device Limit Reached
                        </h3>
                        <p className="text-neutral-500 text-xs max-w-[280px]">
                          This device has already joined the JourneySync Beta.
                        </p>
                      </>
                    )}
                  </motion.div>
                ) : (
                  <motion.div
                    key="form-state"
                    className="w-full flex flex-col items-center"
                    style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}
                    exit={{ opacity: 0 }}
                  >
                    {/* Header: Logo + Beta Access Pill */}
                    <div className="mb-4 flex items-center justify-center gap-2" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                      <div className="flex items-center gap-1 px-2.5 py-0.5 rounded-full border border-neutral-200/50 bg-white/90 shadow-sm" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <img
                          src="/logo.png"
                          alt="JourneySync"
                          className="h-4 w-4 rounded-md object-cover flex-shrink-0"
                          style={{ width: '16px', height: '16px', minWidth: '16px', maxWidth: '16px', minHeight: '16px', maxHeight: '16px' }}
                        />
                        <span className="text-[10px] font-bold text-neutral-600" style={{ fontSize: '10px', fontWeight: 'bold' }}>JourneySync</span>
                      </div>
                      <span className="rounded-full bg-orange-50 border border-orange-100 px-2 py-0.5 text-[9px] font-extrabold uppercase tracking-wider text-orange-700" style={{ fontSize: '9px', fontWeight: '800' }}>
                        Beta Access
                      </span>
                    </div>

                    {/* Header Copy */}
                    <h2 id="modal-title" className="text-lg font-bold tracking-tight text-neutral-900 mb-1.5" style={{ fontSize: '18px', fontWeight: 'bold', letterSpacing: '-0.02em', margin: '0 0 6px 0' }}>
                      Join the JourneySync Beta
                    </h2>
                    <p className="text-neutral-500 text-xs leading-normal mb-5 max-w-xs" style={{ fontSize: '12px', color: '#6b7280', margin: '0 0 20px 0' }}>
                      Be among the first riders helping shape the future of motorcycle group riding.
                    </p>

                    {/* Email Form */}
                    <form onSubmit={handleSubmit} className="w-full space-y-3" style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      <div className="relative w-full" style={{ position: 'relative', width: '100%' }}>
                        <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-neutral-400" style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', display: 'flex', alignItems: 'center' }}>
                          <Mail size={16} />
                        </span>
                        <input
                          type="email"
                          value={email}
                          onFocus={markStarted}
                          onChange={(e) => {
                            setEmail(e.target.value);
                            setError('');
                          }}
                          placeholder="Enter your email address"
                          className="w-full rounded-xl border border-neutral-200 bg-white/60 text-neutral-950 placeholder-neutral-400 focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500 transition-all text-xs"
                          style={{
                            boxSizing: 'border-box',
                            width: '100%',
                            height: '44px',
                            paddingLeft: '40px',
                            paddingRight: '12px',
                            fontSize: '12px',
                            borderRadius: '12px',
                          }}
                        />
                      </div>

                      {error && (
                        <p className="text-left text-[11px] font-semibold text-red-500 pl-1" style={{ color: '#ef4444', fontSize: '11px', textAlign: 'left', margin: '4px 0 0 4px', fontWeight: '600' }}>
                          {error}
                        </p>
                      )}

                      {/* Primary CTA */}
                      <button
                        type="submit"
                        disabled={status === 'submitting'}
                        className="relative overflow-hidden w-full rounded-xl bg-gradient-to-r from-orange-600 to-orange-500 text-white font-semibold text-xs shadow-md shadow-orange-500/10 hover:shadow-lg hover:shadow-orange-500/25 transition-all flex items-center justify-center gap-1.5 group cursor-pointer"
                        style={{
                          width: '100%',
                          height: '44px',
                          border: 'none',
                          outline: 'none',
                          borderRadius: '12px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '6px',
                          cursor: 'pointer',
                        }}
                      >
                        {status === 'submitting' ? (
                          <>
                            <span className="h-3 w-3 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                            <span>Joining...</span>
                          </>
                        ) : (
                          <>
                            <span style={{ color: '#ffffff', fontWeight: 'bold' }}>Join the Beta</span>
                            <ArrowRight size={14} className="transition-transform group-hover:translate-x-0.5" />
                          </>
                        )}
                      </button>
                    </form>

                    {/* Trust Chips */}
                    <div className="mt-6 flex flex-wrap justify-center gap-1.5" style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: '6px', marginTop: '24px' }}>
                      <div className="inline-flex items-center gap-1 whitespace-nowrap rounded-full border border-neutral-200/50 bg-white/60 px-2.5 py-0.5 shadow-sm" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '4px 10px', borderRadius: '9999px', border: '1px solid rgba(229,231,235,0.8)', background: 'rgba(255,255,255,0.7)', whiteSpace: 'nowrap' }}>
                        <Check size={10} className="text-orange-600" />
                        <span className="text-[9px] font-bold text-neutral-600" style={{ fontSize: '9px', fontWeight: '700', color: '#4b5563' }}>Free During Beta</span>
                      </div>
                      <div className="inline-flex items-center gap-1 whitespace-nowrap rounded-full border border-neutral-200/50 bg-white/60 px-2.5 py-0.5 shadow-sm" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '4px 10px', borderRadius: '9999px', border: '1px solid rgba(229,231,235,0.8)', background: 'rgba(255,255,255,0.7)', whiteSpace: 'nowrap' }}>
                        <Smartphone size={10} className="text-orange-600" />
                        <span className="text-[9px] font-bold text-neutral-600" style={{ fontSize: '9px', fontWeight: '700', color: '#4b5563' }}>Android Available</span>
                      </div>
                      <div className="inline-flex items-center gap-1 whitespace-nowrap rounded-full border border-neutral-200/50 bg-white/60 px-2.5 py-0.5 shadow-sm" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '4px 10px', borderRadius: '9999px', border: '1px solid rgba(229,231,235,0.8)', background: 'rgba(255,255,255,0.7)', whiteSpace: 'nowrap' }}>
                        <Shield size={10} className="text-orange-600" />
                        <span className="text-[9px] font-bold text-neutral-600" style={{ fontSize: '9px', fontWeight: '700', color: '#4b5563' }}>Privacy First</span>
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}

