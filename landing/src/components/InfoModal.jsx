import { Briefcase, FileText, Info, Mail, Newspaper, Shield } from 'lucide-react';
import privacyPolicyHtml from '../../public/privacy-policy.html?raw';
import termsOfUseText from '../data/termsOfUse.txt?raw';
import { AppModal } from './AppModal';

function extractPreText(html) {
  const match = html.match(/<pre[^>]*>([\s\S]*?)<\/pre>/i);
  const raw = match ? match[1] : html;

  if (typeof document === 'undefined') {
    return raw.replaceAll('&quot;', '"').replaceAll('&amp;', '&').trim();
  }

  const textarea = document.createElement('textarea');
  textarea.innerHTML = raw;
  return textarea.value.trim();
}

const privacyPolicyText = extractPreText(privacyPolicyHtml);

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
        heading: 'Where we are headed',
        body: [
          'The product is in closed beta with an India-first focus. We are building around rider feedback, reliable ride state, safer group coordination, and a practical workflow that works before, during, and after the ride.',
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
          'JourneySync is still a small founder-led product team. We are not hiring for full-time roles today, but we keep a short list of builders who understand maps, mobility, safety, realtime systems, and rider communities.',
        ],
      },
      {
        heading: 'What we look for',
        body: [
          'Strong product judgment, clean execution, and respect for real-world rider constraints matter more than titles. The work spans Flutter, React, Supabase, maps, realtime coordination, and thoughtful safety design.',
        ],
      },
      {
        heading: 'Reach out',
        body: ['Email journeysync.app@gmail.com with a concise note about what you want to build, links to relevant work, and why JourneySync interests you.'],
      },
    ],
  },
  blog: {
    title: 'Blog',
    icon: Newspaper,
    sections: [
      {
        heading: 'Product notes',
        body: [
          'The public blog is being prepared around practical ride coordination, beta learnings, product updates, and the engineering choices behind JourneySync.',
        ],
      },
      {
        heading: 'Upcoming topics',
        list: [
          'How Ride Radar keeps nearby discovery focused.',
          'Why group rides need shared state, not another chat thread.',
          'What we are learning from closed beta rider groups.',
        ],
      },
      {
        heading: 'Press and stories',
        body: ['For product stories, launch notes, or rider community features, contact journeysync.app@gmail.com.'],
      },
    ],
  },
  contact: {
    title: 'Contact',
    icon: Mail,
    sections: [
      {
        heading: 'Email',
        body: [
          {
            label: 'journeysync.app@gmail.com',
            href: 'mailto:journeysync.app@gmail.com',
          },
        ],
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
        body: [
          {
            prefix: 'Instagram: ',
            label: '@journeysync.app',
            href: 'https://instagram.com/journeysync.app',
            external: true,
          },
          {
            prefix: 'GitHub: ',
            label: 'github.com/pranavv1210/JourneySync-App',
            href: 'https://github.com/pranavv1210/JourneySync-App',
            external: true,
          },
        ],
      },
    ],
  },
  privacy: {
    title: 'Privacy Policy',
    icon: Shield,
    documentText: privacyPolicyText,
  },
  terms: {
    title: 'Terms of Use',
    icon: FileText,
    documentText: termsOfUseText.trim(),
  },
  safety: {
    title: 'Safety Disclaimer',
    icon: Shield,
    sections: [
      {
        heading: 'General safety',
        body: [
          'JourneySync assists with group ride coordination. It does not replace rider judgment, training, protective gear, road awareness, traffic laws, emergency services, or safe riding practices.',
        ],
      },
      {
        heading: 'Road responsibility',
        body: [
          'Riders are responsible for following traffic laws, speed limits, road signs, local regulations, weather conditions, road quality, and safe group riding etiquette at all times.',
        ],
      },
      {
        heading: 'Emergency usage',
        body: [
          'SOS and safety-related features are support tools and may depend on device battery, network connectivity, permissions, location accuracy, third-party services, and service availability. In an emergency, contact local emergency services directly.',
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

function isDocumentHeading(line) {
  return /^[0-9]+\. [A-Z0-9 ,?'-]+$/.test(line) || /^[A-Z][A-Z0-9 ,?'-]{5,}$/.test(line);
}

function renderBodyItem(item) {
  if (typeof item === 'string') return item;

  return (
    <>
      {item.prefix ?? ''}
      <a href={item.href} target={item.external ? '_blank' : undefined} rel={item.external ? 'noopener noreferrer' : undefined}>
        {item.label}
      </a>
    </>
  );
}

function DocumentText({ text }) {
  return (
    <div className="app-modal-document">
      {text.split(/\n+/).map((line) => {
        const value = line.trim();
        if (!value) return null;

        if (isDocumentHeading(value)) {
          return <h3 key={value}>{value}</h3>;
        }

        return <p key={value}>{value}</p>;
      })}
    </div>
  );
}

export function InfoModal({ modalKey, onClose }) {
  const content = modalKey ? modalContent[modalKey] : null;
  const Icon = content?.icon ?? Info;
  const isLegalDocument = Boolean(content?.documentText);

  return (
    <AppModal
      isOpen={Boolean(content)}
      onClose={onClose}
      title={content?.title}
      icon={Icon}
      labelledBy="info-modal-title"
      size="lg"
      maxWidth={isLegalDocument ? '56rem' : '48rem'}
      contentClassName={isLegalDocument ? 'app-modal-document-scroll' : ''}
    >
      {content?.documentText ? (
        <DocumentText text={content.documentText} />
      ) : content ? (
        <div className="app-modal-content mx-auto max-w-[640px]">
          {content.sections.map((section) => (
            <section className="app-modal-section" key={section.heading}>
              <h3>{section.heading}</h3>
              {section.body?.map((paragraph) => (
                <p key={typeof paragraph === 'string' ? paragraph : paragraph.label}>{renderBodyItem(paragraph)}</p>
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
