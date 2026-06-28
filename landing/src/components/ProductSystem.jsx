import React from 'react';
import { motion } from 'framer-motion';
import { Radar, Map, CarFront, CloudRain } from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.15, delayChildren: 0.1 }
  }
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { type: 'spring', stiffness: 100 } }
};

export function ProductSystem() {
  return (
    <section className="py-24 relative overflow-hidden bg-white/40 dark:bg-gray-900/40">
      <div className="absolute inset-0 bg-gradient-to-b from-white/40 via-primary/5 to-transparent pointer-events-none" />
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid lg:grid-cols-[0.9fr_1.1fr] gap-12 items-center">
          <motion.div 
            initial={{ opacity: 0, x: -40 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.7 }}
          >
            <span className="inline-block py-1 px-3 rounded-full bg-primary/10 text-primary font-bold uppercase tracking-wider text-sm mb-4">
              Production Ride OS
            </span>
            <h2 className="text-4xl md:text-5xl lg:text-6xl font-extrabold text-gray-900 dark:text-white leading-tight tracking-tight">
              A premium cockpit <br/>for modern group rides.
            </h2>
            <p className="mt-6 text-lg md:text-xl text-gray-600 dark:text-gray-300 leading-relaxed max-w-lg">
              JourneySync combines Ride Radar, realtime pack tracking, SOS, Google Maps hybrid navigation, weather intelligence, garage, achievements, fuel stations, and a premium ride HUD in one focused product.
            </p>
          </motion.div>

          <motion.div 
            className="grid sm:grid-cols-2 gap-5"
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-50px" }}
          >
            {[
              { icon: Radar, title: "Ride Radar", desc: "Nearby active rides surface automatically with distance-aware discovery." },
              { icon: Map, title: "Hybrid Navigation", desc: "Open Google Maps while JourneySync keeps ride state and tracking alive." },
              { icon: CarFront, title: "Garage + Achievements", desc: "A rider profile that feels personal, not like a placeholder settings page." },
              { icon: CloudRain, title: "Weather + Fuel", desc: "Ride conditions and nearby essentials are built into the journey flow." }
            ].map((feature, i) => (
              <motion.div 
                key={i} 
                variants={itemVariants}
                whileHover={{ y: -5, scale: 1.02 }}
                className="group relative bg-white dark:bg-gray-800 rounded-3xl p-6 shadow-xl border border-gray-100 dark:border-gray-700 hover:border-primary/30 transition-all overflow-hidden"
              >
                <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                <feature.icon className="text-primary mb-4" size={32} strokeWidth={2.5} />
                <h3 className="text-xl font-extrabold text-gray-900 dark:text-white mb-2">{feature.title}</h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">{feature.desc}</p>
              </motion.div>
            ))}
          </motion.div>
        </div>

        <motion.div 
          className="mt-20 grid grid-cols-2 lg:grid-cols-4 gap-6"
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-50px" }}
        >
          {[
            { value: "v1.0", label: "Current Release" },
            { value: "APK", label: "Android Available" },
            { value: "IPA", label: "iOS Ready" },
            { value: "SOS", label: "Safety Stack" }
          ].map((stat, i) => (
            <motion.div 
              key={i}
              variants={itemVariants}
              whileHover={{ scale: 1.05 }}
              className="bg-white/60 dark:bg-gray-800/60 backdrop-blur-md rounded-3xl p-8 text-center shadow-lg border border-white/50 dark:border-white/10"
            >
              <div className="text-4xl md:text-5xl font-extrabold text-primary mb-2">{stat.value}</div>
              <p className="text-sm md:text-base font-bold text-gray-600 dark:text-gray-300 uppercase tracking-wide">{stat.label}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
