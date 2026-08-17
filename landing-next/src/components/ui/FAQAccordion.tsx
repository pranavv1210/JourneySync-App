'use client';

import { useState } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import type { FaqItem } from '@/data/site-content';
import { trackEvent } from '@/lib/tracking';

export function FAQAccordion({ items }: { items: FaqItem[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const reduceMotion = useReducedMotion();

  return (
    <div className="faq-stack">
      {items.map((item, index) => {
        const isOpen = openIndex === index;
        return (
          <article key={item.question} className={`faq-card ${isOpen ? 'open' : ''}`}>
            <button
              type="button"
              className="faq-trigger"
              aria-expanded={isOpen}
              onClick={() => {
                const next = isOpen ? null : index;
                setOpenIndex(next);
                if (next !== null) trackEvent('faq_expand', { question: item.question });
              }}
            >
              <span>{item.question}</span>
              <span className="material-icons-round faq-icon" aria-hidden="true">
                expand_more
              </span>
            </button>
            <AnimatePresence initial={false}>
              {isOpen && (
                <motion.div
                  key="answer"
                  className="faq-panel"
                  initial={reduceMotion ? false : { height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={reduceMotion ? undefined : { height: 0, opacity: 0 }}
                  transition={{ duration: reduceMotion ? 0 : 0.28, ease: [0.22, 1, 0.36, 1] }}
                >
                  <p>{item.answer}</p>
                </motion.div>
              )}
            </AnimatePresence>
          </article>
        );
      })}
    </div>
  );
}
