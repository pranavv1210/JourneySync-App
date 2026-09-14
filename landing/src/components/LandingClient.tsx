'use client';

import { useCallback, useState } from 'react';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { MobileStickyCta } from '@/components/layout/MobileStickyCta';
import { CookieBanner } from '@/components/layout/CookieBanner';
import { HeroSection } from '@/components/sections/HeroSection';
import { ProblemSolutionSection } from '@/components/sections/ProblemSolutionSection';
import { FeaturesSection } from '@/components/sections/FeaturesSection';
import { ComparisonSection } from '@/components/sections/ComparisonSection';
import { DemoSection } from '@/components/sections/DemoSection';
import { BuiltByRidersSection } from '@/components/sections/BuiltByRidersSection';
import { SafetySection } from '@/components/sections/SafetySection';
import { BikeModeSection } from '@/components/sections/BikeModeSection';
import { FaqSection } from '@/components/sections/FaqSection';
import { DownloadSection } from '@/components/sections/DownloadSection';
import { FinalCtaSection } from '@/components/sections/FinalCtaSection';
import { JoinBetaModal } from '@/components/modals/JoinBetaModal';
import { InfoModal } from '@/components/modals/InfoModal';
import { DownloadModal } from '@/components/modals/DownloadModal';
import { useLandingRuntime } from '@/hooks/useLandingRuntime';

export function LandingClient() {
  useLandingRuntime();

  const [betaOpen, setBetaOpen] = useState(false);
  const [downloadOpen, setDownloadOpen] = useState(false);
  const [infoKey, setInfoKey] = useState<string | null>(null);

  const openBeta = useCallback(() => {
    setInfoKey(null);
    setBetaOpen(true);
  }, []);

  const openDownload = useCallback(() => {
    setDownloadOpen(true);
  }, []);

  const openInfo = useCallback((key: string) => {
    setBetaOpen(false);
    setInfoKey(key);
  }, []);

  return (
    <>
      <Header onJoinBeta={openBeta} />
      <main>
        <HeroSection onJoinBeta={openBeta} />
        <ProblemSolutionSection />
        <FeaturesSection />
        <BikeModeSection />
        <ComparisonSection />
        <DemoSection />
        <BuiltByRidersSection />
        <SafetySection />
        <FaqSection />
        <DownloadSection onDownload={openDownload} />
        <FinalCtaSection onJoinBeta={openBeta} />
      </main>
      <Footer onInfo={openInfo} />
      <MobileStickyCta onJoinBeta={openBeta} />
      <CookieBanner />
      <JoinBetaModal isOpen={betaOpen} onClose={() => setBetaOpen(false)} />
      <InfoModal modalKey={infoKey} onClose={() => setInfoKey(null)} />
      <DownloadModal isOpen={downloadOpen} onClose={() => setDownloadOpen(false)} />
    </>
  );
}
