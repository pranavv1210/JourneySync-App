import { useEffect } from 'react';

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

    document.querySelectorAll('.faq-toggle').forEach(function(btn){
      btn.addEventListener('click', function(){
        const item = btn.closest('.faq-item');
        const open = item.classList.toggle('open');
        btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      });
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
        phone.style.setProperty('--phone-ry', `${x * 13}deg`);
        phone.style.setProperty('--phone-rx', `${-y * 9}deg`);
        phone.style.setProperty('--phone-x', `${x * 10}px`);
        phone.style.setProperty('--phone-y', `${y * 10}px`);
        const hero = document.getElementById('hero');
        if(hero) {
          hero.style.setProperty('--hero-glow-x', `${x * 22}px`);
          hero.style.setProperty('--hero-glow-y', `${y * 22}px`);
        }
      });
      heroWrap.addEventListener('pointerleave', function(){
        phone.style.removeProperty('--phone-ry');
        phone.style.removeProperty('--phone-rx');
        phone.style.removeProperty('--phone-x');
        phone.style.removeProperty('--phone-y');
        const hero = document.getElementById('hero');
        if(hero) {
          hero.style.removeProperty('--hero-glow-x');
          hero.style.removeProperty('--hero-glow-y');
        }
      });
    }

    document.querySelectorAll('.tilt-card, .feature-card, .testimonial-card, .faq-item').forEach(function(card){
      if(prefersReduced || !window.matchMedia('(pointer:fine)').matches) return;
      card.addEventListener('pointermove', function(e){
        const rect = card.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width;
        const y = (e.clientY - rect.top) / rect.height;
        card.style.setProperty('--pointer-x', `${x * 100}%`);
        card.style.setProperty('--pointer-y', `${y * 100}%`);
        card.style.setProperty('--tilt-x', `${(x - .5) * 4}deg`);
        card.style.setProperty('--tilt-y', `${-(y - .5) * 4}deg`);
      });
      card.addEventListener('pointerleave', function(){
        card.style.removeProperty('--pointer-x');
        card.style.removeProperty('--pointer-y');
        card.style.removeProperty('--tilt-x');
        card.style.removeProperty('--tilt-y');
      });
    });

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


  (function(){
    const modal = document.getElementById('legal-modal');
    const content = document.getElementById('legal-content');
    const closeBtn = document.getElementById('legal-close');
    const overlay = modal && modal.querySelector('[data-close]');

    let _lastFocused = null;
    let legalContentPromise = null;

    function loadLegalContent(){
      if(!legalContentPromise) {
        legalContentPromise = import('../data/legalContent');
      }
      return legalContentPromise;
    }


    async function openModal(key){
      _lastFocused = document.activeElement;
      document.body.style.overflow = 'hidden';
      const titleEl = document.getElementById('legal-title');
      titleEl.textContent = 'Loading';
      content.innerHTML = '<div class="text-gray-600 dark:text-gray-300">Loading...</div>';
      modal.classList.remove('hidden');
      modal.setAttribute('aria-hidden','false');

      const { templates, titles } = await loadLegalContent();
      if(!templates[key]) return;
      titleEl.textContent = titles[key] || 'Info';
      content.innerHTML = templates[key];
      const firstFocusable = modal.querySelector('button, a, input, textarea') || closeBtn;
      (firstFocusable || closeBtn).focus();
    }

    function closeModal(){
      modal.classList.add('hidden');
      modal.setAttribute('aria-hidden','true');
      // restore background scrolling
      document.body.style.overflow = '';
      if(_lastFocused && typeof _lastFocused.focus === 'function') _lastFocused.focus();
    }

    document.addEventListener('click', function(e){
      const el = e.target.closest && (e.target.closest('.legal-link') || e.target.closest('.info-link'));
      if(!el) return;
      e.preventDefault();
      const key = el.getAttribute('data-legal') || el.getAttribute('data-info');
      openModal(key);
    });

    if(closeBtn) closeBtn.addEventListener('click', closeModal);
    if(overlay) overlay.addEventListener('click', closeModal);
    document.addEventListener('keydown', function(e){ if(e.key === 'Escape') closeModal(); });
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

  // Demo video modal handlers
  (function(){
    const btn = document.getElementById('watch-demo-btn');
    const vmodal = document.getElementById('video-modal');
    const vclose = document.getElementById('video-close');
    const voverlay = vmodal && vmodal.querySelector('[data-close-video]');
    const video = document.getElementById('demo-video');
    let _last = null;
    if(!btn || !vmodal || !video) return;

    function openVideo(src){
      _last = document.activeElement;
      if(src) {
        // update source if provided
        const s = video.querySelector('source');
        if(s) s.src = src;
        try{ video.load(); }catch{}
      }
      document.body.style.overflow = 'hidden';
      document.body.classList.add('modal-open');
      vmodal.classList.remove('hidden');
      vmodal.setAttribute('aria-hidden','false');
      // Try to play with audio; if browser blocks autoplay with sound,
      // mute and try again so the demo reliably starts.
      try {
        const p = video.play();
        if (p && typeof p.catch === 'function') {
          p.catch(() => {
            try { video.muted = true; video.play().catch(()=>{}); } catch{}
          });
        }
      } catch {
        try { video.muted = true; video.play().catch(()=>{}); } catch{}
      }
      (vclose || video).focus();
    }

    function closeVideo(){
      vmodal.classList.add('hidden');
      vmodal.setAttribute('aria-hidden','true');
      try{ video.pause(); video.currentTime = 0; }catch{}
      // reset source to stop downloads (optional)
      const s = video.querySelector('source');
      if(s) s.src = s.getAttribute('data-default') || s.src;
      document.body.style.overflow = '';
      document.body.classList.remove('modal-open');
      if(_last && typeof _last.focus === 'function') _last.focus();
    }

    btn.addEventListener('click', function(e){
      e.preventDefault();
      const src = this.getAttribute('data-video') || './demovideo.mp4';
      openVideo(src);
    });
    if(vclose) vclose.addEventListener('click', closeVideo);
    if(voverlay) voverlay.addEventListener('click', closeVideo);
    document.addEventListener('keydown', function(e){ if(e.key === 'Escape') closeVideo(); });
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
