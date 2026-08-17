'use client';

import { useRef, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { SectionHeading } from '@/components/ui/SectionHeading';
import { trackEvent } from '@/lib/tracking';

export function DemoSection() {
  const reduceMotion = useReducedMotion();
  const videoRef = useRef<HTMLVideoElement>(null);
  const [loaded, setLoaded] = useState(false);

  return (
    <section id="demo" className="section-shell chapter-demo">
      <div className="container">
        <div className="demo-shell">
          <motion.div
            className="demo-copy"
            initial={reduceMotion ? false : { opacity: 0, y: 18 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.35 }}
            transition={{ duration: 0.5 }}
          >
            <SectionHeading
              eyebrow="Product demo"
              title="See the ride layer in motion."
              description="Watch how a group can start together, stay visible, and move through the ride with less coordination friction."
            />
          </motion.div>

          <motion.div
            className="demo-video-wrap"
            initial={reduceMotion ? false : { opacity: 0, scale: 0.96 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true, amount: 0.35 }}
            transition={{ duration: 0.55, delay: 0.08 }}
          >
            {!loaded && <div className="demo-video-loader" aria-hidden="true" />}
            <video
              ref={videoRef}
              className={loaded ? 'is-ready' : ''}
              preload="metadata"
              muted
              playsInline
              autoPlay
              loop
              aria-label="JourneySync product demo preview"
              poster="/map_bg.png"
              onLoadedData={() => setLoaded(true)}
              onPlay={() => trackEvent('demo_viewed', { source: 'inline_autoplay' })}
            >
              <source src="/demovideo.mp4" type="video/mp4" />
            </video>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
