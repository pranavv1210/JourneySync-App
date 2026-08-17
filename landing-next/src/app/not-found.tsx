import Link from 'next/link';
import { CtaButton } from '@/components/ui/CtaButton';

export default function NotFound() {
  return (
    <main className="not-found-page">
      <div className="not-found-atmosphere" aria-hidden="true" />
      <div className="not-found-inner">
        <p className="eyebrow">Route not found</p>
        <h1>404</h1>
        <p>
          This path is not on the JourneySync map. Head back to the main ride and pick up where
          your group left off.
        </p>
        <div className="not-found-actions">
          <CtaButton href="/">Return home</CtaButton>
          <Link href="/#demo" className="not-found-link">
            Watch demo
          </Link>
        </div>
      </div>
    </main>
  );
}
