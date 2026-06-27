import React, { useState, useEffect } from 'react';
import Hero from './components/Hero';
import Features from './components/Features';
import HowItWorks from './components/HowItWorks';
import Footer from './components/Footer';

function Header() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 36);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header className={`fixed top-0 inset-x-0 z-50 transition-all duration-300 ${scrolled ? 'bg-white/80 dark:bg-gray-900/80 backdrop-blur-md shadow-sm py-3' : 'bg-transparent py-5'}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex justify-between items-center">
        <div className="flex items-center gap-3">
          <img src="/logo.png" alt="Logo" className="w-10 h-10 rounded-xl" />
          <span className="font-display font-bold text-xl dark:text-white">JourneySync</span>
        </div>
        <nav className="hidden md:flex gap-8">
          <a href="#features" className="text-gray-600 dark:text-gray-300 hover:text-primary font-medium transition-colors">Features</a>
          <a href="#how-it-works" className="text-gray-600 dark:text-gray-300 hover:text-primary font-medium transition-colors">How It Works</a>
        </nav>
        <a href="#download" className="px-5 py-2.5 bg-primary text-white font-bold rounded-lg hover:bg-primary-dark transition-colors shadow-md">
          Download App
        </a>
      </div>
    </header>
  );
}

function App() {
  return (
    <div className="min-h-screen bg-white dark:bg-gray-950 text-gray-900 dark:text-gray-100 font-sans selection:bg-orange-200 dark:selection:bg-orange-900/50">
      <Header />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
      </main>
      <Footer />
    </div>
  );
}

export default App;
