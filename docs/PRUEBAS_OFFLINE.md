# Primeras pruebas de comunicación offline

Cómo probar **Prepper Mesh** (el chat/SOS/posición sin internet) entre dos
dispositivos. No se necesita señal de datos ni que el WiFi tenga internet.

## Qué necesitas

- **Dos dispositivos** con Prepper Pad instalado (ej. tu Mac + la tablet
  Android, o dos tablets). Un solo equipo NO sirve para la prueba: dos copias
  en la misma máquina comparten identidad y no se "ven".
- **Una red WiFi en común** — y aquí está la clave: **el router NO necesita
  internet**. Sirve cualquiera de estas:
  - El WiFi de tu casa (aunque le desconectes el internet).
  - El **punto de acceso (hotspot) de un teléfono**, sin plan de datos activo.
  - Un router de viaje sin cable de internet conectado.

> El mesh usa WiFi como "cable invisible" entre los aparatos. El internet
> nunca entra en juego.

## Paso a paso

### 1. Conecta ambos dispositivos a la misma WiFi
Aunque no tenga internet. Verifica que los dos digan que están conectados a
la **misma red** (mismo nombre de WiFi).

### 2. En cada dispositivo: abre **Comunicación** y ponte un nombre
La primera vez te pide un nombre (ej. "Papá", "Base", "Scott"). Escríbelo y
guarda. Cada aparato debe tener un nombre distinto para reconocerse.

### 3. Verifica que se descubren
En unos segundos, arriba debería aparecer **"1 cerca"** (o el número de
aparatos que estén en la red). Si dice "0 cerca", ver *Si no se ven* abajo.

### 4. Prueba el chat cifrado
- En un aparato: **Crear canal** → nombre "Familia" (o el que quieras).
- Comparte el canal con el otro aparato: toca el **código / QR** y en el otro
  aparato usa **Unirse** → escanea el QR o escribe el código `PPMESH1…`.
- Escribe un mensaje. Debe llegar al otro en 1–2 segundos.

### 5. Prueba el SOS
- Toca el botón rojo **SOS**. En el otro aparato debe saltar una **alerta a
  pantalla completa** con tu nombre y, si tienes GPS, tu ubicación.
- El SOS se repite cada minuto hasta que lo cancelas.
- Toca **"Ver en mapa"** en la alerta: te lleva al mapa centrado en quien
  pidió ayuda.

### 6. Prueba compartir ubicación
- Activa **compartir posición**. En el otro aparato, abre **Mapas**: verás un
  punto con el nombre del compañero, que se actualiza cada par de minutos.

### 7. Canal EMERGENCIA (siempre abierto)
No hace falta unirse: el canal **EMERGENCIA** lo escuchan todos los Prepper
Pad cercanos automáticamente. Un SOS ahí llega a cualquiera en rango, aunque
no compartan un canal privado.

## Prueba extra: sin ningún WiFi (aparato-a-aparato)

En dos tablets Android, el mesh también intenta **Bluetooth** y **WiFi
Direct** (sin ningún router). Es más lento en descubrir (10–30 s) pero no
necesita ni hotspot. Acepta los permisos de Bluetooth / dispositivos cercanos
cuando la app los pida la primera vez.

## Si no se ven ("0 cerca")

1. Confirma que **ambos están en la misma WiFi** (mismo nombre exacto).
2. Algunos WiFi públicos/hoteles tienen **"aislamiento de clientes"** que
   bloquea que los dispositivos se hablen entre sí → usa el hotspot de un
   teléfono.
3. En Android, acepta los permisos de **ubicación y dispositivos cercanos**
   (hacen falta para descubrir por WiFi/Bluetooth).
4. Cierra y reabre la pestaña **Comunicación** en ambos.
5. Si uno está en Mac y otro en tablet, asegúrate de que el firewall del Mac
   no bloquee la app (Ajustes → Red → Firewall).

## Qué se prueba de fondo

- **Cifrado**: cada canal usa una clave AES-256 propia; sin el código/QR nadie
  lee tus mensajes.
- **Reenvío (mesh)**: si tres aparatos están en línea, el del medio reenvía
  los mensajes para ampliar el alcance.
- **Guardar-y-enviar**: si escribes cuando el otro está fuera de rango, el
  mensaje sale solo en cuanto vuelve a aparecer.
