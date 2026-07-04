import { lazy, Suspense, useState, useEffect } from 'react';
import './index.css';
import {
  DownloadBanner,
  Features,
  FinalCta,
  FooterAndModals,
  Hero,
  Navbar,
  Safety,
  ShellChrome,
} from './components/LandingSections';
import {
  BuiltByRiders,
  BetaDownloadModal,
  Comparison,
  DemoSection,
  Faq,
  ProblemSolution,
  SocialProof,
  Testimonials as GrowthTestimonials,
} from './components/GrowthSections';
import { useLandingRuntime } from './hooks/useLandingRuntime';
import { JoinBetaModal } from './components/JoinBetaModal';
import { InfoModal } from './components/InfoModal';

const BetaDownloadPage = lazy(() => import('./pages/BetaDownloadPage.jsx'));

function LandingPage() {
  useLandingRuntime();

  return (
    <>
      <ShellChrome />
      <Navbar />
      <main>
        <Hero />
        <SocialProof />
        <ProblemSolution />
        <Features />
        <Comparison />
        <DemoSection />
        <BuiltByRiders />
        <Safety />
        <DownloadBanner />
        <GrowthTestimonials />
        <Faq />
        <FinalCta />
      </main>
      <FooterAndModals />
      <BetaDownloadModal />
    </>
  );
}

function PageFallback() {
  return (
    <main className="grid min-h-screen place-items-center bg-background-light px-4 text-center">
      <div className="liquid-glass rounded-3xl border border-white/60 bg-white/70 p-8 shadow-xl backdrop-blur-xl">
        <img src="/logo.png" alt="JourneySync" className="mx-auto mb-4 h-14 w-14 rounded-2xl object-cover" />
        <p className="font-extrabold text-gray-900">Loading JourneySync...</p>
      </div>
    </main>
  );
}

export default function App() {
  const [isBetaOpen, setIsBetaOpen] = useState(false);
  const [activeInfoModal, setActiveInfoModal] = useState(null);
  const pathname = window.location.pathname.replace(/\/+$/, '') || '/';

  // Global event interceptor for Join Beta buttons
  useEffect(() => {
    const handleGlobalClick = (e) => {
      const target = e.target.closest && e.target.closest('a, button');
      if (!target) return;

      const href = target.getAttribute('href');
      const text = target.innerText ? target.innerText.trim() : '';
      const infoKey = target.getAttribute('data-info') || target.getAttribute('data-legal');

      if (infoKey) {
        e.preventDefault();
        e.stopPropagation();
        if (typeof e.stopImmediatePropagation === 'function') e.stopImmediatePropagation();
        setIsBetaOpen(false);
        setActiveInfoModal(infoKey);
        return;
      }

      // Intercept any click pointing to /beta or containing 'Join Beta' / 'Join Closed Beta'
      if (href === '/beta' || text.includes('Join Closed Beta') || text.includes('Join Beta')) {
        e.preventDefault();
        e.stopPropagation();
        if (typeof e.stopImmediatePropagation === 'function') e.stopImmediatePropagation();
        setActiveInfoModal(null);
        setIsBetaOpen(true);
      }
    };

    document.addEventListener('click', handleGlobalClick, true);
    return () => {
      document.removeEventListener('click', handleGlobalClick, true);
    };
  }, []);

  if (pathname === '/beta/download') {
    return (
      <Suspense fallback={<PageFallback />}>
        <BetaDownloadPage />
      </Suspense>
    );
  }

  return (
    <>
      <LandingPage onOpenBeta={() => setIsBetaOpen(true)} />
      <JoinBetaModal isOpen={isBetaOpen} onClose={() => setIsBetaOpen(false)} />
      <InfoModal modalKey={activeInfoModal} onClose={() => setActiveInfoModal(null)} />
    </>
  );
}
