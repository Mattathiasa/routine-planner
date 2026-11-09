/**
 * Routine Planner — Next-Level Landing
 * Stack: Three.js r163 · GSAP 3.12 + ScrollTrigger · Lenis Smooth Scroll
 */

/* ==========================================================================
   0. BOOTSTRAP
   ========================================================================== */
gsap.registerPlugin(ScrollTrigger);

const lenis = new Lenis({ lerp: 0.08, smooth: true });
lenis.on('scroll', ScrollTrigger.update);
gsap.ticker.add((t) => lenis.raf(t * 1000));
gsap.ticker.lagSmoothing(0);

window.addEventListener('DOMContentLoaded', () => {
  initCursor();
  initNav();
  initHeroThree();
  initHeroGSAP();
  initScrollReveal();
  initBentoTilt();
  initMagneticButtons();
  initCalcCanvas();
  initResinCalculator();
  initScheduleFilter();
  initPhoneInteractions();
  initFAQ();
  initCtaCanvas();
  initCounters();
});

/* ==========================================================================
   1. CUSTOM CURSOR
   ========================================================================== */
function initCursor() {
  const cursor = document.getElementById('cursor');
  if (!cursor || window.matchMedia('(hover:none)').matches) return;

  const dot  = cursor.querySelector('.cursor-dot');
  const ring = cursor.querySelector('.cursor-ring');

  let mx = 0, my = 0;
  let rx = 0, ry = 0;

  window.addEventListener('mousemove', (e) => {
    mx = e.clientX;
    my = e.clientY;
    gsap.set(dot, { x: mx, y: my });
  });

  // Ring lags behind
  gsap.ticker.add(() => {
    rx += (mx - rx) * 0.12;
    ry += (my - ry) * 0.12;
    gsap.set(ring, { x: rx, y: ry });
  });

  // Hover state on interactive elements
  const hoverEls = document.querySelectorAll('a, button, .tilt-card, input, select, .day-btn, .faq-q');
  hoverEls.forEach(el => {
    el.addEventListener('mouseenter', () => cursor.classList.add('cursor-hover'));
    el.addEventListener('mouseleave', () => cursor.classList.remove('cursor-hover'));
  });
}

/* ==========================================================================
   2. NAV — Scroll glass effect
   ========================================================================== */
function initNav() {
  const header = document.getElementById('site-header');
  if (!header) return;

  ScrollTrigger.create({
    start: 80,
    onEnter: () => header.classList.add('scrolled'),
    onLeaveBack: () => header.classList.remove('scrolled'),
  });

  // Active nav link scrollspy
  const navLinks = document.querySelectorAll('.nav-link');
  document.querySelectorAll('main section[id]').forEach(section => {
    ScrollTrigger.create({
      trigger: section,
      start: 'top 60%',
      end: 'bottom 40%',
      onEnter: () => setActiveNav(section.id),
      onEnterBack: () => setActiveNav(section.id),
    });
  });

  function setActiveNav(id) {
    navLinks.forEach(link => {
      link.classList.toggle('active', link.getAttribute('href') === `#${id}`);
    });
  }
}

/* ==========================================================================
   3. HERO — THREE.JS (Resin Orb + Particle Field)
   ========================================================================== */
function initHeroThree() {
  const canvas = document.getElementById('hero-canvas');
  if (!canvas || typeof THREE === 'undefined') return;

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(canvas.clientWidth, canvas.clientHeight);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(55, canvas.clientWidth / canvas.clientHeight, 0.1, 100);
  camera.position.set(0, 0, 5);

  // --- Resin Orb ---
  const orbGeo = new THREE.IcosahedronGeometry(1.4, 6);
  const orbMat = new THREE.MeshStandardMaterial({
    color: 0x6C63FF,
    emissive: 0x3B30CC,
    emissiveIntensity: 0.4,
    metalness: 0.8,
    roughness: 0.15,
    wireframe: false,
    transparent: true,
    opacity: 0.75,
  });
  const orb = new THREE.Mesh(orbGeo, orbMat);
  scene.add(orb);

  // Wireframe shell
  const wireMat = new THREE.MeshBasicMaterial({ color: 0x9B8FFF, wireframe: true, transparent: true, opacity: 0.08 });
  const wireOrb = new THREE.Mesh(new THREE.IcosahedronGeometry(1.55, 4), wireMat);
  scene.add(wireOrb);

  // Inner glow core
  const coreMat = new THREE.MeshBasicMaterial({ color: 0xA78BFA, transparent: true, opacity: 0.3 });
  const core = new THREE.Mesh(new THREE.SphereGeometry(0.8, 32, 32), coreMat);
  scene.add(core);

  // --- Orbiting particles ring ---
  const ringCount = 120;
  const ringGeo = new THREE.BufferGeometry();
  const ringPos = new Float32Array(ringCount * 3);
  const ringAngles = new Float32Array(ringCount);
  for (let i = 0; i < ringCount; i++) {
    const angle = (i / ringCount) * Math.PI * 2;
    const radius = 2.2 + (Math.random() - 0.5) * 0.6;
    const tilt = (Math.random() - 0.5) * 0.6;
    ringPos[i * 3]     = Math.cos(angle) * radius;
    ringPos[i * 3 + 1] = tilt;
    ringPos[i * 3 + 2] = Math.sin(angle) * radius;
    ringAngles[i] = angle;
  }
  ringGeo.setAttribute('position', new THREE.BufferAttribute(ringPos, 3));
  const ringMat = new THREE.PointsMaterial({ color: 0x6C63FF, size: 0.04, transparent: true, opacity: 0.7 });
  const ring = new THREE.Points(ringGeo, ringMat);
  scene.add(ring);

  // --- Ambient particle cloud ---
  const starCount = 1200;
  const starGeo = new THREE.BufferGeometry();
  const starPos = new Float32Array(starCount * 3);
  for (let i = 0; i < starCount; i++) {
    starPos[i * 3]     = (Math.random() - 0.5) * 20;
    starPos[i * 3 + 1] = (Math.random() - 0.5) * 14;
    starPos[i * 3 + 2] = (Math.random() - 0.5) * 10 - 2;
  }
  starGeo.setAttribute('position', new THREE.BufferAttribute(starPos, 3));
  const starMat = new THREE.PointsMaterial({ color: 0x8B8FFF, size: 0.025, transparent: true, opacity: 0.5 });
  const stars = new THREE.Points(starGeo, starMat);
  scene.add(stars);

  // --- Floating shards ---
  const shardCount = 14;
  const shards = [];
  for (let i = 0; i < shardCount; i++) {
    const size = 0.06 + Math.random() * 0.12;
    const geo = new THREE.OctahedronGeometry(size);
    const mat = new THREE.MeshBasicMaterial({
      color: Math.random() > 0.5 ? 0x6C63FF : 0xA78BFA,
      transparent: true,
      opacity: 0.3 + Math.random() * 0.4,
      wireframe: Math.random() > 0.5,
    });
    const mesh = new THREE.Mesh(geo, mat);
    const angle = Math.random() * Math.PI * 2;
    const radius = 2.5 + Math.random() * 1.5;
    mesh.position.set(
      Math.cos(angle) * radius,
      (Math.random() - 0.5) * 2,
      Math.sin(angle) * radius - 1
    );
    mesh.userData = {
      speed: 0.3 + Math.random() * 0.5,
      angle,
      radius,
      rotSpeed: (Math.random() - 0.5) * 0.02,
      floatOffset: Math.random() * Math.PI * 2,
      floatSpeed: 0.5 + Math.random() * 1,
    };
    scene.add(mesh);
    shards.push(mesh);
  }

  // Lighting
  scene.add(new THREE.AmbientLight(0x1a1030, 2));
  const pt1 = new THREE.PointLight(0x6C63FF, 4, 10);
  pt1.position.set(3, 2, 3);
  scene.add(pt1);
  const pt2 = new THREE.PointLight(0xA78BFA, 2, 8);
  pt2.position.set(-3, -1, 2);
  scene.add(pt2);

  // Mouse parallax
  let mouseX = 0, mouseY = 0;
  let targetX = 0, targetY = 0;
  window.addEventListener('mousemove', (e) => {
    mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
    mouseY = -(e.clientY / window.innerHeight - 0.5) * 2;
  });

  // Scroll-based orb scale
  ScrollTrigger.create({
    trigger: '#hero',
    start: 'top top',
    end: 'bottom top',
    onUpdate: (self) => {
      const p = self.progress;
      orb.scale.setScalar(1 - p * 0.3);
      wireOrb.scale.setScalar(1 - p * 0.3);
      core.scale.setScalar(1 - p * 0.4);
      orbMat.opacity = 0.75 * (1 - p * 1.5);
      wireMat.opacity = 0.08 * (1 - p * 2);
    }
  });

  // Resize
  window.addEventListener('resize', () => {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  });

  // Intro GSAP reveal of orb
  gsap.from(orb.scale, { x: 0, y: 0, z: 0, duration: 2, ease: 'elastic.out(1, 0.4)', delay: 0.5 });

  // Animation loop
  const clock = new THREE.Clock();
  function animate() {
    requestAnimationFrame(animate);
    const t = clock.getElapsedTime();

    // Smooth mouse parallax
    targetX += (mouseX * 0.25 - targetX) * 0.04;
    targetY += (mouseY * 0.25 - targetY) * 0.04;

    // Orb rotation
    orb.rotation.x = targetY * 0.3 + t * 0.08;
    orb.rotation.y = targetX * 0.3 + t * 0.12;
    wireOrb.rotation.x = -t * 0.05;
    wireOrb.rotation.y =  t * 0.08;
    core.rotation.y = t * 0.2;

    // Orb slow float
    orb.position.y = Math.sin(t * 0.5) * 0.08;
    orb.position.x = targetX * 0.3;

    // Ring orbit
    ring.rotation.y = t * 0.15 + targetX * 0.2;
    ring.rotation.x = 0.4 + targetY * 0.1;

    // Stars drift
    stars.rotation.y = t * 0.01;
    stars.rotation.x = t * 0.005;

    // Shards orbit
    shards.forEach((shard) => {
      const d = shard.userData;
      d.angle += 0.001 * d.speed;
      shard.position.x = Math.cos(d.angle) * d.radius;
      shard.position.z = Math.sin(d.angle) * d.radius - 1;
      shard.position.y += Math.sin(t * d.floatSpeed + d.floatOffset) * 0.001;
      shard.rotation.x += d.rotSpeed;
      shard.rotation.y += d.rotSpeed * 0.7;
    });

    // Pulsing lights
    pt1.intensity = 4 + Math.sin(t * 1.5) * 0.8;
    pt2.intensity = 2 + Math.sin(t * 2.1 + 1) * 0.5;

    renderer.render(scene, camera);
  }
  animate();
}

/* ==========================================================================
   4. HERO — GSAP TEXT & ELEMENT REVEAL
   ========================================================================== */
function initHeroGSAP() {
  const tl = gsap.timeline({ delay: 0.3 });

  // Badge
  tl.to('#hero-badge', { opacity: 1, y: 0, duration: 0.6, ease: 'power3.out' });

  // Words stagger
  tl.to('.word', {
    y: 0,
    opacity: 1,
    duration: 0.7,
    stagger: 0.07,
    ease: 'power4.out',
  }, '-=0.3');

  // Subhead
  tl.to('#hero-sub', { opacity: 1, y: 0, duration: 0.6, ease: 'power3.out' }, '-=0.3');

  // CTA buttons
  tl.to('#hero-ctas', { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, '-=0.2');

  // Stats bar
  tl.to('#hero-stats', { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, '-=0.2');
}

/* ==========================================================================
   5. SCROLL REVEAL — Universal section entrance
   ========================================================================== */
function initScrollReveal() {
  // .reveal-up elements
  gsap.utils.toArray('.reveal-up').forEach((el) => {
    gsap.to(el, {
      scrollTrigger: { trigger: el, start: 'top 88%', toggleActions: 'play none none none' },
      opacity: 1,
      y: 0,
      duration: 0.8,
      ease: 'power3.out',
    });
  });

  // [data-reveal] elements (cards, etc.) with stagger per parent
  const revealGroups = {};
  document.querySelectorAll('[data-reveal]').forEach((el) => {
    const parent = el.parentElement;
    if (!revealGroups[parent]) revealGroups[parent] = [];
    revealGroups[parent].push(el);
  });

  Object.values(revealGroups).forEach((group) => {
    gsap.to(group, {
      scrollTrigger: {
        trigger: group[0].parentElement,
        start: 'top 80%',
        toggleActions: 'play none none none',
      },
      opacity: 1,
      y: 0,
      scale: 1,
      duration: 0.75,
      stagger: 0.1,
      ease: 'power3.out',
    });
  });
}

/* ==========================================================================
   6. 3D TILT on bento/schedule cards
   ========================================================================== */
function initBentoTilt() {
  document.querySelectorAll('.tilt-card').forEach((card) => {
    const strength = 8;
    const liftZ = 20;

    card.addEventListener('mouseenter', () => {
      gsap.to(card, { z: liftZ, duration: 0.4, ease: 'power2.out' });
    });

    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const cx = rect.left + rect.width  / 2;
      const cy = rect.top  + rect.height / 2;
      const dx = (e.clientX - cx) / (rect.width  / 2);
      const dy = (e.clientY - cy) / (rect.height / 2);
      gsap.to(card, {
        rotationY:  dx * strength,
        rotationX: -dy * strength,
        duration: 0.4,
        ease: 'power2.out',
        transformPerspective: 800,
        transformOrigin: 'center center',
      });
    });

    card.addEventListener('mouseleave', () => {
      gsap.to(card, {
        rotationY: 0, rotationX: 0, z: 0,
        duration: 0.6,
        ease: 'elastic.out(1, 0.5)',
      });
    });
  });
}

/* ==========================================================================
   7. MAGNETIC BUTTONS
   ========================================================================== */
function initMagneticButtons() {
  document.querySelectorAll('.mag-btn').forEach((btn) => {
    btn.addEventListener('mousemove', (e) => {
      const rect = btn.getBoundingClientRect();
      const cx = rect.left + rect.width  / 2;
      const cy = rect.top  + rect.height / 2;
      const dx = (e.clientX - cx) * 0.3;
      const dy = (e.clientY - cy) * 0.3;
      gsap.to(btn, { x: dx, y: dy, duration: 0.3, ease: 'power2.out' });
    });
    btn.addEventListener('mouseleave', () => {
      gsap.to(btn, { x: 0, y: 0, duration: 0.5, ease: 'elastic.out(1, 0.5)' });
    });
  });
}

/* ==========================================================================
   8. STAT COUNTERS — count up on scroll
   ========================================================================== */
function initCounters() {
  document.querySelectorAll('.stat-num[data-count]').forEach((el) => {
    const target = parseInt(el.dataset.count, 10);
    const suffix = el.dataset.suffix || '';
    gsap.to({ val: 0 }, {
      val: target,
      duration: 1.6,
      ease: 'power2.out',
      delay: 1.5,
      onUpdate: function() {
        el.textContent = Math.round(this.targets()[0].val) + suffix;
      },
    });
  });
}

/* ==========================================================================
   9. CALC CANVAS — Floating orb behind calculator
   ========================================================================== */
function initCalcCanvas() {
  const canvas = document.getElementById('calc-canvas');
  if (!canvas || typeof THREE === 'undefined') return;

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(60, 1, 0.1, 100);
  camera.position.z = 6;

  // Grid of particles
  const count = 2000;
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    pos[i * 3]     = (Math.random() - 0.5) * 16;
    pos[i * 3 + 1] = (Math.random() - 0.5) * 10;
    pos[i * 3 + 2] = (Math.random() - 0.5) * 4 - 2;
  }
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const mat = new THREE.PointsMaterial({ color: 0x6C63FF, size: 0.03, transparent: true, opacity: 0.4 });
  scene.add(new THREE.Points(geo, mat));

  // Torus ring
  const torusMat = new THREE.MeshBasicMaterial({ color: 0x6C63FF, wireframe: true, transparent: true, opacity: 0.06 });
  const torus = new THREE.Mesh(new THREE.TorusGeometry(3, 0.3, 16, 60), torusMat);
  torus.position.set(4, 0, -2);
  scene.add(torus);

  const resize = () => {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  };
  resize();
  window.addEventListener('resize', resize);

  const clock = new THREE.Clock();
  function animate() {
    requestAnimationFrame(animate);
    const t = clock.getElapsedTime();
    torus.rotation.x = t * 0.2;
    torus.rotation.y = t * 0.1;
    renderer.render(scene, camera);
  }
  animate();
}

/* ==========================================================================
   10. CTA CANVAS — Animated mesh background
   ========================================================================== */
function initCtaCanvas() {
  const canvas = document.getElementById('cta-canvas');
  if (!canvas || typeof THREE === 'undefined') return;

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(60, 1, 0.1, 100);
  camera.position.z = 5;

  // Icosahedron wireframe
  const ico = new THREE.Mesh(
    new THREE.IcosahedronGeometry(2.5, 1),
    new THREE.MeshBasicMaterial({ color: 0x6C63FF, wireframe: true, transparent: true, opacity: 0.07 })
  );
  scene.add(ico);

  const ico2 = new THREE.Mesh(
    new THREE.IcosahedronGeometry(3.5, 1),
    new THREE.MeshBasicMaterial({ color: 0xA78BFA, wireframe: true, transparent: true, opacity: 0.03 })
  );
  scene.add(ico2);

  // Particle cloud
  const count = 800;
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(count * 3);
  for (let i = 0; i < count; i++) {
    const r = 2 + Math.random() * 3;
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    pos[i * 3]     = r * Math.sin(phi) * Math.cos(theta);
    pos[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta);
    pos[i * 3 + 2] = r * Math.cos(phi);
  }
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  scene.add(new THREE.Points(geo, new THREE.PointsMaterial({ color: 0x8B8FFF, size: 0.035, transparent: true, opacity: 0.5 })));

  const resize = () => {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
  };
  resize();
  window.addEventListener('resize', resize);

  const clock = new THREE.Clock();
  function animate() {
    requestAnimationFrame(animate);
    const t = clock.getElapsedTime();
    ico.rotation.x = t * 0.1;
    ico.rotation.y = t * 0.15;
    ico2.rotation.x = -t * 0.07;
    ico2.rotation.y = -t * 0.09;
    renderer.render(scene, camera);
  }
  animate();
}

/* ==========================================================================
   11. RESIN CALCULATOR (functional)
   ========================================================================== */
function initResinCalculator() {
  const range  = document.getElementById('calc-resin-range');
  const num    = document.getElementById('calc-resin-num');
  const server = document.getElementById('calc-server-select');
  const ringEl = document.getElementById('calc-ring-progress');
  const ringVal= document.getElementById('calc-ring-val');
  const t160   = document.getElementById('calc-time-160');
  const t200   = document.getElementById('calc-time-200');
  const tReset = document.getElementById('calc-server-reset');
  if (!range || !num) return;

  const CIRCUMFERENCE = 2 * Math.PI * 80; // r=80 → 502.65

  function recalc() {
    let val = Math.max(0, Math.min(200, parseInt(num.value, 10) || 0));
    range.value = val;
    num.value   = val;
    if (ringVal) ringVal.textContent = val;

    if (ringEl) {
      const offset = CIRCUMFERENCE - (val / 200) * CIRCUMFERENCE;
      ringEl.style.strokeDashoffset = offset;
    }

    const now = new Date();
    const fmt = (d) => d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    // 160
    if (val >= 160) {
      if (t160) t160.innerHTML = `<span style="color:var(--green)">Ready now ✓</span>`;
    } else {
      const mins = (160 - val) * 8;
      const target = new Date(now.getTime() + mins * 60000);
      const h = Math.floor(mins / 60), m = mins % 60;
      if (t160) t160.innerHTML = `<strong>${fmt(target)}</strong> <span style="color:var(--text-3)">in ${h}h ${m}m</span>`;
    }

    // 200
    if (val >= 200) {
      if (t200) t200.innerHTML = `<span style="color:var(--danger)">Capped — wasting resin!</span>`;
    } else {
      const mins = (200 - val) * 8;
      const target = new Date(now.getTime() + mins * 60000);
      const h = Math.floor(mins / 60), m = mins % 60;
      if (t200) t200.innerHTML = `<strong>${fmt(target)}</strong> <span style="color:var(--text-3)">in ${h}h ${m}m</span>`;
    }

    // Server reset
    if (!server || !tReset) return;
    const offsets = { europe: 1, america: -5, asia: 8, tw: 8 };
    const off = offsets[server.value] ?? 1;
    const utcNow = new Date();
    const serverMs = utcNow.getTime() + off * 3600000;
    const serverNow = new Date(serverMs);
    const nextReset = new Date(serverNow);
    nextReset.setUTCHours(4, 0, 0, 0);
    if (serverNow.getUTCHours() >= 4) nextReset.setUTCDate(nextReset.getUTCDate() + 1);
    const diff = nextReset.getTime() - serverNow.getTime();
    const dh = Math.floor(diff / 3600000);
    const dm = Math.floor((diff % 3600000) / 60000);
    const localReset = new Date(utcNow.getTime() + diff);
    tReset.innerHTML = `<strong>${fmt(localReset)}</strong> <span style="color:var(--text-3)">in ${dh}h ${dm}m</span>`;
  }

  range.addEventListener('input', (e) => { num.value = e.target.value; recalc(); });
  num.addEventListener('input', (e) => { range.value = e.target.value; recalc(); });
  if (server) server.addEventListener('change', recalc);
  recalc();

  // Update reset every minute
  setInterval(recalc, 60000);
}

/* ==========================================================================
   12. SCHEDULE FILTER
   ========================================================================== */
function initScheduleFilter() {
  const btns  = document.querySelectorAll('.day-btn');
  const cards = document.querySelectorAll('.sched-card');
  if (!btns.length) return;

  const dayMap = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  const today  = dayMap[new Date().getDay()];

  // Activate today's button
  btns.forEach(btn => {
    const isToday = btn.dataset.day === today;
    btn.classList.toggle('active', isToday);
    btn.setAttribute('aria-pressed', isToday ? 'true' : 'false');
  });
  filterCards(today);

  btns.forEach(btn => {
    btn.addEventListener('click', () => {
      btns.forEach(b => { b.classList.remove('active'); b.setAttribute('aria-pressed', 'false'); });
      btn.classList.add('active');
      btn.setAttribute('aria-pressed', 'true');
      filterCards(btn.dataset.day);
    });
  });

  function filterCards(day) {
    cards.forEach(card => {
      const days = card.dataset.days.split(' ');
      const visible = day === 'sun' || days.includes(day);
      if (visible) {
        gsap.to(card, { opacity: 1, scale: 1, display: 'block', duration: 0.3, ease: 'power2.out' });
        card.style.display = '';
      } else {
        gsap.to(card, { opacity: 0, scale: 0.95, duration: 0.2, ease: 'power2.in',
          onComplete: () => { card.style.display = 'none'; }
        });
      }
    });
  }
}

/* ==========================================================================
   13. PHONE INTERACTIONS (mockup inside #screens)
   ========================================================================== */
function initPhoneInteractions() {
  // 3D tilt on phone
  const wrapper = document.getElementById('phone-wrapper');
  if (wrapper) {
    wrapper.addEventListener('mousemove', (e) => {
      const rect = wrapper.getBoundingClientRect();
      const cx = rect.left + rect.width  / 2;
      const cy = rect.top  + rect.height / 2;
      const dx = (e.clientX - cx) / (rect.width  / 2);
      const dy = (e.clientY - cy) / (rect.height / 2);
      gsap.to('.phone-frame-3d', {
        rotationY:  dx * 12,
        rotationX: -dy * 8,
        duration: 0.4,
        ease: 'power2.out',
        transformPerspective: 1200,
      });
    });
    wrapper.addEventListener('mouseleave', () => {
      gsap.to('.phone-frame-3d', {
        rotationY: 0, rotationX: 0,
        duration: 1,
        ease: 'elastic.out(1, 0.4)',
      });
    });
  }

  // Auto-rotate tabs every 3s
  const tabs = document.querySelectorAll('.pstab');
  const views = document.querySelectorAll('.pview');
  const navItems = document.querySelectorAll('.pnav-item');
  let tabIndex = 0;
  let autoInterval;

  function activateTab(idx) {
    tabIndex = idx;
    tabs.forEach((t, i) => {
      t.classList.toggle('active', i === idx);
      t.setAttribute('aria-selected', i === idx ? 'true' : 'false');
    });
    views.forEach((v, i) => v.classList.toggle('active', i === idx));
    navItems.forEach((n, i) => n.classList.toggle('active', i === idx));
  }

  function startAuto() {
    autoInterval = setInterval(() => {
      activateTab((tabIndex + 1) % tabs.length);
    }, 3200);
  }

  startAuto();

  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => {
      clearInterval(autoInterval);
      activateTab(i);
      startAuto();
    });
  });

  navItems.forEach((item, i) => {
    item.addEventListener('click', () => {
      clearInterval(autoInterval);
      activateTab(i);
      startAuto();
    });
  });

  // Resin spend buttons
  let mockResin = 143;
  document.querySelectorAll('.mock-spend-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      mockResin = Math.max(0, mockResin - 20);
      updateResinDisplays(mockResin);

      const row = btn.closest('.mock-task-row') || btn.closest('.ptc-row');
      if (row) {
        const cb = row.querySelector('.mock-checkbox, .ptc-check');
        if (cb && !cb.classList.contains('checked')) {
          cb.classList.add('checked');
          gsap.from(cb, { scale: 0.5, duration: 0.3, ease: 'back.out(2)' });
        }
      }

      // Animate the button
      gsap.from(btn, { scale: 0.85, duration: 0.2, ease: 'back.out(2)' });
    });
  });

  document.querySelectorAll('.mock-task-row, .ptc-row').forEach(row => {
    row.addEventListener('click', (e) => {
      if (e.target.closest('.mock-spend-btn, .ptc-run')) return;
      const cb = row.querySelector('.mock-checkbox, .ptc-check');
      if (cb) {
        const wasChecked = cb.classList.toggle('checked');
        gsap.to(row, { opacity: wasChecked ? 0.5 : 1, duration: 0.3 });
      }
    });
  });

  // Live timer tick in phone mockup
  let resinSecs = 312;
  setInterval(() => {
    resinSecs--;
    if (resinSecs <= 0) {
      resinSecs = 480;
      mockResin = Math.min(200, mockResin + 1);
      updateResinDisplays(mockResin);
    }
    const m = Math.floor(resinSecs / 60);
    const s = resinSecs % 60;
    document.querySelectorAll('.mock-timer-display').forEach(el => {
      el.textContent = `${m}:${s < 10 ? '0' : ''}${s}`;
    });
  }, 1000);

  function updateResinDisplays(val) {
    document.querySelectorAll('.mock-resin-val-num').forEach(el => { el.textContent = val; });
    document.querySelectorAll('.mock-bar-fill').forEach(bar => {
      const pct = Math.min(100, (val / 200) * 100);
      gsap.to(bar, { width: pct + '%', duration: 0.5, ease: 'power2.out' });
    });
    // Update arc
    const arc = document.querySelector('.pview-gauge-arc');
    if (arc) {
      const offset = 314.16 - (val / 200) * 314.16;
      arc.style.strokeDashoffset = offset;
    }
  }

  // Scroll-triggered phone float entrance
  gsap.fromTo('#phone-wrapper',
    { y: 80, opacity: 0, rotationX: 15 },
    {
      scrollTrigger: { trigger: '#screens', start: 'top 70%', toggleActions: 'play none none none' },
      y: 0, opacity: 1, rotationX: 0,
      duration: 1.2,
      ease: 'power4.out',
    }
  );

  // Label reveals
  gsap.utils.toArray('.plabel').forEach((label, i) => {
    gsap.from(label, {
      scrollTrigger: { trigger: '#screens', start: 'top 60%', toggleActions: 'play none none none' },
      opacity: 0,
      x: label.classList.contains('plabel-left') ? -30 : 30,
      duration: 0.7,
      delay: 0.4 + i * 0.15,
      ease: 'power3.out',
    });
  });
}

/* ==========================================================================
   14. FAQ ACCORDION
   ========================================================================== */
function initFAQ() {
  document.querySelectorAll('.faq-item').forEach(item => {
    const btn = item.querySelector('.faq-q');
    if (!btn) return;

    btn.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');
      // Close all
      document.querySelectorAll('.faq-item.open').forEach(open => {
        open.classList.remove('open');
        open.querySelector('.faq-q').setAttribute('aria-expanded', 'false');
      });
      if (!isOpen) {
        item.classList.add('open');
        btn.setAttribute('aria-expanded', 'true');
        gsap.from(item.querySelector('.faq-a p'), {
          y: 10, opacity: 0, duration: 0.4, ease: 'power2.out'
        });
      }
    });
  });
}
