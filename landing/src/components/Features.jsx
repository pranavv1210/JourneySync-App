import React from 'react';
import { motion } from 'framer-motion';
import { MapPin, Radar, Headset } from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.2,
      delayChildren: 0.1,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { type: 'spring', stiffness: 100, damping: 15 },
  },
};

export function Features() {
  return (
    <section className="py-24 relative bg-white/70 dark:bg-gray-900 overflow-hidden" id="features">
      {/* Background decoration */}
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-primary/5 rounded-full blur-[100px] -translate-y-1/2 translate-x-1/3 pointer-events-none" />
      <div className="absolute bottom-0 left-0 w-[600px] h-[600px] bg-blue-500/5 rounded-full blur-[100px] translate-y-1/2 -translate-x-1/3 pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <motion.div 
          className="text-center max-w-3xl mx-auto mb-20"
          initial={{ opacity: 0, y: -20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.6 }}
        >
          <span className="inline-block py-1 px-3 rounded-full bg-primary/10 text-primary font-bold uppercase tracking-wider text-sm mb-4">
            Built for Real Riders
          </span>
          <h2 className="text-4xl md:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight">
            Everything you need for the long haul.
          </h2>
          <p className="mt-6 text-gray-600 dark:text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
            Designed by motorcycle enthusiasts to solve the real problems of group touring.
          </p>
        </motion.div>

        <motion.div 
          className="grid md:grid-cols-3 gap-8 lg:gap-10"
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-50px" }}
        >
          {/* Feature 1 */}
          <motion.div 
            variants={itemVariants}
            whileHover={{ y: -8, transition: { duration: 0.2 } }}
            className="group relative bg-white dark:bg-gray-800 rounded-3xl p-8 shadow-xl shadow-gray-200/50 dark:shadow-none border border-gray-100 dark:border-gray-700 hover:border-primary/30 dark:hover:border-primary/30 transition-colors z-10"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent rounded-3xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />
            
            <motion.div 
              className="w-16 h-16 bg-primary/10 dark:bg-primary/20 rounded-2xl flex items-center justify-center text-primary mb-8"
              whileHover={{ rotate: 5, scale: 1.05 }}
            >
              <MapPin size={32} strokeWidth={2.5} />
            </motion.div>
            <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">Live Group Tracking</h3>
            <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">
              Never lose a rider again. See everyone's position in real-time, even when the pack gets stretched out on twisty roads.
            </p>
          </motion.div>

          {/* Feature 2 */}
          <motion.div 
            variants={itemVariants}
            whileHover={{ y: -8, transition: { duration: 0.2 } }}
            className="group relative bg-white dark:bg-gray-800 rounded-3xl p-8 shadow-xl shadow-gray-200/50 dark:shadow-none border border-gray-100 dark:border-gray-700 hover:border-primary/30 dark:hover:border-primary/30 transition-colors z-10"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent rounded-3xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />

            <motion.div 
              className="w-16 h-16 bg-primary/10 dark:bg-primary/20 rounded-2xl flex items-center justify-center text-primary mb-8"
              whileHover={{ rotate: -5, scale: 1.05 }}
            >
              <Radar size={32} strokeWidth={2.5} />
            </motion.div>
            <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">Ride Radar</h3>
            <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">
              Discover nearby active rides automatically, then join by radar or access code when your crew is ready.
            </p>
          </motion.div>

          {/* Feature 3 */}
          <motion.div 
            variants={itemVariants}
            whileHover={{ y: -8, transition: { duration: 0.2 } }}
            className="group relative bg-white dark:bg-gray-800 rounded-3xl p-8 shadow-xl shadow-gray-200/50 dark:shadow-none border border-gray-100 dark:border-gray-700 hover:border-primary/30 dark:hover:border-primary/30 transition-colors z-10"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent rounded-3xl opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />

            <motion.div 
              className="w-16 h-16 bg-primary/10 dark:bg-primary/20 rounded-2xl flex items-center justify-center text-primary mb-8"
              whileHover={{ rotate: 5, scale: 1.05 }}
            >
              <Headset size={32} strokeWidth={2.5} />
            </motion.div>
            <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">Premium Ride HUD</h3>
            <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">
              Track riders, route state, GPS quality, connection health, SOS alerts, and weather context from one focused cockpit.
            </p>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
