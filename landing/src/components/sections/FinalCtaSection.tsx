'use client';

import { motion, useReducedMotion } from 'framer-motion';
import { CtaButton } from '@/components/ui/CtaButton';

export function FinalCtaSection({
  onJoinBeta,
}: {
  onJoinBeta: () => void;
}) {
  const reduceMotion = useReducedMotion();

  return (
    <section id="final" className="chapter-final">
      <div className="final-atmosphere" aria-hidden="true" />
      <div className="container final-inner">
        <motion.div
          initial={reduceMotion ? false : { opacity: 0, y: 22 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.4 }}
          transition={{ duration: 0.55 }}
        >
          <p className="eyebrow light">End of the journey</p>
          <h2>Ready to ride with a connected group?</h2>
          <p>
            Join the closed beta and get the Android beta download link by email when your crew
            is ready to test JourneySync.
          </p>
          <div className="final-actions">
            <CtaButton onClick={onJoinBeta} className="final-primary">
              <span className="material-icons-round">groups</span>
              Join closed beta
            </CtaButton>
            <CtaButton href="#demo" variant="ghost">
              <span className="material-icons-round">play_circle</span>
              Watch demo
            </CtaButton>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
