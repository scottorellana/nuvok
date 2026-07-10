# Auditoría de Accesibilidad WCAG 2.1 AA — Nuvok
**Fecha:** 2026-07-04
**Alcance:** App Flutter (`lib/`), sitio web ventas (`website/`), LAN installer (`installer-server/public/`), demo server (`demo-server/public/`).
**Estándar:** WCAG 2.1 Level AA (mínimo).
**Contexto crítico:** App de emergencias para Honduras, español, offline-first. Usuarios objetivo: personas mayores, con discapacidad visual/motora, bajo estrés. Botones de acción (SOS, linterna, sirena) son críticos para salvar vidas.

> **Resumen ejecutivo (TL;DR):**
> - **Cero widgets `Semantics`, `MergeSemantics` o `ExcludeSemantics`** en toda la app Flutter → screen readers no anuncian correctamente varios botones clave.
> - **Cero `aria-*`, `alt`, `<main>`, skip-nav, `:focus`** en los 3 sitios web → sitios prácticamente inaccesibles con teclado o lector de pantalla.
> - **Botón crítico "MODO EMERGENCIA"** no anuncia su propósito al lector de pantalla más allá del texto (correcto, pero `_PanicButtonWidget` es un `InkWell` sin `Semantics` explícito — los icon-only y los textos cortos "RCP"/"Atraganta" en chips pueden no dar contexto).
> - **Dependencia exclusiva de color** en vencimientos (verde/ámbar/rojo) sin ícono ni patrón → falla WCAG 1.4.1.
> - **Textos pequeños hardcoded** (fontSize: 10–13) sin escalar con textScaler → texto ilegible para personas mayores con escala del sistema al 130–200 %.
> - **`GestureDetector` en `flashlight` y `whistle`** envuelve controles críticos sin `Semantics(button: true)` → TalkBack/VoiceOver no los trata como botones.

---

## 🔴 BARRERAS CRÍTICAS (atención inmediata — riesgo de vida)

### C1. Silbato digital — botón gigante no es accesible para screen reader
- **Ubicación:** `lib/modules/tools/whistle.dart:206-257`
- **Problema:** El botón principal es un `GestureDetector` envolviendo un `Container` decorado (círculo rojo con icono y texto "SILBAR"/"DETENER"). Para un usuario con TalkBack/VoiceOver, **no hay Semantics que indique que es un botón, ni que la acción es iniciar/detener sonido**. Un usuario ciego no podría activar el silbato, que es la función #1 de la pantalla.
- **WCAG:** 4.1.2 Name, Role, Value (Level A) — falla.
- **Fix sugerido:**
  ```dart
  Semantics(
    button: true,
    label: _isPlaying ? 'Detener silbato de emergencia' : 'Activar silbato de emergencia',
    child: GestureDetector(onTap: _toggleWhistle, child: ...),
  )
  ```
  O reemplazar por `InkWell` con `Material` (más semántico).

### C2. Linterna — tap a pantalla completa no es accesible
- **Ubicación:** `lib/modules/tools/flashlight.dart:209-222` (GestureDetector a pantalla completa)
- **Problema:** Toda la pantalla es un botón gigante tap-to-cycle. **No hay Semantics que indique modo actual** ("Linterna encendida" / "Modo SOS activo") **ni la acción** ("Tocar para cambiar modo"). Usuario ciego no puede saber si la linterna está encendida o apagada.
- **WCAG:** 4.1.2 Name, Role, Value — falla. También 1.3.1 Info and Relationships.
- **Fix:** envolver el GestureDetector en `Semantics(container: true, label: 'Linterna. Modo actual: ${modeLabel(mode)}. Tocar para cambiar modo.', liveRegion: true)`.

### C3. Botones de pánico — falta contexto semántico
- **Ubicación:** `lib/modules/emergency/emergency_page.dart:766-820` (`_PanicButtonWidget`)
- **Problema:** Cada botón gigante del "MODO EMERGENCIA" es un `Material` + `InkWell` con un icono y label (ej. "NO RESPIRA\n(RCP)"). Aunque el label textual sí lo lee el screen reader, **no se indica que es un botón que abre la guía de RCP**, ni se da contexto como "Toque para abrir guía de reanimación cardiopulmonar". El ícono de RCP (`Icons.monitor_heart`) no es descriptivo sin contexto. En pánico, la persona con discapacidad visual necesita un anuncio claro.
- **WCAG:** 2.4.6 Headings and Labels (Level AA), 4.1.2.
- **Fix:** envolver el `InkWell` en `Semantics(button: true, label: 'Emergencia: no respira. Tocar para abrir guía de RCP.')`.

### C4. Alerta SOS entrante no se anuncia como live region
- **Ubicación:** `lib/app.dart:155-203` (`_onMeshEvent`)
- **Problema:** Cuando llega un SOS de un vecino, aparece un `AlertDialog` rojo. **No hay `Semantics(liveRegion: true)`** que fuerce a TalkBack/VoiceOver a interrumpir y anunciar inmediatamente. Un usuario ciego con la app en segundo plano o sin mirar la pantalla **puede no enterarse de que un vecino está pidiendo ayuda**. En emergencia, esta alerta literalmente salva vidas.
- **WCAG:** 4.1.3 Status Messages (Level AA) — falla.
- **Fix:** envolver el `AlertDialog` o el `Scaffold` que lo presenta con `Semantics(liveRegion: true, label: '¡SOS de ${nombre}! Nota: ${note}. ${posicion}.')` ANTES de mostrar el diálogo, o usar `SemanticsService.announce()` para anunciar al recibir el evento.

### C5. Banner de batería baja no se anuncia
- **Ubicación:** `lib/app.dart:320-363` (`_LowBatteryBanner`)
- **Problema:** Banner rojo "Batería baja (15%). Activa el ahorro" aparece condicionalmente. **No es una live region** — un usuario ciego navegando con TalkBack no escuchará el cambio cuando la batería cruce el umbral. En emergencia, perder batería sin saberlo es un riesgo mortal.
- **WCAG:** 4.1.3 Status Messages (Level AA) — falla.
- **Fix:** `Semantics(liveRegion: true, label: 'Batería baja: ${level} por ciento. Activa el ahorro para durar más.')` envolviendo el `Material`.

---

## 🟠 BARRERAS SERIAS (afectan usabilidad crítica)

### S1. Cero widgets de Semantics en todo el código
- **Ubicación:** `lib/**/*.dart` (búsqueda exhaustiva: 0 ocurrencias de `Semantics`, `MergeSemantics`, `ExcludeSemantics`, `SemanticsService.announce`).
- **Problema:** Flutter deriva la semántica automáticamente de widgets como `Text`, `IconButton(tooltip:...)`, pero **los `GestureDetector`, `InkWell` crudos, y muchos iconos sueltos** (como el `Icon(Icons.qr_code)` en `_channelTile` con tooltip OK pero sin Semantics adicional) no anuncian contexto suficiente. La regla WCAG 4.1.2 exige "name, role, value" — Flutter lo hace parcialmente pero muchos casos quedan descubiertos.
- **WCAG:** 4.1.2 Name, Role, Value (Level A).
- **Fix:** revisar módulo por módulo y envolver widgets interactivos en `Semantics(button: true, label: '...')` cuando no haya equivalente semántico built-in.

### S2. Botón "Enviar" del chat IA sin tooltip ni Semantics
- **Ubicación:** `lib/modules/ai/ai_page.dart:323-333`
- **Problema:** `IconButton.filled` con `Icon(Icons.send)` — **sin `tooltip`**. Usuario de teclado (alternativa teclado externo TalkBack) no sabe qué hace.
- **WCAG:** 4.1.2, 2.4.6.
- **Fix:** agregar `tooltip: 'Enviar mensaje'`.

### S3. Chips de categoría en chat mesh solo decorativos
- **Ubicación:** `lib/modules/mesh/mesh_page.dart:403-424`
- **Problema:** Lista de chips ("LAN/hotspot", "Bluetooth LE", "Wi‑Fi Direct", "LoRa radio") son `Chip` puros sin `onPressed`. **Para screen readers son solo texto**, pero visualmente parecen toggles/botones. Si la intención es informativa, OK; si la intención es filtrar, falta interactividad.
- **WCAG:** 1.3.1 Info and Relationships, 4.1.2.
- **Fix:** si son informativos, marcar con `Semantics(label: 'Transporte soportado: WiFi Local')`. Si son filtros, hacerlos `FilterChip` con `selected:`.

### S4. Vencimientos del checklist dependen solo de color
- **Ubicación:** `lib/modules/prep/checklist_page.dart:367-413` (`_ChecklistTile`), `_ExpiryAlertCard` líneas 199-271
- **Problema:** Items vencidos en rojo (`Colors.red.shade700`), por vencer en naranja (`Colors.orange.shade700`), al día sin distinción. La categoría en sí no tiene ícono diferenciador (los textos sí mencionan "vencido" pero el badge solo dice `${days}d` y "Vencido ${days.abs()}d"). **WCAG 1.4.1 Use of Color (Level A): no usar color como único medio para transmitir información.** Un usuario con deuteranopia o protanopia no distingue rojo de naranja.
- **WCAG:** 1.4.1 Use of Color (Level A).
- **Fix:** agregar íconos (`Icons.warning`, `Icons.dangerous`, `Icons.check_circle`) junto al color; o patrones (borde punteado para "por vencer", sólido para "vencido"); o prefijos textuales ("⚠️ Vencido", "⏰ Por vencer").

### S5. Flashlight modes no comunican estado a screen reader
- **Ubicación:** `lib/modules/tools/flashlight.dart:169-272`
- **Problema:** El estado (off/on/sos) se muestra solo visualmente con cambio de color (negro/blanco/parpadeo). **No hay anuncio cuando el modo cambia** (ni vía Semantics live region ni vía Tooltip dinámico en el IconButton back). Usuario ciego no sabe si pulsó y qué modo está activo.
- **WCAG:** 4.1.3 Status Messages.
- **Fix:** `SemanticsService.announce('Linterna en modo ${label}', TextDirection.ltr)` en cada `setMode`.

### S6. SOS confirmado: el botón rojo no es accesible sin contexto
- **Ubicación:** `lib/modules/mesh/mesh_page.dart:357-374`
- **Problema:** `ListTile` con `trailing: FilledButton(child: Text('SOS'))`. El botón dice solo "SOS" — sin contexto de qué hace. Usuario de screen reader oye "Botón SOS" sin saber que abre un diálogo para confirmar el envío.
- **WCAG:** 2.4.6 Headings and Labels.
- **Fix:** cambiar texto a "Activar SOS" o usar `Semantics(label: 'Activar señal de emergencia SOS')`.

### S7. Textos críticos hardcoded con fontSize pequeño
- **Ubicación:** dispersos — `lib/modules/emergency/emergency_page.dart:166` (fontSize: 12 gris para disclaimer), `lib/modules/prep/checklist_page.dart:140, 240, 248, 408, 429, 442, 452` (fontSize: 11-13 para info vital de vencimientos), `lib/modules/maps/mesh_page.dart:104, 590, 610, 663, 679` (fontSize: 10-12), `lib/modules/depot/depot_page.dart:540, 562, 650, 683` (fontSize: 11-13).
- **Problema:** Textos que comunican **información vital de seguridad** (fechas de vencimiento, disclaimers médicos, resúmenes de mensaje) están en `fontSize: 11` o `12` hardcoded. **Personas mayores (población objetivo de esta app) con vista cansada o presbicia NO PUEDEN LEER** esta información, especialmente en luz baja de emergencia. Además, el `textScaler` del sistema no escala estos textos porque están como `TextStyle` directo, no en `textTheme`.
- **WCAG:** 1.4.4 Resize Text (Level AA) — el texto debe ser redimensionable hasta 200 % sin perder funcionalidad.
- **Fix:** eliminar fontSize hardcoded en info vital; usar `Theme.of(context).textTheme.bodySmall` o `labelSmall` (que sí respetan el textScaler). Si fontSize pequeño es necesario, **asegurarse de que el textScaler del sistema lo escale** envolviendo en `MediaQuery` con `textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1))` o eliminando el fontSize fijo.

### S8. SOS dialog: contraste rojo/white70 insuficiente
- **Ubicación:** `lib/app.dart:172-178` y `lib/app.dart:184-185`
- **Problema:** `Colors.white70` sobre `Colors.red.shade900`. **`Colors.white70` = rgba(255,255,255,0.7)**, lo que sobre rojo oscuro da un contraste aproximado de **5.2:1** para texto normal — pasa 4.5:1 marginalmente. PERO el texto "Posición: lat, lon" es informativo vital, no decorativo; usar `Colors.white` directo sería más seguro.
- **WCAG:** 1.4.3 Contrast (Minimum) — pasa marginalmente, riesgo.
- **Fix:** reemplazar `Colors.white70` por `Colors.white` o `Color(0xFFE8E8E8)`.

---

## 🟡 BARRERAS MODERADAS

### M1. Sitios web: cero atributos ARIA ni `<main>` semántico
- **Ubicación:** `website/index.html`, `installer-server/public/index.html`, `demo-server/public/index.html`
- **Problema:** Las tres páginas usan `<header>`, `<footer>`, `<section>` correctamente, pero **carecen de `<main>`** para delimitar el contenido principal, **no tienen `aria-label`** en las secciones para diferenciarlas, y **no tienen landmarks de navegación** (`<nav aria-label="Principal">`). El nav de `website/index.html` es `<nav>` pero sin label.
- **WCAG:** 1.3.1 Info and Relationships (Level A), 2.4.1 Bypass Blocks (Level A — implica necesidad de skip nav).
- **Fix:**
  ```html
  <nav aria-label="Principal">...</nav>
  <main>... contenido ...</main>
  <footer>...</footer>
  ```

### M2. Sitios web: cero indicador visible de focus (`:focus`)
- **Ubicación:** `website/styles.css`, `installer-server/public/index.html` (inline), `demo-server/public/index.html` (inline)
- **Problema:** Búsqueda exhaustiva: **ningún selector `:focus` ni `:focus-visible` definido en ninguno de los tres CSS**. Usuarios que navegan con teclado (Tab) no ven dónde están. Esto es crítico para usuarios con discapacidad motora o ciegos con teclado Braille.
- **WCAG:** 2.4.7 Focus Visible (Level AA) — falla.
- **Fix:** agregar a cada CSS:
  ```css
  :focus-visible { outline: 3px solid var(--olive-bright); outline-offset: 2px; }
  a:focus-visible, button:focus-visible { outline-color: var(--olive-bright); }
  ```

### M3. Falta skip-nav link en los 3 sitios
- **Ubicación:** los 3 HTML
- **Problema:** No hay enlace "Saltar al contenido principal" al inicio del body. Usuario con teclado o screen reader debe tabular por todo el nav en cada página.
- **WCAG:** 2.4.1 Bypass Blocks (Level A) — falla.
- **Fix:**
  ```html
  <body>
    <a href="#main" class="skip-link">Saltar al contenido principal</a>
    <nav>...</nav>
    <main id="main" tabindex="-1">...</main>
  ```
  Con CSS:
  ```css
  .skip-link { position: absolute; left: -9999px; top: 0; padding: 12px; background: var(--olive); color: var(--bg); z-index: 9999; font-weight: 700; }
  .skip-link:focus { left: 0; }
  ```

### M4. Botones de descarga sin aria-label claro (installer server)
- **Ubicación:** `installer-server/public/index.html:423` y líneas similares
- **Problema:** `<button class="download-btn">Descargar</button>` se genera dinámicamente — el botón dice solo "Descargar". Usuario de screen reader oye "Botón Descargar" tres veces (uno por cada instalador) sin saber cuál es el de Mac vs Android. Falta contexto.
- **WCAG:** 2.4.6 Headings and Labels.
- **Fix:** generar `aria-label="Descargar ${safeName} para ${safePlatform}"` en el botón.

### M5. QR code sin texto alternativo
- **Ubicación:** `installer-server/public/index.html:136-138`, `demo-server/public/index.html` (si tiene QR)
- **Problema:** El canvas del QR se genera dinámicamente sin `aria-label` ni fallback textual. Usuario ciego no sabe qué QR es (ni que hay un texto con la URL abajo).
- **WCAG:** 1.1.1 Non-text Content (Level A) — falla.
- **Fix:** `<canvas id="qr-code" role="img" aria-label="Código QR que apunta a ${serverUrl}"></canvas>`.

### M6. Demo server: badges estadísticos sin contexto
- **Ubicación:** `demo-server/public/index.html:386-410` (sección "Estado del proyecto")
- **Problema:** `<div class="feature-icon" style="font-size:2rem;">164</div>` es visualmente un número grande. Para screen reader es solo "164". Sin contexto, no comunica que es "164 tests pasando".
- **WCAG:** 1.1.1, 1.3.1.
- **Fix:** `<div class="feature-icon" aria-label="164 tests pasando"><span aria-hidden="true">164</span></div>` y mantener el `<h3>Tests</h3><p>Todos pasando, 0 fallos</p>` para el contexto.

### M7. Contraste marginal en textos secundarios
- **Ubicación:** disperso en los 3 sitios web
- **Problema:**
  - `website/styles.css`: `--ink-dim: #9aa097` sobre `--bg: #0d0f0a` → contraste ~7.8:1 (pasa). Pero `--ink-faint: #5d6354` sobre `--bg` → contraste ~3.1:1 — **falla 4.5:1 para texto normal**. Usado en `.hero-note`, `.footnote`, etc.
  - `installer-server/public/index.html`: `--ink-dim: #8a9070` sobre `--bg: #0f120a` → contraste ~6.5:1 (pasa). Pero `.checksum` con `opacity: 0.6` reduce más.
  - `demo-server/public/index.html`: similar, pero `.triage-yellow { color: #333 }` sobre fondo `var(--warn)` (amarillo) → contraste ~7:1 OK.
- **WCAG:** 1.4.3 Contrast (Minimum).
- **Fix:** subir `--ink-faint` de `#5d6354` a `#7d8470` (o más claro).

### M8. Icon-only button en nav del website
- **Ubicación:** `website/index.html:49-50` (botones de idioma ES/EN)
- **Problema:** Botones de cambio de idioma son `<button>` con texto "ES"/"EN" — el texto sí lo lee screen reader, OK. Pero los iconos emoji grandes en `<div class="ic">🚨</div>` (línea 102, 107, 112, 117, 122, 127) son decorativos y **no tienen `aria-hidden`**. Screen reader podría leerlos literalmente.
- **WCAG:** 1.1.1 Non-text Content.
- **Fix:** `<div class="ic" aria-hidden="true">🚨</div>`.

### M9. App Flutter: navegación por teclado/external device
- **Ubicación:** global
- **Problema:** `NavigationRail` (lateral) es navegable con flechas del teclado OK, pero **no hay `Shortcuts` widget definido** para acciones críticas globales (Ctrl+S para SOS, Ctrl+L para linterna, etc.). Personas con discapacidad motora que usan switch control o teclado externo no tienen atajos.
- **WCAG:** 2.1.1 Keyboard (Level A), 2.1.4 Character Key Shortcuts (Level A).
- **Fix:** agregar `Shortcuts`/`Actions` global con Ctrl+S = abrir SOS, Ctrl+L = linterna, Ctrl+F = SOS flash.

---

## 🟢 BARRERAS MENORES

### m1. Visualmente se indica carga con `CircularProgressIndicator` sin label
- **Ubicación:** `lib/modules/emergency/emergency_page.dart:127`, `lib/modules/library/library_page.dart:92`
- **Problema:** `CircularProgressIndicator` sin `Semantics(label: 'Cargando')`.
- **WCAG:** 4.1.2.
- **Fix:** envolver en `Semantics(label: 'Cargando contenido', liveRegion: true)`.

### m2. Mínimo target táctil — algunos iconos de 18px
- **Ubicación:** `lib/modules/notes/notes_page.dart:154` (`IconButton(size: 18)` para borrar)
- **Problema:** WCAG 2.5.5 Target Size (Level AAA) recomienda 44×44 CSS pixels mínimo. Algunos iconos en filas densas (notas, lista de canales mesh) usan 18-20 px sin padding de hit area.
- **WCAG:** 2.5.5 (AAA — no obligatorio para AA, pero buena práctica).
- **Fix:** envolver en `IconButton(iconSize: 18, padding: EdgeInsets.all(12))` o usar `Material(child: InkWell(child: Padding(...)))`.

### m3. Focus order de TextField en dialogs
- **Ubicación:** `lib/modules/mesh/mesh_page.dart:54-69, 130-145`
- **Problema:** El `TextField` con `autofocus: true` recibe focus al abrirse — bien. Pero si el usuario cierra con Cancelar, el foco se pierde (no regresa al botón que abrió el diálogo).
- **WCAG:** 2.4.3 Focus Order.
- **Fix:** usar `FocusScope.of(context).requestFocus(...)` o `FocusManager.instance.primaryFocus?.previousFocus` al cerrar.

### m4. SnackBar — duración fija sin opción de extender
- **Ubicación:** disperso
- **Problema:** SnackBars con `duration: Duration(seconds: 2)` (ej. `lib/modules/prep/checklist_page.dart:163`) — usuarios con discapacidad cognitiva o que leen despacio pueden perder el mensaje. Material 3 ahora recomienda duración mínima 4s para mensajes importantes.
- **WCAG:** 2.2.1 Timing Adjustable.
- **Fix:** `duration: const Duration(seconds: 4)` o mayor para mensajes críticos.

### m5. Labels flotantes sin animación accesible
- **Ubicación:** campos de texto en dialogs
- **Problema:** `InputDecoration(labelText: '...')` usa animación estándar de Material — OK, pero en algunos sitios no se usa `floatingLabelBehavior`. Si el valor es vacío, el label desaparece y un screen reader puede no anunciarlo.
- **WCAG:** 3.3.2 Labels or Instructions.
- **Fix:** asegurar que cada TextField tenga `labelText` o `hintText` semánticamente equivalente.

### m6. Tooltips en icon-only buttons — buenos pero no en todos
- **Ubicación:** algunos IconButton en `lib/modules/depot/depot_page.dart`, `lib/modules/maps/maps_page.dart` (estos sí), pero `lib/modules/library/library_page.dart:84-88` (refresh) sí tiene tooltip — OK.
- **Problema:** El módulo de AI page (línea 323) tiene IconButton.filled sin tooltip (ya cubierto en S2). El módulo de Notas sí tiene tooltips (líneas 114, 122). **Es inconsistente.**
- **Fix:** auditoría y agregar `tooltip:` a todo IconButton/IconButton.filled.

---

## 🎨 OBSERVACIONES DE CONTRASTE Y COLOR

### App Flutter (dark theme)
- Background: `#14170F` (scaffold), colorScheme seed `#8C9E5E` (olive).
- Texto principal: scheme.onSurface (negro/claro según brightness.dark) — **asumir blanco/claro, contraste > 12:1 OK**.
- **Texto secundario `Theme.of(context).hintColor`** usado en muchos lugares con `Colors.grey` literal (ej. `lib/modules/emergency/emergency_page.dart:155-167` usa `color: Colors.grey` para el disclaimer). `Colors.grey` (Material default `#9E9E9E`) sobre fondo `#14170F` → contraste ~5.0:1 — **pasa 4.5:1 marginalmente**.
- **`Colors.grey` como texto informativo vital es riesgoso**: en lib/modules/mesh/mesh_page.dart:260 `style: TextStyle(color: Colors.grey)` para texto explicativo — pasa pero con poco margen.

### Web
- Ya cubierto en M7.

---

## ✅ LO QUE ESTÁ BIEN (reconocer)

- **`lib/app.dart:57-63`**: `FilledButton` con `minimumSize: Size(88, 52)` → 88×52 dp, **supera el mínimo Material de 48×48 y el WCAG 2.5.5 de 44×44** ✅.
- **`lib/modules/maps/maps_page.dart:628-664`**: Todos los `IconButton` del AppBar tienen `tooltip:` descriptivo ✅.
- **`lib/modules/library/library_page.dart:84`**: `IconButton(tooltip: 'Actualizar', ...)` ✅.
- **`lib/modules/notes/notes_page.dart:114-122`**: `IconButton` con `tooltip:` para editar/vista previa/nueva nota ✅.
- **`website/index.html`**: Jerarquía de headings correcta (h1 → h2 → h3, sin saltos) ✅.
- **`website/index.html:65-68`**: Botones CTA tienen texto claro ("Reservar la tablet — $599") ✅.
- **`installer-server/public/index.html`**: Progreso de descarga se anuncia con `progressBar` + `progressText` ✅ (aunque falta aria-live para SR).
- **`demo-server/public/index.html`**: Tabs de guías tienen botón con `cursor: pointer` y estado `active` visual — parcialmente accesible por teclado si se hace focusable, pero **los `<div>` no son `<button>`** (menor, m6 abajo).

---

## 📋 PLAN DE REMEDIACIÓN PRIORIZADO

### Sprint 1 (urgente — 1-2 semanas)
1. **C4, C5**: Agregar `Semantics(liveRegion: true, ...)` al SOS entrante y al banner de batería baja. **Crítico para vidas.**
2. **C1, C2, C3**: Envolver `GestureDetector` e `InkWell` críticos (silbato, linterna, pánico) en `Semantics(button: true, label: ...)` con descripción clara.
3. **S2**: Agregar `tooltip` al botón enviar del chat IA.
4. **M2**: Definir `:focus-visible` en los 3 CSS de los sitios web.
5. **M1, M3**: Agregar `<main>`, `<nav aria-label>`, y skip-nav a los 3 sitios web.

### Sprint 2 (2-4 semanas)
6. **S4**: Enriquecer vencimientos del checklist con íconos además de color.
7. **S7**: Eliminar `fontSize:` hardcoded en textos vitales, usar `textTheme`.
8. **S1**: Auditoría módulo por módulo para agregar `Semantics` a widgets interactivos faltantes.
9. **M4, M5**: Agregar `aria-label` a botones de descarga del installer y al canvas del QR.
10. **M9**: Definir Shortcuts globales para acciones críticas (Ctrl+S = SOS, etc.).

### Sprint 3 (refinamiento)
11. Resolver problemas moderados restantes (M6, M7, M8).
12. Problemas menores (m1-m6).
13. Test con TalkBack en Android, VoiceOver en iOS, NVDA/JAWS en web.

---

## 📊 Resumen cuantitativo

| Categoría | Total |
|---|---|
| 🔴 Críticas | 5 |
| 🟠 Serias | 8 |
| 🟡 Moderadas | 9 |
| 🟢 Menores | 6 |
| **Total barreras identificadas** | **28** |

**Componentes auditados:**
- 12 módulos Flutter (`lib/modules/*`)
- 1 archivo raíz (`lib/app.dart`)
- 3 sitios web (website, installer-server, demo-server)
- ~50 archivos `.dart` escaneados
- 3 archivos HTML principales

**Sin modificaciones al código**, como solicitado. Reporte guardado en `AUDIT_WCAG_2026-07-04.md`.