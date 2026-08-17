'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { CtaButton } from '@/components/ui/CtaButton';

export function HeroSection({ onJoinBeta }: { onJoinBeta: () => void }) {
  const reduceMotion = useReducedMotion();

  return (
    <section id="top" className="hero-chapter">
      <div className="route-atmosphere" aria-hidden="true">
        <svg viewBox="0 0 1440 900" preserveAspectRatio="none">
          <motion.path
            d="M-40 720 C 180 650, 210 430, 430 430 C 680 430, 720 190, 980 220 C 1190 245, 1240 480, 1490 410"
            initial={reduceMotion ? undefined : { pathLength: 0 }}
            animate={{ pathLength: 1 }}
            transition={{ duration: 2.2, ease: 'easeOut' }}
          />
          <motion.path
            d="M-20 215 C 240 260, 280 120, 465 165 C 650 210, 745 365, 950 320 C 1160 275, 1245 125, 1470 170"
            initial={reduceMotion ? undefined : { pathLength: 0 }}
            animate={{ pathLength: 1 }}
            transition={{ duration: 2.6, delay: 0.25, ease: 'easeOut' }}
          />
        </svg>
      </div>

      <div className="container hero-grid">
        <motion.div
          className="hero-copy"
          initial={false}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
        >
          <p className="eyebrow live-eyebrow">
            <span aria-hidden="true" />
            Digital riding experience
          </p>
          <h1>
            The ride layer for crews that move together.
          </h1>
          <p className="hero-lede">
            JourneySync coordinates the parts Google Maps and group chats miss:
            planning, rider visibility, live safety context, and ride memory.
          </p>
          <div className="hero-cta-row">
            <CtaButton onClick={onJoinBeta}>
              <span className="material-icons-round">groups</span>
              Join the beta
            </CtaButton>
            <CtaButton href="#demo" variant="outline">
              <span className="material-icons-round">play_circle</span>
              See how it works
            </CtaButton>
          </div>
          <dl className="hero-telemetry">
            <div>
              <dt>Mode</dt>
              <dd>Group ride</dd>
            </div>
            <div>
              <dt>Signal</dt>
              <dd>Realtime</dd>
            </div>
            <div>
              <dt>Safety</dt>
              <dd>SOS armed</dd>
            </div>
          </dl>
        </motion.div>

        <motion.div
          className="hero-visual"
          initial={false}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
        >
          <div className="product-orbit" aria-hidden="true">
            <span>12.97 N</span>
            <span>77.59 E</span>
            <span>LIVE</span>
          </div>

          <div className="hero-phone" aria-label="Animated JourneySync live ride interface">
            <div className="phone-metal" />
            <div className="phone-screen">
              <div className="map-layer">
                <img src="/map_bg.png" alt="" />
                <svg viewBox="0 0 300 560" preserveAspectRatio="none" aria-hidden="true">
                  <motion.path
                    className="phone-route-shadow"
                    d="M30 405 C 96 358, 86 250, 154 248 C 226 246, 210 152, 276 126"
                    initial={reduceMotion ? undefined : { pathLength: 0 }}
                    animate={{ pathLength: 1 }}
                    transition={{ duration: 2.2, delay: 0.45, ease: 'easeOut' }}
                  />
                  <motion.path
                    className="phone-route"
                    d="M30 405 C 96 358, 86 250, 154 248 C 226 246, 210 152, 276 126"
                    initial={reduceMotion ? undefined : { pathLength: 0 }}
                    animate={{ pathLength: 1 }}
                    transition={{ duration: 2.2, delay: 0.45, ease: 'easeOut' }}
                  />
                </svg>
                <motion.span
                  className="rider-marker lead"
                  animate={reduceMotion ? undefined : { y: [0, -8, 0] }}
                  transition={{ duration: 2.8, repeat: Infinity }}
                >
                  P
                </motion.span>
                <motion.span
                  className="rider-marker wing"
                  animate={reduceMotion ? undefined : { x: [0, 8, 0], y: [0, 5, 0] }}
                  transition={{ duration: 3.2, repeat: Infinity }}
                >
                  R
                </motion.span>
                <motion.span
                  className="rider-marker sweep"
                  animate={reduceMotion ? undefined : { x: [0, -7, 0] }}
                  transition={{ duration: 3.6, repeat: Infinity }}
                >
                  A
                </motion.span>
              </div>

              <div className="phone-status">
                <span>Ride Mode</span>
                <strong>Sunday breakfast ride</strong>
                <small>4 riders synced</small>
              </div>

              <div className="phone-bottom-sheet">
                <div>
                  <span>Distance</span>
                  <strong>68.4 km</strong>
                </div>
                <div>
                  <span>Spread</span>
                  <strong>420 m</strong>
                </div>
                <div>
                  <span>Weather</span>
                  <strong>24 C</strong>
                </div>
              </div>
            </div>
          </div>

          <motion.article
            className="floating-command radar"
            animate={reduceMotion ? undefined : { y: [0, -10, 0] }}
            transition={{ duration: 4.4, repeat: Infinity, ease: 'easeInOut' }}
          >
            <span className="material-icons-round">radar</span>
            <div>
              <strong>Ride Radar active</strong>
              <small>2 nearby rides detected</small>
            </div>
          </motion.article>

          <motion.article
            className="floating-command sos"
            animate={reduceMotion ? undefined : { y: [0, 8, 0] }}
            transition={{ duration: 4.8, repeat: Infinity, ease: 'easeInOut' }}
          >
            <span className="material-icons-round">shield</span>
            <div>
              <strong>SOS ready</strong>
              <small>Emergency context attached</small>
            </div>
          </motion.article>
        </motion.div>
      </div>
    </section>
  );
}
