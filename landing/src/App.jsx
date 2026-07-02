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

export default function App() {
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
