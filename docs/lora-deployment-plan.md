# Plan técnico de deployment LoRa — Prepper Pad

> Objetivo: dejar 3–5 dispositivos LoRa listos para producción (conectados a Prepper Pad en Android) para comunicación offline de largo alcance en Honduras (915 MHz).
>
> Estado del código: el *seam* del driver (`LoraLinkDriver`), fragmentación/reassembly (`LoraFrame`, `LoraReassembler`) y el transporte (`LoraTransport`) ya están implementados en `lib/modules/mesh/lora_transport.dart` y verificados a nivel pruebas unitarias con un *fake driver*. Falta el **driver físico** (USB serial + BLE UART), la selección de hardware, el firmware del radio y la validación de campo.

---

## 0. Contrato del driver (resumen del código existente)

Cualquier driver real debe implementar `LoraLinkDriver`:

```dart
abstract class LoraLinkDriver {
  bool get available;                       // true solo con radio válido y handshake OK
  Future<bool> open();                      // abrir USB serial / BLE UART + handshake
  Future<void> close();
  Future<bool> writeFrame(Uint8List frame); // un frame <= loraMaxFrameSize (230 B)
  Stream<Uint8List> get onFrame;            // frames entrantes crudos
}
```

Constantes relevantes:

- `loraMaxFrameSize = 230` bytes (ceiling de payload a nivel radio, con margen para headers de firmware).
- Header interno de Prepper Pad: 4 bytes (`[flags][seq 24-bit BE]`), payload útil por frame = **226 bytes**.
- `LoraTransport` ya se suscribe a `onFrame` **antes** de `open()` (importante: el driver puede emitir bytes encolados al abrir el puerto).
- `LoraTransport.send()` fragmenta y escribe frame a frame; aborta el datagrama si `writeFrame` devuelve `false`.
- `LoraLinkKind { usbSerial, bleUart }` — el driver debe declarar su tipo.

**Regla de oro de seguridad**: `available` debe quedar `false` hasta que el radio haya pasado el *checklist de campo* (sección 6). Esto ya está reflejado en `docs/offline_comms_production_protocol.md`.

---

## 1. Selección de hardware recomendado

### 1.1 Criterios

| Criterio | Peso | Notas |
| --- | --- | --- |
| Banda soportada | Crítico | Debe operar en **915 MHz ISM** (Honduras). |
| Conectividad al Android | Crítico | USB-C CDC-ACM/serial **o** BLE UART. |
| Cadena de suministro | Alto | Disponible en EE. UU. / importable a Honduras sin licencia especial. |
| Firmware actualizable | Alto | USB/OTA flasheable desde un dev box. |
| Consumo en RX | Medio | Para dispositivo de bolsillo alimentado por power bank. |
| Antena SMA | Medio | Para usar antena externa de mayor ganancia. |

### 1.2 Recomendación: **dispositivo completo con Meshtastic firmware** (no módulo suelto)

**Decisión**: usar **nodos completos basados en SX1262/SX1276** corriendo **firmware Meshtastic** (que expone una interfaz serial/BLE ya probada), en lugar de integrar un módulo LoRa crudo contra un MCU propio.

Justificación:

1. **Accesor novedoso**: Meshtastic ya resuelve radio config, channel mapping, PKI por canal, y expone una API serial (protobuf sobre USB CDC) y BLE GATT UART (`c220e35c-...`). Implementamos un driver cliente, no un stack de radio.
2. **Certificación por módulo**: los módulos Semtech/Heltec vienen pre-certificados (FCC/CE). El producto final hereda el *modular approval* del fabricante, reduciendo el esfuerzo de certificación CONATEL (ver sección 7).
3. **Soporte y comunidad activa** (firmware en C++ sobre RadioLib).
4. **Interoperabilidad futura** con redes Meshtastic existentes.

### 1.3 Hardware específico recomendado (3–5 unidades)

| Rol | Modelo recomendado | Chip | Precio aprox. USD | Notas |
| --- | --- | --- | --- | --- |
| Nodo de campo (bolsillo) | **Heltec LoRa 32 V3** o **LILYGO T-Beam Supreme** | SX1262 | $30–$45 | WiFi/BLE integrados, pantalla OLED, batería LiPo, USB-C. BLE UART para emparejar con Android sin cable. |
| Nodo repetidor / base fija | **RAK WisBlock RAK4631 + RAK19007** o **LILYGO T-Echo** | SX1262 | $35–$60 | Bajo consumo, ideal para nodo solar 24/7 (store-and-forward persistente). |
| Nodo gateway de clínica (opcional) | **Meshtastic Station / n5105 base** | SX1262 | $70–$90 | Alimentación continua, antena externa de 5.8 dBi. |

**Antenas**: una antena 915 MHz de **3 dBi (rubber duck)** por defecto para nodo móvil; **5.8–8 dBi omnidireccional con cable coaxial corto** para el repetidor fijo. Coaxial de bajas pérdidas (LMR-100/240, no más de 2 m). Evitar antenas de 433/868 MHz que desintonizan.

**Alimentación**: power bank USB-C de 10 000 mAh por nodo móvil; panel solar de 5–10 W + carga TP4056/LiPo de 18650×2 para el repetidor.

**Lista de compra recomendada (4 nodos)**:
- 2 × Heltec LoRa 32 V3 (nodos móviles)
- 1 × LILYGO T-Echo (nodo repetidor de bajo consumo)
- 1 × RAK4631 + RAK19007 (nodo base de clínica)
- 4 × antena 915 MHz 3 dBi SMA-M, 1 × antena 915 MHz 5.8 dBi omnidireccional
- 4 × cable SMA (adaptador a antena externa)
- 4 × power bank 10 000 mAh USB-C, 1 × panel solar 10 W + batería 18650×2

### 1.4 Por qué NO módulo suelto (RFM95/SX1276 en breadboard)

- Requiere MCU (ESP32/STM32) y desarrollo de firmware desde cero (RadioLib + protocolo MAC).
- Sin certificación heredada: aumenta trámite CONATEL.
- Mayor riesgo de errores de RF (matching de antena, blindaje).
- Mayor tiempo de desarrollo (estimación +6–10 semanas).

Se deja como *fallback* solo si la cadena de suministro de Meshtastic falla o si se necesita un factor de forma custom.

---

## 2. Implementación del driver real para Android

Dos transportes a implementar como clases concretas que implementan `LoraLinkDriver`:

- `UsbSerialLoraLinkDriver` (`LoraLinkKind.usbSerial`)
- `BleUartLoraLinkDriver` (`LoraLinkKind.bleUart`)

Ambos envuelven el protocolo del firmware (Meshtastic serial/protobuf o BLE UART) y exponen el *frame stream* binario que `LoraTransport` ya sabe consumir.

### 2.1 Opción preferida: USB serial via `flutter_usb_serial`

Paquete recomendado: **`flutter_usb_serial`** (Android, CDC-ACM). Alternativa: **`usb_serial`** (más mantenimiento activo, soporta FTDI/CH34x/CP210x).

Flujo del driver:

1. **Enumeración y permisos** (`onDeviceAttached`/`requestPermission`).
   - Filtrar por USB VID/PID del nodo Meshtastic (ej. Heltec V3 expone un CDC composite). Permitir al usuario seleccionar dispositivo si hay varios.
2. **`open()`**:
   - Pedir permiso USB al usuario (diálogo nativo de Android).
   - Abrir puerto CDC a **115200 baud** (config Meshtastic por defecto).
   - Realizar **handshake del firmware** (sección 4): enviar `wantConfigId` y leer `MyNodeInfo`/`RadioConfig`.
   - Habilitar notificaciones de `onFrame`.
3. **`writeFrame(frame)`**:
   - Encapsular el *frame* de Prepper Pad en un **`MeshPacket`** de Meshtastic dirigido al canal apropiado, serializarlo como protobuf, y escribirlo al CDC como mensaje `ToRadio`.
   - Devolver `false` si el FIFO del radio está lleno (el firmware responde con error de *queue full*); `LoraTransport` aborta el datagrama, que será reintentado por el outbox store-and-forward.
4. **`onFrame`**:
   - Stream que publica cada `MeshPacket` recibido (mensaje `FromRadio` con `packet.decoded.payload`) como `Uint8List` directo (el payload es ya el datagrama `MeshEnvelope` de Prepper Pad).
5. **`close()`**: cerrar puerto CDC, liberar el USB.

**Consideraciones Android**:
- Requiere permiso `android.permission.USB_PERMISSION` gestionado en runtime.
- El dispositivo Android debe ser **host USB** (OTG). La mayoría de tablets/phones Android modernos lo soportan via USB-C.
- `android.hardware.usb.host` feature en el manifest.
- Cuando el cable se desconecta, capturar `onDeviceDetached` → marcar `available = false` y propagar a `LoraTransport.stop()`.
- Modo OTG puede consumir batería del teléfono; ofrecer BLE como alternativa.

### 2.2 Alternativa: BLE UART

Usar **`flutter_blue_plus`** (rama activa) o **`flutter_reactive_ble`**.

Servicio/characteristic estándar Meshtastic (BLE):
- Service: `6ba1b218-15a8-461f-9faf-13720efc07f3`
- Characteristic **TX (to radio)**: `f75c76d2-129e-4dad-a1dd-78d6d4c5344f` (write/write-no-response)
- Characteristic **RX (from radio)**: `2c55ab69-92cc-4e3b-9ebc-7e9b5f8b7b60` (notify)

Flujo:

1. **Scan** por nombre/service UUID del nodo Meshtastic.
2. **Connect** (incluye `mtu = 247` request para mejorar throughput; Meshtastic fragmenta paquetes grandes con *Tap`/`BTP`*).
3. **Enable notifications** en la característica RX.
4. **`open()`** = connect + MTU + handshake `wantConfigId`.
5. **`writeFrame`** = escribir paquete protobuf a la característica TX; Meshtastic requiere fragmentación del payload en tramos de `MTU-3` con header `0x1A 0x1D` (BLE frame) — implementar helper `BleMeshtasticFramer`.
6. **`onFrame`** = notificaciones RX, re-ensambladas con el mismo helper.

Ventajas BLE: sin cable, menor consumo, multi-nodo fácil. Desventajas: throughput menor, MTU limita frames grandes (Prepper Pad ya fragmenta a 226 B así que es manejable), emparejamiento.

### 2.3 Estructura de código propuesta

```
lib/modules/mesh/lora/
  lora_link_driver.dart         (re-export del seam existente)
  meshtastic/
    meshtastic_pb.dart          (stubs protobuf o dependencia opcional)
    meshtastic_serial.dart      (encoders/decoders ToRadio/FromRadio)
  usb_serial_lora_link_driver.dart
  ble_uart_lora_link_driver.dart
  lora_driver_factory.dart      (resuelve USB vs BLE segun disponibilidad)
```

`LoraTransport` se queda tal cual; solo se inyecta el driver concreto:

```dart
final driver = await LoraDriverFactory.resolve(); // USB primero, BLE fallback
final transport = LoraTransport(link: driver, kind: driver.kind, portName: driver.id);
```

### 2.4 Manejo de errores y fiabilidad del driver

- **Reconexión automática**: si `writeFrame` falla 3 veces consecutivas o `onFrame` se cierra, intentar `close()` + `open()` con backoff (1s, 2s, 4s, 8s, tope 30s).
- **Detección de desconexión USB/BLE** debe poner `available = false` inmediatamente para que el mesh no intente enviar por LoRa y el usuario vea "LoRa no conectado".
- **Timeout de handshake** (sección 4): si en 3 s no llega respuesta, considerar radio no válido.
- **Logs**: emitir eventos `loraDriverState` (conectando/listo/error) al logger de diagnósticos existente de Prepper Pad, para depuración de campo.

---

## 3. Configuración de radio

Configuración objetivo para Honduras (legal y robusta). Todos los parámetros viven en el firmware (Meshtastic `RadioConfig`); se aplican al hacer provisioning.

### 3.1 Banda y canal

| Parámetro | Valor | Justificación |
| --- | --- | --- |
| Frecuencia central | **915.0 MHz** | Banda ISM de Honduras (CONATEL alinea con Región 2 / FCC Part 15). |
| Rango de subcanales | 902–928 MHz | FHSS legal; Meshtastic usa *channel* index + offset. |
| Channel spacing | 915 MHz preset Meshtastic `LongFast` modificado | Conservar *spreading* rápido para baja latencia de SOS. |
| Ancho de banda | **250 kHz** | Compromiso: velocidad vs. sensibilidad. |
| Spreading Factor | **SF7** (default), **SF9** si se necesita más alcance | SF7 = ~1 km urbano; SF9/BW125 = ~3–5 km LOS. |
| Coding Rate | **4/5** | Buen balance; 4/8 para enlaces malos. |
| TX Power | **20 dBm (100 mW)** máximo legal EIRP | Meshtastic SX1262 soporta 22 dBm pero el techo regulatorio Honduras es 30 dBm EIRP; se recomienda 20 dBm para consumo/batería. |
| Preamble length | 8 símbolos (default) | Compatibilidad entre nodos. |
| LDR (adaptive rate) | Off (fijar SF/BW/CR) | Para que todos los nodos se oigan siempre (SOS no puede depender de negotiation). |
| Sync word | 0x2B (public) | Compatible con otros Meshtastic. Usar 0x2A/custom si se quiere privacidad mínima. |

### 3.2 Configuración específica por rol

| Nodo | SF | BW | CR | TX | Notas |
| --- | --- | --- | --- | --- | --- |
| Nodo móvil (Heltec) | SF7 | 250 | 4/5 | 17 dBm | Batería; antena 3 dBi. |
| Repetidor fijo (T-Echo/RAK) | **SF9** | 125 | 4/8 | 20 dBm | Maximiza alcance del store-and-forward. |
| Base clínica | SF9 | 125 | 4/8 | 20 dBm | Antena externa 5.8 dBi. |

⚠️ **SF/BW deben coincidir entre nodos que se comunican directamente**. Para la topología propuesta:

- Topología A (rápida, urbano): todos SF7/250 → latencia baja, ~1 km.
- Topología B (extendida): todos SF9/125 → alcance mayor, ~3–5 km, mayor latencia.

Recomendado **empezar con A** (todos iguales, más simple) y migrar a B si las pruebas de 500 m fallan.

### 3.3 Consideración sobre *duty cycle* y LBT

- 915 MHz en Región 2 **no tiene límite de duty cycle** (a diferencia de 868 MHz en Europa), pero Meshtastic aplica *Listen-Before-Talk* (LBT) por defecto.
- Keep interval de beacon de Prepper Pad: dejar el valor actual (~10 s) — está bien dentro del aire legal.

### 3.4 Criptografía de canal (capa radio)

Meshtastic soporta canales encriptados AES-128 por *channel*. Prepper Pad ya cifra `MeshEnvelope` con AES-256-GCM encima. **Doble cifrado OK** (no se anulan). Configuración Meshtastic:

- **PRIMARY channel**: nombre `ppmesh`, clave compartida fuera de banda (se carga en provisioning). Es el canal donde viajan los datagramas Prepper Pad.
- **No exponer `EMERGENCIA`** como canal Meshtastic secundario plaintext; el plaintext ya está dentro del `MeshEnvelope`, no hace falta exponerlo en otra capa radio.

---

## 4. Protocolo de handshake al conectar radio

El *handshake* verifica que el radio está vivo, configurado correctamente y listo para transportar frames. Ocurre dentro de `open()` del driver y **antes** de marcar `available = true`.

### 4.1 Secuencia (USB serial, Meshtastic)

```
Android ───(USB CDC)───► Radio (Meshtastic)

1.  Android → Radio:  ToRadio { wantConfigId = 0x... (nonce) }
2.  Radio → Android:  FromRadio { configCompleteId = mismo nonce }
3.  Radio → Android:  FromRadio { myNodeInfo { ... } }            ← aquí se valida banda/SF
4.  Radio → Android:  FromRadio { radioConfig { ... } }           ← validar vs. sección 3
5.  Android → Radio:  ToRadio { meshPacket { text "PPHANDSHAKE" } }
6.  Radio → Android:  FromRadio { meshPacket { text "PPHANDSHAKE_OK" } }  ← eco round-trip
```

**Criterios de éxito (todos obligatorios)**:

| # | Check | Acción si falla |
| --- | --- | --- |
| 1 | `configCompleteId` coincide con nonce enviado en < 3 s | Marcar `available=false`, reintentar 1 vez, luego error. |
| 2 | `myNodeInfo.num` válido (node id > 0) | Lo mismo. |
| 3 | `radioConfig` tiene `region = US915`, SF/BW/CR/TX según sección 3 | Enviar `setRadio` con la config correcta y re-pedir; si sigue mal, error. |
| 4 | El texto de eco `PPHANDSHAKE_OK` vuelve en < 8 s (un salto de radio) | Reintentar 1 vez; si no, marcar como radio con falla de RF. |
| 5 | Versión de firmware ≥ mínima soportada (ej. ≥ 2.2.x) | Marcar error de versión y ofrecer flash (en app de provisioning). |

### 4.2 Secuencia (BLE UART)

Igual conceptualmente, pero `wantConfigId` viaja por la característica TX con fragmentación BLE. El eco `PPHANDSHAKE` valida también que el reensamblado BLE funciona.

### 4.3 Estado del driver después del handshake

- `available = true`.
- Suscripción a notificaciones/lectura CDC ya activa **antes** de completar el handshake (porque Meshtastic emite `FromRadio` eventos async).
- Enviar **beacon de Prepper Pad** inmediatamente para que el mesh descubra el nodo LoRa.

### 4.4 Diagnóstico visible para el usuario

En la UI de "Comunicación (sin internet)" agregar un estado de LoRa:

- 🔴 **No conectado** — no hay radio USB/BLE.
- 🟡 **Conectando** — handshake en curso.
- 🟢 **Listo** — `available && handshake OK`.
- 🟠 **Error** — handshake falló (mostrar motivo: versión de FW, configuración de banda incorrecta, eco no recibido).

Esto es importante para el objetivo de "uso por persona no técnica" del protocolo de producción.

---

## 5. Testing de campo

Antes de declarar LoRa "listo para producción", ejecutar el siguiente protocolo con **al menos 3 dispositivos** y registrar resultados en `/docs/lora-field-test-log.md`.

### 5.1 Topología de prueba

```
  [A: móvil]  ──USB/BLE──► [Radio 1] ~~~~RF~~~~ [Radio 2] ──USB/BLE──► [B: móvil]
                                                              │
                                              ~~~~RF~~~~ [Radio 3] ──USB/BLE──► [C: repetidor]
```

- 2 nodos móviles + 1 repetidor/configurado como relay.
- Cada Android en **modo avión** con Wi-Fi/Bluetooth **activados para BLE**, datos móviles **desactivados**.
- App Prepper Pad abierta, sin cerrar pantalla (keep awake).

### 5.2 Casos de prueba

| # | Escenario | Distancia / Condiciones | Éxito |
| --- | --- | --- | --- |
| 5.1 | SOS en línea de vista (LOS) | 100 m, exterior | SOS recibido en B en < 10 s con ACK. |
| 5.2 | Chat bidireccional LOS | 100 m | 10 mensajes cada sentido, latencia < 3 s/msg. |
| 5.3 | SOS LOS | 500 m, exterior | SOS recibido en < 15 s. |
| 5.4 | Chat LOS | 500 m | 5 mensajes cada sentido, latencia < 6 s/msg. |
| 5.5 | SOS LOS | 1 km, exterior | SOS recibido (puede requerir repetidor). |
| 5.6 | Obstáculo: 1 pared de concreto | 50 m indoor | SOS + 3 mensajes entregados. |
| 5.7 | Obstáculo: 2 paredes + metal | 30 m indoor | SOS entregado, ACK opcional. |
| 5.8 | **Store-and-forward** | A envía con B apagado; B enciende a los 10 min | Mensaje entregado al reencender (vía repetidor). |
| 5.9 | **Reconexión USB** | Desconectar/reconectar cable | Driver re-handshakea, `available` vuelve a `true` sin reiniciar app. |
| 5.10 | **Reconexión BLE** | Apagar/encender radio | Mismo. |
| 5.11 | Dedup + relay | A→B→C con hop limit 2; C recibe una sola vez | Ver logs del mesh. |
| 5.12 | Consumo batería | 2 h de beacon cada 10 s | < 15 % batería del power bank; app no crashea. |
| 5.13 | Payload grande | Mensaje de 1 KB (multimedia pequeño o posición con notas) | Fragmentación visible en logs, entrega exitosa. |

### 5.3 Métricas a registrar por caso

- RSSI y SNR reportados por el radio (vía `MeshPacket.rxSnr`/`rxRssi`).
- Latencia de round-trip (timestamp del ACK).
- Pérdida de paquetes (%).
- Tiempo hasta primer mensaje exitoso (cold start).

### 5.4 Aceptación para producción

LoRa se declara "listo para producción" solo cuando:

- Casos 5.1–5.8 pasan con **3 dispositivos** en **2 sesiones** de campo distintas.
- 5.9 y 5.10 pasan sin intervención del usuario.
- 5.12 no presenta consumo anormal ni crash.
- RSSI reportado en 1 km ≥ −115 dBm (cerca del floor del SX1262) — si peor, revisar antenas/ubicación.

### 5.5 Equipos de medición recomendados

- App **Meshtastic** oficial en un tercer teléfono, para validar el enlace de radio independientemente de Prepper Pad (aisla problemas de driver vs. radio).
- Teléfonos secundarios para logging con `adb logcat | grep lora`.
- GPS del teléfono para medir distancias reales.

---

## 6. Certificación y regulación (CONATEL, Honduras)

### 6.1 Régimen legal

- La banda **902–928 MHz** es **libre de licencia** en Honduras para equipos de baja potencia, bajo la normativa de CONATEL alineada con la **Región 2 UIT**.
- Honduras exige **homologación** del equipo de radio (tipo de aprobación) antes de uso comercial/operativo, pero para **uso personal o de emergencia sin venta** la práctica habitual es relajada. Prepper Pad en escenarios comunitarios debe, no obstante, cumplir:
  - **EIRP ≤ 30 dBm (1 W)** (FCC Part 15.247 equivalente).
  - Antenas de ganancia moderada, no direccionales de alta ganancia sin ajuste de TX power.
  - Equipos que operen **solo en bandas ISM** y acepten interferencia.

### 6.2 Estrategia de cumplimiento recomendada

1. **Usar módulos/dispositivos pre-homologados** (FCC Part 15.247 y/o IFT México). El Heltec Lora 32 V3 y el RAK4631 tienen certificación FCC; esto facilita cualquier homologación CONATEL por equivalencia técnica.
2. **Documentación técnica** a preparar:
   - Hoja de datos del módulo Semtech SX1262.
   - Certificado FCC del producto (FCC ID).
   - Diagrama de la instalación, antenas y potencias.
   - Descripción de uso (emergencias comunitarias, sin fines comerciales).
3. **Trámite ante CONATEL** (procedimiento de homologación simplificado):
   - Presentar solicitud ante la **Gerencia de Gestión del Espectro** de CONATEL.
   - Pago de tasa (aprox. **HNL 5 000–15 000** según tarifa vigente para equipos de baja potencia).
   - Tiempo estimado: **2–6 semanas**.
4. **Si no hay venta ni instalación permanente**: se puede operar bajo el principio de equipo de uso personal; pero para el proyecto Prepper Pad (despliegue comunitario en clínicas) se recomienda completar la homologación para evitar riesgo.

### 6.3 Recursos

- CONATEL: https://www.conatel.gob.hn — buscar "Homologación de equipos".
- UIT-R Región 2: banda 902–928 MHz, primary mobile except aeronautical.
- FCC Part 15.247: reglas técnicas (potencia, FHSS, LBT).

### 6.4 Privacidad de RF

- La señal LoRa es analógica/digital pero **no cifrada por defecto** salvo el canal Meshtastic. **Prepper Pad ya cifra** los `MeshEnvelope` privados; el canal `EMERGENCIA` es deliberadamente plaintext para que cualquier receptor compatible lo pueda leer (diseño intencional del protocolo).
- Recomendado: cargar clave AES del canal Meshtastic PRIMARY en provisioning y **rotar** periódicamente.

---

## 7. Firmware recomendado para los radios

### 7.1 Firmware principal: **Meshtastic firmware (firmware de Meshtastic Stable)**

- Repo: https://github.com/meshtastic/firmware
- Versión mínima recomendada: **2.2.x** (soporta SX1262, BLE MTU 247, API protobuf estables).
- Flasheo: `meshtastic --flash` desde una PC con Python, o **web flasher** (https://flasher.meshtastic.org) vía Chrome.

**Build targets por dispositivo**:
| Dispositivo | Target Meshtastic |
| --- | --- |
| Heltec LoRa 32 V3 | `heltec-v3` |
| LILYGO T-Beam Supreme | `t-beam` |
| LILYGO T-Echo | `t-echo` |
| RAK4631 + RAK19007 | `rak4631` |

### 7.2 Configuración inicial (provisioning)

Por cada radio, vía la app Meshtastic oficial o CLI:

```
meshtastic --set lora.region US915
meshtastic --set lora.modem_preset LongFast   # SF7/250/4:5
meshtastic --set lora.tx_power 20
meshtastic --set lora.tx_enabled true
meshtastic --ch-set name ppmesh
meshtastic --ch-set key <base64>             # clave canal
meshtastic --set bluetooth.enabled true
meshtastic --set serial.enabled true
meshtastic --set serial.baud 115200
```

Guardar el config en `/docs/lora-radio-config.toml` para re-aplicar.

### 7.3 Firmware alternativo: **custom (RadioLib + PlatformIO)**

Usar **solo si** se necesita:
- Soporte de un módulo no soportado por Meshtastic (raro).
- Protocolo MAC con estampado de tiempo preciso para rangos con TDOA.
- Menor latencia para SOS dedicado.

Stack: ESP32/SX1262 + [RadioLib](https://github.com/jgromes/RadioLib) + un framing propio tipo `[len][flags][seq][payload]` para encajar con `LoraLinkDriver` directamente (sin capa Meshtastic protobuf). Esto duplica el trabajo de la sección 2 y **se desaconseja** salvo requisito fuerte.

### 7.4 Actualizaciones

- Flashear OTA vía Meshtastic (BLE) cuando salga estable 2.3+. Mantener un **change freeze** antes de simulacros/deploy de emergencia.
- Llevar un **changelog de firmware** por radio en `/docs/lora-radio-inventory.md` (MAC, firmware, config aplicada, fecha).

---

## 8. Timeline y presupuesto

### 8.1 Timeline (10 semanas, part-critical path en paralelo)

| Semana | Hito | Entregables |
| --- | --- | --- |
| 1 | **Compra y recepción de hardware** | 4 radios + antenas + accesorios en mano. |
| 1–2 | **Flasheo y provisioning de radios** | 4 nodos con Meshtastic 2.2.x, banda 915, canal `ppmesh`, config TOML guardada. |
| 2–5 | **Implementación driver USB serial** | `UsbSerialLoraLinkDriver` + handshake + integración con `LoraTransport`. Pruebas unitarias con mock. |
| 4–7 | **Implementación driver BLE UART** | `BleUartLoraLinkDriver` + handshake + MTU/framing. |
| 6–7 | **UI de estado LoRa** + diagnóstico | Indicador 🔴/🟡/🟢/🟠, logs. |
| 7–8 | **Pruebas de escritorio** (2 nodos, mesa) | Round-trip OK, fragmentación visible. |
| 8–9 | **Pruebas de campo** (3+ dispositivos) | Casos 5.1–5.8 documentados. |
| 9 | **Trámite CONATEL iniciado** (paralelo desde semana 2) | Solicitud de homologación presentada. |
| 10 | **Hardening + release** | Reconexión robusta, *field checklist* en UI, `/docs/lora-field-test-log.md` firmado. |

Camino crítico: **hardware → driver USB → pruebas de campo**. La paralelización máxima es driver USB + driver BLE a la vez (2 dev-tasks), y CONATEL se arranca en semana 2.

### 8.2 Presupuesto estimado (4 nodos, sin mano de obra de dev)

| Concepto | Cantidad | Unitario USD | Subtotal USD |
| --- | --- | --- | --- |
| Heltec LoRa 32 V3 | 2 | 35 | 70 |
| LILYGO T-Echo | 1 | 55 | 55 |
| RAK4631 + RAK19007 | 1 | 55 | 55 |
| Antena 915 MHz 3 dBi SMA-M | 4 | 8 | 32 |
| Antena 915 MHz 5.8 dBi omni | 1 | 25 | 25 |
| Cables/adaptadores SMA | sur | — | 20 |
| Power banks 10 000 mAh USB-C | 4 | 20 | 80 |
| Panel solar 10 W + control + LiPo 18650×2 | 1 | 50 | 50 |
| Envío/importación Honduras | — | — | 60 |
| Reserva repuestos (1 radio extra) | 1 | 40 | 40 |
| **Subtotal hardware** | | | **487** |
| Homologación CONATEL | | | 300–600 |
| **Total estimado** | | | **~800–1 100 USD** |

Si se compra un quinto nodo, sumar ~$80 (Heltec completo) o ~$90 (RAK). Para 5 nodos completos: **~900–1 200 USD**.

### 8.3 Riesgos y mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
| --- | --- | --- | --- |
| Driver USB serial inestable en tablet Android específica | Media | Alto | Probar en el modelo exacto desde semana 4; fallback BLE. |
| Alcance menor a 500 m por topografía | Media | Alto | Antena externa 5.8 dBi + SF9; repetidor fijo alto. |
| Retraso CONATEL | Media | Medio | Iniciar trámite semana 2; usar FCC equivalente. |
| Cadena de suministro Heltec | Baja | Medio | RAK4631 como drop-in equivalente. |
| Consumo batería mayor a esperado | Media | Bajo | Power bank 20 000 mAh; beacons cada 20 s en vez de 10 s. |
| Interferencia de WiFi del propio Android | Baja | Bajo | Usar canales 915 MHz lejos de armónicos WiFi; cable USB corto. |

---

## 9. Resumen ejecutivo

- **Hardware**: 4 nodos Meshtastic (2 Heltec V3 + 1 T-Echo + 1 RAK4631), banda 915 MHz, antenas SMA. ~$800–1 100 incluyendo homologación.
- **Firmware**: Meshtastic 2.2.x Stable. Sin custom MCU.
- **Driver Android**: `flutter_usb_serial` (preferido) + `flutter_blue_plus` (BLE UART fallback), ambos implementando `LoraLinkDriver`.
- **Radio config**: SF7/BW250/CR4:5 para urbano; SF9/BW125/CR4:8 para alcance extendido. TX 20 dBm. Canal `ppmesh` cifrado.
- **Handshake**: wantConfigId → configCompleteId → validar banda/SF → eco `PPHANDSHAKE_OK`. `available=true` solo al pasar.
- **Campo**: 13 casos de prueba (100 m / 500 m / 1 km / obstáculos / store-and-forward / reconexión). Aceptación: 2 sesiones exitosas con 3 dispositivos.
- **Regulatorio**: Banda libre en Honduras; homologación CONATEL recomendada (~HNL 5–15k, 2–6 semanas). Módulos FCC pre-certificados facilitan trámite.
- **Timeline**: 10 semanas desde compra hasta release.
- **Contrato con el código**: no se modifica `lora_transport.dart` ni `mesh_transport.dart`; solo se añaden drivers concretos y un factory.

---

## Apéndice A — Esqueleto de driver USB serial (referencia)

```dart
class UsbSerialLoraLinkDriver implements LoraLinkDriver {
  UsbSerialLoraLinkDriver(this._portName);
  final String _portName;

  final _onFrame = StreamController<Uint8List>.broadcast();
  UsbPort? _port;
  bool _ready = false;

  @override
  bool get available => _ready;

  @override
  Stream<Uint8List> get onFrame => _onFrame.stream;

  @override
  Future<bool> open() async {
    final dev = await UsbSerial.findDevice(_portName);
    if (dev == null) return false;
    _port = await dev.create(baudRate: 115200);
    if (_port == null) return false;
    _port!.inputStream!.listen(_onSerialBytes);
    if (!await _handshake()) {
      await close();
      return false;
    }
    _ready = true;
    return true;
  }

  @override
  Future<bool> writeFrame(Uint8List frame) async {
    if (!_ready || _port == null) return false;
    final packet = MeshtasticCodec.wrapMeshPacket(channel: 0, payload: frame);
    final toRadio = MeshtasticCodec.encodeToRadio(packet);
    return _port!.write(toRadio) == toRadio.length;
  }

  Future<void> _onSerialBytes(Uint8List chunk) async {
    for (final pkt in MeshtasticCodec.decodeFromRadio(chunk)) {
      if (pkt.hasDecoded()) {
        _onFrame.add(Uint8List.fromList(pkt.decoded.payload));
      }
    }
  }

  Future<bool> _handshake() async {
    // 1. wantConfigId
    // 2. esperar configCompleteId matching
    // 3. validar region/SF/BW
    // 4. eco PPHANDSHAKE
    // devolver false si cualquier paso falla dentro del timeout
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {
    _ready = false;
    await _port?.close();
    _port = null;
  }
}
```

## Apéndice B — Esqueleto de driver BLE UART (referencia)

```dart
class BleUartLoraLinkDriver implements LoraLinkDriver {
  final String _deviceId;
  // ... mismo patrón que USB pero usando FlutterBluePlus sobre el GATT Meshtastic.
}
```

## Apéndice C — Logs de campo (template)

Crear `/docs/lora-field-test-log.md` con tabla por sesión: fecha, nodos, ubicación, clima, caso, RSSI, SNR, latencia, resultado.
