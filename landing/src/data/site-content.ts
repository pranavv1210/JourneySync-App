export type NavItem = { label: string; href: string };
export type StatItem = {
  value: number;
  suffix?: string;
  label: string;
  detail: string;
};
export type StoryStep = {
  index: string;
  phase: string;
  title: string;
  description: string;
  signal: string;
};
export type FeatureMoment = {
  id: string;
  kicker: string;
  title: string;
  description: string;
  metric: string;
  icon: string;
  bullets: string[];
};
export type ComparisonRow = {
  category: string;
  googleMaps: string;
  whatsapp: string;
  journeysync: string;
};
export type Testimonial = {
  quote: string;
  name: string;
  bike: string;
  location: string;
};
export type FaqItem = { question: string; answer: string };
export type BuiltByBullet = { text: string; icon: string };

export const appVersion = 'v1.1.2';
export const siteUrl = 'https://journeysyncrideapp.in';

export const navItems: NavItem[] = [
  { label: 'Story', href: '#problem-solution' },
  { label: 'Ride Layer', href: '#features' },
  { label: 'Compare', href: '#comparison' },
  { label: 'Demo', href: '#demo' },
  { label: 'Safety', href: '#safety' },
  { label: 'Download', href: '#download' },
];

export const socialStats: StatItem[] = [
  {
    value: 120,
    suffix: '+',
    label: 'rides coordinated',
    detail: 'Closed beta target across Bengaluru rider groups.',
  },
  {
    value: 75,
    suffix: '+',
    label: 'beta testers',
    detail: 'Founding cohort shaping the first ride layer.',
  },
  {
    value: 12,
    label: 'cities covered',
    detail: 'India-first rollout with real road feedback.',
  },
  {
    value: 300,
    suffix: '+',
    label: 'testing hours',
    detail: 'Road, simulator, and group ride validation.',
  },
];

export const storySteps: StoryStep[] = [
  {
    index: '01',
    phase: 'Before',
    title: 'Plans scatter before the ride starts.',
    description:
      'Routes, meet points, riders, fuel stops, and timing usually live across different chats and map links.',
    signal: 'Plan',
  },
  {
    index: '02',
    phase: 'During',
    title: 'The pack stretches at junctions and traffic lights.',
    description:
      'Once riders split, nobody knows if the group should wait, call, reroute, or keep moving.',
    signal: 'Sync',
  },
  {
    index: '03',
    phase: 'Safety',
    title: 'When something goes wrong, context matters.',
    description:
      'SOS, location, rider status, and emergency contacts need to exist inside the active ride, not in a separate panic flow.',
    signal: 'Protect',
  },
  {
    index: '04',
    phase: 'After',
    title: 'The ride should become a record.',
    description:
      'Completed journeys, route memory, telemetry, and group history help the next ride start smarter.',
    signal: 'Remember',
  },
];

export const featureMoments: FeatureMoment[] = [
  {
    id: 'lobby',
    kicker: 'Ride lobby',
    icon: 'groups',
    metric: '6 riders',
    title: 'Start with one shared ride state.',
    description:
      'Create a ride, set route visibility, invite riders, and keep the crew aligned before the engine starts.',
    bullets: ['Invite-only or public rides', 'Maximum rider limits', 'Route and stop context'],
  },
  {
    id: 'radar',
    kicker: 'Ride Radar',
    icon: 'radar',
    metric: '5 km radius',
    title: 'Discover nearby active rides without chat noise.',
    description:
      'Radar keeps discovery focused on active rides near you, so spontaneous riding has real context.',
    bullets: ['Distance-aware discovery', 'Active ride status', 'Quick join requests'],
  },
  {
    id: 'tracking',
    kicker: 'Live tracking',
    icon: 'share_location',
    metric: 'Live GPS',
    title: 'See the pack move as one connected system.',
    description:
      'JourneySync keeps rider positions, route state, and safety context alive while navigation continues.',
    bullets: ['Realtime rider markers', 'Group spread awareness', 'Persistent ride mode'],
  },
  {
    id: 'navigation',
    kicker: 'Hybrid maps',
    icon: 'map',
    metric: 'Route sync',
    title: 'Use familiar navigation without losing group context.',
    description:
      'Google Maps handles turn-by-turn navigation. JourneySync handles the group ride layer around it.',
    bullets: ['Google Maps handoff', 'Route preview', 'Weather and essentials'],
  },
  {
    id: 'memory',
    kicker: 'Ride journal',
    icon: 'timeline',
    metric: 'After ride',
    title: 'Turn completed rides into usable memory.',
    description:
      'Ride history, distance, summaries, and saved routes make the next group ride easier to plan.',
    bullets: ['Ride history', 'Journey stats', 'Route memory'],
  },
];

export const comparisonRows: ComparisonRow[] = [
  {
    category: 'Navigation',
    googleMaps: 'Excellent solo routing',
    whatsapp: 'Map links only',
    journeysync: 'Hybrid Google Maps flow plus ride state',
  },
  {
    category: 'Live tracking',
    googleMaps: 'Individual sharing',
    whatsapp: 'Manual updates',
    journeysync: 'Built around the group session',
  },
  {
    category: 'Ride coordination',
    googleMaps: 'No ride lobby',
    whatsapp: 'Chat noise',
    journeysync: 'Lobby, riders, stops, and synced route',
  },
  {
    category: 'SOS',
    googleMaps: 'Not ride-aware',
    whatsapp: 'Manual calls',
    journeysync: 'Emergency context inside the ride',
  },
  {
    category: 'Weather + fuel',
    googleMaps: 'Search separately',
    whatsapp: 'Ask the group',
    journeysync: 'Ride-aware essentials',
  },
  {
    category: 'Ride memory',
    googleMaps: 'Trip only',
    whatsapp: 'Lost in chat',
    journeysync: 'History, stats, and route memory',
  },
];

export const builtByBullets: BuiltByBullet[] = [
  {
    icon: 'two_wheeler',
    text: 'JourneySync was built from real ride moments: junctions, fuel stops, missed turns, and late regroup calls.',
  },
  {
    icon: 'route',
    text: 'It does not replace the tools riders trust. It adds the missing coordination layer around them.',
  },
  {
    icon: 'location_on',
    text: 'The India-first beta starts with rider groups who understand how quickly a good ride becomes hard to coordinate.',
  },
];

export const safetyFeatures = [
  {
    icon: 'sensors',
    title: 'Crash detection support',
    description:
      'Phone-sensor based detection can help surface emergency context when a rider may not be able to respond.',
  },
  {
    icon: 'sos',
    title: 'SOS inside ride mode',
    description:
      'One-tap emergency signaling keeps location and ride context attached to the active session.',
  },
  {
    icon: 'verified_user',
    title: 'Safety as product behavior',
    description:
      'Permissions, location state, rider visibility, and emergency contacts are treated as core surfaces.',
  },
];

export const testimonials: Testimonial[] = [
  {
    quote:
      'Ride Radar is the first thing that made group discovery feel practical instead of random.',
    name: 'Aarav Menon',
    bike: 'Royal Enfield Himalayan',
    location: 'Bengaluru',
  },
  {
    quote:
      'The hybrid Google Maps flow makes sense. I keep familiar navigation but the group stays visible.',
    name: 'Nisha Rao',
    bike: 'KTM Duke 390',
    location: 'Bengaluru',
  },
  {
    quote:
      'This solves the exact junction problem every weekend ride has. Less calling, more riding.',
    name: 'Rohan Iyer',
    bike: 'Interceptor 650',
    location: 'Bengaluru',
  },
  {
    quote:
      'The safety and SOS thinking makes JourneySync feel like a serious ride product, not a demo.',
    name: 'Dev Gowda',
    bike: 'Dominar 400',
    location: 'Bengaluru',
  },
];

export const faqs: FaqItem[] = [
  {
    question: 'Is JourneySync available now?',
    answer:
      'JourneySync v1.1.2 is available as a direct Android APK download. iOS compatibility is planned through TestFlight.',
  },
  {
    question: 'Does it replace Google Maps?',
    answer:
      'No. JourneySync uses a hybrid model: riders can open Google Maps while JourneySync maintains ride state, tracking, and safety context.',
  },
  {
    question: 'Why not just use WhatsApp?',
    answer:
      'WhatsApp is useful for chat, but it does not know who missed a turn, where the pack is, what the route state is, or whether a rider needs help.',
  },
  {
    question: 'How does Ride Radar work?',
    answer:
      'When a ride is created, realtime events refresh nearby riders. Distance filtering keeps Radar focused on rides near you.',
  },
  {
    question: 'How do I join beta?',
    answer:
      'Use Join Beta or the final CTA. We use the beta list to prioritize active riders and groups, then share download guidance by email.',
  },
];

export const footerGroups = [
  {
    title: 'Company',
    links: [
      { label: 'About Us', infoKey: 'about' },
      { label: 'Careers', infoKey: 'careers' },
      { label: 'Blog', infoKey: 'blog' },
      { label: 'Contact', infoKey: 'contact' },
    ],
  },
  {
    title: 'Legal',
    links: [
      { label: 'Privacy Policy', infoKey: 'privacy' },
      { label: 'Terms of Use', infoKey: 'terms' },
      { label: 'Safety Disclaimer', infoKey: 'safety' },
    ],
  },
] as const;
