export type InfoContent = {
  title: string;
  sections?: Array<{
    heading: string;
    body?: Array<string | { prefix?: string; label: string; href: string; external?: boolean }>;
    list?: string[];
  }>;
  documentText?: string;
};

export const infoContent: Record<string, InfoContent> = {
  about: {
    title: 'About Us',
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
        body: ['Email journeysync.app@gmail.com with a concise note about what you want to build and why JourneySync interests you.'],
      },
    ],
  },
  blog: {
    title: 'Blog',
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
    sections: [
      {
        heading: 'Email',
        body: [{ label: 'journeysync.app@gmail.com', href: 'mailto:journeysync.app@gmail.com' }],
      },
      {
        heading: 'Location',
        body: ['Bengaluru, India. Built for rider groups, starting with India-first beta testing.'],
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
  },
  terms: {
    title: 'Terms of Use',
  },
  safety: {
    title: 'Safety Disclaimer',
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
          'Riders are responsible for following traffic laws, speed limits, road signs, local regulations, weather conditions, road quality, and safe riding etiquette at all times.',
        ],
      },
      {
        heading: 'Emergency usage',
        body: [
          'SOS and safety-related features are support tools and may depend on battery, network connectivity, permissions, location accuracy, third-party services, and service availability. In emergencies, contact local emergency services directly.',
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
