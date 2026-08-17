'use client';

import { useEffect, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { appVersion } from '@/data/site-content';
import { CtaButton } from '@/components/ui/CtaButton';

export function DownloadSection({ onDownload }: { onDownload: () => void }) {
  const reduceMotion = useReducedMotion();
  const [qrSrc, setQrSrc] = useState(() => {
    if (typeof window === 'undefined') return '';
    const apkUrl = new URL('/journeysync.apk', window.location.origin).href;
    return `https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=12&data=${encodeURIComponent(apkUrl)}`;
  });

  useEffect(() => {
    if (qrSrc) return;
    const id = window.setTimeout(() => {
      const apkUrl = new URL('/journeysync.apk', window.location.origin).href;
      setQrSrc(
        `https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=12&data=${encodeURIComponent(apkUrl)}`,
      );
    }, 0);
    return () => window.clearTimeout(id);
  }, [qrSrc]);

  return (
    <section id="download" className="chapter-download">
      <div className="container">
        <motion.div
          className="download-panel"
          initial={reduceMotion ? false : { opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.55 }}
        >
          <div className="download-copy">
            <div className="download-badge">
              <img src="/logo.png" alt="" width={32} height={32} />
              <span>JourneySync {appVersion}</span>
            </div>
            <h2>Join the closed beta and test the Android build.</h2>
            <p>
              Built for Bengaluru rider groups testing real coordination before the public
              launch.
            </p>
            <div className="download-actions">
              <CtaButton onClick={onDownload} variant="ghost" className="download-primary">
                <span className="material-icons-round">download</span>
                Download Android beta
              </CtaButton>
              <CtaButton
                href="mailto:journeysync.app@gmail.com?subject=JourneySync%20iOS%20beta%20access"
                variant="outline"
                className="download-secondary"
              >
                <span className="material-icons-round">phone_iphone</span>
                Request iOS beta
              </CtaButton>
            </div>
            <div className="download-meta">
              <div>
                <span>Android</span>
                <strong>Beta APK available</strong>
              </div>
              <div>
                <span>iOS</span>
                <strong>TestFlight planned</strong>
              </div>
            </div>
          </div>

          <div className="download-qr">
            <div className="download-qr-phone">
              <a href="/journeysync.apk" download aria-label="Scan to download JourneySync APK">
                {qrSrc ? (
                  <img src={qrSrc} alt="QR code to download JourneySync Android beta APK" />
                ) : (
                  <div className="download-qr-placeholder" aria-hidden="true" />
                )}
              </a>
              <p>Scan to download</p>
              <small>Android beta build</small>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
