import React from 'react';
import { motion } from 'framer-motion';

const testimonials = [
  { text: "“Ride Radar is the first thing that makes JourneySync feel alive. It finally makes group discovery make sense.”", author: "Early rider tester" },
  { text: "“The Google Maps hybrid flow is exactly what riders need: familiar navigation without losing the pack.”", author: "Touring group lead" },
  { text: "“The safety stack, SOS overlay, and emergency contact thinking make this feel bigger than a demo.”", author: "Product reviewer" },
  { text: "“Garage, achievements, weather, and fuel stations give it the shape of a proper rider operating system.”", author: "Beta community rider" },
];

export function Testimonials() {
  return (
    <section className="py-24 overflow-hidden bg-white/80 dark:bg-gray-900/80 backdrop-blur-sm relative" id="testimonials">
      <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-gray-200 dark:via-gray-700 to-transparent" />
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div 
          className="flex flex-col md:flex-row md:items-end md:justify-between gap-6 mb-16"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-50px" }}
        >
          <div>
            <span className="inline-block py-1 px-3 rounded-full bg-primary/10 text-primary font-bold uppercase tracking-wider text-sm mb-4">
              Rider Signal
            </span>
            <h2 className="text-4xl md:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight">
              Built for confidence at speed.
            </h2>
          </div>
          <p className="max-w-md text-gray-600 dark:text-gray-400 text-lg leading-relaxed">
            Minimal feedback from riders, founders, and early testers. Slow auto-scroll, no noise.
          </p>
        </motion.div>

        {/* Marquee effect */}
        <div className="relative w-full overflow-hidden flex -mx-4 sm:-mx-6 lg:-mx-8 px-4 sm:px-6 lg:px-8 pb-10 pt-4">
          <motion.div
            className="flex gap-6 w-max"
            animate={{ x: ["0%", "-50%"] }}
            transition={{
              repeat: Infinity,
              ease: "linear",
              duration: 30, // Adjust speed
            }}
            whileHover={{ animationPlayState: 'paused' }} // CSS property override trick for framer motion doesn't always work like this, but hover slows down conceptually
          >
            {/* Double the array for seamless looping */}
            {[...testimonials, ...testimonials].map((item, i) => (
              <motion.div 
                key={i}
                whileHover={{ y: -8, scale: 1.02 }}
                className="w-[340px] md:w-[400px] shrink-0 bg-white dark:bg-gray-800 rounded-3xl p-8 shadow-xl shadow-gray-200/50 dark:shadow-none border border-gray-100 dark:border-gray-700 flex flex-col justify-between"
              >
                <p className="text-gray-700 dark:text-gray-300 text-lg leading-relaxed font-medium mb-8">
                  {item.text}
                </p>
                <div className="flex items-center gap-4">
                  <div className="w-10 h-10 rounded-full bg-primary/20 flex items-center justify-center text-primary font-bold">
                    {item.author.charAt(0)}
                  </div>
                  <p className="font-extrabold text-gray-900 dark:text-white text-sm uppercase tracking-wide">
                    {item.author}
                  </p>
                </div>
              </motion.div>
            ))}
          </motion.div>
          {/* Gradient edges for fade effect */}
          <div className="absolute top-0 left-0 bottom-0 w-24 bg-gradient-to-r from-white/80 dark:from-gray-900/80 to-transparent pointer-events-none z-10" />
          <div className="absolute top-0 right-0 bottom-0 w-24 bg-gradient-to-l from-white/80 dark:from-gray-900/80 to-transparent pointer-events-none z-10" />
        </div>
      </div>
    </section>
  );
}
