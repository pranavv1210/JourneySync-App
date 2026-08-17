'use client';

import { useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { featureMoments } from '@/data/site-content';

export function FeaturesSection() {
  const [activeId, setActiveId] = useState(featureMoments[0].id);
  const active = featureMoments.find((item) => item.id === activeId) ?? featureMoments[0];
  const reduceMotion = useReducedMotion();

  return (
    <section id="features" className="chapter-features">
      <div className="container feature-stage">
        <div className="feature-intro">
          <p className="eyebrow">The ride layer</p>
          <h2>Discover. Plan. Connect. Ride. Stay safe. Remember.</h2>
          <p>
            Each product moment maps to a real group-ride failure point, with the phone interface
            staying pinned as the ride state changes.
          </p>
        </div>

        <div className="feature-system">
          <div className="feature-switcher" role="tablist" aria-label="JourneySync ride layer">
            {featureMoments.map((item) => (
              <button
                key={item.id}
                type="button"
                role="tab"
                aria-selected={item.id === activeId}
                className={item.id === activeId ? 'active' : ''}
                onClick={() => setActiveId(item.id)}
              >
                <span className="material-icons-round">{item.icon}</span>
                <span>{item.kicker}</span>
              </button>
            ))}
          </div>

          <motion.article
            key={active.id}
            className="feature-product"
            role="tabpanel"
            aria-live="polite"
            initial={reduceMotion ? false : { opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35 }}
          >
            <div className="feature-product-copy">
              <p className="eyebrow light">{active.kicker}</p>
              <h3>{active.title}</h3>
              <p>{active.description}</p>
              <ul>
                {active.bullets.map((bullet) => (
                  <li key={bullet}>{bullet}</li>
                ))}
              </ul>
            </div>

            <div className={`feature-device ${active.id}`} aria-hidden="true">
              <div className="feature-device-map">
                <img src="/map_bg.png" alt="" />
                <svg viewBox="0 0 260 360" preserveAspectRatio="none">
                  <motion.path
                    d="M18 302 C 88 270, 68 166, 144 158 C 205 151, 200 74, 242 42"
                    initial={reduceMotion ? undefined : { pathLength: 0 }}
                    animate={{ pathLength: 1 }}
                    transition={{ duration: 0.9, ease: 'easeOut' }}
                  />
                </svg>
                <span className="feature-puck one">{active.metric}</span>
                <span className="feature-puck two">SYNC</span>
              </div>
              <div className="feature-hud">
                <span className="material-icons-round">{active.icon}</span>
                <strong>{active.kicker}</strong>
                <small>{active.metric}</small>
              </div>
            </div>
          </motion.article>
        </div>
      </div>
    </section>
  );
}
