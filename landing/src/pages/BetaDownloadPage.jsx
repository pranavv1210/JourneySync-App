import { useEffect } from 'react';
import { motion, useReducedMotion } from 'framer-motion';

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

function BetaDownloadSeo() {
  useEffect(() => {
    const canonical = 'https://journeysyncrideapp.in/beta/download';
    document.title = 'Download JourneySync Beta';
    setMetaTag('description', 'Download the official JourneySync Beta for Android.');
    setCanonical(canonical);
  }, []);

  return null;
}

const glassCard = {
  background: 'linear-gradient(135deg, rgba(255,255,255,.72), rgba(255,255,255,.36))',
  backdropFilter: 'blur(22px) saturate(1.32)',
  WebkitBackdropFilter: 'blur(22px) saturate(1.32)',
  border: '1px solid rgba(255,255,255,.42)',
  boxShadow: '0 14px 45px rgba(31,25,18,.08), inset 0 1px 0 rgba(255,255,255,.58)',
};

const infoPill = {
  background: 'linear-gradient(135deg, rgba(255,255,255,.68), rgba(255,255,255,.32))',
  backdropFilter: 'blur(18px) saturate(1.2)',
  WebkitBackdropFilter: 'blur(18px) saturate(1.2)',
  border: '1px solid rgba(255,255,255,.5)',
  boxShadow: '0 8px 28px rgba(31,25,18,.05), inset 0 1px 0 rgba(255,255,255,.5)',
};

export default function BetaDownloadPage() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <main className="relative min-h-screen overflow-hidden text-gray-900" style={{
      background: 'radial-gradient(circle at 12% 8%, rgba(219,119,6,.16), transparent 30rem), radial-gradient(circle at 86% 16%, rgba(21,128,61,.11), transparent 28rem), linear-gradient(135deg, #fbf7f1 0%, #f4efea 42%, #fffaf3 100%)',
    }}>
      <BetaDownloadSeo />

      {/* Map texture overlay */}
      <div className="absolute inset-0 map-texture opacity-50" aria-hidden="true" />

      {/* Animated mesh blobs */}
      <motion.div
        className="absolute -top-28 right-[-10rem] h-[340px] w-[340px] rounded-full opacity-50 pointer-events-none"
        style={{ background: 'rgba(219,119,6,.30)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, 28, 0], x: [0, -20, 0] }}
        transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
      />
      <motion.div
        className="absolute bottom-[-10rem] left-[-8rem] h-[380px] w-[380px] rounded-full opacity-40 pointer-events-none"
        style={{ background: 'rgba(21,128,61,.22)', filter: 'blur(42px)' }}
        aria-hidden="true"
        animate={shouldReduceMotion ? undefined : { y: [0, -28, 0], x: [0, 20, 0] }}
        transition={{ duration: 14, repeat: Infinity, ease: 'easeInOut' }}
      />

      <section className="relative z-10 flex min-h-screen flex-col items-center justify-center px-4 py-12 sm:px-6 lg:px-8">
        
        {/* Logo Header */}
        <motion.a
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          href="/"
          className="mb-8 inline-flex items-center gap-2.5 rounded-full px-5 py-2.5 text-sm font-bold text-gray-700 transition-all duration-300 hover:text-primary hover:-translate-y-0.5"
          style={infoPill}
        >
          <img src="/logo.png" alt="JourneySync" className="h-8 w-8 rounded-lg object-cover shadow-sm" />
          JourneySync
        </motion.a>

        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 28, filter: 'blur(12px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          className="w-full max-w-2xl"
        >
          <div className="relative overflow-hidden rounded-[2.5rem] p-8 sm:p-10 lg:p-12 text-center" style={glassCard}>
            {/* Decorative radial highlight */}
            <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_0%,rgba(219,119,6,0.1),transparent_40%),linear-gradient(135deg,rgba(255,255,255,0.4),transparent_50%)]" aria-hidden="true" />

            <div className="relative">
              <span className="inline-flex items-center gap-2 rounded-full bg-primary/10 px-4 py-2 text-xs font-extrabold uppercase tracking-[0.18em] text-primary mb-6">
                <span className="material-icons-round text-sm">verified</span>
                Access Granted
              </span>

              <h1 className="text-3xl font-extrabold leading-[1.1] tracking-tight text-gray-900 sm:text-4xl lg:text-[2.75rem] mb-4">
                Download <span className="text-primary">JourneySync Beta</span>
              </h1>

              <p className="mx-auto max-w-lg text-base leading-relaxed text-gray-600 sm:text-lg mb-10">
                You're officially on the beta list. Android can install the APK now; iOS access will open through TestFlight.
              </p>

              {/* Download Grid */}
              <div className="grid gap-4 sm:grid-cols-2">
                
                {/* Android Download Card */}
                <div className="relative flex flex-col items-center justify-between overflow-hidden rounded-3xl p-6 text-left transition-all duration-300 hover:shadow-2xl hover:shadow-primary/10"
                  style={{
                    background: 'linear-gradient(135deg, rgba(255,255,255,.9), rgba(255,255,255,.6))',
                    backdropFilter: 'blur(16px)',
                    border: '1px solid rgba(255,255,255,.7)',
                    boxShadow: '0 4px 20px rgba(0,0,0,.03)'
                  }}>
                  <div className="w-full">
                    <div className="mb-4 flex items-center justify-between">
                      <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-green-500/10 text-green-600">
                        <span className="material-icons-round text-2xl">android</span>
                      </span>
                      <span className="rounded-full bg-green-500/10 px-2.5 py-1 text-xs font-bold uppercase tracking-wider text-green-600">
                        v1.1.1
                      </span>
                    </div>
                    <h3 className="mb-1 text-lg font-extrabold text-gray-900">Android Beta</h3>
                    <p className="mb-2 text-sm font-medium text-gray-500">Requires Android 8.0+</p>
                    <p className="mb-6 text-xs font-semibold leading-relaxed text-gray-500">
                      If Gmail stalls at 100%, open this page in Chrome and install from there.
                    </p>
                  </div>
                  <a
                    href="/journeysync.apk"
                    download
                    className="premium-btn glow-pulse flex w-full items-center justify-center gap-2 rounded-xl bg-primary-dark px-4 py-3.5 text-sm font-extrabold text-white shadow-lg shadow-primary/25 transition-all duration-300 hover:-translate-y-0.5 hover:bg-[#8f4a03]"
                  >
                    <span className="material-icons-round text-lg">download</span>
                    Download APK
                  </a>
                </div>

                {/* iOS Status Card */}
                <div className="relative flex flex-col items-center justify-between overflow-hidden rounded-3xl p-6 text-left opacity-75 grayscale-[30%] transition-all duration-300 hover:grayscale-0"
                  style={{
                    background: 'linear-gradient(135deg, rgba(255,255,255,.6), rgba(255,255,255,.3))',
                    backdropFilter: 'blur(16px)',
                    border: '1px solid rgba(255,255,255,.4)',
                    boxShadow: '0 4px 20px rgba(0,0,0,.02)'
                  }}>
                  <div className="w-full">
                    <div className="mb-4 flex items-center justify-between">
                      <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gray-900/5 text-gray-700">
                        <span className="material-icons-round text-2xl">phone_iphone</span>
                      </span>
                      <span className="rounded-full bg-gray-900/5 px-2.5 py-1 text-xs font-bold uppercase tracking-wider text-gray-500">
                        Planned
                      </span>
                    </div>
                    <h3 className="mb-1 text-lg font-extrabold text-gray-900">iOS Beta</h3>
                    <p className="mb-6 text-sm font-medium text-gray-500">Your iOS interest is saved when you choose iOS on the beta form.</p>
                  </div>
                  <a
                    href="mailto:journeysync.app@gmail.com?subject=JourneySync%20iOS%20TestFlight%20access"
                    className="flex w-full items-center justify-center gap-2 rounded-xl border border-gray-900/10 bg-white/70 px-4 py-3.5 text-sm font-bold text-gray-700 transition-all duration-300 hover:-translate-y-0.5 hover:bg-white"
                  >
                    <span className="material-icons-round text-lg">mail</span>
                    Request TestFlight
                  </a>
                </div>
              </div>

              {/* Release Notes */}
              <div className="mt-8 rounded-2xl p-5 text-left" style={infoPill}>
                <h4 className="mb-3 flex items-center gap-2 text-sm font-bold text-gray-900">
                  <span className="material-icons-round text-primary text-base">new_releases</span>
                  What's new in v1.1.1
                </h4>
                <ul className="space-y-2 text-sm text-gray-600">
                  <li className="flex items-start gap-2">
                    <span className="mt-1 block h-1.5 w-1.5 rounded-full bg-primary/60 shrink-0" />
                    Updated Android beta package for more reliable installation.
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="mt-1 block h-1.5 w-1.5 rounded-full bg-primary/60 shrink-0" />
                    Ride Radar, ride creation, and in-app feedback improvements.
                  </li>
                  <li className="flex items-start gap-2">
                    <span className="mt-1 block h-1.5 w-1.5 rounded-full bg-primary/60 shrink-0" />
                    Latest APK is always available from this landing page.
                  </li>
                </ul>
              </div>

              <div className="mt-8 rounded-3xl bg-[#171717] p-6 text-left text-white shadow-2xl shadow-primary/10">
                <p className="text-xs font-extrabold uppercase tracking-[0.18em] text-primary">
                  Download fallback
                </p>
                <h2 className="mt-3 text-2xl font-extrabold tracking-tight">
                  If Gmail gets stuck, download from here.
                </h2>
                <p className="mt-3 text-sm leading-relaxed text-gray-300">
                  Open this page in Chrome and tap the button below. Keep this page bookmarked because the same link will always point to the latest Android beta APK.
                </p>
                <a
                  href="/journeysync.apk"
                  download
                  className="mt-5 flex w-full items-center justify-center gap-2 rounded-xl bg-primary-dark px-5 py-4 text-sm font-extrabold text-white shadow-xl shadow-primary/25 transition-all duration-300 hover:-translate-y-0.5 hover:bg-[#8f4a03]"
                >
                  <span className="material-icons-round">download</span>
                  Download Latest Android APK
                </a>
              </div>

            </div>
          </div>
        </motion.div>
      </section>
    </main>
  );
}
