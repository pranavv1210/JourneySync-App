import type { Metadata } from 'next';
import { BetaDownloadClient } from '@/components/BetaDownloadClient';

export const metadata: Metadata = {
  title: 'Download JourneySync Beta',
  description: 'Download the official JourneySync Beta for Android.',
  alternates: {
    canonical: 'https://journeysyncrideapp.in/beta/download',
  },
};

export default function BetaDownloadPage() {
  return <BetaDownloadClient />;
}
