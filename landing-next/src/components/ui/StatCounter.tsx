'use client';

import { useEffect, useRef, useState } from 'react';

export function StatCounter({ value, suffix = '' }: { value: number; suffix?: string }) {
  const [display, setDisplay] = useState(0);
  const ref = useRef<HTMLSpanElement | null>(null);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries[0].isIntersecting) return;

        const start = performance.now();
        const duration = 1200;
        const tick = (now: number) => {
          const progress = Math.min((now - start) / duration, 1);
          const eased = 1 - Math.pow(1 - progress, 3);
          setDisplay(Math.round(value * eased));
          if (progress < 1) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
        observer.disconnect();
      },
      { threshold: 0.45 },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [value]);

  return (
    <span ref={ref}>
      {display}
      {suffix}
    </span>
  );
}
