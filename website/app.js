// Nuvok — Interactions & Animations

// ══ Configuración de lanzamiento ══
// Un solo lugar para conectar los servicios externos. Vacío = el sitio
// degrada con honestidad (botón de compra → lista de espera por correo).
const NUVOK_CONFIG = {
  // URL del checkout de Lemon Squeezy (se pega al crear el producto).
  checkoutUrl: '',
  // Base del API de la tienda (Worker de Cloudflare, ver store-worker/).
  apiBase: '/api',
  // GHL / Hexona (GoHighLevel): pegar el src del iframe del formulario
  // (Sites → Forms → Integrate) para captar leads en el CRM.
  ghlFormUrl: '',
  // GHL: src del script del chat widget (Sites → Chat Widget → Get Code).
  ghlChatWidgetSrc: '',
};

// ── Botón de compra: checkout real si existe; si no, lista de espera ──
function initBuy() {
  const btn = document.getElementById('buy-btn');
  if (!btn) return;
  if (NUVOK_CONFIG.checkoutUrl) {
    btn.href = NUVOK_CONFIG.checkoutUrl;
    btn.removeAttribute('data-i18n');
  } else {
    // Aún sin tienda: llevar al formulario/correo es honesto, no un 404.
    btn.href = '#contacto';
    btn.textContent = 'Muy pronto — avísame';
  }
}

// ── CRM (GHL/Hexona): formulario y chat, solo si están configurados ──
function initGhl() {
  const slot = document.getElementById('ghl-form-slot');
  if (slot && NUVOK_CONFIG.ghlFormUrl) {
    const f = document.createElement('iframe');
    f.src = NUVOK_CONFIG.ghlFormUrl;
    f.style.cssText = 'width:100%;min-height:420px;border:none;border-radius:12px;';
    f.title = 'Formulario de contacto';
    slot.appendChild(f);
    const mail = document.getElementById('contact-mail');
    if (mail) mail.classList.add('ghost');
  }
  if (NUVOK_CONFIG.ghlChatWidgetSrc) {
    const s = document.createElement('script');
    s.src = NUVOK_CONFIG.ghlChatWidgetSrc;
    s.defer = true;
    document.body.appendChild(s);
  }
}

// ── Detección del sistema del visitante (usada en /descargas.html) ──
function detectOS() {
  const ua = navigator.userAgent;
  if (/Android/i.test(ua)) return 'android';
  if (/iPhone|iPad|iPod/i.test(ua)) return 'ios';
  if (/Macintosh/i.test(ua)) return 'macos';
  if (/Windows/i.test(ua)) return 'windows';
  if (/Linux/i.test(ua)) return 'linux';
  return 'otro';
}

// ── Gate reveal animations on JS availability ──
// CSS hides `.js .reveal` (opacity 0). We add the `.js` class to <html> on
// load so users without JS / offline-first browsers / reduced-motion see the
// fully-rendered page instead of an invisible one.
document.documentElement.classList.add('js');

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
  initBuy();
  initGhl();
  // initParallax is janky with CSS animation, skip for now
});
