'use client';

import Link from 'next/link';
import { motion, useReducedMotion } from 'framer-motion';
import { appVersion } from '@/data/site-content';

export function BetaDownloadClient() {
  const reduceMotion = useReducedMotion();

  return (
    <main className="beta-download-page">
      <section className="beta-download-shell">
        <motion.div
          initial={reduceMotion ? false : { opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55 }}
          className="beta-download-card"
        >
          <Link href="/" className="beta-download-brand">
            <img src="/logo.png" alt="JourneySync logo" width={32} height={32} />
            JourneySync
          </Link>

          <span className="beta-download-pill">
            <span className="material-icons-round">verified</span>
            Beta access
          </span>

          <h1>
            Download <span className="text-accent">JourneySync Beta</span>
          </h1>
          <p>
            Android can install the APK now. iOS interest is handled through the beta form and
            future TestFlight access.
          </p>

          <div className="beta-download-grid">
            <article>
              <div className="beta-platform-head">
                <span className="material-icons-round">android</span>
                <span>{appVersion}</span>
              </div>
              <h2>Android beta</h2>
              <p>Requires Android 8.0+. If Gmail stalls at 100%, open this page in Chrome.</p>
              <a href="/journeysync.apk" download className="beta-download-primary">
                <span className="material-icons-round">download</span>
                Download APK
              </a>
            </article>

            <article className="muted">
              <div className="beta-platform-head">
                <span className="material-icons-round">phone_iphone</span>
                <span>Planned</span>
              </div>
              <h2>iOS beta</h2>
              <p>Your iOS interest is saved when you choose iOS on the beta form.</p>
              <a
                href="mailto:journeysync.app@gmail.com?subject=JourneySync%20iOS%20TestFlight%20access"
                className="beta-download-secondary"
              >
                <span className="material-icons-round">mail</span>
                Request TestFlight
              </a>
            </article>
          </div>

          <div className="beta-release-notes">
            <h3>
              <span className="material-icons-round">new_releases</span>
              What is in {appVersion}
            </h3>
            <ul>
              <li>Updated Android beta package for more reliable installation.</li>
              <li>Ride Radar, ride creation, and in-app feedback improvements.</li>
              <li>The latest APK is always available from this download page.</li>
            </ul>
          </div>

          <div className="beta-fallback">
            <p className="eyebrow light">Download fallback</p>
            <h3>If Gmail gets stuck, download from here.</h3>
            <p>
              Open this page in Chrome and tap the button below. Bookmark it - the same link always
              points to the latest Android beta APK.
            </p>
            <a href="/journeysync.apk" download className="beta-download-primary">
              <span className="material-icons-round">download</span>
              Download latest Android APK
            </a>
          </div>
        </motion.div>
      </section>
    </main>
  );
}
