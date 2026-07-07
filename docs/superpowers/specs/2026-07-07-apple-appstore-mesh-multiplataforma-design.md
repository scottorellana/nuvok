# Prepper Pad listo para App Store: mesh multiplataforma y escala de producción

Fecha: 2026-07-07 · Estado: aprobado en diseño

## Objetivo

Dejar Prepper Pad listo para publicarse en **App Store y Google Play** con
distribución masiva, con el mesh funcionando **entre iPhone y Android** en los
dos escenarios (misma WiFi y aparato-a-aparato sin red), y con un ruteo que
escala a **~50 dispositivos por zona** (millones de usuarios = millones de
meshes locales independientes; no hay servidor central que sature).

## No-objetivos (v1 iOS)

- **IA local en iPhone**: llama-server corre como proceso hijo y iOS lo
  prohíbe. En iOS v1 el Asistente IA se deshabilita con un mensaje honesto
  ("disponible en tablet/computadora"). Portarlo (llama.cpp como librería
  enlazada) es un proyecto aparte.
- **Mesh en segundo plano en iOS**: v1 funciona con la app abierta. Los modos
  de background BLE se piden en v2 con justificación (reduce riesgo de rechazo
  inicial).
- Ruteo por tablas/vecinos (cientos de nodos por mesh): innecesario a esta
  escala; la inundación con supresión es el estándar probado (Meshtastic).

## Sub-proyecto 1 — Núcleo mesh multiplataforma (verificable hoy Mac↔Android)

### 1a. LAN: descubrimiento Bonjour + datos unicast

Problema: iOS restringe multicast/broadcast crudo (entitlement especial), y
muchos routers/hotspots lo filtran de todos modos.

- Plugin `bonsoir` (NSD en Android, NetService/nw_browser en iOS/macOS, Avahi
  en Linux). Bonjour está **exento** del entitlement de multicast en iOS si se
  declara `NSBonjourServices` en Info.plist.
- Cada dispositivo **anuncia** `_prepperpad._udp` con TXT `{id, port}` y
  **navega** el mismo tipo. Cada peer resuelto siembra `_peerAddrs` del
  `LanTransport` existente → los datos viajan por el socket UDP actual en
  **unicast** (permitido en iOS sin entitlements).
- El multicast/broadcast actual se conserva como vía adicional donde funciona
  (Android/desktop, y iOS cuando Apple otorgue el entitlement que igualmente
  solicitaremos).
- Manejo de errores: si bonsoir falla (plataforma sin soporte, permiso
  denegado), el transporte sigue con multicast+unicast como hoy — degradación
  silenciosa, patrón ya establecido.

### 1b. BLE doble rol (iPhone↔Android sin ninguna red)

Problema: `flutter_blue_plus` solo escanea (rol central). Nadie se anuncia →
dos teléfonos nunca se encuentran. Además no soporta rol periférico.

- Migrar a `bluetooth_low_energy` (central **y** periférico; iOS, Android,
  macOS). Cada dispositivo anuncia un servicio GATT propio de Prepper Pad
  (UUID fijo) y a la vez escanea.
- GATT: característica RX (write sin respuesta, entrante) y TX (notify,
  saliente).
- **Fragmentación**: BLE mueve ~180 bytes/paquete; los sobres del mesh miden
  200–600. Capa de fragmentos con cabecera `[idFragmento, seq, total]`,
  reensamblado con timeout de 10s y descarte de incompletos. Tests unitarios
  puros de partir/rearmar/perder fragmentos.
- El contrato `MeshTransport` no cambia: el router ni se entera.

### 1c. Escalabilidad a ~50 nodos: supresión de inundación

En `MeshRouter` (lógica pura, testeable sin sockets):

- Contador de veces-oído por `msgId`. Al recibir un sobre ajeno con
  `hopLimit>0`, el relevo se **agenda con jitter aleatorio** (50–300ms); si
  antes de disparar se oye el mismo msgId ≥2 veces (otro nodo ya relevó), se
  **cancela**. Corta ~80% del tráfico redundante en grupos densos.
- **Prioridad SOS**: jitter corto (20–80ms) y umbral de cancelación 3 — un SOS
  se releva casi siempre y primero. Beacons nunca se relevan (hop 1, ya así).
- **Beacons adaptativos**: 15s con actividad/peers; 60s en reposo (ahorra
  batería en la mochila). La ráfaga de arranque actual se conserva.
- El puenteo entre transportes ya existe (el router reenvía por TODOS los
  transportes): un teléfono con WiFi+BLE une ambos mundos. Se añade test que
  lo fija.

## Sub-proyecto 2 — Target iOS completo y conforme

- `flutter create --platforms=ios .` + Podfile con plataforma mínima iOS 14.
- Info.plist: `NSBluetoothAlwaysUsageDescription`,
  `NSLocalNetworkUsageDescription`, `NSBonjourServices` (`_prepperpad._udp.`),
  `NSLocationWhenInUseUsageDescription` — textos específicos y honestos
  ("chat de emergencia sin internet entre tus dispositivos", "tu posición en
  el mapa offline y en un SOS").
- **PrivacyInfo.xcprivacy** (obligatorio 2024+): la app no recolecta nada;
  se declaran solo los required-reason APIs de los plugins (UserDefaults,
  timestamps de archivo) con sus códigos estándar.
- **Cifrado**: `ITSAppUsesNonExemptEncryption = false` (AES estándar para
  contenido del usuario = exención mass-market).
- **Nativo**: compilar zstd/liblzma como librerías estáticas iOS
  (`scripts/build_native_ios.sh`, cmake + toolchain iOS) enlazadas al Runner;
  `zim_native` gana rama iOS que resuelve símbolos con
  `DynamicLibrary.process()`. La Biblioteca ZIM funciona igual que en Android.
- IA: `Platform.isIOS` → página con mensaje honesto y enlace a qué sí funciona.
- Verificación: `flutter build ios --simulator` limpio + humo en simulador
  (navegación, mapas con .pmtiles, crear canal mesh).

## Sub-proyecto 3 — Listo para las tiendas

- **Actualizaciones**: Apple (2.5.2) y Play prohíben auto-actualizarse.
  Build de tienda con `--dart-define=STORE_BUILD=true`: oculta la pestaña
  App/actualizaciones y no incluye `REQUEST_INSTALL_PACKAGES` (manifest de
  flavor). Desktop y APK directo conservan el sistema LAN actual intacto.
- **Android/Play**: generar `.aab` firmado, targetSdk vigente, revisar
  permisos declarados vs. usados (los de mesh ya están justificados).
- **Robustez de producción**: disco lleno al descargar (mensaje claro +
  limpieza de `.part`), reanudación de descargas ya existe, atribución OSM ya
  existe, descargo médico ya existe.
- Contenido: Wikipedia/mapas vienen de espejos públicos de Kiwix/Protomaps
  (diseñados para volumen masivo) — cero infraestructura propia.

## Sub-proyecto 4 — Firma, TestFlight y envío (requiere sesiones del usuario)

- Configurar firma con la cuenta Developer de pago; instalar en iPhone real;
  prueba de campo iPhone↔Android (WiFi y BLE).
- Solicitar a Apple el entitlement `com.apple.developer.networking.multicast`
  (formulario; llega en días) — refuerzo, no bloqueador, gracias a Bonjour.
- Guía paso a paso para App Store Connect y Play Console (ficha, capturas,
  privacidad, revisión). El envío final lo ejecuta el usuario.

## Orden de ejecución y verificación

1 → 2 → 3 → 4. Cada sub-proyecto con TDD (fragmentación, supresión, jitter,
Bonjour mock), suite completa verde, y verificación en vivo donde el hardware
lo permite (Mac↔Android ya; iPhone al firmar en el paso 4).
