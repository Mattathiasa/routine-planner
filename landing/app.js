/**
 * Routine Planner Landing Page — Interactive Controller
 * Follows Modern Web Standards, Accessibility (WCAG AAA) & Smooth Feedback
 */

document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initScrollspy();
  initMockupInteractions();
  initResinCalculator();
  initScheduleFilter();
  initFaqAccordion();
});

/* ==========================================================================
   1. Theme Management (Light / Dark Mode)
   ========================================================================== */
function initTheme() {
  const toggleBtn = document.getElementById('theme-toggle');
  if (!toggleBtn) return;

  const currentTheme = localStorage.getItem('rp-theme') || 
    (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');

  setTheme(currentTheme);

  toggleBtn.addEventListener('click', () => {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const newTheme = isDark ? 'light' : 'dark';
    setTheme(newTheme);
    localStorage.setItem('rp-theme', newTheme);
  });

  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem('rp-theme')) {
      setTheme(e.matches ? 'dark' : 'light');
    }
  });
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  const toggleBtn = document.getElementById('theme-toggle');
  if (toggleBtn) {
    toggleBtn.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
    const sunIcon = toggleBtn.querySelector('.icon-sun');
    const moonIcon = toggleBtn.querySelector('.icon-moon');
    if (sunIcon && moonIcon) {
      if (theme === 'dark') {
        sunIcon.style.display = 'block';
        moonIcon.style.display = 'none';
      } else {
        sunIcon.style.display = 'none';
        moonIcon.style.display = 'block';
      }
    }
  }
}

/* ==========================================================================
   2. Modern Scrollspy with Fallback & Accessibility Sync
   ========================================================================== */
function initScrollspy() {
  const nav = document.querySelector('nav[aria-label="Main Navigation"]');
  if (!nav) return;

  const navLinks = nav.querySelectorAll('a[href^="#"]');
  const sections = document.querySelectorAll('main section[id]');

  // Feature detection for native CSS scroll-target-group
  const supportsScrollTargetGroup = CSS.supports('scroll-target-group: auto');

  if (supportsScrollTargetGroup) {
    const syncAriaCurrent = () => {
      const currentLink = nav.querySelector('a:target-current');
      navLinks.forEach(link => {
        link.setAttribute('aria-current', link === currentLink ? 'true' : 'false');
      });
    };
    syncAriaCurrent();
    document.addEventListener('scrollend', syncAriaCurrent);
  } else {
    // IntersectionObserver fallback
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const id = entry.target.getAttribute('id');
          navLinks.forEach(link => {
            const isActive = link.getAttribute('href') === `#${id}`;
            link.classList.toggle('target-current', isActive);
            link.setAttribute('aria-current', isActive ? 'true' : 'false');
          });
        }
      });
    }, { rootMargin: '-20% 0px -60% 0px', threshold: 0 });

    sections.forEach(section => observer.observe(section));
  }
}

/* ==========================================================================
   3. Interactive Mobile Phone Mockup
   ========================================================================== */
function initMockupInteractions() {
  // Tab Switching
  const tabBtns = document.querySelectorAll('.mock-tab-btn');
  const views = document.querySelectorAll('.mockup-view');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetView = btn.dataset.view;

      tabBtns.forEach(b => {
        b.classList.remove('active');
        b.setAttribute('aria-selected', 'false');
      });
      views.forEach(v => v.classList.remove('active'));

      btn.classList.add('active');
      btn.setAttribute('aria-selected', 'true');

      const activeView = document.getElementById(`mock-view-${targetView}`);
      if (activeView) activeView.classList.add('active');

      // Also sync bottom pill nav
      document.querySelectorAll('.mock-nav-item').forEach(item => {
        const isMatch = item.dataset.view === targetView;
        item.classList.toggle('active', isMatch);
      });
    });
  });

  // Bottom Pill Nav Switching
  document.querySelectorAll('.mock-nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const targetView = item.dataset.view;
      const tabBtn = document.querySelector(`.mock-tab-btn[data-view="${targetView}"]`);
      if (tabBtn) tabBtn.click();
    });
  });

  // Interactive Farm Task Checkboxes
  const taskRows = document.querySelectorAll('.mock-task-row');
  taskRows.forEach(row => {
    row.addEventListener('click', (e) => {
      // Don't trigger if clicked spend button directly
      if (e.target.closest('.mock-spend-btn')) return;

      const checkbox = row.querySelector('.mock-checkbox');
      if (checkbox) {
        const isChecked = checkbox.classList.toggle('checked');
        row.style.opacity = isChecked ? '0.6' : '1';
        updateMockTasksRemaining();
      }
    });
  });

  // Mock Spend Button: Simulates spending 20 resin in real-time
  const spendBtns = document.querySelectorAll('.mock-spend-btn');
  spendBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      spendMockResin(20);
      
      const row = btn.closest('.mock-task-row');
      if (row) {
        const checkbox = row.querySelector('.mock-checkbox');
        if (checkbox && !checkbox.classList.contains('checked')) {
          checkbox.classList.add('checked');
          row.style.opacity = '0.6';
          updateMockTasksRemaining();
        }
      }
    });
  });

  // Mock Resin Spending Logic
  let mockResin = 143;
  function spendMockResin(amount) {
    if (mockResin >= amount) {
      mockResin -= amount;
    } else {
      mockResin = 160; // reset loop for fun
    }
    updateMockResinDisplays(mockResin);
  }

  function updateMockResinDisplays(val) {
    const numEls = document.querySelectorAll('.mock-resin-val-num');
    const barFill = document.querySelector('.mock-bar-fill');
    numEls.forEach(el => el.textContent = val);
    if (barFill) {
      const pct = Math.min(100, Math.max(0, (val / 200) * 100));
      barFill.style.width = `${pct}%`;
    }
  }

  function updateMockTasksRemaining() {
    const total = document.querySelectorAll('.mock-task-row').length;
    const checked = document.querySelectorAll('.mock-task-row .mock-checkbox.checked').length;
    const badge = document.getElementById('mock-tasks-badge');
    if (badge) {
      const remaining = total - checked;
      badge.textContent = `${remaining} task${remaining === 1 ? '' : 's'}`;
    }
  }

  // Ticking countdown timer simulation in mockup
  let nextResinSeconds = 312; // 5m 12s
  setInterval(() => {
    nextResinSeconds--;
    if (nextResinSeconds <= 0) {
      nextResinSeconds = 480; // 8 minutes
      mockResin = Math.min(200, mockResin + 1);
      updateMockResinDisplays(mockResin);
    }
    const mins = Math.floor(nextResinSeconds / 60);
    const secs = nextResinSeconds % 60;
    const timeStr = `${mins}:${secs < 10 ? '0' : ''}${secs}`;
    const timerEls = document.querySelectorAll('.mock-timer-display');
    timerEls.forEach(el => el.textContent = timeStr);
  }, 1000);
}

/* ==========================================================================
   4. Live Interactive Resin & Domain Calculator
   ========================================================================== */
function initResinCalculator() {
  const rangeInput = document.getElementById('calc-resin-range');
  const numInput = document.getElementById('calc-resin-num');
  const serverSelect = document.getElementById('calc-server-select');
  const ringNum = document.getElementById('calc-ring-val');
  const ringCircle = document.getElementById('calc-ring-progress');
  const timeTo160El = document.getElementById('calc-time-160');
  const timeTo200El = document.getElementById('calc-time-200');
  const serverResetEl = document.getElementById('calc-server-reset');

  if (!rangeInput || !numInput) return;

  function recalculate() {
    let resin = parseInt(numInput.value, 10);
    if (isNaN(resin)) resin = 0;
    resin = Math.max(0, Math.min(200, resin));

    rangeInput.value = resin;
    numInput.value = resin;
    if (ringNum) ringNum.textContent = resin;

    // Circular SVG Progress
    if (ringCircle) {
      const radius = 68;
      const circumference = 2 * Math.PI * radius; // ~427.25
      const offset = circumference - (resin / 200) * circumference;
      ringCircle.style.strokeDashoffset = offset;
    }

    const now = new Date();

    // Time to 160 (Condensed crafting threshold)
    if (resin >= 160) {
      if (timeTo160El) timeTo160El.innerHTML = '<strong style="color: var(--success-text)">Ready now</strong>';
    } else {
      const needed160 = 160 - resin;
      const minutesTo160 = needed160 * 8;
      const targetTime160 = new Date(now.getTime() + minutesTo160 * 60000);
      const hours160 = Math.floor(minutesTo160 / 60);
      const remMin160 = minutesTo160 % 60;
      const timeStr160 = targetTime160.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      if (timeTo160El) {
        timeTo160El.innerHTML = `<strong>${timeStr160}</strong> (${hours160}h ${remMin160}m)`;
      }
    }

    // Time to 200 (Cap)
    if (resin >= 200) {
      if (timeTo200El) timeTo200El.innerHTML = '<strong style="color: var(--danger-text)">Capped at 200</strong>';
    } else {
      const needed200 = 200 - resin;
      const minutesTo200 = needed200 * 8;
      const targetTime200 = new Date(now.getTime() + minutesTo200 * 60000);
      const hours200 = Math.floor(minutesTo200 / 60);
      const remMin200 = minutesTo200 % 60;
      const timeStr200 = targetTime200.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      if (timeTo200El) {
        timeTo200El.innerHTML = `<strong>${timeStr200}</strong> (${hours200}h ${remMin200}m)`;
      }
    }

    // Server Reset Calculation
    updateServerResetDisplay();
  }

  function updateServerResetDisplay() {
    if (!serverSelect || !serverResetEl) return;
    const server = serverSelect.value;
    
    // Server UTC offsets: Asia +8, Europe +1, America -5, TW +8
    let serverOffsetHours = 8;
    if (server === 'europe') serverOffsetHours = 1;
    if (server === 'america') serverOffsetHours = -5;
    if (server === 'asia' || server === 'tw') serverOffsetHours = 8;

    const nowUtc = new Date();
    // Server daily reset is at 04:00 server time
    // Server time = UTC + serverOffsetHours
    const nowServerMs = nowUtc.getTime() + (serverOffsetHours * 3600000);
    const serverNow = new Date(nowServerMs);

    // Calculate next 04:00 AM server time
    const nextResetServer = new Date(serverNow);
    nextResetServer.setUTCHours(4, 0, 0, 0);
    if (serverNow.getUTCHours() >= 4) {
      nextResetServer.setUTCDate(nextResetServer.getUTCDate() + 1);
    }

    const diffMs = nextResetServer.getTime() - serverNow.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMins = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    // Convert next reset to player's local browser time
    const nextResetLocal = new Date(nowUtc.getTime() + diffMs);
    const localTimeStr = nextResetLocal.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    serverResetEl.innerHTML = `<strong>${localTimeStr}</strong> (in ${diffHours}h ${diffMins}m)`;
  }

  rangeInput.addEventListener('input', (e) => {
    numInput.value = e.target.value;
    recalculate();
  });

  numInput.addEventListener('input', (e) => {
    rangeInput.value = e.target.value;
    recalculate();
  });

  if (serverSelect) {
    serverSelect.addEventListener('change', recalculate);
  }

  recalculate();
}

/* ==========================================================================
   5. Interactive Weekly Domain Schedule Filter
   ========================================================================== */
function initScheduleFilter() {
  const filterBtns = document.querySelectorAll('.day-filter-btn');
  const cards = document.querySelectorAll('.schedule-card');

  // Auto-detect current weekday if possible
  const currentDayIndex = new Date().getDay(); // 0 is Sunday, 1 is Monday
  const dayMap = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  const currentDayKey = dayMap[currentDayIndex];

  // Set default active button to today
  filterBtns.forEach(btn => {
    const isToday = btn.dataset.day === currentDayKey;
    btn.classList.toggle('active', isToday);
    btn.setAttribute('aria-pressed', isToday ? 'true' : 'false');
  });

  filterScheduleCards(currentDayKey);

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => {
        b.classList.remove('active');
        b.setAttribute('aria-pressed', 'false');
      });
      btn.classList.add('active');
      btn.setAttribute('aria-pressed', 'true');

      filterScheduleCards(btn.dataset.day);
    });
  });

  function filterScheduleCards(day) {
    cards.forEach(card => {
      const openDays = card.dataset.days.split(' ');
      // Sunday (sun) opens all domains
      const isOpen = day === 'sun' || openDays.includes(day);
      card.style.display = isOpen ? 'flex' : 'none';
    });
  }
}

/* ==========================================================================
   6. Accessible FAQ Accordion
   ========================================================================== */
function initFaqAccordion() {
  const faqItems = document.querySelectorAll('.faq-item');

  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (!questionBtn) return;

    questionBtn.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');

      // Close all others for accordion behavior
      faqItems.forEach(otherItem => {
        otherItem.classList.remove('open');
        const otherBtn = otherItem.querySelector('.faq-question');
        if (otherBtn) otherBtn.setAttribute('aria-expanded', 'false');
      });

      if (!isOpen) {
        item.classList.add('open');
        questionBtn.setAttribute('aria-expanded', 'true');
      }
    });
  });
}

