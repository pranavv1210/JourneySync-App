import React, { useState } from 'react';
import { motion } from 'framer-motion';

export default function Footer() {
  const [modalOpen, setModalOpen] = useState(false);
  const [modalContent, setModalContent] = useState({ title: '', body: '' });

  const legals = {
    privacy: {
      title: 'Privacy Policy',
      body: <iframe src="/privacy-policy.html" title="Privacy Policy" className="w-full rounded-lg border border-gray-200 h-[56vh]" />
    },
    terms: {
      title: 'Terms of Use',
      body: <p>Last updated April 06, 2026. We are JourneySync...</p>
    },
    safety: {
      title: 'Safety Disclaimer',
      body: <p>JourneySync is designed to enhance ride coordination, not replace responsible riding practices.</p>
    }
  };

  const openModal = (key) => {
    if (legals[key]) {
      setModalContent(legals[key]);
      setModalOpen(true);
    }
  };

  return (
    <>
      <section className="py-24 bg-gray-900 text-white relative overflow-hidden" id="download">
        <div className="absolute inset-0 bg-primary/20 blur-[120px] rounded-full max-w-4xl mx-auto top-1/2 -translate-y-1/2 opacity-30"></div>
        <div className="max-w-4xl mx-auto px-4 text-center relative z-10">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <h2 className="text-4xl md:text-5xl font-display font-bold mb-6">Ready to ride?</h2>
            <p className="text-xl text-gray-400 mb-10 max-w-2xl mx-auto">
              Join the community of riders who have already upgraded their group touring experience.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a href="/journeysync.apk" download className="px-8 py-4 bg-primary text-white rounded-xl font-bold hover:bg-primary-dark transition-all flex items-center justify-center gap-3">
                Download APK
              </a>
              <a href="/journeysync.ipa" download className="px-8 py-4 bg-white text-gray-900 rounded-xl font-bold hover:bg-gray-100 transition-all flex items-center justify-center gap-3">
                Download IPA
              </a>
            </div>
          </motion.div>
        </div>
      </section>

      <footer className="bg-gray-950 pt-16 pb-8 border-t border-gray-900 text-gray-400 text-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 grid grid-cols-1 md:grid-cols-4 gap-12 mb-12">
          <div>
            <div className="flex items-center gap-2 mb-6">
              <img src="/logo.png" alt="JourneySync Logo" className="w-8 h-8 rounded-lg" />
              <span className="font-display font-bold text-xl text-white">JourneySync</span>
            </div>
            <p className="mb-6">The definitive app for group motorcycle rides.</p>
            <div className="flex gap-4">
              <a href="https://github.com/pranavv1210/journeysync-app" target="_blank" rel="noreferrer" className="text-white hover:text-primary transition-colors">
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.09 3.29 9.4 7.86 10.93.58.11.79-.25.79-.56 0-.28-.01-1.02-.02-2-3.2.7-3.88-1.54-3.88-1.54-.53-1.35-1.3-1.71-1.3-1.71-1.06-.72.08-.7.08-.7 1.17.08 1.78 1.2 1.78 1.2 1.04 1.78 2.73 1.27 3.4.97.11-.76.41-1.27.74-1.56-2.56-.29-5.25-1.28-5.25-5.7 0-1.26.45-2.29 1.2-3.1-.12-.29-.52-1.47.11-3.06 0 0 .98-.31 3.2 1.18.93-.26 1.92-.39 2.91-.39.99 0 1.98.13 2.91.39 2.22-1.5 3.2-1.18 3.2-1.18.63 1.59.23 2.77.11 3.06.75.81 1.2 1.84 1.2 3.1 0 4.43-2.7 5.4-5.27 5.68.42.36.8 1.07.8 2.16 0 1.56-.01 2.82-.01 3.2 0 .31.21.68.8.56C20.71 21.4 24 17.09 24 12c0-6.35-5.15-11.5-12-11.5z"/>
                </svg>
              </a>
            </div>
          </div>
          <div>
            <h4 className="font-bold text-white mb-4">Product</h4>
            <ul className="space-y-2">
              <li><a href="#features" className="hover:text-primary transition-colors">Features</a></li>
              <li><a href="#download" className="hover:text-primary transition-colors">Download</a></li>
            </ul>
          </div>
          <div>
            <h4 className="font-bold text-white mb-4">Company</h4>
            <ul className="space-y-2">
              <li><a href="#" className="hover:text-primary transition-colors">About Us</a></li>
              <li><a href="mailto:journeysync.app@gmail.com" className="hover:text-primary transition-colors">Contact</a></li>
            </ul>
          </div>
          <div>
            <h4 className="font-bold text-white mb-4">Legal</h4>
            <ul className="space-y-2">
              <li><button onClick={() => openModal('privacy')} className="hover:text-primary transition-colors">Privacy Policy</button></li>
              <li><button onClick={() => openModal('terms')} className="hover:text-primary transition-colors">Terms of Use</button></li>
              <li><button onClick={() => openModal('safety')} className="hover:text-primary transition-colors">Safety Disclaimer</button></li>
            </ul>
          </div>
        </div>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 border-t border-gray-800 pt-8 flex justify-between items-center">
          <p>© 2026 JourneySync Inc. All rights reserved.</p>
          <p>Made for riders.</p>
        </div>
      </footer>

      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center px-4 bg-black/60">
          <div className="relative w-full max-w-2xl bg-white dark:bg-gray-900 rounded-xl shadow-2xl p-6">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-bold">{modalContent.title}</h3>
              <button onClick={() => setModalOpen(false)} className="text-gray-500 hover:text-gray-900 dark:hover:text-white">✕</button>
            </div>
            <div className="text-sm overflow-y-auto max-h-[70vh]">
              {modalContent.body}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
