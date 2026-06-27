import React from 'react';
import { motion } from 'framer-motion';

export default function Hero() {
  return (
    <section className="relative pt-32 pb-20 md:pt-40 md:pb-28 overflow-hidden" id="home">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-orange-50 via-white to-white dark:from-orange-950/20 dark:via-gray-900 dark:to-gray-900 -z-10"></div>
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-8 items-center">
          <motion.div 
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="text-center lg:text-left"
          >
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-orange-100 dark:bg-orange-900/30 text-primary-dark dark:text-orange-400 font-semibold text-sm mb-6 shadow-sm border border-orange-200 dark:border-orange-800/50">
              <span className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-primary"></span>
              </span>
              Now Available for Android & iOS
            </div>
            
            <h1 className="text-5xl md:text-6xl lg:text-7xl font-display font-extrabold tracking-tight text-gray-900 dark:text-white mb-6 leading-tight">
              Ride together.<br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-primary to-orange-400">Stay connected.</span>
            </h1>
            
            <p className="text-xl md:text-2xl text-gray-600 dark:text-gray-300 mb-8 max-w-2xl mx-auto lg:mx-0 leading-relaxed">
              The smartest way to organize motorcycle group rides, track friends in real-time, and ensure everyone reaches safely.
            </p>
            
            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <a href="#download" className="px-8 py-4 bg-primary text-white rounded-xl font-bold text-lg hover:bg-primary-dark transition-all shadow-lg hover:shadow-orange-500/30 hover:-translate-y-1 flex items-center justify-center gap-2">
                Download App
              </a>
              <button className="px-8 py-4 bg-white dark:bg-gray-800 text-gray-900 dark:text-white rounded-xl font-bold text-lg border-2 border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 transition-all flex items-center justify-center gap-2">
                Watch Demo
              </button>
            </div>
          </motion.div>
          
          <motion.div 
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 1, delay: 0.2 }}
            className="relative mx-auto w-full max-w-[320px] lg:max-w-md perspective-1000"
          >
            <div className="relative rounded-[2.5rem] border-[8px] border-gray-900 dark:border-gray-800 bg-gray-900 shadow-2xl overflow-hidden aspect-[19.5/40]">
              <div className="absolute top-0 inset-x-0 h-6 bg-gray-900 rounded-b-3xl w-40 mx-auto z-20"></div>
              <img src="/map_bg.png" alt="App interface" className="w-full h-full object-cover opacity-90" />
            </div>
            
            <motion.div 
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 1 }}
              className="absolute -right-6 top-1/4 bg-white dark:bg-gray-800 p-4 rounded-xl shadow-xl border border-gray-100 dark:border-gray-700 z-30"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center text-green-600 dark:text-green-400">
                  ✓
                </div>
                <div>
                  <div className="font-bold text-sm text-gray-900 dark:text-white">Alex joined</div>
                  <div className="text-xs text-gray-500">2 mins ago</div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
