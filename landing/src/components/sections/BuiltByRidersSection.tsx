'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { builtByBullets } from '@/data/site-content';
import { SectionHeading } from '@/components/ui/SectionHeading';

export function BuiltByRidersSection() {
  const reduceMotion = useReducedMotion();

  return (
    <section id="built-by-riders" className="section-shell chapter-built">
      <div className="container">
        <SectionHeading
          eyebrow="Startup story"
          title="Built by riders. For riders."
          description="Every group ride starts with excitement. Then someone misses a turn, someone gets left behind, someone stops for fuel, and the whole group starts coordinating through calls and chat."
        />

        <div className="built-layout">
          <motion.div
            className="built-story"
            initial={reduceMotion ? false : { opacity: 0, y: 18 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.35 }}
            transition={{ duration: 0.5 }}
          >
            {builtByBullets.map((item) => (
              <article key={item.text}>
                <span className="material-icons-round">{item.icon}</span>
                <p>{item.text}</p>
              </article>
            ))}
          </motion.div>

          <motion.aside
            className="built-visual"
            initial={reduceMotion ? false : { opacity: 0, scale: 0.96 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true, amount: 0.35 }}
            transition={{ duration: 0.55, delay: 0.1 }}
            aria-hidden="true"
          >
            <div className="built-route">
              <svg viewBox="0 0 400 320" preserveAspectRatio="none">
                <path d="M20 280 C 120 260, 160 120, 260 120 S 360 60, 380 40" />
              </svg>
            </div>
            <div className="built-badge">
              <span className="material-icons-round">two_wheeler</span>
              <div>
                <strong>Bengaluru rider groups</strong>
                <small>Closed beta feedback loop</small>
              </div>
            </div>
          </motion.aside>
        </div>
      </div>
    </section>
  );
}
