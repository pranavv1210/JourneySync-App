import './index.css';
import {
  DownloadBanner,
  Features,
  FinalCta,
  FooterAndModals,
  Hero,
  HowItWorks,
  Navbar,
  ProductSystem,
  Safety,
  ShellChrome,
} from './components/LandingSections';
import {
  BuiltByRiders,
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
        <ProductSystem />
        <HowItWorks />
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
    </>
  );
}
