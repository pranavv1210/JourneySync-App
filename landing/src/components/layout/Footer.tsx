import { appVersion, footerGroups } from '@/data/site-content';

type FooterLink =
  | { label: string; href: string }
  | { label: string; infoKey: string };

export function Footer({ onInfo }: { onInfo: (key: string) => void }) {
  return (
    <footer className="site-footer">
      <div className="container footer-grid">
        <div className="footer-brand">
          <div className="brand-mark">
            <img src="/logo.png" alt="JourneySync logo" width={34} height={34} />
            <h3>JourneySync</h3>
          </div>
          <p>
            The coordination layer for motorcycle group rides - safer, calmer, and more connected
            journeys.
          </p>
          <div className="social-links">
            <a
              href="https://github.com/pranavv1210/JourneySync-App"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="JourneySync GitHub"
            >
              GitHub
            </a>
            <a
              href="https://www.instagram.com/journeysync.app/?utm_source=ig_web_button_share_sheet"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="JourneySync Instagram"
            >
              Instagram
            </a>
          </div>
        </div>

        {footerGroups.map((group) => (
          <div key={group.title} className="footer-group">
            <h4>{group.title}</h4>
            <ul>
              {(group.links as readonly FooterLink[]).map((link) => (
                <li key={link.label}>
                  {'href' in link ? (
                    <a href={link.href}>{link.label}</a>
                  ) : (
                    <button type="button" onClick={() => onInfo(link.infoKey)}>
                      {link.label}
                    </button>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="container footer-bottom">
        <p>Copyright 2026 JourneySync. All rights reserved.</p>
        <p>{appVersion}</p>
      </div>
    </footer>
  );
}
