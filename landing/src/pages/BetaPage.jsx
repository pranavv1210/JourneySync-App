import { useEffect, useRef, useState } from 'react';
import confetti from 'canvas-confetti';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { isSupabaseConfigured, supabase } from '../lib/supabase';
import { trackBetaEvent } from '../utils/tracking';

const DEVICE_ID_KEY = 'journeysync_beta_device_id';
const REGISTERED_KEY = 'journeysync_beta_registered';
const ease = [0.16, 1, 0.3, 1];

function setMetaTag(name, content) {
  let tag = document.querySelector(`meta[name="${name}"]`);
  if (!tag) {
    tag = document.createElement('meta');
    tag.setAttribute('name', name);
    document.head.appendChild(tag);
  }
  tag.setAttribute('content', content);
}

function setCanonical(href) {
  let link = document.querySelector('link[rel="canonical"]');
  if (!link) {
    link = document.createElement('link');
    link.setAttribute('rel', 'canonical');
    document.head.appendChild(link);
  }
  link.setAttribute('href', href);
}

function getDeviceId() {
  const existing = window.localStorage.getItem(DEVICE_ID_KEY);
  if (existing) return existing;

  const next = window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  window.localStorage.setItem(DEVICE_ID_KEY, next);
  return next;
}

function BetaSeo() {
  useEffect(() => {
    const canonical = 'https://journeysyncrideapp.in/beta';
    document.title = 'Join the JourneySync Beta';
    setMetaTag('description', 'Apply for the official JourneySync Beta and help shape the future of motorcycle group riding.');
    setCanonical(canonical);

    const existing = document.getElementById('beta-page-schema');
    if (existing) existing.remove();

    const script = document.createElement('script');
    script.id = 'beta-page-schema';
    script.type = 'application/ld+json';
    script.textContent = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Join the JourneySync Beta',
      description: 'Apply for the official JourneySync Beta and help shape the future of motorcycle group riding.',
      url: canonical,
      isPartOf: {
        '@type': 'WebSite',
        name: 'JourneySync',
        url: 'https://journeysyncrideapp.in/',
      },
      potentialAction: {
        '@type': 'RegisterAction',
        target: canonical,
        name: 'Apply for the JourneySync Beta',
      },
    });
    document.head.appendChild(script);
    trackBetaEvent('beta_page_view');

    return () => {
      script.remove();
    };
  }, []);

  return null;
}

function ShaderBackground() {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return undefined;

    const syncSize = () => {
      const width = canvas.clientWidth || 1280;
      const height = canvas.clientHeight || 720;
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
    };

    const resizeObserver = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(syncSize) : null;
    resizeObserver?.observe(canvas);
    syncSize();

    const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
    if (!gl) return () => resizeObserver?.disconnect();

    const vertexSource = `
      attribute vec2 a_position;
      varying vec2 v_texCoord;
      void main() {
        v_texCoord = a_position * 0.5 + 0.5;
        gl_Position = vec4(a_position, 0.0, 1.0);
      }
    `;
    const fragmentSource = `
      precision highp float;
      uniform float u_time;
      uniform vec2 u_resolution;
      uniform vec2 u_mouse;
      varying vec2 v_texCoord;

      vec3 colorBg = vec3(0.973, 0.976, 1.0);
      vec3 colorOrange = vec3(0.85, 0.46, 0.02);
      vec3 colorGreen = vec3(0.13, 0.30, 0.18);

      float noise(vec2 p) {
        return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
      }

      void main() {
        vec2 uv = v_texCoord;
        vec2 p = -1.0 + 2.0 * uv;
        p.x *= u_resolution.x / u_resolution.y;
        vec2 mouse = (u_mouse / u_resolution) * 2.0 - 1.0;
        mouse.y *= -1.0;

        float t = u_time * 0.3;
        vec2 b1 = vec2(0.5 * sin(t), 0.5 * cos(t * 1.2)) + mouse * 0.045;
        float glow1 = smoothstep(1.5, 0.0, length(p - b1));

        vec2 b2 = vec2(0.7 * cos(t * 0.8), 0.4 * sin(t * 1.5)) - mouse * 0.035;
        float glow2 = smoothstep(1.2, 0.0, length(p - b2));

        vec2 b3 = vec2(-0.6 * sin(t * 0.5), -0.5 * cos(t * 0.7));
        float glow3 = smoothstep(1.8, 0.0, length(p - b3));

        vec3 color = colorBg;
        color = mix(color, colorOrange, glow1 * 0.15);
        color = mix(color, colorGreen, glow2 * 0.08);
        color = mix(color, colorOrange, glow3 * 0.1);
        color += (noise(uv * 1000.0) - 0.5) * 0.02;

        gl_FragColor = vec4(color, 1.0);
      }
    `;

    const compile = (type, source) => {
      const shader = gl.createShader(type);
      gl.shaderSource(shader, source);
      gl.compileShader(shader);
      return shader;
    };

    const program = gl.createProgram();
    gl.attachShader(program, compile(gl.VERTEX_SHADER, vertexSource));
    gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragmentSource));
    gl.linkProgram(program);
    gl.useProgram(program);

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);

    const position = gl.getAttribLocation(program, 'a_position');
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

    const uTime = gl.getUniformLocation(program, 'u_time');
    const uResolution = gl.getUniformLocation(program, 'u_resolution');
    const uMouse = gl.getUniformLocation(program, 'u_mouse');
    const mouse = { x: canvas.width / 2, y: canvas.height / 2 };

    const handleMouseMove = (event) => {
      const rect = canvas.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      mouse.x = ((event.clientX - rect.left) / rect.width) * canvas.width;
      mouse.y = (1 - ((event.clientY - rect.top) / rect.height)) * canvas.height;
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });

    let frame = 0;
    const render = (time) => {
      if (!resizeObserver) syncSize();
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.uniform1f(uTime, time * 0.001);
      gl.uniform2f(uResolution, canvas.width, canvas.height);
      gl.uniform2f(uMouse, mouse.x, mouse.y);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      frame = requestAnimationFrame(render);
    };
    frame = requestAnimationFrame(render);

    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener('mousemove', handleMouseMove);
      resizeObserver?.disconnect();
    };
  }, []);

  return <canvas ref={canvasRef} className="absolute inset-0 h-full w-full" aria-hidden="true" />;
}

function TrustRow() {
  const badges = [
    ['check', 'Free During Beta'],
    ['smartphone', 'Android Available'],
    ['shield', 'Privacy First'],
  ];

  return (
    <motion.div
      className="mt-7 flex flex-wrap justify-center gap-2"
      initial="hidden"
      animate="visible"
      variants={{ visible: { transition: { staggerChildren: 0.08, delayChildren: 0.35 } } }}
    >
      {badges.map(([icon, label]) => (
        <motion.div
          key={label}
          variants={{ hidden: { opacity: 0, y: 8 }, visible: { opacity: 1, y: 0 } }}
          whileHover={{ y: -2 }}
          className="glass-panel inline-flex min-h-8 items-center gap-1.5 whitespace-nowrap rounded-full bg-white/20 px-2.5 py-1 shadow-[0_6px_18px_rgba(31,38,135,0.045)] backdrop-blur-[24px]"
        >
          <span className="material-symbols-outlined text-[12px] text-[#8d4b00]">{icon}</span>
          <span className="text-[9.5px] font-semibold uppercase leading-none tracking-[0.035em] text-[#554336]">{label}</span>
        </motion.div>
      ))}
    </motion.div>
  );
}

function SuccessState({ duplicate = false, deviceBlocked = false }) {
  const title = duplicate || deviceBlocked ? "You're already on the list." : 'Welcome to JourneySync!';
  const text = duplicate || deviceBlocked
    ? "We'll notify you as soon as beta access becomes available."
    : "You're officially on the beta waitlist. We'll notify you as soon as beta access becomes available.";

  return (
    <motion.div
      key="success"
      initial={{ opacity: 0, y: 18, scale: 0.97, filter: 'blur(10px)' }}
      animate={{ opacity: 1, y: 0, scale: 1, filter: 'blur(0px)' }}
      exit={{ opacity: 0, y: -16, scale: 0.98, filter: 'blur(8px)' }}
      transition={{ duration: 0.5, ease }}
      className="glass-panel flex w-full flex-col items-center rounded-[32px] p-8 text-center"
      role="status"
      aria-live="polite"
    >
      <motion.div
        className="relative mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-[#b15f00]/20 text-[#b15f00]"
        initial={{ scale: 0.72, rotate: -8 }}
        animate={{ scale: 1, rotate: 0 }}
        transition={{ type: 'spring', stiffness: 260, damping: 18 }}
      >
        <span className="material-symbols-outlined text-4xl">check_circle</span>
      </motion.div>
      <h3 className="mb-2 text-[24px] font-semibold leading-[1.3] text-[#121c2a]">{title}</h3>
      <p className="text-[16px] leading-[1.5] text-[#554336]">{text}</p>
    </motion.div>
  );
}

export default function BetaPage() {
  const shouldReduceMotion = useReducedMotion();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [status, setStatus] = useState('idle');
  const [submitting, setSubmitting] = useState(false);
  const startedRef = useRef(false);

  useEffect(() => {
    getDeviceId();
  }, []);

  useEffect(() => {
    document.body.classList.add('beta-page-lock');
    return () => {
      document.body.classList.remove('beta-page-lock');
    };
  }, []);

  function markStarted() {
    if (startedRef.current) return;
    startedRef.current = true;
    trackBetaEvent('beta_form_started');
  }

  function fireSuccessConfetti() {
    if (shouldReduceMotion) return;

    confetti({
      particleCount: 42,
      spread: 56,
      startVelocity: 28,
      scalar: 0.72,
      origin: { y: 0.58 },
      colors: ['#b15f00', '#ffb77d', '#ffdcc3'],
    });
  }

  async function handleSubmit(event) {
    event.preventDefault();

    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) {
      setError('Enter your email address.');
      return;
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      setError('Enter a valid email address.');
      return;
    }

    if (window.localStorage.getItem(REGISTERED_KEY) === 'true') {
      setStatus('device');
      trackBetaEvent('beta_duplicate', { reason: 'device_local' });
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Beta registration is not configured yet.');
      return;
    }

    setSubmitting(true);
    setError('');
    trackBetaEvent('beta_submit');

    const { error: dbError } = await supabase.from('beta_applications').insert({
      email: normalizedEmail,
      device_id: getDeviceId(),
      status: 'pending',
    });

    setSubmitting(false);

    if (dbError) {
      const message = dbError.message?.toLowerCase() ?? '';
      const isDuplicate = dbError.code === '23505' || dbError.status === 409 || message.includes('duplicate');
      if (isDuplicate) {
        const reason = message.includes('device') ? 'device' : 'email';
        setStatus(reason === 'device' ? 'device' : 'duplicate');
        trackBetaEvent('beta_duplicate', { reason });
        return;
      }

      setError('Something went wrong. Please try again.');
      return;
    }

    window.localStorage.setItem(REGISTERED_KEY, 'true');
    setStatus('success');
    trackBetaEvent('beta_success');
    fireSuccessConfetti();

    window.setTimeout(() => {
      window.location.href = '/beta/download';
    }, 2600);
  }

  return (
    <main className="relative flex h-[100svh] items-center justify-center overflow-hidden bg-[#f8f9ff] px-5 py-4 font-['Geist','Inter',sans-serif] text-[#121c2a] md:px-10">
      <BetaSeo />

      <div className="fixed inset-0 z-0">
        <ShaderBackground />
        <div className="beta-plus-grid absolute inset-0 pointer-events-none" aria-hidden="true" />
        <motion.div
          className="absolute -right-24 top-16 h-72 w-72 rounded-full bg-[#D97706]/10 blur-3xl"
          aria-hidden="true"
          animate={shouldReduceMotion ? undefined : { x: [0, -12, 0], y: [0, 10, 0] }}
          transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute -bottom-28 -left-24 h-80 w-80 rounded-full bg-[#214d2e]/10 blur-3xl"
          aria-hidden="true"
          animate={shouldReduceMotion ? undefined : { x: [0, 12, 0], y: [0, -10, 0] }}
          transition={{ duration: 11, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      <section className="beta-signup-wrapper relative z-10 mx-auto flex w-full flex-col items-center text-center">
        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 20, filter: 'blur(10px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.8, ease, delay: 0.1 }}
          className="mb-4 flex flex-col items-center gap-2.5"
        >
          <a
            href="/"
            aria-label="Return to JourneySync home"
            className="glass-panel beta-brand-pill"
          >
            <img src="/logo.png" alt="" className="h-7 w-7 rounded-[0.6rem] object-cover shadow-sm" />
            <span>JourneySync</span>
          </a>

          <div className="glass-panel beta-access-pill">
            Beta Access
          </div>
        </motion.div>

        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 20, filter: 'blur(10px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.8, ease, delay: 0.2 }}
          className="mb-5 space-y-2.5"
        >
          <h1 className="beta-signup-title">
            Join the JourneySync <span className="text-[#D97706]">Beta</span>
          </h1>
          <p className="mx-auto max-w-[360px] text-[15px] font-normal leading-[1.45] text-[#554336]">
            Become one of the first riders helping shape the future of group motorcycle riding.
          </p>
          <p className="mx-auto max-w-[310px] text-[13px] font-normal leading-[1.35] text-[#887364]">
            We're inviting a limited number of early riders before public launch.
          </p>
        </motion.div>

        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 20, filter: 'blur(10px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.8, ease, delay: 0.3 }}
          className="beta-form-shell relative w-full"
        >
          <AnimatePresence mode="wait">
            {status === 'success' || status === 'duplicate' || status === 'device' ? (
              <SuccessState duplicate={status === 'duplicate'} deviceBlocked={status === 'device'} />
            ) : (
              <motion.form
                key="form"
                className="flex w-full flex-col gap-4"
                onSubmit={handleSubmit}
                noValidate
                exit={{ opacity: 0, y: -18, filter: 'blur(10px)' }}
                transition={{ duration: 0.48, ease }}
              >
                <label className="sr-only" htmlFor="beta-email">Email address</label>
                <div className="group relative w-full">
                  <span className="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-[22px] text-[#dbc2b0] transition-colors group-focus-within:text-[#b15f00]">mail</span>
                  <input
                    id="beta-email"
                    type="email"
                    value={email}
                    onFocus={markStarted}
                    onChange={(event) => {
                      setEmail(event.target.value);
                      setError('');
                    }}
                    placeholder="Enter your email address"
                    required
                    autoComplete="email"
                    aria-invalid={Boolean(error)}
                    aria-describedby={error ? 'beta-email-error' : undefined}
                    className="beta-email-input"
                  />
                </div>

                {error && (
                  <motion.p
                    id="beta-email-error"
                    initial={{ opacity: 0, y: -4 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="text-left text-sm font-semibold text-red-600"
                  >
                    {error}
                  </motion.p>
                )}

                <motion.button
                  type="submit"
                  disabled={submitting}
                  whileHover={submitting || shouldReduceMotion ? undefined : { y: -2, scale: 1.01 }}
                  whileTap={submitting || shouldReduceMotion ? undefined : { scale: 0.98 }}
                  className="beta-submit-button button-glow group"
                >
                  <div className="absolute inset-0 translate-y-full bg-white/20 transition-transform duration-300 ease-out group-hover:translate-y-0" />
                  <span className="relative z-10 flex items-center gap-2">
                    {submitting ? (
                      <>
                        <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/45 border-t-white" aria-hidden="true" />
                        Joining...
                      </>
                    ) : (
                      <>
                        Join Beta
                        <span className="material-symbols-outlined transition-transform group-hover:translate-x-1">arrow_forward</span>
                      </>
                    )}
                  </span>
                </motion.button>
              </motion.form>
            )}
          </AnimatePresence>
        </motion.div>

        <TrustRow />
      </section>
    </main>
  );
}
