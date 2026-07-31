// Nuvok — i18n system (ES/EN)
// Lightweight, no dependencies. Falls back to ES.
const I18N = {
  es: {
    // Nav
    'nav.what': 'Qué hace',
    'nav.offline': 'Sin internet',
    'nav.mesh': 'Malla',
    'nav.pricing': 'Comprar',
    'nav.code': 'Código',
    'nav.buy': 'Comprar — $99',

    // Hero
    'hero.badge': '● Funciona cuando todo lo demás falla',
    'hero.title_pre': 'El conocimiento que ',
    'hero.title_hl': 'salva vidas',
    'hero.title_post': ', sin depender de internet.',
    'hero.subtitle': 'Instálalo en tu teléfono en minutos: primeros auxilios paso a paso, mapas con GPS, comunicación entre tu grupo y una biblioteca completa — todo funcionando sin señal, sin datos, sin nube.',
    'hero.cta1': 'Comprar — $99 único',
    'hero.cta2': 'Ver qué incluye',
    'hero.note': 'Pago único. Sin suscripciones ni cuentas. Código abierto (GPL v3): compilarlo tú mismo es gratis, siempre.',
    'hero.status': '◉ Sin conexión · 100%',

    // Modules
    'modules.eyebrow': 'Todo en un solo aparato',
    'modules.title': 'Seis herramientas para cuando más importan',
    'modules.lead': 'Cada módulo funciona 100% sin conexión. Descargas el contenido una vez y queda para siempre.',

    'module.emergency.title': 'Guías de emergencia',
    'module.emergency.desc': 'Primeros auxilios explicados paso a paso: reanimación, hemorragias, atragantamiento, fracturas, parto y más. Buscador por síntoma ("no respira") en español e inglés.',

    'module.maps.title': 'Mapas y GPS offline',
    'module.maps.desc': 'Ubícate y traza rutas por calle sin datos. Evita calles privadas y portones, marca zonas de riesgo, y busca "llévame a…" cualquier lugar. Instala mapas de todo el mundo.',

    'module.mesh.title': 'Comunicación sin internet',
    'module.mesh.desc': 'Chatea, comparte tu ubicación y lanza un SOS a los aparatos cercanos por WiFi, Bluetooth o LoRa — cifrado, sin torres ni servidores. Ideal cuando la red se cae.',

    'module.library.title': 'Biblioteca de conocimiento',
    'module.library.desc': 'Wikipedia completa, enciclopedia médica, guías de supervivencia y video — todo descargado y navegable sin señal.',

    'module.ai.title': 'Asistente con IA local',
    'module.ai.desc': 'Un asistente que responde desde el propio aparato, sin enviar nada a la nube, apoyándose en las guías y la biblioteca con citas.',

    'module.yours.title': 'Tuyo para siempre',
    'module.yours.desc': 'Sin suscripción ni cuenta. El contenido vive en el aparato y se copia a otros teléfonos y computadoras de tu familia o grupo.',

    // Mesh section
    'mesh.eyebrow': 'Malla Prepper',
    'mesh.title': 'Conectado cuando no hay señal',
    'mesh.lead': 'Tres capas de comunicación sin internet. Tus mensajes viajan entre dispositivos sin torres, sin servidores, sin nube.',
    'mesh.wifi.title': 'WiFi Local',
    'mesh.wifi.desc': 'Cualquier router, hotspot o punto de acceso. Tus dispositivos se encuentran automáticamente.',
    'mesh.bt.title': 'Bluetooth',
    'mesh.bt.desc': 'Conexión directa dispositivo a dispositivo. Sin router, sin configuración.',
    'mesh.lora.title': 'LoRa (km de alcance)',
    'mesh.lora.desc': 'Radio de largo alcance para comunicación a kilómetros sin ninguna infraestructura.',

    // Offline stats
    'offline.eyebrow': 'Diseñado para el peor día',
    'offline.title': 'Cuando no hay señal, sigue funcionando',
    'offline.lead': 'Huracán, apagón, zona remota, desastre: Nuvok no necesita internet, ni cobertura, ni electricidad de red para ayudarte.',
    'offline.stat1': '0',
    'offline.stat1l': 'datos móviles necesarios',
    'offline.stat2': '100%',
    'offline.stat2l': 'local, sin nube',
    'offline.stat3': '32',
    'offline.stat3l': 'guías de primeros auxilios',
    'offline.stat4': '🌎',
    'offline.stat4l': 'mapas de todo el mundo',

    // Footer
    'footer.copy': '© 2026 Nuvok · Conocimiento offline que salva vidas',
    'footer.disclaimer': 'Las guías de primeros auxilios son material educativo y no sustituyen la atención médica profesional ni un curso presencial certificado; busca ayuda médica siempre que sea posible. El radio LoRa es un accesorio en desarrollo; su disponibilidad, alcance y compatibilidad finales se confirmarán en el lanzamiento. Datos de mapa © OpenStreetMap contributors.',
  },

  en: {
    'nav.what': 'What it does',
    'nav.offline': 'Offline',
    'nav.mesh': 'Mesh',
    'nav.pricing': 'Buy',
    'nav.code': 'Code',
    'nav.buy': 'Buy — $99',

    'hero.badge': '● Works when everything else fails',
    'hero.title_pre': 'Knowledge that ',
    'hero.title_hl': 'saves lives',
    'hero.title_post': ', without internet.',
    'hero.subtitle': 'Install it on your phone in minutes: step-by-step first aid, offline GPS maps, group communication and a full knowledge library — all working without signal, without data, without the cloud.',
    'hero.cta1': 'Buy — one-time $99',
    'hero.cta2': 'See what\'s included',
    'hero.note': 'One-time payment. No subscriptions, no accounts. Open source (GPL v3): building it yourself is free, forever.',
    'hero.status': '◉ Offline · 100%',

    'modules.eyebrow': 'All in one device',
    'modules.title': 'Six tools for when they matter most',
    'modules.lead': 'Every module works 100% offline. Download content once and it\'s yours forever.',

    'module.emergency.title': 'Emergency guides',
    'module.emergency.desc': 'Step-by-step first aid: CPR, bleeding, choking, fractures, childbirth and more. Search by symptom ("not breathing") in English and Spanish.',

    'module.maps.title': 'Offline maps & GPS',
    'module.maps.desc': 'Find your location and route by road without data. Avoid private roads and gates, mark danger zones, search "take me to…" any place. Install maps for anywhere in the world.',

    'module.mesh.title': 'Communication without internet',
    'module.mesh.desc': 'Chat, share your location and broadcast SOS to nearby devices via WiFi, Bluetooth or LoRa — encrypted, no towers, no servers. Ideal when the network is down.',

    'module.library.title': 'Knowledge library',
    'module.library.desc': 'Full Wikipedia, medical encyclopedia, survival guides and video — all downloaded and browsable without signal.',

    'module.ai.title': 'On-device AI assistant',
    'module.ai.desc': 'An assistant that answers from the device itself, sending nothing to the cloud, backed by the guides and library with citations.',

    'module.yours.title': 'Yours forever',
    'module.yours.desc': 'No subscription or account. Content lives on the device and copies to other phones and computers in your family or group.',

    'mesh.eyebrow': 'Prepper Mesh',
    'mesh.title': 'Connected when there\'s no signal',
    'mesh.lead': 'Three layers of internet-free communication. Your messages travel between devices without towers, servers, or the cloud.',
    'mesh.wifi.title': 'Local WiFi',
    'mesh.wifi.desc': 'Any router, hotspot or access point. Your devices find each other automatically.',
    'mesh.bt.title': 'Bluetooth',
    'mesh.bt.desc': 'Direct device-to-device connection. No router, no setup.',
    'mesh.lora.title': 'LoRa (km range)',
    'mesh.lora.desc': 'Long-range radio for communication over kilometers with zero infrastructure.',

    'offline.eyebrow': 'Built for the worst day',
    'offline.title': 'When there\'s no signal, it still works',
    'offline.lead': 'Hurricane, blackout, remote area, disaster: Nuvok needs no internet, no coverage, no grid power to help you.',
    'offline.stat1': '0',
    'offline.stat1l': 'mobile data needed',
    'offline.stat2': '100%',
    'offline.stat2l': 'local, no cloud',
    'offline.stat3': '32',
    'offline.stat3l': 'first-aid guides',
    'offline.stat4': '🌎',
    'offline.stat4l': 'maps of the entire world',

    'footer.copy': '© 2026 Nuvok · Offline knowledge that saves lives',
    'footer.disclaimer': 'First-aid guides are educational material and do not replace professional medical care or a certified in-person course; always seek medical help when possible. The LoRa radio is an accessory in development; final availability, range and compatibility will be confirmed at launch. Map data © OpenStreetMap contributors.',
  }
};

function getLang() {
  const stored = localStorage.getItem('pp-lang');
  if (stored) return stored;
  // Default to Spanish (primary market), let user switch to EN
  return 'es';
}

function setLang(lang) {
  localStorage.setItem('pp-lang', lang);
  document.documentElement.lang = lang;
  const dict = I18N[lang] || I18N.es;
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (dict[key]) el.textContent = dict[key];
  });
  document.querySelectorAll('[data-i18n-html]').forEach(el => {
    const key = el.getAttribute('data-i18n-html');
    if (dict[key]) el.innerHTML = dict[key];
  });
  // Update toggle button states
  document.querySelectorAll('.lang-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });
}

// Auto-init on load
document.addEventListener('DOMContentLoaded', () => {
  setLang(getLang());
});
