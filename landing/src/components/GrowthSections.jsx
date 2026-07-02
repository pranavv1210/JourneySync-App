import { useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { trackEvent } from '../utils/tracking';

const fadeUp = {
  hidden: { opacity: 0, y: 28, filter: 'blur(10px)' },
  visible: { opacity: 1, y: 0, filter: 'blur(0px)' },
};

const container = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.08 },
  },
};

function MotionSection({ id, className = '', children, onViewportEnter }) {
  const reduced = useReducedMotion();

  return (
    <motion.section
      id={id}
      className={`section-reveal ${className}`}
      initial={reduced ? false : 'hidden'}
      whileInView="visible"
      viewport={{ once: true, amount: 0.16 }}
      variants={container}
      onViewportEnter={onViewportEnter}
    >
      {children}
    </motion.section>
  );
}

function SectionHeader({ eyebrow, title, copy, align = 'center' }) {
  const centered = align === 'center';

  return (
    <motion.div
      className={`${centered ? 'mx-auto text-center' : ''} mb-10 max-w-3xl`}
      variants={fadeUp}
    >
      <span className="text-primary font-bold uppercase tracking-wider text-sm">{eyebrow}</span>
      <h2 className="mt-3 text-3xl md:text-4xl font-extrabold text-gray-900 dark:text-white">
        {title}
      </h2>
      {copy ? (
        <p className="mt-4 text-gray-600 dark:text-gray-300 text-lg leading-relaxed">{copy}</p>
      ) : null}
    </motion.div>
  );
}

const stats = [
  { label: 'Rides Coordinated', value: 120, suffix: '+', note: 'closed beta target' },
  { label: 'Beta Testers', value: 75, suffix: '+', note: 'founding cohort' },
  { label: 'Cities Covered', value: 12, suffix: '', note: 'India-first rollout' },
  { label: 'Hours of Testing', value: 300, suffix: '+', note: 'road + simulator checks' },
];

export function SocialProof() {
  return (
    <MotionSection id="beta-signal" className="pt-14 pb-20 md:pt-16 md:pb-24 bg-white/60 dark:bg-gray-900/80">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Beta Signal"
          title="Built for real riding groups, not solo navigation."
          copy="JourneySync is being shaped around the moments where group rides usually break down: junctions, fuel stops, weak coordination, and missing riders."
        />
        <motion.div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-5" variants={container}>
          {stats.map((stat) => (
            <motion.article
              key={stat.label}
              className="liquid-glass stat-entrance rounded-3xl p-6 border border-white/10"
              variants={fadeUp}
            >
              <div className="flex items-end gap-1 text-4xl font-extrabold text-gray-900 dark:text-white">
                <span className="stat-number" data-count={stat.value}>0</span>
                <span className="text-primary">{stat.suffix}</span>
              </div>
              <h3 className="mt-3 font-bold text-gray-900 dark:text-white">{stat.label}</h3>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">{stat.note}</p>
            </motion.article>
          ))}
        </motion.div>
      </div>
    </MotionSection>
  );
}

const problems = [
  ['Getting separated', 'The group stretches out and riders disappear after traffic lights or turns.'],
  ['Waiting at junctions', 'Leads stop repeatedly because nobody knows who missed the turn.'],
  ['No live visibility', 'WhatsApp messages arrive late and maps only solve individual navigation.'],
];

export function ProblemSolution() {
  return (
    <MotionSection id="problems" className="pt-20 pb-16 md:pt-24 md:pb-20 bg-background-light dark:bg-background-dark">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-[0.92fr_1.08fr] gap-10 items-start">
          <SectionHeader
            align="left"
            eyebrow="Problem to Solution"
            title="Group rides are social. Coordination should not be chaotic."
            copy="JourneySync gives every rider the same ride context before, during, and after the journey, so the group moves like one connected pack."
          />
          <motion.div className="space-y-4" variants={container}>
            {problems.map(([title, copy], index) => (
              <motion.article
                key={title}
                className="feature-card rounded-3xl p-5"
                variants={fadeUp}
              >
                <div className="flex items-start gap-4">
                  <div className="grid h-10 w-10 flex-none place-items-center rounded-full bg-primary text-white font-extrabold shadow-xl shadow-primary/25">
                    {index + 1}
                  </div>
                  <div>
                    <h3 className="font-extrabold text-gray-900 dark:text-white">{title}</h3>
                    <p className="mt-2 text-sm text-gray-600 dark:text-gray-300">{copy}</p>
                  </div>
                </div>
              </motion.article>
            ))}
            <motion.article className="rounded-3xl p-5 bg-background-dark text-white shadow-2xl" variants={fadeUp}>
              <div className="flex items-start gap-4">
                <div className="grid h-10 w-10 flex-none place-items-center rounded-full bg-secondary text-white shadow-xl">
                  <span className="material-icons-round">check</span>
                </div>
                <div>
                  <h3 className="font-extrabold">JourneySync solves all of these.</h3>
                  <p className="mt-2 text-sm text-gray-300">One ride lobby, one shared route, live rider visibility, safety tools, and a ride record your group can trust.</p>
                </div>
              </div>
            </motion.article>
          </motion.div>
        </div>
      </div>
    </MotionSection>
  );
}

const comparisonRows = [
  ['Navigation', 'Good', 'Links only', 'Hybrid Google Maps flow'],
  ['Live Tracking', 'Individual', 'Manual sharing', 'Built for the group'],
  ['Ride Coordination', 'No', 'Chat noise', 'Lobby + synced route'],
  ['SOS', 'No', 'Manual calls', 'Ride safety context'],
  ['Weather + Fuel', 'Search only', 'Chat only', 'Ride-aware essentials'],
  ['Group Management', 'No', 'Groups only', 'Ride crew state'],
];

export function Comparison() {
  return (
    <MotionSection
      id="comparison"
      className="py-16 bg-white/60 dark:bg-gray-900/80"
      onViewportEnter={() => trackEvent('comparison_viewed')}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Why JourneySync"
          title="Maps navigate. Chats notify. JourneySync coordinates the ride."
          copy="Riders already use Google Maps and WhatsApp. JourneySync is the missing ride layer that connects navigation, safety, and group state."
        />
        <motion.div className="hidden md:block overflow-hidden rounded-3xl border border-white/40 shadow-2xl bg-white/60 backdrop-blur-xl" variants={fadeUp}>
          <table className="w-full text-left">
            <thead className="bg-background-dark text-white">
              <tr>
                <th className="p-5 text-sm uppercase tracking-wider">Capability</th>
                <th className="p-5 text-sm uppercase tracking-wider">Google Maps</th>
                <th className="p-5 text-sm uppercase tracking-wider">WhatsApp</th>
                <th className="p-5 text-sm uppercase tracking-wider text-primary">JourneySync</th>
              </tr>
            </thead>
            <tbody>
              {comparisonRows.map(([capability, maps, whatsapp, js]) => (
                <tr key={capability} className="border-t border-gray-200/70">
                  <td className="p-5 font-bold text-gray-900">{capability}</td>
                  <td className="p-5 text-gray-600">{maps}</td>
                  <td className="p-5 text-gray-600">{whatsapp}</td>
                  <td className="p-5 font-bold text-gray-900">{js}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </motion.div>
        <motion.div className="md:hidden space-y-4" variants={container}>
          {comparisonRows.map(([capability, maps, whatsapp, js]) => (
            <motion.article key={capability} className="feature-card rounded-2xl p-4" variants={fadeUp}>
              <h3 className="text-sm font-extrabold uppercase tracking-wide text-gray-900 dark:text-white">{capability}</h3>
              <div className="mt-4 grid gap-2 text-sm">
                <div className="rounded-xl bg-white/60 p-3">
                  <span className="block text-xs font-extrabold uppercase tracking-wide text-gray-500">Google Maps</span>
                  <span className="mt-1 block text-gray-800">{maps}</span>
                </div>
                <div className="rounded-xl bg-white/60 p-3">
                  <span className="block text-xs font-extrabold uppercase tracking-wide text-gray-500">WhatsApp</span>
                  <span className="mt-1 block text-gray-800">{whatsapp}</span>
                </div>
                <div className="rounded-xl bg-primary/10 p-3">
                  <span className="block text-xs font-extrabold uppercase tracking-wide text-primary">JourneySync</span>
                  <span className="mt-1 block font-bold text-gray-900">{js}</span>
                </div>
              </div>
            </motion.article>
          ))}
        </motion.div>
      </div>
    </MotionSection>
  );
}

export function DemoSection() {
  return (
    <MotionSection
      id="demo"
      className="py-14 bg-background-light dark:bg-background-dark"
      onViewportEnter={() => trackEvent('demo_viewed')}
    >
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="relative overflow-hidden rounded-[2rem] bg-[#171717] text-white shadow-2xl download-glow">
          <div className="absolute inset-0 download-banner-glow pointer-events-none" />
          <div className="relative grid lg:grid-cols-2 gap-6 lg:gap-8 items-center p-6 sm:p-8 lg:p-10">
            <SectionHeader
              align="left"
              eyebrow="Product Demo"
              title="See the ride layer in motion."
              copy="Watch how a group can start together, stay visible, and move through the ride with less coordination friction."
            />
            <motion.div
              className="relative aspect-video w-full lg:max-w-md lg:justify-self-end overflow-hidden rounded-[1.25rem] border border-white/10 bg-black shadow-2xl"
              variants={fadeUp}
              aria-label="JourneySync demo video"
            >
              <video
                className="h-full w-full object-cover opacity-95"
                preload="metadata"
                muted
                playsInline
                autoPlay
                loop
                aria-label="JourneySync product demo preview"
                onPlay={() => trackEvent('demo_viewed', { source: 'inline_autoplay' })}
              >
                <source src="./assets/demovideo.mp4" type="video/mp4" />
              </video>
            </motion.div>
          </div>
        </div>
      </div>
    </MotionSection>
  );
}

export function BuiltByRiders() {
  return (
    <MotionSection id="built-by-riders" className="py-16 bg-background-light dark:bg-background-dark">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-10 items-center">
          <SectionHeader
            align="left"
            eyebrow="Startup Story"
            title="Built by Riders. For Riders."
            copy="Every group ride starts with excitement. Then someone misses a turn, someone gets left behind, someone stops for fuel, and the whole group starts coordinating through calls and chat."
          />
          <motion.div className="feature-card rounded-[2rem] p-6 sm:p-8" variants={fadeUp}>
            <div className="grid gap-4">
              {[
                'JourneySync was built from those real ride moments.',
                'The goal is simple: help riding groups stay connected without replacing the tools riders already trust.',
                'Google Maps still handles navigation. JourneySync handles the ride layer around it.',
              ].map((copy) => (
                <div key={copy} className="flex gap-3">
                  <span className="material-icons-round text-primary">two_wheeler</span>
                  <p className="text-gray-700 dark:text-gray-300 leading-relaxed">{copy}</p>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </div>
    </MotionSection>
  );
}

const testimonials = [
  {
    name: 'Aarav Menon',
    bike: 'Royal Enfield Himalayan',
    location: 'Bengaluru',
    quote: 'Ride Radar is the first thing that made group discovery feel practical instead of random.',
  },
  {
    name: 'Nisha Rao',
    bike: 'KTM Duke 390',
    location: 'Bengaluru',
    quote: 'The hybrid Google Maps flow makes sense. I keep familiar navigation but the group stays visible.',
  },
  {
    name: 'Rohan Iyer',
    bike: 'Interceptor 650',
    location: 'Bengaluru',
    quote: 'This solves the exact junction problem every weekend ride has. Less calling, more riding.',
  },
  {
    name: 'Dev Gowda',
    bike: 'Dominar 400',
    location: 'Bengaluru',
    quote: 'The safety and SOS thinking makes JourneySync feel like a serious ride product, not a demo.',
  },
];

export function Testimonials() {
  return (
    <MotionSection id="testimonials" className="py-16 overflow-hidden bg-white/60 dark:bg-gray-900/80">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Rider Feedback"
          title="What founding riders are asking for."
          copy="Short beta signals from Bengaluru riders who understand the group-ride problem."
        />
        <motion.div className="grid md:grid-cols-3 gap-5" variants={container}>
          {testimonials.slice(0, 3).map((item) => (
            <motion.article key={item.name} className="testimonial-card rounded-3xl p-6" variants={fadeUp}>
              <div className="flex items-center gap-3">
                <div className="h-12 w-12 rounded-full bg-primary text-white grid place-items-center font-extrabold">
                  {item.name.split(' ').map((part) => part[0]).join('')}
                </div>
                <div>
                  <h3 className="font-extrabold text-gray-900 dark:text-white">{item.name}</h3>
                  <p className="text-xs text-gray-500">{item.location} - {item.bike}</p>
                </div>
              </div>
              <div className="mt-4 flex text-primary" aria-label="5 out of 5 rating">
                {Array.from({ length: 5 }).map((_, index) => (
                  <span key={index} className="material-icons-round text-base">star</span>
                ))}
              </div>
              <p className="mt-4 text-gray-700 dark:text-gray-200 leading-relaxed">"{item.quote}"</p>
            </motion.article>
          ))}
        </motion.div>
      </div>
    </MotionSection>
  );
}
const faqs = [
  ['Does it replace Google Maps?', 'No. JourneySync uses a hybrid flow: Google Maps handles turn-by-turn navigation while JourneySync maintains group ride state, tracking, and safety context.'],
  ['Why not just use WhatsApp?', 'WhatsApp is great for chat, but it does not know who missed a turn, where the pack is, what the route state is, or whether a rider needs help.'],
  ['Does everyone need the app?', 'For the best experience, every rider should join the lobby. The ride can still start with a smaller crew and expand as riders join.'],
  ['Is my location private?', 'Ride location is designed around active ride context. Privacy and permission controls are a core part of the beta roadmap.'],
  ['How do I join beta?', 'Use Join Closed Beta or the final CTA. We will use the beta list to prioritize active riders and groups.'],
];

export function Faq() {
  const [openQuestion, setOpenQuestion] = useState(null);

  return (
    <MotionSection id="faq" className="py-16 bg-background-light dark:bg-background-dark">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="FAQ"
          title="Answers before you join the beta."
        />
        <motion.div className="space-y-4" variants={container}>
          {faqs.map(([question, answer]) => (
            <motion.article
              key={question}
              className={`faq-item rounded-3xl p-5 ${openQuestion === question ? 'open' : ''}`}
              variants={fadeUp}
            >
              <button
                className="faq-toggle w-full flex items-center justify-between gap-4 text-left"
                aria-expanded={openQuestion === question}
                onClick={() => {
                  const next = openQuestion === question ? null : question;
                  setOpenQuestion(next);
                  if (next) trackEvent('faq_expand', { question });
                }}
              >
                <span className="font-extrabold text-gray-900 dark:text-white">{question}</span>
                <span className="material-icons-round text-primary">expand_more</span>
              </button>
              <div className="faq-answer text-gray-600 dark:text-gray-300">{answer}</div>
            </motion.article>
          ))}
        </motion.div>
      </div>
    </MotionSection>
  );
}

export function BetaDownloadModal() {
  return (
    <div
      id="download-modal"
      className="fixed inset-0 z-[99999] hidden flex items-center justify-center px-4 py-8"
      aria-hidden="true"
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/70"
        data-close-download
        aria-label="Close beta download modal"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="download-modal-title"
        className="relative w-full max-w-md overflow-hidden rounded-[2rem] border border-white/15 bg-[#171717] p-6 text-white shadow-2xl"
      >
        <button
          type="button"
          className="absolute right-4 top-4 grid h-10 w-10 place-items-center rounded-full bg-white/10 text-white transition-colors hover:bg-white/15"
          data-close-download
          aria-label="Close"
        >
          <span className="material-icons-round">close</span>
        </button>
        <div className="pr-10">
          <span className="text-primary text-xs font-extrabold uppercase tracking-wider">
            Closed Beta
          </span>
          <h2 id="download-modal-title" className="mt-3 text-2xl font-extrabold leading-tight">
            Download the Android beta build.
          </h2>
          <p className="mt-4 text-sm leading-relaxed text-gray-300">
            This is an early rider test build for active groups. Install it only if you are comfortable testing beta software and sharing feedback.
          </p>
        </div>
        <div className="mt-6 grid gap-3 rounded-2xl border border-white/10 bg-white/5 p-4 text-sm text-gray-300">
          <div className="flex items-start gap-3">
            <span className="material-icons-round text-primary text-lg">android</span>
            <span>Android beta APK is available now.</span>
          </div>
          <div className="flex items-start gap-3">
            <span className="material-icons-round text-primary text-lg">verified_user</span>
            <span>Ride carefully and do not interact with the app while moving.</span>
          </div>
          <div className="flex items-start gap-3">
            <span className="material-icons-round text-primary text-lg">feedback</span>
            <span>Feedback from Bengaluru rider groups will shape the next build.</span>
          </div>
        </div>
        <div className="mt-6 grid gap-3">
          <a
            href="./journeysync.apk"
            download
            className="flex items-center justify-center gap-2 rounded-xl bg-primary-dark px-5 py-3.5 font-bold text-white shadow-xl shadow-primary/25 transition-transform hover:-translate-y-0.5"
          >
            <span className="material-icons-round">download</span>
            Download Android Beta
          </a>
          <a
            href="mailto:journeysync.app@gmail.com?subject=JourneySync%20closed%20beta%20access"
            className="flex items-center justify-center gap-2 rounded-xl border border-white/15 bg-white/5 px-5 py-3.5 font-bold text-white transition-colors hover:bg-white/10"
          >
            <span className="material-icons-round">mail</span>
            Request Beta Access
          </a>
        </div>
      </div>
    </div>
  );
}

export function LegalInfoModal() {
  return (
    <div
      id="legal-modal"
      className="fixed inset-0 z-[99999] hidden items-center justify-center px-4 py-6 sm:py-8"
      aria-hidden="true"
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        data-close
        aria-label="Close information modal"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="legal-title"
        className="relative max-h-[88vh] w-full max-w-2xl overflow-hidden rounded-[2rem] shadow-2xl"
        style={{
          background: 'linear-gradient(135deg, rgba(255,255,255,.82), rgba(255,255,255,.52))',
          backdropFilter: 'blur(24px) saturate(1.4)',
          WebkitBackdropFilter: 'blur(24px) saturate(1.4)',
          border: '1px solid rgba(255,255,255,.5)',
          boxShadow: '0 24px 80px rgba(31,25,18,.15), inset 0 1px 0 rgba(255,255,255,.6)',
        }}
      >
        {/* Header */}
        <div
          className="flex items-center justify-between gap-4 px-6 py-5 sm:px-8"
          style={{
            borderBottom: '1px solid rgba(219,119,6,.12)',
            background: 'linear-gradient(135deg, rgba(219,119,6,.06), transparent 60%)',
          }}
        >
          <div className="flex items-center gap-3">
            <div className="grid h-10 w-10 flex-none place-items-center rounded-xl bg-primary/10 text-primary">
              <span className="material-icons-round text-xl">gavel</span>
            </div>
            <h2 id="legal-title" className="text-xl font-extrabold text-gray-900 sm:text-2xl">Info</h2>
          </div>
          <button
            id="legal-close"
            type="button"
            className="grid h-10 w-10 flex-none place-items-center rounded-full text-gray-500 transition-all duration-200 hover:bg-gray-900/5 hover:text-gray-800"
            style={{
              background: 'linear-gradient(135deg, rgba(255,255,255,.6), rgba(255,255,255,.3))',
              border: '1px solid rgba(255,255,255,.5)',
            }}
            aria-label="Close"
          >
            <span className="material-icons-round text-xl">close</span>
          </button>
        </div>
        {/* Body */}
        <div
          id="legal-content"
          className="legal-content-scroll max-h-[68vh] overflow-y-auto px-6 py-5 sm:px-8 sm:py-6 text-sm leading-relaxed text-gray-600"
        />
        <style dangerouslySetInnerHTML={{ __html: `
          .legal-content-scroll::-webkit-scrollbar { width: 6px; }
          .legal-content-scroll::-webkit-scrollbar-track { background: transparent; }
          .legal-content-scroll::-webkit-scrollbar-thumb { background: rgba(219,119,6,.2); border-radius: 999px; }
          .legal-content-scroll::-webkit-scrollbar-thumb:hover { background: rgba(219,119,6,.35); }
          .legal-content-scroll { scrollbar-width: thin; scrollbar-color: rgba(219,119,6,.2) transparent; }
          .legal-content-scroll h5 { font-size: 1.125rem; font-weight: 800; color: #1a1a1a; margin-bottom: .5rem; }
          .legal-content-scroll ul { list-style-type: disc; margin-left: 1.25rem; }
          .legal-content-scroll li { margin-bottom: .35rem; }
          .legal-content-scroll a { color: #db7706; text-decoration: underline; text-underline-offset: 3px; }
          .legal-content-scroll a:hover { color: #b45f04; }
          .legal-content-scroll pre { font-family: inherit; }
          .legal-content-scroll .legal-section { margin-bottom: 1.5rem; padding-bottom: 1.5rem; border-bottom: 1px solid rgba(0,0,0,.06); }
          .legal-content-scroll .legal-section:last-child { border-bottom: none; margin-bottom: 0; padding-bottom: 0; }
          .legal-content-scroll .legal-heading { font-size: .8125rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; color: #db7706; margin-bottom: .5rem; }
          .legal-content-scroll .legal-meta { display: inline-flex; align-items: center; gap: .5rem; padding: .375rem .75rem; border-radius: 9999px; background: rgba(219,119,6,.08); color: #b45f04; font-size: .75rem; font-weight: 700; margin-bottom: 1rem; }
          .legal-content-scroll iframe { border-radius: 1rem; border: 1px solid rgba(0,0,0,.08) !important; }
        ` }} />
      </div>
    </div>
  );
}
