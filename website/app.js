// Prepper Pad — Interactions & Animations

// ── Scroll reveal with IntersectionObserver ──
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.12, rootMargin: '0px 0px -60px 0px' });

function initReveal() {
  // Add reveal class to sections and cards
  document.querySelectorAll('section .wrap > div, .card, .price, .stat, .mesh-card').forEach(el => {
    el.classList.add('reveal');
    revealObserver.observe(el);
  });
}

// ── Nav scroll effect ──
function initNavScroll() {
  const nav = document.querySelector('nav');
  if (!nav) return;
  let ticking = false;
  window.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(() => {
        nav.classList.toggle('scrolled', window.scrollY > 40);
        ticking = false;
      });
      ticking = true;
    }
  }, { passive: true });
}

// ── Floating particles in hero ──
function initParticles() {
  const container = document.querySelector('.particles');
  if (!container) return;
  const count = 24;
  for (let i = 0; i < count; i++) {
    const p = document.createElement('div');
    p.className = 'particle';
    p.style.left = Math.random() * 100 + '%';
    p.style.animationDuration = (8 + Math.random() * 12) + 's';
    p.style.animationDelay = (Math.random() * 8) + 's';
    p.style.width = p.style.height = (2 + Math.random() * 3) + 'px';
    container.appendChild(p);
  }
}

// ── Animated stat counters ──
function initCounters() {
  const counters = document.querySelectorAll('[data-count]');
  const obs = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const el = entry.target;
      const target = parseInt(el.dataset.count);
      if (isNaN(target)) return;
      let current = 0;
      const duration = 1500;
      const start = performance.now();
      function step(now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        current = Math.round(target * eased);
        el.textContent = current.toLocaleString();
        if (progress < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
      obs.unobserve(el);
    });
  }, { threshold: 0.5 });
  counters.forEach(c => obs.observe(c));
}

// ── Mesh node animation ──
function initMeshAnim() {
  const nodes = document.querySelectorAll('.mesh-node');
  const lines = document.querySelectorAll('.mesh-line');
  if (nodes.length === 0) return;

  let activeIdx = 0;
  setInterval(() => {
    nodes.forEach(n => n.classList.remove('active'));
    lines.forEach(l => l.classList.remove('active'));

    const node = nodes[activeIdx % nodes.length];
    node.classList.add('active');

    // Activate adjacent line
    const nextLine = lines[activeIdx % (lines.length || 1)];
    if (nextLine) {
      nextLine.classList.add('active');
      // Reset and restart pulse dot
      const dot = nextLine.querySelector('.pulse-dot');
      if (dot) {
        dot.style.animation = 'none';
        dot.offsetHeight; // reflow
        dot.style.animation = '';
      }
    }
    activeIdx++;
  }, 1200);
}

// ── Parallax hero device ──
function initParallax() {
  const device = document.querySelector('.device');
  if (!device) return;
  const hero = document.querySelector('header');
  if (!hero) return;

  hero.addEventListener('mousemove', (e) => {
    const rect = hero.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    device.style.transform = `rotateY(${-8 + x * 12}deg) rotateX(${4 - y * 8}deg)`;
  });
  hero.addEventListener('mouseleave', () => {
    device.style.transform = '';
  });
}

// ── Smooth scroll for anchor links ──
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', (e) => {
      const href = link.getAttribute('href');
      if (href === '#') return;
      const target = document.querySelector(href);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });
}

// ── Init everything ──
document.addEventListener('DOMContentLoaded', () => {
  initReveal();
  initNavScroll();
  initParticles();
  initCounters();
  initMeshAnim();
  initSmoothScroll();
  // initParallax is janky with CSS animation, skip for now
});
