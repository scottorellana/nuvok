# Plan de promoción — Nuvok open source

**Regla de oro:** Hacker News y Reddit huelen el marketing a kilómetros. Todo
lo de abajo funciona solo con honestidad radical: qué hace, qué no hace, qué
falta. La historia real (el apagón de Venezuela) vale más que cualquier
eslogan.

**Quién publica:** las cuentas son de Scott; este plan trae borradores, pero
publicar es siempre acción del dueño. En HN/Reddit el AUTOR debe responder
comentarios en persona el día del lanzamiento (4-6 horas de disponibilidad).

---

## Fase 0 — Antes de hacer ruido (esta semana)

Sin esto, cada visitante que llegue se pierde:

1. **Visuales en el README** — hoy no tiene NI UNA imagen. Mínimo: 3
   capturas (Emergencia, Asistente IA respondiendo, mapa) + un GIF/video de
   30 s del SOS cruzando la malla con los teléfonos en modo avión. Es el
   activo de promoción #1: se rueda con 2 teléfonos en 1 hora.
2. **Metadata del repo** (5 min, checklist §3 de LANZAMIENTO_GITHUB.md):
   descripción, topics, homepage, Discussions, private vulnerability
   reporting, social preview 1280×640.
3. **Tienda encendida** (R2 + wrangler + Lemon Squeezy + DNS): si HN manda
   10.000 visitas y el botón dice "Muy pronto", se quemó el lanzamiento.
4. **Notarización macOS** — el aviso de "Apple no pudo verificar" mata la
   conversión de cada descarga de prueba.
5. **Purga de historia** cuando Hermes esté quieto (clon 1.4 GB → ~150 MB):
   "clona y compila en 3 comandos" debe ser verdad también en tiempo.

## Fase 1 — Lanzamiento técnico (semana 1)

Un canal por día, nunca todos juntos:

### Show HN (martes-jueves, 8-10 am hora del Este)

- **Título:** `Show HN: Nuvok – Offline emergency app with on-device AI and Bluetooth mesh SOS`
- **URL:** el repo de GitHub (no el sitio de venta — HN castiga aterrizar en
  un paywall).
- **Primer comentario (borrador, publicado por Scott al instante):**

  > Hi HN — I built this after Venezuela lost internet for three days.
  > My family is from Honduras; blackouts and hurricanes are not
  > hypotheticals for us.
  >
  > Nuvok is a Flutter app where everything runs without internet: first-aid
  > guides in 7 languages, an AI assistant (llama.cpp compiled in via FFI —
  > Gemma 4 E2B at ~100 tok/s on an iPhone 15 Pro), offline maps with street
  > routing, medical Wikipedia, and a Bluetooth/Wi-Fi mesh where an SOS
  > store-and-forwards between phones with no signal.
  >
  > Honest notes: it's GPL-3.0 and building it yourself is free forever; I
  > sell signed binaries on nuvok.org ($99, Ardour model) to fund it. The
  > first-aid content follows 2025 guidelines but a licensed medical review
  > is still in progress — the app says so. iPhone needs building from
  > source until I sort out App Store distribution (dual licensing).
  >
  > I'd love scrutiny on the mesh crypto (AES-256-GCM per channel, header as
  > AAD, docs in SECURITY.md) — that's why it's open source.

- Ese día: cero promoción cruzada. Solo responder, rápido y sin defensas.

### r/LocalLLaMA (otro día)

- **Título:** `Gemma 4 E2B running fully offline on phones for emergency guidance — ~100 tok/s on iPhone 15 Pro (GPL app)`
- Cuerpo: la tabla de modelos por RAM del README, cómo se embebió llama.cpp
  por FFI (el detalle del template `<|turn>`, Metal en iOS), y una invitación
  concreta: "publica tus tokens/s y tu equipo y armamos la tabla comunitaria".
  Esa comunidad participa cuando hay números que aportar.

### Product Hunt (martes de OTRA semana)

- Galería con las capturas + el video del SOS. Primer comentario con la
  historia. Responder todo el día.

### Reddit por comunidades (1 por semana, leyendo las reglas de cada una)

- r/preppers: narrativa personal ("construí esto tras el apagón de
  Venezuela"), sin enlaces de venta, el repo si lo piden.
- r/selfhosted y r/opensource: ángulo GPL + nada-sale-de-tu-equipo.
- r/flutter: ángulo técnico (FFI, 576 tests, mesh, bootstrap en 3 comandos)
  — de aquí salen contribuidores.

## Fase 2 — Latam y la historia humana (semanas 2-4)

- **TikTok/Reels/Shorts:** el guion viral ya escrito (apagón de Venezuela) +
  serie "¿tu teléfono puede salvarte sin internet?" — demos de 30 s: el SOS
  en modo avión, la IA respondiendo en un túnel, el mapa sin datos.
- **Prensa tech en español:** Xataka, Hipertextual, Genbeta. Pitch de una
  línea: "El desarrollador hondureño que convirtió el apagón de Venezuela en
  una app open source con IA sin internet". Prensa local hondureña: el
  ángulo "software hecho en Honduras para el mundo" es nota segura.
- **Comunidades venezolanas/cubanas:** con tacto y utilidad real (la app es
  gratis compilándola; el APK se pasa de teléfono a teléfono sin internet —
  ESO es noticia ahí). Nunca tono oportunista sobre desastres.
- **X/Twitter:** hilo técnico en inglés el día del Show HN; en español la
  historia. Después, "build in public": cada release con sus números.

## Fase 3 — Sostener (mensual)

- **Release mensual** con changelog legible + post corto. La constancia
  pesa más que el pico del lanzamiento.
- **Newsletters/agregadores** (se envían solos): Console.dev, Changelog
  News, TLDR, Flutter Weekly. **Awesome lists** por PR: awesome-flutter,
  awesome-privacy.
- **YouTubers** con clave de regalo y demo preparada: NetworkChuck (perfil
  exacto: tech+preparedness), Fireship ("Nuvok in 100 seconds" es soñar,
  pero el pitch es gratis); en español, canales de tech Latam.
- **Podcasts:** Self-Hosted, Late Night Linux; los de software en español.
- **Auditoría de seguridad pro bono:** aplicar a OSTIF y Radically Open
  Security (auditan proyectos open source de interés público — una app de
  emergencias GPL califica). Un reporte público de auditoría del mesh es
  promoción Y producto.
- **Charlas:** meetups Flutter Latam, FlutterConf; CFP con "llama.cpp dentro
  de una app Flutter por FFI".

## Métricas de la primera ola

| Métrica | Bien | Excelente |
|---|---|---|
| Estrellas semana 1 | 200 | 1.000 |
| Show HN | portada >2 h | top 10 del día |
| Contribuidores externos (mes 1) | 2 PRs | 10 PRs / good-first-issues cerrados |
| Ventas semana 1 | 10 | 50 |
| Tabla comunitaria de benchmarks | 5 equipos | 25 equipos |

## Lo que NO hacer

- Lanzar con el botón de compra apagado o el README sin imágenes.
- Publicar en todos los canales el mismo día (parece spam y divide la
  atención del autor).
- Exagerar lo médico: el disclaimer visible es parte del pitch, no una
  vergüenza.
- Astroturfing (cuentas falsas, votos comprados): HN y Reddit lo detectan y
  es la muerte reputacional de un proyecto de confianza.
