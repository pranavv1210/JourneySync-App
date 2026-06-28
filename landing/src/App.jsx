import './index.css';
import {
  DownloadBanner,
  Faq,
  Features,
  FinalCta,
  FooterAndModals,
  Hero,
  HowItWorks,
  Navbar,
  ProductSystem,
  Safety,
  ShellChrome,
  Testimonials,
} from './components/LandingSections';
import { useLandingRuntime } from './hooks/useLandingRuntime';

export default function App() {
  useLandingRuntime();

  return (
    <>
      <ShellChrome />
      <Navbar />
      <main>
        <Hero />
        <Features />
        <ProductSystem />
        <HowItWorks />
        <Safety />
        <DownloadBanner />
        <Testimonials />
        <Faq />
        <FinalCta />
      </main>
      <FooterAndModals />
    </>
  );
}
