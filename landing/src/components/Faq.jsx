import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown } from 'lucide-react';

const faqs = [
  { q: "Is JourneySync available now?", a: "JourneySync v1.0.0 is available as a direct Android APK download. iOS compatibility is planned through TestFlight." },
  { q: "How does Ride Radar work?", a: "When a ride is created, realtime events refresh nearby riders. Distance filtering keeps Radar focused on rides near you." },
  { q: "Does it replace Google Maps?", a: "No. JourneySync uses a hybrid model: riders can open Google Maps while JourneySync maintains ride state, tracking, and safety context." },
  { q: "What safety features are included?", a: "SOS alerts, emergency contacts, realtime rider status, safety overlays, and notification history are part of the ride experience." }
];

export function Faq() {
  const [openIndex, setOpenIndex] = useState(null);

  return (
    <section className="py-24 bg-background-light dark:bg-background-dark relative" id="faq">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <motion.div 
          className="text-center mb-16"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
        >
          <span className="inline-block py-1 px-3 rounded-full bg-primary/10 text-primary font-bold uppercase tracking-wider text-sm mb-4">
            FAQ
          </span>
          <h2 className="text-4xl md:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight">
            Answers before install.
          </h2>
        </motion.div>

        <div className="space-y-4">
          {faqs.map((faq, index) => {
            const isOpen = openIndex === index;
            
            return (
              <motion.div 
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ delay: index * 0.1 }}
                className={`rounded-3xl border transition-all duration-300 overflow-hidden ${isOpen ? 'bg-white dark:bg-gray-800 border-primary/30 shadow-xl' : 'bg-white/50 dark:bg-gray-800/50 border-gray-200 dark:border-gray-700 hover:border-primary/50 hover:bg-white dark:hover:bg-gray-800'}`}
              >
                <button 
                  onClick={() => setOpenIndex(isOpen ? null : index)}
                  className="w-full flex items-center justify-between text-left p-6 sm:p-8"
                >
                  <span className="text-xl font-bold text-gray-900 dark:text-white pr-4">
                    {faq.q}
                  </span>
                  <motion.div
                    animate={{ rotate: isOpen ? 180 : 0 }}
                    transition={{ duration: 0.3 }}
                    className={`shrink-0 w-10 h-10 rounded-full flex items-center justify-center transition-colors ${isOpen ? 'bg-primary text-white' : 'bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 group-hover:bg-primary/10 group-hover:text-primary'}`}
                  >
                    <ChevronDown size={20} strokeWidth={3} />
                  </motion.div>
                </button>
                
                <AnimatePresence>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3 }}
                    >
                      <div className="px-6 sm:px-8 pb-8 pt-0 text-gray-600 dark:text-gray-300 text-lg leading-relaxed">
                        {faq.a}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
