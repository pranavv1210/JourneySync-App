import { useEffect, useState, useRef } from 'react';
import confetti from 'canvas-confetti';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { Mail, ArrowRight, Check, Shield, Smartphone } from 'lucide-react';
import { AppModal } from './AppModal';
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

function needsLegacyBetaPayload(error) {
  const message = error?.message?.toLowerCase() ?? '';
  const details = error?.details?.toLowerCase() ?? '';

  return (
    error?.code === '23502' &&
    (message.includes('name') ||
      message.includes('city') ||
      message.includes('vehicle') ||
      details.includes('name') ||
      details.includes('city') ||
      details.includes('vehicle'))
  );
}

function normalizePlatform(value) {
  return value === 'ios' ? 'ios' : 'android';
}

function AndroidLogo({ className = '' }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path
        fill="currentColor"
        d="M7.2 9.4h9.6c1 0 1.8.8 1.8 1.8v5.4c0 1-.8 1.8-1.8 1.8H7.2c-1 0-1.8-.8-1.8-1.8v-5.4c0-1 .8-1.8 1.8-1.8Zm2.1 2.5a.8.8 0 1 0 0 1.6.8.8 0 0 0 0-1.6Zm5.4 0a.8.8 0 1 0 0 1.6.8.8 0 0 0 0-1.6ZM7.6 7.8 5.8 5.9a.5.5 0 1 1 .7-.7l2 2.1A7.8 7.8 0 0 1 12 6.5c1.2 0 2.4.3 3.5.8l2-2.1a.5.5 0 0 1 .7.7l-1.8 1.9c1.1.8 1.8 1.7 2.1 2.9h-13c.3-1.2 1-2.1 2.1-2.9ZM3.8 11.3c.6 0 1 .4 1 1v4.3a1 1 0 0 1-2 0v-4.3c0-.6.4-1 1-1Zm16.4 0c.6 0 1 .4 1 1v4.3a1 1 0 0 1-2 0v-4.3c0-.6.4-1 1-1ZM8.3 19.1h1.8v1.7a.9.9 0 0 1-1.8 0v-1.7Zm5.6 0h1.8v1.7a.9.9 0 0 1-1.8 0v-1.7Z"
      />
    </svg>
  );
}

function AppleLogo({ className = '' }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path
        fill="currentColor"
        d="M16.7 12.5c0-2 1.7-3 1.8-3.1-1-1.4-2.4-1.6-2.9-1.6-1.2-.1-2.4.7-3 0-.7-.7-1.7-.7-2.7-.7-1.4 0-2.7.8-3.4 2.1-1.5 2.6-.4 6.4 1 8.5.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7c1.2 0 1.9-1.1 2.6-2.1.8-1.2 1.1-2.3 1.2-2.4 0 0-2.9-1.1-2.9-3.8Zm-2-6c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.6.7-1 1.6-.9 2.6.9.1 1.9-.5 2.5-1.2Z"
      />
    </svg>
  );
}

function isMissingPlatformColumn(error) {
  const message = error?.message?.toLowerCase() ?? '';
  const details = error?.details?.toLowerCase() ?? '';
  return (
    (error?.code === 'PGRST204' || error?.code === '42703') &&
    (message.includes('platform') || details.includes('platform'))
  );
}

async function insertBetaApplication(payload) {
  const response = await supabase.from('beta_applications').insert(payload);

  if (isMissingPlatformColumn(response.error)) {
    const legacyPayload = { ...payload };
    delete legacyPayload.platform;
    return supabase.from('beta_applications').insert(legacyPayload);
  }

  if (!needsLegacyBetaPayload(response.error)) return response;

  return supabase.from('beta_applications').insert({
    ...payload,
    name: 'Beta rider',
    city: 'Not provided',
    vehicle: 'Not provided',
    platform: normalizePlatform(payload.platform),
  });
}

async function sendWelcomeEmail(email, platform) {
  const { error } = await supabase.functions.invoke('send-beta-welcome-email', {
    body: { email, platform: normalizePlatform(platform) },
  });

  if (error) {
    console.warn('Beta welcome email failed:', error.message);
    trackBetaEvent('beta_welcome_email_failed');
    return;
  }

  trackBetaEvent('beta_welcome_email_sent');
}

export function JoinBetaModal({ isOpen, onClose }) {
  const shouldReduceMotion = useReducedMotion();
  const [email, setEmail] = useState('');
  const [platform, setPlatform] = useState('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState('idle'); // 'idle' | 'submitting' | 'success' | 'duplicate_email' | 'duplicate_device'
  const startedRef = useRef(false);

  // Track modal open/close
  useEffect(() => {
    if (isOpen) {
      trackBetaEvent('beta_modal_open');
      setStatus('idle');
      setEmail('');
      setPlatform('');
      setError('');
      startedRef.current = false;
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

    if (!platform) {
      setError('Choose Android or iOS');
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

    const { error: dbError } = await insertBetaApplication({
      email: normalizedEmail,
      device_id: deviceId,
      platform: normalizePlatform(platform),
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

      if (dbError.code === '42P01' || dbError.code === 'PGRST205') {
        setError('Beta signup table is missing in Supabase.');
      } else if (dbError.code === '42501') {
        setError('Beta signup is blocked by Supabase permissions.');
      } else {
        setError('Something went wrong. Please try again.');
      }
      setStatus('idle');
      return;
    }

    // Success
    window.localStorage.setItem(REGISTERED_KEY, 'true');
    setStatus('success');
    trackBetaEvent('beta_success');
    void sendWelcomeEmail(normalizedEmail, platform);
    fireSuccessConfetti();

    setTimeout(() => {
      onClose();
    }, 2800);
  };

  const normalizedEmail = email.trim().toLowerCase();
  const canSubmit = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail) && Boolean(platform);

  return (
    <AppModal
      isOpen={isOpen}
      onClose={onClose}
      labelledBy="modal-title"
      contentClassName="p-6 sm:p-8"
    >
            {/* Ambient orange reflection */}
            <div className="pointer-events-none absolute -top-24 left-1/2 h-40 w-40 -translate-x-1/2 rounded-full bg-orange-500/10 blur-3xl" />

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
                          Check your inbox for the beta download link.
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
                      Choose your device and join the rider test list.
                    </p>

                    {/* Email Form */}
                    <form onSubmit={handleSubmit} className="w-full" style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: '16px' }}>
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

                      <div className="grid grid-cols-2 gap-2" role="radiogroup" aria-label="Choose beta platform">
                        {[
                          { key: 'android', label: 'Android', note: 'APK ready', icon: AndroidLogo },
                          { key: 'ios', label: 'iOS', note: 'TestFlight', icon: AppleLogo },
                        ].map((option) => {
                          const Icon = option.icon;
                          const selected = platform === option.key;
                          return (
                            <button
                              key={option.key}
                              type="button"
                              role="radio"
                              aria-checked={selected}
                              onClick={() => {
                                markStarted();
                                setPlatform(option.key);
                                setError('');
                              }}
                              className={`relative rounded-xl border px-3 py-3 text-left transition-all ${
                                selected
                                  ? 'border-orange-600 bg-gradient-to-br from-orange-100 via-amber-50 to-white shadow-xl shadow-orange-500/25 ring-2 ring-orange-500/35'
                                  : 'border-neutral-200 bg-white/70 shadow-sm hover:border-orange-300 hover:bg-orange-50/50 hover:shadow-md'
                              }`}
                              style={
                                selected
                                  ? {
                                      background: 'linear-gradient(135deg, #ffedd5 0%, #fff7ed 55%, #ffffff 100%)',
                                      borderColor: '#ea580c',
                                      boxShadow: '0 14px 30px rgba(234, 88, 12, 0.22), 0 0 0 2px rgba(234, 88, 12, 0.18)',
                                    }
                                  : undefined
                              }
                            >
                              <span className="flex items-center gap-2 text-xs font-extrabold text-neutral-900">
                                <span
                                  className={`grid h-6 w-6 place-items-center rounded-lg ${
                                    selected ? 'bg-orange-600 text-white' : 'bg-neutral-100 text-neutral-500'
                                  }`}
                                >
                                  <Icon className="h-4 w-4" />
                                </span>
                                {option.label}
                              </span>
                              <span className={`mt-1.5 block text-[10px] font-bold ${selected ? 'text-orange-800' : 'text-neutral-400'}`}>
                                {option.note}
                              </span>
                            </button>
                          );
                        })}
                      </div>

                      {error && (
                        <p className="text-left text-[11px] font-semibold text-red-500 pl-1" style={{ color: '#ef4444', fontSize: '11px', textAlign: 'left', margin: '4px 0 0 4px', fontWeight: '600' }}>
                          {error}
                        </p>
                      )}

                      {/* Primary CTA */}
                      <button
                        type="submit"
                        disabled={status === 'submitting' || !canSubmit}
                        className="relative overflow-hidden w-full rounded-xl bg-primary-dark text-white font-semibold text-xs shadow-md shadow-primary/20 transition-all hover:bg-[#8f4a03] hover:shadow-lg hover:shadow-primary/25 active:bg-[#733a02] flex items-center justify-center gap-1.5 group cursor-pointer disabled:cursor-not-allowed disabled:bg-neutral-300 disabled:text-neutral-500 disabled:shadow-none"
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
                          cursor: status === 'submitting' || !canSubmit ? 'not-allowed' : 'pointer',
                          backgroundColor: !canSubmit ? '#fed7aa' : undefined,
                          color: !canSubmit ? '#9a3412' : undefined,
                          boxShadow: !canSubmit ? 'none' : undefined,
                        }}
                      >
                        {status === 'submitting' ? (
                          <>
                            <span className="h-3 w-3 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                            <span>Joining...</span>
                          </>
                        ) : (
                          <>
                            <span style={{ color: canSubmit ? '#ffffff' : '#6b7280', fontWeight: 'bold' }}>Join the Beta</span>
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
    </AppModal>
  );
}

