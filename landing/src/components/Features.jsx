import React from 'react';
import { motion } from 'framer-motion';
import { Map, ShieldCheck, Users, Zap } from 'lucide-react';

const features = [
  {
    icon: <Map className="w-6 h-6 text-primary" />,
    title: 'Real-time Tracking',
    desc: 'See exactly where everyone in your group is on the map.'
  },
  {
    icon: <Users className="w-6 h-6 text-primary" />,
    title: 'Easy Group Creation',
    desc: 'Generate a QR code or share a link. No accounts needed for guests.'
  },
  {
    icon: <ShieldCheck className="w-6 h-6 text-primary" />,
    title: 'Offline Resilience',
    desc: 'Lose cell service? The app auto-syncs the moment you get back online.'
  },
  {
    icon: <Zap className="w-6 h-6 text-primary" />,
    title: 'Battery Optimized',
    desc: 'Engineered for minimal background drain during long rides.'
  }
];

export default function Features() {
  return (
    <section className="py-24 bg-gray-50 dark:bg-gray-900/50" id="features">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          className="text-center max-w-3xl mx-auto mb-16"
        >
          <h2 className="text-primary font-bold tracking-wide uppercase text-sm mb-3">Built for Real Riders</h2>
          <h3 className="text-3xl md:text-5xl font-display font-bold text-gray-900 dark:text-white mb-6">
            Everything you need for the long haul.
          </h3>
          <p className="text-lg text-gray-600 dark:text-gray-300">
            Designed by motorcycle enthusiasts to solve the real problems of group touring.
          </p>
        </motion.div>
        
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          {features.map((feature, idx) => (
            <motion.div 
              key={idx}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ delay: idx * 0.1 }}
              className="bg-white dark:bg-gray-800 p-8 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-700 hover:shadow-lg transition-shadow"
            >
              <div className="w-12 h-12 bg-orange-50 dark:bg-orange-900/20 rounded-xl flex items-center justify-center mb-6">
                {feature.icon}
              </div>
              <h4 className="text-xl font-bold text-gray-900 dark:text-white mb-3">{feature.title}</h4>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
                {feature.desc}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
