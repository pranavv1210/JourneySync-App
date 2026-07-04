import { Briefcase, FileText, Info, Mail, Newspaper, Shield } from 'lucide-react';
import { AppModal } from './AppModal';

const modalContent = {
  about: {
    title: 'About Us',
    icon: Info,
    sections: [
      {
        heading: 'What JourneySync is',
        body: [
          'JourneySync is a coordination layer for motorcycle group rides. It helps riders plan together, stay visible during the ride, handle stops, and keep the group moving with less calling and chat noise.',
        ],
      },
      {
        heading: 'Why it was built',
        body: [
          'Group rides often break down at junctions, fuel stops, traffic lights, and route changes. JourneySync was built from those real ride moments to keep every rider aligned without replacing the tools riders already trust.',
        ],
      },
      {
        heading: 'The problem it solves',
        body: [
          'Maps are built for individual navigation. Chats are built for conversation. JourneySync connects the ride state around both: who is in the crew, where the route is going, what changed, and whether anyone needs help.',
        ],
      },
    ],
  },
  careers: {
    title: 'Careers',
    icon: Briefcase,
    sections: [
      {
        heading: 'Current openings',
        body: [
          "We're currently a small team building JourneySync.",
          "Although we don't have open positions today, we'd love to hear from passionate builders who care about mobility, maps, safety, and rider communities.",
        ],
      },
      {
        heading: 'Reach out',
        body: ['Email us at journeysync.app@gmail.com with a short note about what you want to build and why JourneySync interests you.'],
      },
    ],
  },
  blog: {
    title: 'Blog',
    icon: Newspaper,
    sections: [
      {
        heading: 'Coming soon',
        body: ['Articles and ride stories are coming soon.'],
      },
      {
        heading: 'What to expect',
        list: ['Ride Tips', 'Product Updates', 'Community Stories'],
      },
    ],
  },
  contact: {
    title: 'Contact',
    icon: Mail,
    sections: [
      {
        heading: 'Email',
        body: ['journeysync.app@gmail.com'],
      },
      {
        heading: 'Location',
        body: ['Bengaluru, India. Built for rider groups, starting with India-first beta testing.'],
      },
      {
        heading: 'Response time',
        body: ['We typically review beta, support, and partnership messages within 2-3 business days.'],
      },
      {
        heading: 'Social',
        body: ['Instagram: @journeysync.app', 'GitHub: github.com/pranavv1210/JourneySync-App'],
      },
    ],
  },
  privacy: {
    title: 'Privacy Policy',
    icon: Shield,
    sections: [
      {
        heading: 'Information we collect',
        body: [
          'JourneySync may collect information you provide directly, including your email address, beta signup details, profile information, motorcycle details, ride preferences, support messages, and feedback.',
          'When you use ride features, JourneySync may process location data, route information, ride lobby participation, rider status, timestamps, device identifiers, diagnostics, and app usage events needed to operate the service.',
        ],
      },
      {
        heading: 'How we use information',
        body: [
          'We use information to provide group ride coordination, operate live ride visibility, improve beta reliability, detect abuse, respond to support requests, and communicate important product updates.',
          'Location and ride data are used to power active ride experiences such as shared route context, rider visibility, SOS context, and ride history where available.',
        ],
      },
      {
        heading: 'Sharing and storage',
        body: [
          'We do not sell personal information. We may share limited information with service providers that help us host, secure, analyze, and operate JourneySync.',
          'Beta-stage systems may change as the product evolves. We aim to keep data access limited to what is needed for product operation, safety, support, and improvement.',
        ],
      },
      {
        heading: 'Your choices',
        body: [
          'You can choose not to provide certain information, but some ride coordination features may not work without location, profile, or ride lobby data.',
          'For privacy questions or deletion requests, contact journeysync.app@gmail.com.',
        ],
      },
    ],
  },
  terms: {
    title: 'Terms of Use',
    icon: FileText,
    sections: [
      {
        heading: 'Beta-stage service',
        body: [
          'JourneySync is currently a beta-stage product. Features may change, break, be delayed, or be removed as we test and improve the service.',
        ],
      },
      {
        heading: 'Acceptable use',
        body: [
          'You agree to use JourneySync only for lawful ride planning, coordination, and community purposes. Do not misuse the service, interfere with other riders, attempt unauthorized access, or submit harmful content.',
        ],
      },
      {
        heading: 'Accounts and access',
        body: [
          'You are responsible for the information you provide and for activity associated with your access. We may limit, suspend, or revoke beta access if needed to protect the product, riders, or the community.',
        ],
      },
      {
        heading: 'No guarantees',
        body: [
          'JourneySync is provided as-is during beta. We aim to build reliable tools, but we do not guarantee uninterrupted access, perfect location accuracy, or suitability for every ride condition.',
        ],
      },
    ],
  },
  safety: {
    title: 'Safety Disclaimer',
    icon: Shield,
    sections: [
      {
        heading: 'General safety',
        body: [
          'JourneySync assists with group ride coordination. It does not replace rider judgment, training, protective gear, road awareness, or safe riding practices.',
        ],
      },
      {
        heading: 'Road responsibility',
        body: [
          'Riders are responsible for following traffic laws, speed limits, road signs, local regulations, and safe group riding etiquette at all times.',
        ],
      },
      {
        heading: 'Emergency usage',
        body: [
          'SOS and safety-related features are support tools and may depend on device battery, network connectivity, permissions, location accuracy, and service availability. In an emergency, contact local emergency services directly.',
        ],
      },
      {
        heading: 'Liability',
        body: [
          'JourneySync is not responsible for riding decisions, route choices, traffic conditions, accidents, injuries, losses, or damages that occur before, during, or after a ride.',
        ],
      },
    ],
  },
};

export function InfoModal({ modalKey, onClose }) {
  const content = modalKey ? modalContent[modalKey] : null;
  const Icon = content?.icon ?? Info;

  return (
    <AppModal
      isOpen={Boolean(content)}
      onClose={onClose}
      title={content?.title}
      icon={Icon}
      labelledBy="info-modal-title"
      size="lg"
      maxWidth="48rem"
      contentClassName="px-5 pb-6 sm:px-6 sm:pb-8"
    >
      {content ? (
              <div className="app-modal-content mx-auto max-w-[640px] pt-2">
                {content.sections.map((section) => (
                  <section className="app-modal-section" key={section.heading}>
                    <h3>{section.heading}</h3>
                    {section.body?.map((paragraph) => (
                      <p key={paragraph}>{paragraph}</p>
                    ))}
                    {section.list ? (
                      <ul>
                        {section.list.map((item) => (
                          <li key={item}>{item}</li>
                        ))}
                      </ul>
                    ) : null}
                  </section>
                ))}
              </div>
      ) : null}
    </AppModal>
  );
}
