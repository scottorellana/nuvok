# 📦 Guía de instalación de Prepper Pad

**Prepper Pad** es tu biblioteca de conocimiento que funciona **sin internet**:
Wikipedia completa, charlas TED con video, mapas de tu país, asistente de
inteligencia artificial y notas — todo dentro de una sola app.

Internet solo se necesita **una vez**: para instalar y descargar el contenido
que quieras. Después, todo funciona para siempre sin conexión.

---

## Antes de empezar: ¿de dónde descargo la app?

Todos los instaladores se descargan de la página de **Releases** del proyecto:

```
https://github.com/scottorellana/prepper-pad/releases
```

Descarga el archivo que corresponda a tu dispositivo según la tabla:

| Tu dispositivo | Archivo a descargar |
|---|---|
| Mac (Apple Silicon o Intel) | `PrepperPad.dmg` |
| Windows 10 u 11 | `prepper-pad-windows-x64.zip` |
| Linux (PC normal) | `prepper-pad-linux-x64.tar.gz` |
| Raspberry Pi 4 o 5 | `prepper-pad-linux-arm64.tar.gz` |
| Tablet o teléfono Android | `app-release.apk` |

---

## 🍎 Mac

1. Descarga `PrepperPad.dmg` y ábrelo con doble clic.
2. Arrastra **Prepper Pad** a la carpeta **Aplicaciones**.
3. **Solo la primera vez:** haz clic derecho sobre la app → **Abrir** → **Abrir**.
   (Esto es porque la app aún no está firmada por Apple; solo se pide una vez.)
4. Listo. La app crea tu carpeta `PrepperPad` automáticamente.

*Los videos, el audio y los mapas funcionan directamente.*

---

## 🪟 Windows

1. Descarga `prepper-pad-windows-x64.zip`.
2. Clic derecho → **Extraer todo…** a la carpeta que quieras
   (por ejemplo `C:\PrepperPad`).
3. Abre la carpeta y haz doble clic en **prepper_pad.exe**.
4. (Opcional) Clic derecho sobre el .exe → **Anclar a la barra de tareas**
   para tener el ícono siempre a mano.

*Si un video no reproduce, instala "WebView2 Runtime" de Microsoft (gratis,
viene incluido en Windows 11 y en la mayoría de Windows 10).*

---

## 🐧 Linux (PC)

1. Descarga `prepper-pad-linux-x64.tar.gz`.
2. Extrae y ejecuta:

```bash
tar -xzf prepper-pad-linux-x64.tar.gz
cd prepper-pad-linux-x64
./prepper_pad
```

3. Requisitos (una sola vez): `sudo apt install libgtk-3-0 libzstd1 liblzma5`

*Para ver videos: dentro de un libro, toca el botón ▶️ de la barra superior
("Ver con videos en el navegador") — se abre en tu navegador usando el mismo
contenido offline, sin internet.*

---

## 🍓 Raspberry Pi 4 / 5

Igual que Linux, pero con el archivo ARM:

```bash
tar -xzf prepper-pad-linux-arm64.tar.gz
cd prepper-pad-linux-arm64
./prepper_pad
```

Recomendaciones para la Pi:
- **Pi 5 con 8GB** y disco SSD/NVMe si vas a guardar mucho contenido.
- Raspberry Pi OS de 64 bits (el estándar actual).
- Los videos se ven con el botón ▶️ (se abren en Chromium, que la Pi ya trae).
- La IA en la Pi funciona solo con modelos pequeños (1–3B) y responde lento —
  es la limitación del hardware, no de la app.

*(Opcional avanzado: para que la Pi arranque directo mostrando Prepper Pad en
una pantalla táctil, o emita su propia red WiFi para que otros dispositivos se
conecten a su contenido, pídemelo y lo configuramos como fase aparte.)*

---

## 🤖 Tablet o teléfono Android

1. Descarga `app-release.apk` **desde el navegador del dispositivo Android**.
2. Toca el archivo descargado.
3. Android preguntará si permites instalar apps de esta fuente → **Permitir**
   (es normal: la app no está en Play Store, igual que muchas apps legítimas).
4. Toca **Instalar** y abre Prepper Pad desde tu pantalla de inicio.

Notas de Android:
- Biblioteca (con videos), mapas y notas funcionan.
- El asistente de IA todavía no está disponible en Android (en desarrollo).

---

## 📚 Cargar contenido (una sola vez, con internet)

Abre Prepper Pad → módulo **Depósito**:

- **Biblioteca**: busca "wikipedia", "medicina", "ted", "supervivencia"… y toca ⬇️.
  El catálogo tiene miles de colecciones en español y otros idiomas.
- **Modelos IA**: elige uno según tu equipo (la app te avisa si es muy grande).
- **Mapas**: sigue las instrucciones de la pestaña Mapas para descargar tu país.

Las descargas se reanudan solas si se corta la conexión.

---

## 🔄 Copiar tu biblioteca a otro dispositivo (sin internet)

Todo tu contenido vive en **una sola carpeta** llamada `PrepperPad`:

| Sistema | Dónde está |
|---|---|
| Mac / Linux / Pi | `/home/tu-usuario/PrepperPad` (en Mac: `/Users/tu-usuario/PrepperPad`) |
| Windows | `C:\Users\tu-usuario\PrepperPad` |
| Android | Carpeta `PrepperPad` del almacenamiento interno |

Para llevar tus 50GB de Wikipedia a la Pi o a la tablet **sin volver a
descargarlos**: copia la carpeta `PrepperPad` completa por USB (o con la app
gratuita LocalSend entre dispositivos en la misma WiFi) y pégala en la
ubicación equivalente del otro dispositivo. Al abrir la app, todo tu contenido
aparece listo.

```
PrepperPad/
├── zim/      ← Wikipedia, TED, libros (.zim)
├── maps/     ← mapas offline (.pmtiles)
├── models/   ← modelos de IA (.gguf)
└── notes/    ← tus notas (.md)
```

---

## ❓ Problemas frecuentes

| Problema | Solución |
|---|---|
| macOS dice "no se puede abrir" | Clic derecho → Abrir (solo la primera vez) |
| Un libro aparece "dañado o incompleto" | La copia/descarga se interrumpió — vuelve a copiarlo o descargarlo |
| El mapa se ve raro o vacío | Botón ⟳ del módulo Mapas (limpia la caché) |
| La IA dice "memoria ajustada" | Cierra otras apps o usa un modelo más pequeño |
| Video no reproduce en Linux/Pi | Usa el botón ▶️ "Ver con videos en el navegador" |

---

## Estado por dispositivo

| Dispositivo | Estado |
|---|---|
| Mac (Apple Silicon) | ✅ Verificado por completo, incluyendo videos TED y mapa de Honduras |
| Windows / Linux / Pi / Android | 🏗️ Instaladores generados automáticamente — pendientes de prueba en hardware real; reporta cualquier problema |
| iPhone / iPad | ❌ Por ahora no (Apple exige cuenta de desarrollador de pago) |
