import { landingChunks } from '../data/landingChunks';
import { StaticMarkup } from './StaticMarkup';

const motionSections = new Set([
  'Features',
  'ProductSystem',
  'HowItWorks',
  'Safety',
  'DownloadBanner',
  'Testimonials',
  'Faq',
  'FinalCta',
]);

function chunk(name) {
  const match = landingChunks.find((item) => item.name === name);
  if (!match) throw new Error('Missing landing chunk: ' + name);
  return match.html;
import { Features as FramerFeatures } from './Features';
import { HowItWorks as FramerHowItWorks } from './HowItWorks';
import { ProductSystem as FramerProductSystem } from './ProductSystem';
import { Testimonials as FramerTestimonials } from './Testimonials';
import { Faq as FramerFaq } from './Faq';

export function ShellChrome() { return <StaticMarkup html={chunk('ShellChrome')} />; }
export function Navbar() { return <StaticMarkup html={chunk('Navbar')} />; }
export function Hero() { return <StaticMarkup html={chunk('Hero')} />; }
export function Features() { return <FramerFeatures />; }
export function ProductSystem() { return <FramerProductSystem />; }
export function HowItWorks() { return <FramerHowItWorks />; }
export function Safety() { return <StaticMarkup html={chunk('Safety')} motionEnabled={motionSections.has('Safety')} />; }
export function DownloadBanner() { return <StaticMarkup html={chunk('DownloadBanner')} motionEnabled={motionSections.has('DownloadBanner')} />; }
export function Testimonials() { return <FramerTestimonials />; }
export function Faq() { return <FramerFaq />; }
export function FinalCta() { return <StaticMarkup html={chunk('FinalCta')} motionEnabled={motionSections.has('FinalCta')} />; }
export function FooterAndModals() { return <StaticMarkup html={chunk('FooterAndModals')} />; }
