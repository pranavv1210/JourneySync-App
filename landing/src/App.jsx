import { lazy, Suspense } from 'react';
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
  LegalInfoModal,
  ProblemSolution,
  SocialProof,
  Testimonials as GrowthTestimonials,
} from './components/GrowthSections';
import { useLandingRuntime } from './hooks/useLandingRuntime';

const BetaPage = lazy(() => import('./pages/BetaPage.jsx'));

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
      <LegalInfoModal />
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
  const pathname = window.location.pathname.replace(/\/+$/, '') || '/';

  if (pathname === '/beta') {
    return (
      <Suspense fallback={<PageFallback />}>
        <BetaPage />
      </Suspense>
    );
  }

  return <LandingPage />;
}
