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
  { label: 'Group Riders', value: 480, suffix: '+', note: 'rider network goal' },
  { label: 'Beta Testers', value: 75, suffix: '+', note: 'founding cohort' },
  { label: 'Cities Covered', value: 12, suffix: '', note: 'India-first rollout' },
  { label: 'Countries', value: 1, suffix: '', note: 'built from Bengaluru' },
  { label: 'Hours of Testing', value: 300, suffix: '+', note: 'road + simulator checks' },
];

export function SocialProof() {
  return (
    <MotionSection id="beta-signal" className="py-14 bg-white/60 dark:bg-gray-900/80">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Beta Signal"
          title="Built for real riding groups, not solo navigation."
          copy="JourneySync is being shaped around the moments where group rides usually break down: junctions, fuel stops, weak coordination, and missing riders."
        />
        <motion.div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5" variants={container}>
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
  ['Emergency handling', 'A rider needs help, but the group has no shared safety context.'],
  ['No ride memory', 'After the ride, there is no replay, performance context, or shared record.'],
];

export function ProblemSolution() {
  return (
    <MotionSection id="problems" className="py-20 bg-background-light dark:bg-background-dark">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-[0.92fr_1.08fr] gap-10 items-start">
          <SectionHeader
            align="left"
            eyebrow="Problem to Solution"
            title="Group rides are social. Coordination should not be chaotic."
            copy="JourneySync gives every rider the same ride context before, during, and after the journey, so the group moves like one connected pack."
          />
          <motion.div className="relative space-y-4" variants={container}>
            <div className="absolute left-6 top-5 bottom-5 w-px bg-gradient-to-b from-primary via-primary/40 to-secondary/40" />
            {problems.map(([title, copy], index) => (
              <motion.article
                key={title}
                className="relative ml-0 pl-16 feature-card rounded-3xl p-5"
                variants={fadeUp}
              >
                <div className="absolute left-0 top-5 w-12 h-12 rounded-full bg-primary text-white grid place-items-center font-extrabold shadow-xl shadow-primary/25">
                  {index + 1}
                </div>
                <h3 className="font-extrabold text-gray-900 dark:text-white">{title}</h3>
                <p className="mt-2 text-sm text-gray-600 dark:text-gray-300">{copy}</p>
              </motion.article>
            ))}
            <motion.article className="relative ml-0 pl-16 rounded-3xl p-5 bg-background-dark text-white shadow-2xl" variants={fadeUp}>
              <div className="absolute left-0 top-5 w-12 h-12 rounded-full bg-secondary text-white grid place-items-center shadow-xl">
                <span className="material-icons-round">check</span>
              </div>
              <h3 className="font-extrabold">JourneySync solves all of these.</h3>
              <p className="mt-2 text-sm text-gray-300">One ride lobby, one shared route, live rider visibility, safety tools, and a ride record your group can trust.</p>
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
  ['Ride Radar', 'No', 'No', 'Nearby active rides'],
  ['Ride Coordination', 'No', 'Chat noise', 'Lobby + synced route'],
  ['SOS', 'No', 'Manual calls', 'Ride safety context'],
  ['Ride Replay', 'No', 'No', 'Planned ride history'],
  ['Ride Analytics', 'No', 'No', 'Distance and pack insights'],
  ['Achievements', 'No', 'No', 'Rider progression'],
  ['Weather', 'Basic search', 'No', 'Ride-aware context'],
  ['Fuel Stops', 'Search only', 'Chat only', 'Nearby essentials'],
  ['Group Management', 'No', 'Groups only', 'Ride crew state'],
];

export function Comparison() {
  return (
    <MotionSection
      id="comparison"
      className="py-20 bg-white/60 dark:bg-gray-900/80"
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
            <motion.article key={capability} className="feature-card rounded-3xl p-5" variants={fadeUp}>
              <h3 className="font-extrabold text-gray-900 dark:text-white">{capability}</h3>
              <div className="mt-4 grid gap-3 text-sm">
                <p><span className="font-bold">Google Maps:</span> {maps}</p>
                <p><span className="font-bold">WhatsApp:</span> {whatsapp}</p>
                <p className="text-primary"><span className="font-bold">JourneySync:</span> {js}</p>
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
      className="py-20 bg-background-light dark:bg-background-dark"
      onViewportEnter={() => trackEvent('demo_viewed')}
    >
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="relative overflow-hidden rounded-[2rem] bg-[#171717] text-white shadow-2xl download-glow">
          <div className="absolute inset-0 download-banner-glow pointer-events-none" />
          <div className="relative grid lg:grid-cols-[0.8fr_1.2fr] gap-8 items-center p-6 sm:p-10 lg:p-12">
            <SectionHeader
              align="left"
              eyebrow="Product Demo"
              title="See the ride layer in motion."
              copy="Watch how a group can start together, stay visible, and move through the ride with less coordination friction."
            />
            <motion.button
              type="button"
              data-demo-open
              data-video="./assets/demovideo.mp4"
              onClick={() => trackEvent('watch_demo', { source: 'demo_section' })}
              className="group relative aspect-video w-full overflow-hidden rounded-[2rem] border border-white/10 bg-black shadow-2xl"
              variants={fadeUp}
              aria-label="Watch JourneySync demo video"
            >
              <video className="h-full w-full object-cover opacity-80" preload="metadata" muted playsInline>
                <source src="./assets/demovideo.mp4" type="video/mp4" />
              </video>
              <span className="absolute inset-0 bg-black/20" />
              <span className="absolute inset-0 grid place-items-center">
                <span className="grid h-20 w-20 place-items-center rounded-full bg-white text-primary shadow-2xl transition-transform group-hover:scale-105">
                  <span className="material-icons-round text-4xl">play_arrow</span>
                </span>
              </span>
            </motion.button>
          </div>
        </div>
      </div>
    </MotionSection>
  );
}

export function BuiltByRiders() {
  return (
    <MotionSection id="built-by-riders" className="py-20 bg-background-light dark:bg-background-dark">
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
    location: 'Pune',
    quote: 'The hybrid Google Maps flow makes sense. I keep familiar navigation but the group stays visible.',
  },
  {
    name: 'Rohan Iyer',
    bike: 'Interceptor 650',
    location: 'Chennai',
    quote: 'This solves the exact junction problem every weekend ride has. Less calling, more riding.',
  },
  {
    name: 'Dev Shah',
    bike: 'Dominar 400',
    location: 'Mumbai',
    quote: 'The safety and SOS thinking makes JourneySync feel like a serious ride product, not a demo.',
  },
];

export function Testimonials() {
  return (
    <MotionSection id="testimonials" className="py-20 overflow-hidden bg-white/60 dark:bg-gray-900/80">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="Rider Feedback"
          title="What founding riders are asking for."
          copy="Placeholder beta testimonials are structured for future backend replacement."
        />
        <div className="overflow-hidden">
          <motion.div className="testimonial-track flex gap-5 w-max" variants={container}>
            {[...testimonials, ...testimonials].map((item, index) => (
              <motion.article key={`${item.name}-${index}`} className="testimonial-card w-[320px] rounded-3xl p-6" variants={fadeUp}>
                <div className="flex items-center gap-3">
                  <div className="h-12 w-12 rounded-full bg-primary text-white grid place-items-center font-extrabold">
                    {item.name.split(' ').map((part) => part[0]).join('')}
                  </div>
                  <div>
                    <h3 className="font-extrabold text-gray-900 dark:text-white">{item.name}</h3>
                    <p className="text-xs text-gray-500">{item.location} · {item.bike}</p>
                  </div>
                </div>
                <div className="mt-4 flex text-primary" aria-label="5 out of 5 rating">
                  {'★★★★★'}
                </div>
                <p className="mt-4 text-gray-700 dark:text-gray-200 leading-relaxed">“{item.quote}”</p>
              </motion.article>
            ))}
          </motion.div>
        </div>
      </div>
    </MotionSection>
  );
}

const faqs = [
  ['Is JourneySync free?', 'JourneySync is currently focused on closed beta riders. Core ride coordination is planned to stay accessible while premium capabilities evolve from rider feedback.'],
  ['Does it replace Google Maps?', 'No. JourneySync uses a hybrid flow: Google Maps handles turn-by-turn navigation while JourneySync maintains group ride state, tracking, and safety context.'],
  ['Why not just use WhatsApp?', 'WhatsApp is great for chat, but it does not know who missed a turn, where the pack is, what the route state is, or whether a rider needs help.'],
  ['Does everyone need the app?', 'For the best experience, every rider should join the lobby. The ride can still start with a smaller crew and expand as riders join.'],
  ['How much battery does it consume?', 'The beta is being tuned for practical ride sessions with location updates balanced against battery impact.'],
  ['How accurate is tracking?', 'Accuracy depends on device GPS, network conditions, and permissions. JourneySync surfaces ride context instead of pretending every point is perfect.'],
  ['Is my location private?', 'Ride location is designed around active ride context. Privacy and permission controls are a core part of the beta roadmap.'],
  ['Can I use it on iPhone?', 'iOS support is planned through the beta path. Android APK access is available first.'],
  ['How do I join beta?', 'Use Join Closed Beta or the final CTA. We will use the beta list to prioritize active riders and groups.'],
];

export function Faq() {
  return (
    <MotionSection id="faq" className="py-20 bg-background-light dark:bg-background-dark">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <SectionHeader
          eyebrow="FAQ"
          title="Answers before you join the beta."
        />
        <motion.div className="space-y-4" variants={container}>
          {faqs.map(([question, answer]) => (
            <motion.article key={question} className="faq-item rounded-3xl p-5" variants={fadeUp}>
              <button
                className="faq-toggle w-full flex items-center justify-between gap-4 text-left"
                aria-expanded="false"
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
