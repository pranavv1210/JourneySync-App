import type { Metadata, Viewport } from 'next';
import { Outfit } from 'next/font/google';
import Script from 'next/script';
import { analyticsConfig } from '@/lib/tracking';
import './globals.css';

const outfit = Outfit({
  subsets: ['latin'],
  variable: '--font-outfit',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'JourneySync | Never Lose Your Riding Group Again',
  description:
    'The operating system for group motorcycle rides. Plan the route, keep every rider visible, handle stops and safety, and turn every ride into a shared memory.',
  keywords: [
    'motorcycle',
    'group rides',
    'GPS',
    'navigation',
    'JourneySync',
    'ride coordination',
    'safety',
  ],
  metadataBase: new URL('https://journeysyncrideapp.in'),
  alternates: { canonical: 'https://journeysyncrideapp.in' },
  icons: {
    icon: '/favicon.svg',
    apple: '/logo.png',
  },
  manifest: '/site.webmanifest',
  openGraph: {
    title: 'JourneySync | Group Motorcycle Ride OS',
    description:
      'Plan the route, keep every rider visible, handle stops and safety, and turn every ride into a shared memory. Join the closed beta.',
    url: 'https://journeysyncrideapp.in',
    siteName: 'JourneySync',
    images: [
      {
        url: '/map_bg.png',
        width: 1200,
        height: 630,
        alt: 'JourneySync - Group Motorcycle Ride OS',
      },
    ],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'JourneySync | Group Motorcycle Ride OS',
    description: 'Never lose your riding group again. Join the closed beta.',
    images: ['/map_bg.png'],
  },
};

export const viewport: Viewport = {
  themeColor: '#fbf7f1',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/icon?family=Material+Icons+Round"
        />
      </head>
      <body className={`${outfit.variable} font-sans antialiased`}>
        <div id="scroll-progress" aria-hidden="true" />
        {children}
        <Script
          src={`https://www.googletagmanager.com/gtag/js?id=${analyticsConfig.googleMeasurementId}`}
          strategy="afterInteractive"
        />
        <Script id="gtag-init" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', '${analyticsConfig.googleMeasurementId}');
          `}
        </Script>
        <Script id="clarity-init" strategy="afterInteractive">
          {`
            (function(c,l,a,r,i,t,y){
              c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
              t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
              y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
            })(window, document, "clarity", "script", "${analyticsConfig.clarityProjectId}");
          `}
        </Script>
      </body>
    </html>
  );
}
