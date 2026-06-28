import { motion } from 'framer-motion';

export function StaticMarkup({ html, motionEnabled = false }) {
  const props = { className: 'react-static-chunk', dangerouslySetInnerHTML: { __html: html } };

  if (!motionEnabled) {
    return <div {...props} />;
  }

  return (
    <motion.div
      {...props}
      initial={false}
      whileInView={{}}
      viewport={{ once: true, amount: 0.12 }}
    />
  );
}
