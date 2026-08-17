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

          <h1>Download JourneySync Beta</h1>
          <p>
            Install the latest Android beta build. If this opened inside Gmail,
            use Chrome for the smoothest download.
          </p>

          <div className="beta-download-panel">
            <span className="material-icons-round">android</span>
            <div>
              <strong>Android beta</strong>
              <small>{appVersion} - APK download</small>
            </div>
          </div>

          <a href="/journeysync.apk" download className="beta-download-primary">
            <span className="material-icons-round">download</span>
            Download APK
          </a>

          <p className="beta-download-note">
            iOS TestFlight is not public yet. For iOS access, email{' '}
            <a href="mailto:journeysync.app@gmail.com?subject=JourneySync%20iOS%20TestFlight%20access">
              journeysync.app@gmail.com
            </a>
            .
          </p>
        </motion.div>
      </section>
    </main>
  );
}
