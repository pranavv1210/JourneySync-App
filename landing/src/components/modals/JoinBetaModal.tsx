'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { AppModal } from './AppModal';
import { isSupabaseConfigured, supabase } from '@/lib/supabase';
import { trackBetaEvent } from '@/lib/tracking';

const DEVICE_ID_KEY = 'journeysync_beta_device_id';
const REGISTERED_KEY = 'journeysync_beta_registered';

type Status = 'idle' | 'submitting' | 'success' | 'duplicate_email' | 'duplicate_device';

function getDeviceId() {
  if (typeof window === 'undefined') return '';
  const existing = window.localStorage.getItem(DEVICE_ID_KEY);
  if (existing) return existing;

  const next =
    window.crypto?.randomUUID?.() ??
    `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  window.localStorage.setItem(DEVICE_ID_KEY, next);
  return next;
}

function normalizePlatform(value: string) {
  return value === 'ios' ? 'ios' : 'android';
}

function isMissingPlatformColumn(error: unknown): boolean {
  const err = error as { code?: string; message?: string; details?: string } | null;
  const message = err?.message?.toLowerCase() ?? '';
  const details = err?.details?.toLowerCase() ?? '';
  return (
    (err?.code === 'PGRST204' || err?.code === '42703') &&
    (message.includes('platform') || details.includes('platform'))
  );
}

function needsLegacyPayload(error: unknown): boolean {
  const err = error as { code?: string; message?: string; details?: string } | null;
  const message = err?.message?.toLowerCase() ?? '';
  const details = err?.details?.toLowerCase() ?? '';
  return (
    err?.code === '23502' &&
    (message.includes('name') ||
      message.includes('city') ||
      message.includes('vehicle') ||
      details.includes('name') ||
      details.includes('city') ||
      details.includes('vehicle'))
  );
}

async function insertBetaApplication(payload: Record<string, string>) {
  if (!supabase) return { error: { message: 'Supabase not configured' } };

  const response = await supabase.from('beta_applications').insert(payload);

  if (isMissingPlatformColumn(response.error)) {
    const legacyPayload = { ...payload };
    delete legacyPayload.platform;
    return supabase.from('beta_applications').insert(legacyPayload);
  }

  if (!needsLegacyPayload(response.error)) return response;

  return supabase.from('beta_applications').insert({
    ...payload,
    name: 'Beta rider',
    city: 'Not provided',
    vehicle: 'Not provided',
    platform: normalizePlatform(payload.platform),
  });
}

async function sendWelcomeEmail(email: string, platform: string) {
  if (!supabase) return;

  try {
    const { error } = await supabase.functions.invoke('send-beta-welcome-email', {
      body: { email, platform: normalizePlatform(platform) },
    });

    if (error) {
      trackBetaEvent('beta_welcome_email_failed');
      return;
    }

    trackBetaEvent('beta_welcome_email_sent');
  } catch {
    trackBetaEvent('beta_welcome_email_failed');
  }
}

export function JoinBetaModal({
  isOpen,
  onClose,
}: {
  isOpen: boolean;
  onClose: () => void;
}) {
  const shouldReduceMotion = useReducedMotion();
  const [email, setEmail] = useState('');
  const [platform, setPlatform] = useState('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState<Status>('idle');
  const startedRef = useRef(false);

  useEffect(() => {
    if (!isOpen) return;

    const id = window.setTimeout(() => {
      setStatus('idle');
      setEmail('');
      setPlatform('');
      setError('');
      startedRef.current = false;
      trackBetaEvent('beta_modal_open');
    }, 0);
    return () => window.clearTimeout(id);
  }, [isOpen]);

  const normalizedEmail = useMemo(() => email.trim().toLowerCase(), [email]);
  const isEmailValid = useMemo(
    () => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail),
    [normalizedEmail],
  );
  const canSubmit = isEmailValid && Boolean(platform) && status !== 'submitting';

  const markStarted = () => {
    if (startedRef.current) return;
    startedRef.current = true;
    trackBetaEvent('beta_form_started');
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

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!normalizedEmail) {
      setError('Enter your email address.');
      return;
    }

    if (!isEmailValid) {
      setError('Enter a valid email address.');
      return;
    }

    if (!platform) {
      setError('Choose Android or iOS.');
      return;
    }

    if (window.localStorage.getItem(REGISTERED_KEY) === 'true') {
      setStatus('duplicate_device');
      trackBetaEvent('beta_duplicate_device');
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Beta registration is temporarily unavailable. Please try again soon.');
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

    const err = dbError as
      | { code?: string; message?: string; details?: string; status?: number }
      | null
      | undefined;

    if (err) {
      const message = err.message?.toLowerCase() ?? '';
      const details = err.details?.toLowerCase() ?? '';
      const isDuplicate = err.code === '23505' || err.status === 409 || message.includes('duplicate');

      if (isDuplicate) {
        const deviceDuplicate = message.includes('device_id') || details.includes('device_id');
        setStatus(deviceDuplicate ? 'duplicate_device' : 'duplicate_email');
        trackBetaEvent(deviceDuplicate ? 'beta_duplicate_device' : 'beta_duplicate_email');
        return;
      }

      if (err.code === '42P01' || err.code === 'PGRST205') {
        setError('Beta registration table is missing. Please contact support.');
      } else if (err.code === '42501') {
        setError('Beta registration is blocked by permissions.');
      } else {
        setError('Something went wrong. Please try again.');
      }
      setStatus('idle');
      return;
    }

    window.localStorage.setItem(REGISTERED_KEY, 'true');
    setStatus('success');
    trackBetaEvent('beta_success');
    void sendWelcomeEmail(normalizedEmail, platform);
    fireSuccessConfetti();

    setTimeout(() => {
      onClose();
      trackBetaEvent('beta_modal_close_after_success');
    }, 2800);
  };

  const statusTitle =
    status === 'duplicate_email'
      ? 'Already registered'
      : status === 'duplicate_device'
      ? 'Device already registered'
      : "You're on the beta";

  const statusMessage =
    status === 'duplicate_email'
      ? 'This email is already on the JourneySync beta list. Use the download page to get the latest APK.'
      : status === 'duplicate_device'
      ? 'This device already joined the beta. Open the download page to install the latest Android build.'
      : 'Thanks for joining. Check your inbox for beta updates and Android access guidance.';

  return (
    <AppModal
      isOpen={isOpen}
      onClose={onClose}
      title="Join the JourneySync beta"
      labelledBy="join-beta-title"
      size="md"
      panelClassName="border-white/60 bg-[linear-gradient(140deg,rgba(255,255,255,0.96),rgba(255,248,241,0.9))] text-neutral-950 shadow-[0_30px_80px_rgba(0,0,0,0.28)]"
      headerClassName="bg-white/90 text-neutral-950"
    >
      <div className="relative">
        <div className="pointer-events-none absolute -top-10 left-1/2 h-24 w-24 -translate-x-1/2 rounded-full bg-orange-300/40 blur-3xl" />
        <AnimatePresence mode="wait">
          {(status === 'success' || status === 'duplicate_email' || status === 'duplicate_device') && (
            <motion.section
              key={status}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 8 }}
              transition={{ duration: 0.2 }}
              className="space-y-5 py-4 text-center"
            >
              <div className="mx-auto grid h-14 w-14 place-items-center rounded-full border border-orange-200 bg-orange-50 text-orange-600">
                <span className="material-icons-round text-2xl">check_circle</span>
              </div>
              <div className="space-y-2">
                <h3 className="text-xl font-extrabold tracking-tight">{statusTitle}</h3>
                <p className="text-sm leading-relaxed text-neutral-600">{statusMessage}</p>
              </div>
              <a
                href="/beta/download"
                className="inline-flex min-h-11 items-center justify-center rounded-full bg-[#d46211] px-6 text-sm font-bold text-white transition hover:bg-[#b6520e]"
              >
                Open download page
              </a>
            </motion.section>
          )}

          {status !== 'success' && status !== 'duplicate_email' && status !== 'duplicate_device' && (
            <motion.form
              key="form"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 8 }}
              transition={{ duration: 0.2 }}
              className="space-y-5"
              onSubmit={handleSubmit}
            >
              <p className="text-sm leading-relaxed text-neutral-600">
                Choose your platform, enter your email, and we will guide you to the latest beta build and updates.
              </p>

              <fieldset className="space-y-3" aria-label="Select platform">
                <legend className="text-xs font-bold uppercase tracking-[0.14em] text-neutral-500">
                  Platform
                </legend>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { key: 'android', label: 'Android', icon: 'android' },
                    { key: 'ios', label: 'iOS', icon: 'phone_iphone' },
                  ].map((item) => (
                    <button
                      key={item.key}
                      type="button"
                      className={`inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border px-3 text-sm font-semibold transition ${
                        platform === item.key
                          ? 'border-orange-300 bg-orange-50 text-orange-700'
                          : 'border-neutral-200 bg-white text-neutral-700 hover:border-neutral-300'
                      }`}
                      onClick={() => {
                        setPlatform(item.key);
                        markStarted();
                      }}
                      aria-pressed={platform === item.key}
                    >
                      <span className="material-icons-round text-base">{item.icon}</span>
                      {item.label}
                    </button>
                  ))}
                </div>
              </fieldset>

              <label className="block space-y-2 text-sm font-medium text-neutral-800" htmlFor="beta-email">
                Email
                <div className="relative">
                  <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-neutral-400 material-icons-round text-base">
                    mail
                  </span>
                  <input
                    id="beta-email"
                    type="email"
                    autoComplete="email"
                    inputMode="email"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      setError('');
                      markStarted();
                    }}
                    className="w-full rounded-xl border border-neutral-300 bg-white py-3 pl-10 pr-4 text-sm text-neutral-900 outline-none transition placeholder:text-neutral-400 focus:border-orange-300 focus:ring-2 focus:ring-orange-100"
                    placeholder="you@example.com"
                    aria-invalid={Boolean(error)}
                    required
                  />
                </div>
              </label>

              {error && (
                <p className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700" role="alert">
                  {error}
                </p>
              )}

              <button
                type="submit"
                disabled={!canSubmit}
                className="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-[#d46211] px-4 text-sm font-bold text-white transition hover:bg-[#b6520e] disabled:cursor-not-allowed disabled:bg-orange-300"
              >
                {status === 'submitting' ? (
                  <>
                    <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                    Submitting...
                  </>
                ) : (
                  <>
                    Join beta
                    <span className="material-icons-round text-base">arrow_forward</span>
                  </>
                )}
              </button>

              <p className="text-center text-xs leading-relaxed text-neutral-500">
                By joining beta, you agree to receive JourneySync beta updates and release guidance.
              </p>
            </motion.form>
          )}
        </AnimatePresence>
      </div>
    </AppModal>
  );
}
