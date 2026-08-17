'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { safetyFeatures } from '@/data/site-content';
import { SectionHeading } from '@/components/ui/SectionHeading';

export function SafetySection() {
  const reduceMotion = useReducedMotion();

  return (
    <section id="safety" className="chapter-safety">
      <div className="container safety-grid">
        <motion.div
          className="safety-copy"
          initial={reduceMotion ? false : { opacity: 0, x: -18 }}
          whileInView={{ opacity: 1, x: 0 }}
          viewport={{ once: true, amount: 0.35 }}
          transition={{ duration: 0.5 }}
        >
          <SectionHeading
            eyebrow="Safety first"
            title="When it matters most, the ride context stays attached."
            description="JourneySync treats safety as core ride behavior - not a marketing bullet buried in settings."
          />

          <div className="safety-features">
            {safetyFeatures.map((item) => (
              <article key={item.title}>
                <span className="material-icons-round">{item.icon}</span>
                <div>
                  <h3>{item.title}</h3>
                  <p>{item.description}</p>
                </div>
              </article>
            ))}
          </div>
        </motion.div>

        <motion.div
          className="safety-phone-wrap"
          initial={reduceMotion ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.35 }}
          transition={{ duration: 0.55, delay: 0.08 }}
        >
          <div className="safety-phone">
            <div className="safety-screen">
              <div className="sos-pulse" aria-hidden="true" />
              <div className="sos-core">
                <span className="material-icons-round">sos</span>
              </div>
              <h3>Crash detected</h3>
              <p>
                Sending alert in <strong>14s</strong>
              </p>
              <button type="button" className="sos-cancel">
                I&apos;m okay - cancel
              </button>
              <button type="button" className="sos-emergency">
                Call emergency now
              </button>
              <img src="/map_bg.png" alt="" className="safety-map" />
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
