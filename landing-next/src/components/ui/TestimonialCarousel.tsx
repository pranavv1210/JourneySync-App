'use client';

import { useEffect, useRef, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import type { Testimonial } from '@/data/site-content';

function initials(name: string) {
  return name
    .split(' ')
    .map((part) => part[0])
    .join('')
    .slice(0, 2);
}

export function TestimonialCarousel({ items }: { items: Testimonial[] }) {
  const reduceMotion = useReducedMotion();
  const [active, setActive] = useState(0);
  const trackRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (reduceMotion) return;
    const timer = window.setInterval(() => {
      setActive((value) => (value + 1) % items.length);
    }, 5200);
    return () => window.clearInterval(timer);
  }, [items.length, reduceMotion]);

  useEffect(() => {
    const node = trackRef.current;
    if (!node) return;
    const card = node.children[active] as HTMLElement | undefined;
    card?.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', inline: 'center', block: 'nearest' });
  }, [active, reduceMotion]);

  return (
    <div className="testimonial-carousel">
      <div className="testimonial-track-wrap" ref={trackRef}>
        {items.map((item, index) => (
          <motion.article
            key={item.name}
            className={`testimonial-slide ${index === active ? 'is-active' : ''}`}
            animate={reduceMotion ? undefined : { scale: index === active ? 1 : 0.96, opacity: index === active ? 1 : 0.72 }}
            transition={{ duration: 0.35 }}
          >
            <div className="testimonial-head">
              <div className="testimonial-avatar">{initials(item.name)}</div>
              <div>
                <h3>{item.name}</h3>
                <p>
                  {item.location} · {item.bike}
                </p>
              </div>
            </div>
            <div className="testimonial-stars" aria-label="5 out of 5 rating">
              {Array.from({ length: 5 }).map((_, star) => (
                <span key={star} className="material-icons-round">
                  star
                </span>
              ))}
            </div>
            <blockquote>&ldquo;{item.quote}&rdquo;</blockquote>
          </motion.article>
        ))}
      </div>

      <div className="testimonial-controls" aria-label="Testimonial navigation">
        {items.map((item, index) => (
          <button
            key={item.name}
            type="button"
            className={index === active ? 'active' : ''}
            aria-label={`Show testimonial from ${item.name}`}
            aria-current={index === active}
            onClick={() => setActive(index)}
          />
        ))}
      </div>
    </div>
  );
}
