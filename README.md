# Nuvok

**Español** · [English](README.en.md)

[![CI](https://github.com/scottorellana/nuvok/actions/workflows/ci.yml/badge.svg)](https://github.com/scottorellana/nuvok/actions/workflows/ci.yml)
[![Licencia: GPL v3](https://img.shields.io/badge/licencia-GPL%20v3-blue.svg)](LICENSE)
[![IA 100% local](https://img.shields.io/badge/IA-100%25%20local-success.svg)](#-ia-local-en-tu-iphone-paso-a-paso)

**Conocimiento que no se apaga.** Guías de emergencia, Wikipedia, mapas,
asistente de IA y comunicación en malla — todo funcionando **sin internet**,
sin servidores y sin cuentas. Nacida del apagón que dejó a Venezuela tres
días sin internet: Nuvok existe para el momento en que la red desaparece.

| Módulo | Qué hace |
|---|---|
| 🚨 Emergencia | Guías propias de primeros auxilios y supervivencia con búsqueda por síntoma, en 7 idiomas |
| 🧠 Asistente IA | Especialistas de IA que corren **dentro de tu teléfono** (llama.cpp + Metal), con tus guías como fuentes |
| 📖 Biblioteca | Wikipedia y libros offline (`.zim` de Kiwix) |
| 🗺️ Mapas | Mapas offline con GPS, ruteo por calles y "llévame a…" (`.pmtiles`) |
| 📡 Comunicación | Malla Bluetooth/WiFi sin internet: chat cifrado, SOS que se reenvía solo, posiciones del grupo |
| 📦 Depósito | Donde eliges y descargas tu contenido (el único lugar que usa internet) |

<p align="center">
  <img src=".github/media/emergencia.png" width="49%" alt="Guías de Emergencia: modo emergencia, buscador por síntoma y accesos rápidos de RCP, atragantamiento y sangrado" />
  <img src=".github/media/mapas.png" width="49%" alt="Mapas offline a nivel de calle (San Pedro Sula) con datos de OpenStreetMap" />
</p>
<p align="center">
  <img src=".github/media/especialistas.png" width="49%" alt="Seis especialistas de IA locales: médica, apoyo psicológico, ingeniero, supervivencia, traductora y bibliotecario" />
  <img src=".github/media/asistente.png" width="49%" alt="Vera responde una pregunta de RCP con la guía offline — funciona incluso sin modelo cargado" />
</p>

---

## Instalar Nuvok

La app se instala **ligera**; el contenido pesado (IA, mapas, enciclopedia)
lo eliges después según tu equipo y tu región.

### 🖥 macOS (Apple Silicon)

1. Descarga `Nuvok.dmg` desde [nuvok.org](https://nuvok.org) y verifica el
   SHA-256 publicado junto al enlace.
2. Arrastra **Nuvok** a Aplicaciones.
3. La primera vez: clic derecho → **Abrir**.

### 🤖 Android

1. Descarga el `.apk` desde [nuvok.org](https://nuvok.org) (o recíbelo de
   alguien que ya tenga Nuvok, ver abajo).
2. Ábrelo y permite "instalar apps de origen desconocido" cuando Android lo
   pida.

**¿Sin internet?** Cualquier teléfono Android con Nuvok puede pasarte la app:
en el otro equipo, **Depósito → Pasar Nuvok a otro teléfono** crea una página
en la red WiFi local (sirve un hotspot sin datos) desde la que tú descargas
el APK. Así se propaga durante un apagón.

### 📱 iPhone

Nuvok todavía no está en la App Store (ver [Licencia](#licencia)); hoy se
instala compilándola tú, con una Mac:

1. Instala [Xcode](https://apps.apple.com/app/xcode/id497799835) (gratis) y
   [Flutter](https://docs.flutter.dev/get-started/install/macos).
2. Clona este repositorio y compila el motor de IA (una sola vez):

   ```bash
   git clone --depth 1 https://github.com/scottorellana/nuvok.git
   cd nuvok && ./scripts/bootstrap.sh   # deps + llama.cpp + motores
   ./scripts/build_llm_ios.sh           # motor de IA para iPhone (Metal)
   ./scripts/build_native_ios.sh        # descompresor de la biblioteca
   ```

3. Conecta tu iPhone y ejecuta `flutter run --release`. Xcode te pedirá
   iniciar sesión con tu Apple ID para firmar (la cuenta gratuita sirve;
   con ella la app caduca a los 7 días y se reinstala igual de rápido).
4. En el iPhone: Ajustes → General → VPN y gestión de dispositivos →
   confía en tu certificado de desarrollador.

Requisitos: iOS 13 o más nuevo. Funciona verificado en hardware real.

### 🪟 Windows / 🐧 Linux

Compilan en CI y la IA usa `llama-server` como proceso local; aún están
pendientes de verificación en hardware real. Instrucciones en
[CONTRIBUTING.md](CONTRIBUTING.md).

---

## 🧠 IA local en tu iPhone, paso a paso

Sin nube, sin cuenta, sin API key: el modelo corre en el chip de tu teléfono
y **nada de lo que preguntas sale del dispositivo**.

1. Abre Nuvok y toca **Asistente IA** en la barra inferior.
2. Toca **Descargar**. No necesitas saber de modelos: la app mide la memoria
   de tu equipo y elige sola el mejor que aguanta.
3. Espera la descarga con WiFi (0.5–3.4 GB según tu equipo; se verifica con
   SHA-256 y se reanuda si se corta). **Esta es la única vez que se necesita
   internet.**
4. Listo. Activa el modo avión y pregunta: los especialistas responden usando
   además tus guías offline como fuentes citadas.

Qué esperar según tu equipo:

| Tu equipo | Modelo que la app elige | Descarga | Cómo responde |
|---|---|---|---|
| iPhone con 8 GB de RAM (15 Pro o más nuevo) y Macs | Gemma 4 E2B | 3.4 GB | Nivel especialista, ~100 tokens/s medidos en un 15 Pro |
| La mayoría de iPhones y Androids recientes | Qwen 2.5 1.5B | 1.1 GB | Coherente y útil |
| Equipos con poca memoria | Qwen 2.5 0.5B | 0.5 GB | Básico: respuestas cortas, guías literales |

En **Depósito → Modelos** puedes instalar otros (cada uno muestra su licencia
antes de descargar). Los mismos pasos funcionan en Android y macOS.

---

## Primeros pasos después de instalar

En **📦 Depósito** eliges tu paquete de supervivencia — antes de necesitarlo:

- **Tu mapa**: 58 países disponibles, o recorta cualquier región del mundo.
- **Wikipedia médica** en tu idioma, y más libros del catálogo Kiwix.
- **Tu modelo de IA** (ver arriba).

Todo queda en una carpeta portable `Nuvok/` (`zim/`, `maps/`, `models/`,
`mesh/`, `notes/`): cópiala por USB a otro dispositivo con Nuvok y tu
biblioteca viaja contigo, sin descargar nada dos veces.

## ¿Y cuando no hay internet?

Todo lo anterior sigue funcionando — ese es el punto. Además, la pestaña
**Comunicación** conecta los teléfonos cercanos entre sí por Bluetooth y WiFi
local formando una malla: chat cifrado por canal (AES-256-GCM), posiciones
del grupo en el mapa, y un **SOS** que salta de teléfono en teléfono, se
guarda y se reenvía a quien aparezca después — sin que nadie tenga señal.
Los detalles y límites honestos del cifrado están en
[SECURITY.md](SECURITY.md).

## ¿Comprar o compilar?

Las dos opciones son legítimas:

- **Comprar en [nuvok.org](https://nuvok.org)** te da los binarios oficiales
  firmados, actualizaciones y descargas rápidas de paquetes — y financia el
  proyecto.
- **Compilarla tú** es gratis y siempre lo será: el código completo está aquí
  bajo GPL. Instrucciones en [CONTRIBUTING.md](CONTRIBUTING.md).

La app también puede revisar si hay versión nueva cuando detecta internet
(nunca se actualiza sola ni bloquea el uso offline), y
`node installer-server/server.js` levanta un instalador en tu red WiFi local
para repartir la app y el contenido ya descargado a los demás dispositivos de
la casa.

## Desarrollo — desde cero en 3 comandos

```bash
git clone --depth 1 https://github.com/scottorellana/nuvok.git
cd nuvok && ./scripts/bootstrap.sh
flutter run -d macos
```

`bootstrap.sh` lo hace todo: dependencias, motores nativos (IA local con
Metal incluida) y la suite de verificación (569 tests). Requisitos: Flutter
y, en macOS, cmake. En Linux: `flutter run -d linux` (la IA usa un
`llama-server` del sistema). Android: `flutter build apk` tras el bootstrap.

Guía completa (y el CLA) en [CONTRIBUTING.md](CONTRIBUTING.md) ·
vulnerabilidades en [SECURITY.md](SECURITY.md).

## Licencia

Copyright © 2026 Scott Orellana.

Nuvok es software libre bajo la **[GNU General Public License v3](LICENSE)**.
Puedes usarlo, estudiar su código, modificarlo y redistribuirlo bajo esos
mismos términos. Se entrega **sin ninguna garantía**.

Que el código sea abierto es deliberado: una app que promete que nada sale de
tu dispositivo debe poder demostrarlo. Cualquiera puede auditar el cifrado de
la malla y verificar que la IA corre local. La GPL además asegura que las
mejoras de la comunidad vuelvan a la comunidad.

**Vender binarios es compatible con la GPL.** Nuvok se compra en nuvok.org;
la licencia obliga a entregar el código fuente a quien reciba el binario, no
a regalar el binario.

Una consecuencia a tener presente: la GPL v3 es **incompatible con la App
Store de Apple** (sus términos imponen restricciones de uso que la GPL
prohíbe). Nuvok se distribuye directo desde el sitio, así que no aplica hoy.
Para publicar en la App Store, el titular del copyright puede usar doble
licencia sin dejar de mantener este repositorio en GPL — por eso las
contribuciones piden un CLA (ver [CONTRIBUTING.md](CONTRIBUTING.md)).

Nuvok incorpora trabajo de terceros con sus propias licencias —
[llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT),
[zstd](https://github.com/facebook/zstd) (BSD), modelos Apache 2.0, el
catálogo de [Kiwix](https://kiwix.org) (CC BY-SA) y mapas de
[Protomaps](https://protomaps.com)/OpenStreetMap (ODbL). Los avisos que esas
licencias exigen están en [NOTICE.md](NOTICE.md) y dentro de la app, en
Ajustes → Créditos y licencias.

El contenido descargable (mapas, enciclopedia, modelos) **no es de Nuvok** y
conserva su licencia original: la GPL cubre el código, no ese material.

Inspirada en [Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad)
(Apache 2.0), repensada de servidor Docker a app nativa.

### Marca

«Nuvok», su logo y nuvok.org **no** forman parte de la licencia: identifican
las compilaciones oficiales. Un fork puede usar todo el código bajo la GPL,
pero debe distribuirse con otro nombre y otro logo. Es la misma regla de
Firefox o Grafana: el código es libre; la confianza en el nombre, no.
