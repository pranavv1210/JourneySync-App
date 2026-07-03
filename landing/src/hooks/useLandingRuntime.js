import { useEffect } from 'react';
import { trackEvent } from '../utils/tracking';

export function useLandingRuntime() {
  useEffect(() => {
    // We execute the extracted JS here
    try {
      
  setTimeout(function(){
    var loader = document.getElementById('loading-screen');
    if(loader) loader.remove();
  }, 720);


  // Show a small toast when links with .coming-soon are clicked
  (function(){
    const toast = document.getElementById('coming-soon-toast');
    const toastText = document.getElementById('coming-soon-text');
    function showToast(msg){
      toastText.textContent = msg;
      toast.style.opacity = '1';
      toast.classList.remove('pointer-events-none');
      clearTimeout(window._comingSoonTimer);
      window._comingSoonTimer = setTimeout(()=>{
        toast.style.opacity = '0';
        toast.classList.add('pointer-events-none');
      }, 3000);
    }
    document.addEventListener('click', function(e){
      const el = e.target.closest && e.target.closest('.coming-soon');
      if(!el) return;
      e.preventDefault();
      const item = el.getAttribute('data-item') || 'This feature';
      showToast(item + ' will be available soon. Stay tuned!');
    });
  })();


  (function(){
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const header = document.querySelector('header');
    const progress = document.getElementById('scroll-progress');

    document.addEventListener('DOMContentLoaded', function(){
      document.getElementById('loading-screen')?.classList.add('is-hidden');
    });
    setTimeout(function(){
      document.getElementById('loading-screen')?.classList.add('is-hidden');
    }, 900);

    function onScroll(){
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const ratio = max > 0 ? window.scrollY / max : 0;
      if(progress) progress.style.width = (ratio * 100).toFixed(2) + '%';
      if(header) header.classList.toggle('is-scrolled', window.scrollY > 36);
      [25, 50, 75, 90].forEach(function(milestone){
        if(ratio * 100 >= milestone && !window.__jsScrollMilestones?.[milestone]) {
          window.__jsScrollMilestones = window.__jsScrollMilestones || {};
          window.__jsScrollMilestones[milestone] = true;
          trackEvent('scroll_milestone', { milestone });
        }
      });
    }
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    const revealTargets = [
      '.section-reveal',
      '.stagger-children',
      '.slide-in-left',
      '.slide-in-right',
      '.rotate-in',
      '.timeline-connector',
      '.stat-entrance',
    ].join(',');

    function bootRevealMotion(){
      const targets = Array.from(document.querySelectorAll(revealTargets));

      if (!('IntersectionObserver' in window)) {
        targets.forEach(function(target){
          target.classList.add('is-visible');
        });
        return;
      }

      const revealObserver = new IntersectionObserver(function(entries){
        entries.forEach(function(entry){
          if(entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            revealObserver.unobserve(entry.target);
          }
        });
      }, { threshold: 0.08, rootMargin: '0px 0px 12% 0px' });

      targets.forEach(function(target){
        revealObserver.observe(target);
      });

      setTimeout(function(){
        targets.forEach(function(target){
          target.classList.add('is-visible');
        });
      }, 1800);
    }

    bootRevealMotion();

    function bootInteractiveMotion(){
      const glow = document.getElementById('cursor-glow');
      const sections = Array.from(document.querySelectorAll('section[id]'));
      const navLinks = Array.from(document.querySelectorAll('header nav a[href^="#"]'));

      function updateActiveNav(){
        let active = '';
        for(const section of sections){
          const rect = section.getBoundingClientRect();
          if(rect.top <= 120 && rect.bottom >= 120) {
            active = '#' + section.id;
            break;
          }
        }
        navLinks.forEach(link => link.classList.toggle('active', link.getAttribute('href') === active));
      }
      updateActiveNav();
      window.addEventListener('scroll', updateActiveNav, { passive: true });

    const countObserver = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if(!entry.isIntersecting) return;
        const el = entry.target;
        const target = Number(el.dataset.count || 0);
        const start = performance.now();
        const duration = prefersReduced ? 1 : 1200;
        function tick(now){
          const progress = Math.min((now - start) / duration, 1);
          const eased = 1 - Math.pow(1 - progress, 3);
          el.textContent = Math.round(target * eased).toLocaleString();
          if(progress < 1) requestAnimationFrame(tick);
        }
        requestAnimationFrame(tick);
        countObserver.unobserve(el);
      });
    }, { threshold: 0.5 });
    document.querySelectorAll('.stat-number').forEach(el => countObserver.observe(el));

    document.addEventListener('click', function(e){
      const target = e.target.closest && e.target.closest('a, button');
      if(!target) return;
      const text = target.innerText ? target.innerText.trim() : '';
      const href = target.getAttribute('href') || '';
      if(text.includes('Join Closed Beta') || text.includes('Join Beta')) trackEvent('hero_cta', { label: text || 'Join Beta' });
      if(text.includes('Download Android') || text.includes('Download APK')) trackEvent('apk_download', { label: text });
      if(text.includes('Watch Demo')) trackEvent('watch_demo', { label: text || 'Demo' });
      if(href.includes('instagram.com')) trackEvent('instagram', { href });
      if(href.includes('github.com')) trackEvent('github', { href });
      if(href.includes('linkedin.com')) trackEvent('linkedin', { href });
      if(target.closest('#download')) trackEvent('footer_cta', { label: text });
    });

    if(!prefersReduced && glow && window.matchMedia('(pointer:fine)').matches) {
      window.addEventListener('pointermove', function(e){
        glow.style.opacity = '.9';
        glow.style.left = e.clientX + 'px';
        glow.style.top = e.clientY + 'px';
      }, { passive: true });
    }

    const heroWrap = document.querySelector('.hero-device-wrap');
    const phone = document.querySelector('.phone-mockup');
    if(!prefersReduced && heroWrap && phone && window.matchMedia('(pointer:fine)').matches) {
      heroWrap.addEventListener('pointermove', function(e){
        const rect = heroWrap.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width - .5;
        const y = (e.clientY - rect.top) / rect.height - .5;
        phone.style.transform = `rotateY(${x * 13}deg) rotateX(${-y * 9}deg) translate3d(${x * 8}px, ${y * 8}px, 0)`;
      });
      heroWrap.addEventListener('pointerleave', function(){
        phone.style.transform = '';
      });
    }

    document.querySelectorAll('.magnetic').forEach(function(el){
      if(prefersReduced || !window.matchMedia('(pointer:fine)').matches) return;
      el.addEventListener('pointermove', function(e){
        const rect = el.getBoundingClientRect();
        const x = (e.clientX - rect.left - rect.width / 2) * .12;
        const y = (e.clientY - rect.top - rect.height / 2) * .12;
        el.style.transform = `translate(${x}px, ${y}px) translateY(-2px)`;
      });
      el.addEventListener('pointerleave', function(){
        el.style.transform = '';
      });
    });

    }

    if('requestIdleCallback' in window) {
      requestIdleCallback(bootInteractiveMotion, { timeout: 1800 });
    } else {
      setTimeout(bootInteractiveMotion, 1200);
    }
  })();



  // Mobile menu toggle
  (function(){
    const btn = document.getElementById('mobile-menu-btn');
    const nav = document.getElementById('mobile-nav');
    if(!btn || !nav) return;
    btn.addEventListener('click', function(){
      const expanded = this.getAttribute('aria-expanded') === 'true';
      this.setAttribute('aria-expanded', (!expanded).toString());
      nav.classList.toggle('hidden');
    });
    // hide menu after clicking a link
    nav.addEventListener('click', function(e){
      if(e.target.tagName === 'A'){
        nav.classList.add('hidden');
        btn.setAttribute('aria-expanded','false');
      }
    });
  })();

  function handleHeaderDownloadCTA(e) {
    if(e) e.preventDefault();

    if(window.innerWidth < 768) {
      openDownloadModal();
      return;
    }

    const banner = document.getElementById('download-banner');
    if(!banner) return;

    const header = document.querySelector('header');
    const headerOffset = header ? header.offsetHeight + 24 : 100;
    const targetTop = banner.getBoundingClientRect().top + window.pageYOffset - headerOffset;

    window.scrollTo({
      top: Math.max(targetTop, 0),
      behavior: 'smooth'
    });
  }

  function openDownloadModal(e) {
    if(e) e.preventDefault();
    const dmodal = document.getElementById('download-modal');
    if(!dmodal) return;
    trackEvent('apk_download_modal_opened');
    document.body.style.overflow = 'hidden';
    document.body.classList.add('modal-open');
    dmodal.classList.remove('hidden');
    dmodal.setAttribute('aria-hidden', 'false');
  }

  function closeDownloadModal() {
    const dmodal = document.getElementById('download-modal');
    if(!dmodal) return;
    dmodal.classList.add('hidden');
    dmodal.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
    document.body.classList.remove('modal-open');
  }

  window.handleHeaderDownloadCTA = handleHeaderDownloadCTA;
  window.openDownloadModal = openDownloadModal;
  window.closeDownloadModal = closeDownloadModal;

  (function(){
    const dcancels = document.querySelectorAll('[data-close-download]');
    dcancels.forEach(btn => {
      btn.addEventListener('click', closeDownloadModal);
    });
    document.addEventListener('keydown', function(e){ 
      if(e.key === 'Escape') closeDownloadModal(); 
    });
  })();

  (function() {
    const qrImage = document.getElementById('download-qr-image');
    const qrLink = document.getElementById('download-qr-link');
    if(!qrImage || !qrLink) return;

    const apkUrl = new URL('./journeysync.apk', window.location.href).href;
    qrLink.href = apkUrl;
    qrImage.src = 'https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=12&data=' + encodeURIComponent(apkUrl);
  })();


    } catch (e) {
      console.error("Vanilla JS Error:", e);
    }
  }, []);
}
