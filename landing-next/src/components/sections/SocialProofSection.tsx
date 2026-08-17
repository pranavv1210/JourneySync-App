'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { socialStats } from '@/data/site-content';
import { StatCounter } from '@/components/ui/StatCounter';

export function SocialProofSection() {
  const reduceMotion = useReducedMotion();

  return (
    <section className="chapter-stats" aria-labelledby="social-proof-heading">
      <div className="container stats-band">
        <motion.div
          className="stats-statement"
          initial={reduceMotion ? false : { opacity: 0, y: 18 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.4 }}
          transition={{ duration: 0.5 }}
        >
          <p className="eyebrow">Beta signal</p>
          <h2 id="social-proof-heading">Built around ride breakdowns, not dashboard vanity.</h2>
        </motion.div>
        <div className="stats-line" role="list">
          {socialStats.map((item, index) => (
            <motion.article
              key={item.label}
              role="listitem"
              initial={reduceMotion ? false : { opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.35 }}
              transition={{ duration: 0.42, delay: index * 0.07 }}
            >
              <p className="stat-value">
                <StatCounter value={item.value} suffix={item.suffix} />
              </p>
              <h3>{item.label}</h3>
              <p>{item.detail}</p>
            </motion.article>
          ))}
        </div>
      </div>
    </section>
  );
}
