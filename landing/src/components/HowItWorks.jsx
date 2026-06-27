import React from 'react';
import { motion } from 'framer-motion';
import { QrCode, Navigation, Bell } from 'lucide-react';

const steps = [
  {
    icon: <QrCode className="w-8 h-8 text-primary" />,
    title: 'Seamless Onboarding',
    desc: 'No more "wait, let me type that address." Just scan the lobby QR code and your phone configures the entire route automatically.'
  },
  {
    icon: <Navigation className="w-8 h-8 text-primary" />,
    title: 'Hybrid Navigation',
    desc: 'Get Google Maps turn-by-turn directions layered with our real-time rider radar. You never have to switch apps while riding.'
  },
  {
    icon: <Bell className="w-8 h-8 text-primary" />,
    title: 'Smart Alerts',
    desc: 'If someone falls too far behind or goes off route, the lead rider gets notified instantly. No one gets left behind.'
  }
];

export default function HowItWorks() {
  return (
    <section className="py-24 relative overflow-hidden" id="how-it-works">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="mb-16">
          <motion.h2 
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            className="text-4xl md:text-5xl font-display font-bold text-gray-900 dark:text-white"
          >
            Get Rolling in Seconds
          </motion.h2>
        </div>
        
        <div className="relative">
          {/* Vertical line connecting steps */}
          <div className="hidden md:block absolute left-[39px] top-8 bottom-8 w-1 bg-gray-200 dark:bg-gray-800 rounded-full"></div>
          
          <div className="space-y-12">
            {steps.map((step, idx) => (
              <motion.div 
                key={idx}
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-100px" }}
                className="relative flex flex-col md:flex-row gap-8 md:gap-12 items-start"
              >
                <div className="relative z-10 flex-shrink-0 w-20 h-20 bg-white dark:bg-gray-900 border-4 border-orange-100 dark:border-gray-800 rounded-full flex items-center justify-center shadow-md">
                  {step.icon}
                </div>
                
                <div className="bg-white dark:bg-gray-800 rounded-3xl p-8 md:p-10 shadow-lg border border-gray-100 dark:border-gray-700 flex-1 hover:shadow-xl transition-shadow">
                  <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">{step.title}</h3>
                  <p className="text-lg text-gray-600 dark:text-gray-400 leading-relaxed">
                    {step.desc}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
