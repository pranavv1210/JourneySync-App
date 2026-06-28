import React from 'react';
import { motion } from 'framer-motion';
import { Users, QrCode, Map, Bike } from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.2,
      delayChildren: 0.2,
    },
  },
};

const stepVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { 
    opacity: 1, 
    y: 0,
    transition: { type: 'spring', stiffness: 100 }
  },
};

export function HowItWorks() {
  return (
    <section className="py-24 bg-background-light dark:bg-background-dark border-t border-gray-200 dark:border-gray-800 relative overflow-hidden" id="how-it-works">
      {/* Background decoration */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full max-w-[1000px] max-h-[1000px] bg-primary/5 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <motion.div 
          className="mb-16 text-center md:text-left"
          initial={{ opacity: 0, x: -30 }}
          whileInView={{ opacity: 1, x: 0 }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.6 }}
        >
          <span className="inline-block py-1 px-3 rounded-full bg-primary/10 text-primary font-bold uppercase tracking-wider text-sm mb-4">
            Simple Onboarding
          </span>
          <h2 className="text-4xl md:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight">
            Get Rolling in Seconds
          </h2>
        </motion.div>

        <div className="relative">
          {/* Animated Connecting Line (Desktop) */}
          <div className="hidden md:block absolute top-12 left-[10%] right-[10%] h-1 bg-gray-200 dark:bg-gray-800 rounded-full overflow-hidden">
            <motion.div 
              className="h-full bg-primary"
              initial={{ width: "0%" }}
              whileInView={{ width: "100%" }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 1.5, ease: "easeInOut" }}
            />
          </div>

          <motion.div 
            className="grid md:grid-cols-4 gap-8 lg:gap-12 relative"
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-50px" }}
          >
            {/* Step 1 */}
            <motion.div variants={stepVariants} className="relative group text-center md:text-left flex flex-col items-center md:items-start">
              <motion.div 
                whileHover={{ scale: 1.1, rotate: 5 }}
                className="w-24 h-24 bg-white dark:bg-gray-800 rounded-full flex items-center justify-center border-4 border-background-light dark:border-background-dark shadow-xl mb-6 z-10 relative"
              >
                <div className="absolute inset-0 rounded-full border-2 border-primary/0 group-hover:border-primary/100 transition-colors duration-300" />
                <Users size={36} className="text-primary" strokeWidth={2.5} />
              </motion.div>
              <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-3">Create Lobby</h3>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">Start a private ride lobby and set your destination.</p>
            </motion.div>

            {/* Step 2 */}
            <motion.div variants={stepVariants} className="relative group text-center md:text-left flex flex-col items-center md:items-start">
              <motion.div 
                whileHover={{ scale: 1.1, rotate: -5 }}
                className="w-24 h-24 bg-white dark:bg-gray-800 rounded-full flex items-center justify-center border-4 border-background-light dark:border-background-dark shadow-xl mb-6 z-10 relative"
              >
                <div className="absolute inset-0 rounded-full border-2 border-primary/0 group-hover:border-primary/100 transition-colors duration-300" />
                <QrCode size={36} className="text-primary" strokeWidth={2.5} />
              </motion.div>
              <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-3">Invite Crew</h3>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">Share a simple link or QR code to add your friends.</p>
            </motion.div>

            {/* Step 3 */}
            <motion.div variants={stepVariants} className="relative group text-center md:text-left flex flex-col items-center md:items-start">
              <motion.div 
                whileHover={{ scale: 1.1, rotate: 5 }}
                className="w-24 h-24 bg-white dark:bg-gray-800 rounded-full flex items-center justify-center border-4 border-background-light dark:border-background-dark shadow-xl mb-6 z-10 relative"
              >
                <div className="absolute inset-0 rounded-full border-2 border-primary/0 group-hover:border-primary/100 transition-colors duration-300" />
                <Map size={36} className="text-primary" strokeWidth={2.5} />
              </motion.div>
              <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-3">Sync Route</h3>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">Everyone gets the same GPS route instantly.</p>
            </motion.div>

            {/* Step 4 */}
            <motion.div variants={stepVariants} className="relative group text-center md:text-left flex flex-col items-center md:items-start">
              <motion.div 
                whileHover={{ scale: 1.1, rotate: -5 }}
                className="w-24 h-24 bg-primary text-white rounded-full flex items-center justify-center border-4 border-background-light dark:border-background-dark shadow-xl shadow-primary/30 mb-6 z-10 relative"
              >
                <div className="absolute inset-0 rounded-full border-2 border-primary/0 group-hover:border-white/50 transition-colors duration-300" />
                <Bike size={36} className="text-white" strokeWidth={2.5} />
              </motion.div>
              <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-3">Ride Connected</h3>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">Hit the road with peace of mind and full connectivity.</p>
            </motion.div>
          </motion.div>
        </div>

        {/* Lobby Mockup */}
        <motion.div 
          className="mt-20 bg-white dark:bg-gray-800 rounded-3xl p-8 md:p-10 shadow-2xl border border-gray-100 dark:border-gray-700 max-w-5xl mx-auto flex flex-col md:flex-row items-center gap-12 group"
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
          transition={{ duration: 0.7 }}
          whileHover={{ y: -5, transition: { duration: 0.3 } }}
        >
          <div className="flex-1 space-y-6">
            <h4 className="text-3xl font-bold text-gray-900 dark:text-white flex items-center gap-3">
              <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
                <QrCode size={24} className="text-primary" />
              </div>
              Seamless Onboarding
            </h4>
            <p className="text-gray-600 dark:text-gray-400 text-lg leading-relaxed">
              No more "wait, let me type that address." Just scan the lobby QR code and your phone configures the entire route automatically. Works cross-platform.
            </p>
          </div>
          <div className="w-full md:w-80 bg-gray-100 dark:bg-gray-900 rounded-2xl p-6 aspect-[4/3] flex items-center justify-center relative overflow-hidden">
            <motion.div 
              className="absolute inset-0 bg-cover bg-center opacity-80" 
              style={{ backgroundImage: "url('https://lh3.googleusercontent.com/aida-public/AB6AXuCqrlr2ZVW33SkURhlo3RXRaedar1DhD6M66yYFuD8X--cnr9g9SroYb-kqQXLzHFK4qYVVjDUz60x_71OLWib0QidiRC_KarxwTxNL7Gx04UJXz2sQhQYA-zMxv0Pue_nFj7SQ9GsJLT_xEUU7yj5FXqRGQ5wY69eI67GfXCct2xK2gTaE7JYzrQuqrBKW3vm8I1VWr49spLvdqdaeDVI-T82ZOQYF-ZEQuWES-fLuFfg89sgFJwvRGFtU5SnIUG-2vxdyF-xJcEY')" }}
              whileHover={{ scale: 1.05 }}
              transition={{ duration: 0.6 }}
            />
            <div className="absolute inset-0 bg-black/40 flex items-center justify-center pointer-events-none">
              <motion.div 
                className="bg-white p-4 rounded-2xl shadow-2xl"
                initial={{ scale: 0.8, opacity: 0 }}
                whileInView={{ scale: 1, opacity: 1 }}
                viewport={{ once: true }}
                transition={{ delay: 0.3, type: 'spring' }}
              >
                <QrCode size={48} className="text-gray-800" />
              </motion.div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
