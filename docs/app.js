/**
 * Routine Planner — Orbix Studio-Inspired Interaction Engine
 * GSAP 3.12 + ScrollTrigger · Lenis Smooth Scroll · Interactive Telemetry
 */

(function () {
  'use strict';

  // --- Smooth Scroll (Lenis) ---
  let lenisInstance = null;
  if (typeof Lenis !== 'undefined') {
    try {
      lenisInstance = new Lenis({
        duration: 1.1,
        easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
        orientation: 'vertical',
        smoothWheel: true,
      });

      function raf(time) {
        lenisInstance.raf(time);
        requestAnimationFrame(raf);
      }
      requestAnimationFrame(raf);

      if (typeof gsap !== 'undefined' && typeof ScrollTrigger !== 'undefined') {
        lenisInstance.on('scroll', ScrollTrigger.update);
        gsap.ticker.add((time) => {
          lenisInstance.raf(time * 1000);
        });
        gsap.ticker.lagSmoothing(0);
      }
    } catch (e) {
      console.warn('Lenis smooth scroll fallback:', e);
    }
  }

  // Register GSAP plugins
  if (typeof gsap !== 'undefined' && typeof ScrollTrigger !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
  }

  document.addEventListener('DOMContentLoaded', () => {
    initSmoothAnchors();
    initHeroPillSlider();
    initHeroGraph();
    initResinCalculator();
    initScheduleFilter();
    initPhoneTour();
    initAccordion();
    initScrollAnimations();
  });

  /* ==========================================================================
     1. SMOOTH ANCHOR NAVIGATION
     ========================================================================== */
  function initSmoothAnchors() {
    document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
      anchor.addEventListener('click', function (e) {
        const targetId = this.getAttribute('href');
        if (!targetId || targetId === '#') return;
        const targetEl = document.querySelector(targetId);
        if (targetEl) {
          e.preventDefault();
          if (lenisInstance) {
            lenisInstance.scrollTo(targetEl, { offset: -70 });
          } else {
            targetEl.scrollIntoView({ behavior: 'smooth' });
          }
        }
      });
    });
  }

  /* ==========================================================================
     2. HERO ROTATING PILL SLIDER (Orbix Signature Banner)
     ========================================================================== */
  function initHeroPillSlider() {
    const slider = document.getElementById('pill-slider');
    if (!slider) return;

    const items = slider.querySelectorAll('.pill-slider-item');
    if (items.length <= 1) return;

    let currentIndex = 0;

    setInterval(() => {
      const prevItem = items[currentIndex];
      currentIndex = (currentIndex + 1) % items.length;
      const nextItem = items[currentIndex];

      if (typeof gsap !== 'undefined') {
        gsap.to(prevItem, {
          y: -14,
          opacity: 0,
          duration: 0.4,
          ease: 'power2.in',
          onComplete: () => {
            prevItem.classList.remove('active');
            gsap.set(prevItem, { y: 14 });
            nextItem.classList.add('active');
            gsap.to(nextItem, {
              y: 0,
              opacity: 1,
              duration: 0.45,
              ease: 'power2.out',
            });
          },
        });
      } else {
        prevItem.classList.remove('active');
        nextItem.classList.add('active');
      }
    }, 3800);
  }

  /* ==========================================================================
     3. HERO INTERACTIVE CURVE GRAPH & REGEN TIMER
     ========================================================================== */
  function initHeroGraph() {
    // Ticking regen timer in hero
    const timerEl = document.getElementById('hero-regen-timer');
    let regenSecs = 312;

    if (timerEl) {
      setInterval(() => {
        regenSecs--;
        if (regenSecs <= 0) {
          regenSecs = 480;
          const heroVal = document.getElementById('hero-resin-val');
          if (heroVal) {
            const cur = parseInt(heroVal.textContent, 10) || 143;
            if (cur < 200) heroVal.textContent = cur + 1;
          }
        }
        const m = Math.floor(regenSecs / 60);
        const s = regenSecs % 60;
        timerEl.textContent = `${m}:${s < 10 ? '0' : ''}${s}`;
      }, 1000);
    }

    // Hoverable anchor points on curve
    const points = document.querySelectorAll('.curve-pt');
    points.forEach((pt) => {
      const tipText = pt.getAttribute('data-tip');
      if (!tipText) return;

      pt.addEventListener('mouseenter', (e) => {
        showTooltip(e, tipText);
        if (typeof gsap !== 'undefined') {
          gsap.to(pt, { attr: { r: 8 }, duration: 0.2, ease: 'back.out(2)' });
        }
      });

      pt.addEventListener('mouseleave', () => {
        hideTooltip();
        const baseR = pt.classList.contains('active-pt') ? 6 : 5;
        if (typeof gsap !== 'undefined') {
          gsap.to(pt, { attr: { r: baseR }, duration: 0.2 });
        }
      });
    });

    // Tooltip singleton
    let tooltipEl = document.getElementById('orbix-curve-tooltip');
    if (!tooltipEl) {
      tooltipEl = document.createElement('div');
      tooltipEl.id = 'orbix-curve-tooltip';
      tooltipEl.style.cssText = `
        position: fixed;
        pointer-events: none;
        background: #0A0A0E;
        color: #FFFFFF;
        font-family: 'Inter', sans-serif;
        font-size: 11px;
        font-weight: 600;
        padding: 5px 10px;
        border-radius: 6px;
        border: 1px solid rgba(255, 255, 255, 0.15);
        box-shadow: 0 4px 14px rgba(0,0,0,0.3);
        opacity: 0;
        transform: translate(-50%, -120%);
        transition: opacity 0.15s ease, transform 0.15s ease;
        z-index: 9999;
      `;
      document.body.appendChild(tooltipEl);
    }

    function showTooltip(e, text) {
      tooltipEl.textContent = text;
      tooltipEl.style.left = `${e.clientX}px`;
      tooltipEl.style.top = `${e.clientY}px`;
      tooltipEl.style.opacity = '1';
      tooltipEl.style.transform = 'translate(-50%, -130%)';
    }

    function hideTooltip() {
      tooltipEl.style.opacity = '0';
      tooltipEl.style.transform = 'translate(-50%, -120%)';
    }
  }

  /* ==========================================================================
     4. LIVE RESIN & SERVER RESET CALCULATOR
     ========================================================================== */
  function initResinCalculator() {
    const rangeInput = document.getElementById('calc-resin-range');
    const numInput = document.getElementById('calc-resin-num');
    const serverSelect = document.getElementById('calc-server-select');
    const ringProgress = document.getElementById('calc-ring-progress');
    const ringVal = document.getElementById('calc-ring-val');
    const time160El = document.getElementById('calc-time-160');
    const time200El = document.getElementById('calc-time-200');
    const serverResetEl = document.getElementById('calc-server-reset');

    if (!rangeInput || !numInput) return;

    // Radius = 74, Circumference = 2 * PI * 74 = ~464.95
    const CIRCUMFERENCE = 464.955;

    // Server reset hour in UTC (04:00 server local time):
    // Europe: 04:00 UTC+1 -> 03:00 UTC
    // America: 04:00 UTC-5 -> 09:00 UTC
    // Asia: 04:00 UTC+8 -> 20:00 UTC
    // TW/HK/MO: 04:00 UTC+8 -> 20:00 UTC
    const SERVER_RESET_UTC_HOURS = {
      europe: 3,
      america: 9,
      asia: 20,
      tw: 20,
    };

    function calculate() {
      let resin = parseInt(rangeInput.value, 10);
      if (isNaN(resin)) resin = 0;
      resin = Math.max(0, Math.min(200, resin));

      // Sync inputs
      rangeInput.value = resin;
      numInput.value = resin;
      if (ringVal) ringVal.textContent = resin;

      // Update circular dial
      if (ringProgress) {
        const offset = CIRCUMFERENCE - (resin / 200) * CIRCUMFERENCE;
        ringProgress.style.strokeDashoffset = offset;
        if (resin >= 200) {
          ringProgress.style.stroke = '#EF4444'; // Red alert for capped
        } else if (resin >= 160) {
          ringProgress.style.stroke = '#F59E0B'; // Amber alert for condensed window
        } else {
          ringProgress.style.stroke = '#2D47E2'; // Brand blue
        }
      }

      const now = new Date();

      // Calculation to 160
      if (time160El) {
        if (resin >= 160) {
          time160El.innerHTML = `<span style="color: #F59E0B">Capped (${resin} ≥ 160)</span>`;
        } else {
          const needed = 160 - resin;
          const mins = needed * 8;
          const target = new Date(now.getTime() + mins * 60 * 1000);
          const hh = String(target.getHours()).padStart(2, '0');
          const mm = String(target.getMinutes()).padStart(2, '0');
          const durHours = Math.floor(mins / 60);
          const durMins = mins % 60;
          time160El.textContent = `${hh}:${mm} (in ${durHours}h ${durMins}m)`;
        }
      }

      // Calculation to 200
      if (time200El) {
        if (resin >= 200) {
          time200El.innerHTML = `<span style="color: #EF4444">Full Cap Waste Warning!</span>`;
        } else {
          const needed = 200 - resin;
          const mins = needed * 8;
          const target = new Date(now.getTime() + mins * 60 * 1000);
          const hh = String(target.getHours()).padStart(2, '0');
          const mm = String(target.getMinutes()).padStart(2, '0');
          const durHours = Math.floor(mins / 60);
          const durMins = mins % 60;
          time200El.textContent = `${hh}:${mm} (in ${durHours}h ${durMins}m)`;
        }
      }

      // Daily server reset calculation
      if (serverResetEl && serverSelect) {
        const serverKey = serverSelect.value || 'europe';
        const resetUtcHour = SERVER_RESET_UTC_HOURS[serverKey] ?? 3;

        // Construct next reset in UTC
        const nextReset = new Date();
        nextReset.setUTCHours(resetUtcHour, 0, 0, 0);

        // If today's reset already passed, advance to tomorrow
        if (nextReset.getTime() <= now.getTime()) {
          nextReset.setUTCDate(nextReset.getUTCDate() + 1);
        }

        const diffMs = nextReset.getTime() - now.getTime();
        const diffMinsTotal = Math.floor(diffMs / (1000 * 60));
        const remHours = Math.floor(diffMinsTotal / 60);
        const remMins = diffMinsTotal % 60;

        const localH = String(nextReset.getHours()).padStart(2, '0');
        const localM = String(nextReset.getMinutes()).padStart(2, '0');

        serverResetEl.textContent = `${localH}:${localM} (in ${remHours}h ${remMins}m)`;
      }
    }

    rangeInput.addEventListener('input', (e) => {
      numInput.value = e.target.value;
      calculate();
    });

    numInput.addEventListener('input', (e) => {
      let val = parseInt(e.target.value, 10);
      if (isNaN(val)) val = 0;
      val = Math.max(0, Math.min(200, val));
      rangeInput.value = val;
      calculate();
    });

    if (serverSelect) {
      serverSelect.addEventListener('change', calculate);
    }

    // Initial calculation
    calculate();
  }

  /* ==========================================================================
     5. WEEKLY DOMAIN ROTATION SCHEDULE
     ========================================================================== */
  function initScheduleFilter() {
    const dayButtons = document.querySelectorAll('.day-tab-btn');
    const cards = document.querySelectorAll('.schedule-card');
    if (!dayButtons.length || !cards.length) return;

    // Detect actual day of week to set default
    const dayNames = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    const todayIndex = new Date().getDay();
    const currentDayStr = dayNames[todayIndex];

    // Set default active tab matching today if available
    let matchedInitial = false;
    dayButtons.forEach((btn) => {
      const day = btn.getAttribute('data-day');
      if (day === currentDayStr) {
        dayButtons.forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        filterDay(day);
        matchedInitial = true;
      }
    });

    if (!matchedInitial) {
      filterDay('fri'); // default fallback
    }

    dayButtons.forEach((btn) => {
      btn.addEventListener('click', () => {
        dayButtons.forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        const selectedDay = btn.getAttribute('data-day');
        filterDay(selectedDay);
      });
    });

    function filterDay(day) {
      cards.forEach((card) => {
        const supported = (card.getAttribute('data-days') || '').split(' ');
        const shouldShow = day === 'sun' || supported.includes(day);

        if (shouldShow) {
          card.style.display = 'block';
          if (typeof gsap !== 'undefined') {
            gsap.fromTo(
              card,
              { opacity: 0, y: 12 },
              { opacity: 1, y: 0, duration: 0.35, ease: 'power2.out' }
            );
          } else {
            card.style.opacity = '1';
          }
        } else {
          card.style.display = 'none';
        }
      });
    }
  }

  /* ==========================================================================
     6. INTERACTIVE PHONE TOUR & RESIN ACTIONS
     ========================================================================== */
  function initPhoneTour() {
    const tabs = document.querySelectorAll('.ps-tab-btn');
    const bottomNavItems = document.querySelectorAll('.ps-bnav-item');
    const views = document.querySelectorAll('.ps-view');

    function switchView(tabKey) {
      tabs.forEach((t) => {
        const isActive = t.getAttribute('data-tab') === tabKey;
        t.classList.toggle('active', isActive);
        t.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });

      bottomNavItems.forEach((b) => {
        b.classList.toggle('active', b.getAttribute('data-tab') === tabKey);
      });

      views.forEach((v) => {
        const isMatch = v.id === `ps-view-${tabKey}`;
        v.classList.toggle('active', isMatch);
        if (isMatch && typeof gsap !== 'undefined') {
          gsap.fromTo(
            v,
            { opacity: 0, y: 10 },
            { opacity: 1, y: 0, duration: 0.3, ease: 'power2.out' }
          );
        }
      });
    }

    tabs.forEach((tab) => {
      tab.addEventListener('click', () => {
        const targetTab = tab.getAttribute('data-tab');
        if (targetTab) switchView(targetTab);
      });
    });

    bottomNavItems.forEach((item) => {
      item.addEventListener('click', () => {
        const targetTab = item.getAttribute('data-tab');
        if (targetTab) switchView(targetTab);
      });
    });

    // Mock Resin spend buttons (-20 button)
    let phoneResin = 143;
    const spendButtons = document.querySelectorAll('.mock-spend-btn');

    spendButtons.forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        phoneResin = Math.max(0, phoneResin - 20);
        updatePhoneResinDisplays(phoneResin);

        // Tick parent checkbox
        const row = btn.closest('.mock-task-row');
        if (row) {
          const cb = row.querySelector('.mock-checkbox');
          if (cb && !cb.classList.contains('checked')) {
            cb.classList.add('checked');
            if (typeof gsap !== 'undefined') {
              gsap.from(cb, { scale: 0.6, duration: 0.3, ease: 'back.out(2)' });
            }
          }
        }

        // Button pop feedback
        if (typeof gsap !== 'undefined') {
          gsap.from(btn, { scale: 0.8, duration: 0.2, ease: 'back.out(2)' });
        }
      });
    });

    // Toggle tasks on row click
    document.querySelectorAll('.mock-task-row').forEach((row) => {
      row.addEventListener('click', (e) => {
        if (e.target.closest('.mock-spend-btn')) return;
        const cb = row.querySelector('.mock-checkbox');
        if (cb) {
          const wasChecked = cb.classList.toggle('checked');
          if (typeof gsap !== 'undefined') {
            gsap.to(row, { opacity: wasChecked ? 0.45 : 1, duration: 0.25 });
          }
        }
      });
    });

    function updatePhoneResinDisplays(val) {
      document.querySelectorAll('.mock-resin-val-num').forEach((el) => {
        el.textContent = val;
      });
      document.querySelectorAll('.mock-bar-fill').forEach((bar) => {
        const pct = Math.min(100, (val / 200) * 100);
        if (typeof gsap !== 'undefined') {
          gsap.to(bar, { width: pct + '%', duration: 0.4, ease: 'power2.out' });
        } else {
          bar.style.width = pct + '%';
        }
      });
    }

    // Mock countdown timer
    let phoneSecs = 312;
    setInterval(() => {
      phoneSecs--;
      if (phoneSecs <= 0) {
        phoneSecs = 480;
        phoneResin = Math.min(200, phoneResin + 1);
        updatePhoneResinDisplays(phoneResin);
      }
      const m = Math.floor(phoneSecs / 60);
      const s = phoneSecs % 60;
      document.querySelectorAll('.mock-timer-display').forEach((el) => {
        el.textContent = `${m}:${s < 10 ? '0' : ''}${s}`;
      });
    }, 1000);
  }

  /* ==========================================================================
     7. FREQUENTLY ASKED QUESTIONS (Orbix Accordion)
     ========================================================================== */
  function initAccordion() {
    const items = document.querySelectorAll('.accordion-item');
    if (!items.length) return;

    items.forEach((item) => {
      const header = item.querySelector('.accordion-header');
      if (!header) return;

      header.addEventListener('click', () => {
        const isOpen = item.classList.contains('active');

        // Close all others
        items.forEach((other) => {
          if (other !== item) {
            other.classList.remove('active');
            const h = other.querySelector('.accordion-header');
            if (h) h.setAttribute('aria-expanded', 'false');
          }
        });

        // Toggle clicked
        if (isOpen) {
          item.classList.remove('active');
          header.setAttribute('aria-expanded', 'false');
        } else {
          item.classList.add('active');
          header.setAttribute('aria-expanded', 'true');
          const body = item.querySelector('.accordion-body');
          if (body && typeof gsap !== 'undefined') {
            gsap.from(body.querySelector('p'), {
              y: 8,
              opacity: 0,
              duration: 0.35,
              ease: 'power2.out',
            });
          }
        }
      });
    });
  }

  /* ==========================================================================
     8. GSAP SCROLL ENTRANCES (Orbix Subtle Animations)
     ========================================================================== */
  function initScrollAnimations() {
    if (typeof gsap === 'undefined' || typeof ScrollTrigger === 'undefined') return;

    // Hero entrance timeline
    const heroTl = gsap.timeline({ defaults: { ease: 'power3.out' } });

    heroTl
      .from('.orbix-navbar', { y: -30, opacity: 0, duration: 0.8, delay: 0.1 })
      .from('.orbix-pill-slider', { y: 20, opacity: 0, duration: 0.6 }, '-=0.4')
      .from('.orbix-hero-headline', { y: 24, opacity: 0, duration: 0.8 }, '-=0.4')
      .from('.orbix-hero-sub', { y: 20, opacity: 0, duration: 0.6 }, '-=0.5')
      .from('.orbix-trust-pill', { y: 16, opacity: 0, duration: 0.5 }, '-=0.4')
      .from('.orbix-hero-actions', { y: 20, opacity: 0, duration: 0.6 }, '-=0.3')
      .from('.hero-showcase-card', { y: 40, opacity: 0, duration: 0.9, ease: 'power4.out' }, '-=0.4');

    // Bento cards stagger reveal
    gsap.utils.toArray('.orbix-card').forEach((card, idx) => {
      gsap.from(card, {
        scrollTrigger: {
          trigger: card,
          start: 'top 85%',
          toggleActions: 'play none none none',
        },
        y: 35,
        opacity: 0,
        duration: 0.7,
        delay: (idx % 3) * 0.1,
        ease: 'power3.out',
      });
    });

    // Dark section phone mockup reveal
    gsap.from('.orbix-phone-frame', {
      scrollTrigger: {
        trigger: '#screens',
        start: 'top 70%',
        toggleActions: 'play none none none',
      },
      y: 50,
      opacity: 0,
      duration: 1.0,
      ease: 'power3.out',
    });

    // Dark section callout cards stagger
    gsap.utils.toArray('.callout-card').forEach((callout, i) => {
      gsap.from(callout, {
        scrollTrigger: {
          trigger: callout,
          start: 'top 85%',
          toggleActions: 'play none none none',
        },
        y: 25,
        opacity: 0,
        duration: 0.6,
        delay: i * 0.12,
        ease: 'power2.out',
      });
    });

    // Final CTA reveal
    gsap.from('.final-cta-card', {
      scrollTrigger: {
        trigger: '.orbix-final-cta-section',
        start: 'top 80%',
        toggleActions: 'play none none none',
      },
      scale: 0.96,
      y: 30,
      opacity: 0,
      duration: 0.8,
      ease: 'power3.out',
    });
  }
})();
