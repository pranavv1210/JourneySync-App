'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { storySteps } from '@/data/site-content';

export function ProblemSolutionSection() {
  const reduceMotion = useReducedMotion();

  return (
    <section id="problem-solution" className="chapter-story">
      <div className="container story-grid">
        <div className="story-sticky">
          <p className="eyebrow">The ride problem</p>
          <h2>Riding alone is simple. Riding together becomes a system problem.</h2>
          <p>
            JourneySync turns the messy sequence before, during, and after a group ride into one
            connected ride state.
          </p>
          <div className="story-route-card" aria-hidden="true">
            <svg viewBox="0 0 360 420" preserveAspectRatio="none">
              <motion.path
                d="M74 348 C 110 296, 72 244, 140 216 C 214 186, 160 112, 238 92 C 286 80, 300 54, 318 34"
                initial={reduceMotion ? undefined : { pathLength: 0 }}
                whileInView={{ pathLength: 1 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{ duration: 1.7, ease: 'easeOut' }}
              />
            </svg>
            <span className="route-node node-a">Start</span>
            <span className="route-node node-b">Split</span>
            <span className="route-node node-c">Regroup</span>
            <span className="route-node node-d">Memory</span>
          </div>
        </div>

        <div className="story-steps">
          {storySteps.map((item, index) => (
            <motion.article
              key={item.index}
              initial={reduceMotion ? false : { opacity: 0, x: 24 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, amount: 0.35 }}
              transition={{ duration: 0.5, delay: index * 0.05 }}
            >
              <span className="story-index">{item.index}</span>
              <p className="story-phase">{item.phase}</p>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <strong>{item.signal}</strong>
            </motion.article>
          ))}
        </div>
      </div>
    </section>
  );
}
