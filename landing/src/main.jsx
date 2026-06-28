let booted = false;

function bootReact() {
  if (booted) return;
  booted = true;
  import('./bootstrap.jsx');
}

function scheduleBoot() {
  const bootAfterInteraction = () => bootReact();
  ['pointerdown', 'keydown', 'touchstart'].forEach((eventName) => {
    window.addEventListener(eventName, bootAfterInteraction, { once: true, passive: true });
  });
}

if (document.readyState === 'complete') {
  scheduleBoot();
} else {
  window.addEventListener('load', scheduleBoot, { once: true });
}
