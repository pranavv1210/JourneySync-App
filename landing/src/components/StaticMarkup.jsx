export function StaticMarkup({ html, motionEnabled = false }) {
  const props = { className: 'react-static-chunk', dangerouslySetInnerHTML: { __html: html } };

  return <div data-motion={motionEnabled ? 'enabled' : undefined} {...props} />;
}
