'use client';

import { useState } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';

const spring = { type: 'spring' as const, bounce: 0, duration: 0.38 };

export function BikeModeSection() {
  const [enabled, setEnabled] = useState(true);
  const reduceMotion = useReducedMotion();
  const transition = reduceMotion ? { duration: 0.12 } : spring;

  return (
    <section id="bike-mode" className="bike-mode-chapter">
      <div className="container bike-mode-layout">
        <div className="bike-mode-copy">
          <p className="eyebrow">Ride Mode Ã‚Â· v1.7.0</p>
          <h2>Keep your hands on the bars and callers in the loop.</h2>
          <p>
            Try the switch. The preview shows what JourneySync does when Ride Mode is onÃ¢â‚¬â€and
            what changes the moment you turn it off.
          </p>
          <ul>
            <li>Declines calls while preserving the exceptions you choose.</li>
            <li>Shows the riding reply that is ready for supported releases.</li>
            <li>Returns calls to their normal flow as soon as Ride Mode is off.</li>
          </ul>
          <small>
            Android requires Caller ID &amp; spam access. The direct-download APK does not request
            restricted SMS access; automatic SMS remains reserved for a Play-reviewed release.
          </small>
        </div>

        <div className={`bike-mode-demo ${enabled ? 'is-on' : 'is-off'}`} aria-live="polite">
          <div className="bike-mode-demo-header">
            <div className="bike-mode-state-copy">
              <motion.span className="bike-mode-state-dot" animate={{ scale: enabled ? 1 : 0.72, opacity: enabled ? 1 : 0.45 }} transition={transition} />
              <div>
                <strong>Ride Mode {enabled ? 'is on' : 'is off'}</strong>
                <span>{enabled ? 'Calls follow your riding rules.' : 'Calls ring normally.'}</span>
              </div>
            </div>
            <button type="button" role="switch" aria-checked={enabled} aria-label={`Turn Ride Mode ${enabled ? 'off' : 'on'} in this preview`} className="bike-mode-preview-switch" onClick={() => setEnabled((value) => !value)}>
              <motion.span className="bike-mode-switch-thumb" animate={{ x: enabled ? 34 : 0 }} transition={transition}>
                <span className="material-icons-round" aria-hidden="true">{enabled ? 'two_wheeler' : 'phone_in_talk'}</span>
              </motion.span>
              <span className="bike-mode-switch-label" aria-hidden="true">{enabled ? 'ON' : 'OFF'}</span>
            </button>
          </div>

          <div className="bike-mode-simulation" aria-label="Ride Mode behavior preview">
            <div className="bike-mode-phone-top"><span>10:32</span><span className="material-icons-round" aria-hidden="true">signal_cellular_alt</span></div>
            <div className="bike-mode-call-row">
              <motion.div className="bike-mode-caller" animate={{ scale: enabled ? 0.92 : 1, y: enabled ? -2 : 0 }} transition={transition}><span className="material-icons-round" aria-hidden="true">person</span></motion.div>
              <div className="bike-mode-call-copy">
                <small>Incoming call</small><strong>Weekend Crew</strong><span>{enabled ? 'Checking your Ride Mode rulesÃ¢â‚¬Â¦' : 'Your phone is ringing'}</span>
              </div>
              <motion.span className={`bike-mode-call-action ${enabled ? 'declined' : 'ringing'}`} animate={{ rotate: enabled ? 135 : [0, -8, 8, 0], scale: enabled ? 0.9 : 1 }} transition={reduceMotion ? { duration: 0.12 } : enabled ? spring : { duration: 0.7, repeat: Infinity, repeatDelay: 1.1 }}>
                <span className="material-icons-round" aria-hidden="true">phone</span>
              </motion.span>
            </div>

            <AnimatePresence mode="wait" initial={false}>
              <motion.div key={enabled ? 'protected' : 'normal'} className={`bike-mode-outcome ${enabled ? 'protected' : 'normal'}`} initial={reduceMotion ? { opacity: 0 } : { opacity: 0, y: 12, scale: 0.98 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={reduceMotion ? { opacity: 0 } : { opacity: 0, y: -8, scale: 0.98 }} transition={transition}>
                <span className="material-icons-round" aria-hidden="true">{enabled ? 'do_not_disturb_on' : 'notifications_active'}</span>
                <div><small>{enabled ? 'Call handled' : 'Normal call behavior'}</small><p>{enabled ? 'The call is declined unless this caller matches one of your exceptions.' : 'JourneySync steps back. Your phone rings and no riding reply is prepared.'}</p></div>
              </motion.div>
            </AnimatePresence>

            <motion.div className="bike-mode-message-preview" animate={{ opacity: enabled ? 1 : 0.42, y: enabled ? 0 : 6 }} transition={transition}>
              <span className="material-icons-round" aria-hidden="true">sms</span>
              <div><small>{enabled ? 'Riding reply ready' : 'Riding reply paused'}</small><p>I&apos;m riding and can&apos;t take your call. I&apos;ll get back to you when I stop.</p></div>
              <span className="bike-mode-ready-pill">{enabled ? 'READY' : 'PAUSED'}</span>
            </motion.div>
          </div>

          <p className="bike-mode-demo-hint"><span className="material-icons-round" aria-hidden="true">touch_app</span>Tap the switch to compare both states</p>
        </div>
      </div>
    </section>
  );
}
