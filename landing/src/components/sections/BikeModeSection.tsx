'use client';

import { useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';

export function BikeModeSection() {
  const [enabled, setEnabled] = useState(true);
  const reduceMotion = useReducedMotion();

  return (
    <section id="bike-mode" className="bike-mode-chapter">
      <div className="container bike-mode-layout">
        <div className="bike-mode-copy">
          <p className="eyebrow">Bike Mode</p>
          <h2>Keep your hands on the bars and callers in the loop.</h2>
          <p>
            Turn Bike Mode on for a commute or a long ride. On supported Android phones,
            JourneySync can decline incoming calls and send your selected SMS reply while the
            mode stays active.
          </p>
          <ul>
            <li>Write and save multiple replies in Settings.</li>
            <li>Switch messages to match the ride you are taking.</li>
            <li>Get a reminder after you have been stationary for a while.</li>
            <li>Bike Mode stays on until you turn it off.</li>
          </ul>
          <small>
            Call handling requires Android system approval and SMS permission. Carrier charges
            may apply. iPhone support is limited to the in-app riding status.
          </small>
        </div>

        <div className="bike-mode-demo" aria-live="polite">
          <div className="bike-mode-demo-header">
            <div>
              <strong>{enabled ? 'Bike Mode is on' : 'Bike Mode'}</strong>
              <span>
                {enabled
                  ? 'Calls get your selected reply.'
                  : 'Let callers know you are riding.'}
              </span>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={enabled}
              aria-label="Preview Bike Mode"
              className={`bike-mode-preview-switch ${enabled ? 'is-on' : ''}`}
              onClick={() => setEnabled((value) => !value)}
            >
              <motion.span
                className="bike-mode-preview-bike material-icons-round"
                animate={{ x: enabled ? 34 : 0, rotate: enabled ? -2 : 0 }}
                transition={
                  reduceMotion
                    ? { duration: 0.08 }
                    : { type: 'spring', bounce: 0, duration: 0.38 }
                }
              >
                two_wheeler
              </motion.span>
              <motion.span
                className="bike-mode-preview-lines"
                animate={{ opacity: enabled ? 1 : 0, scaleX: enabled ? 1 : 0.4 }}
                transition={{ duration: reduceMotion ? 0.08 : 0.2 }}
              />
              <motion.span
                className="bike-mode-preview-stop"
                animate={{ opacity: enabled ? 0 : 1 }}
                transition={{ duration: reduceMotion ? 0.08 : 0.16 }}
              />
            </button>
          </div>
          <div className="bike-mode-message-preview">
            <span className="material-icons-round" aria-hidden="true">sms</span>
            <div>
              <small>Automatic reply</small>
              <p>
                I&apos;m currently riding and can&apos;t take your call. I&apos;ll get back to you
                when I stop. Sent by JourneySync Bike Mode.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
