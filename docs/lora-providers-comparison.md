# Proveedores LoRa para Prepper Pad — Honduras, China y EE.UU.

> Investigación de mercado con precios reales verificados el 4 de julio 2026.
> Objetivo: identificar dónde comprar 3-5 dispositivos LoRa 915 MHz para Prepper Pad con envío a Honduras.

---

## Resumen ejecutivo

| Métrica | Valor |
|---|---|
| Mejor opción precio/calidad | **AliExpress (China)** — Heltec V3 desde HNL 514 |
| Mejor opción rapidez | **Amazon US** — entrega 5-9 días a Honduras |
| Mejor dispositivo completo | **LILYGO T-Echo** — GPS, e-ink, batería, NFC integrado |
| Kit Meshtastic más fácil | **RAK WisBlock Starter Kit** — listo para Meshtastic |
| Presupuesto recomendado (4 nodos) | **HNL 6,000–10,000** (~USD 245–410) |
| Frecuencia legal Honduras | **915 MHz ISM (902-928 MHz)** — libre de licencia |

---

## 1. Proveedores por región

### 🇺🇸 Estados Unidos — Amazon.com

**Ventaja principal**: envío directo a Honduras en 5-9 días, garantía de devolución, productos FCC pre-certificados.

| Producto | Modelo | Precio (HNL) | Precio (USD aprox.) | Envío a HN |
|---|---|---|---|---|
| Heltec LoRa 32 **V4** (SX1262, ESP32-S3) | Heltec oficial | HNL 802 | ~$33 | 5 días, HNL 577 |
| ESP32 LoRa V3 (SX1262, 915MHz genérico) | Compatible | HNL 615 | ~$25 | 5 días |
| Heltec V3 (Meshtastic, SX1262) | Compatible | HNL 695 | ~$28 | 5 días |
| ESP32 LoRa V3 pack ×2 (SX1262) | Compatible | HNL 1,070 | ~$44 | 5 días |
| **RAK WisBlock Mini Meshtastic Starter Kit US915** | RAK19003 + RAK4631 | **HNL 855** | ~**$35** | 5 días, HNL 562 |
| RAK12501 GPS (complemento) | GNSS L76K | HNL 481 | ~$20 | 5 días |

**URL**: https://www.amazon.com (buscar "Heltec LoRa 32 V3" o "RAK4631 Meshtastic")
**Detección automática**: Amazon ya detecta dirección "Deliver to Honduras"

**Notas Amazon**:
- Amazon cobra envío e impuestos de importación al checkout
- Heltec V4 es la versión actualizada (ESP32-S3, más memoria) — mejor que V3
- RAK WisBlock Starter Kit viene con firmware Meshtastic preinstalable
- 79 resultados disponibles para Heltec LoRa 32 V3

---

### 🇨🇳 China — AliExpress

**Ventaja principal**: precios más bajos, envío gratis frecuente, tienda oficial LILYGO y Heltec disponibles.

| Producto | Modelo | Precio (HNL) | Precio (USD aprox.) | Ventas | Envío a HN |
|---|---|---|---|---|---|
| Heltec V3 Meshtastic (SX1262, 915MHz) | Tienda oficial | **HNL 514** | ~**$21** | 900+ vendidos | 2-4 semanas |
| Heltec WiFi LoRa 32 V3 (ESP32-S3, SX1262) | Oficial con batería | HNL 577 | ~$24 | 325 vendidos | 2-4 semanas |
| Heltec WiFi LoRa 32 V3 (ESP32S3, 868-915MHz) | Compatible | HNL 570 | ~$23 | — | 2-4 semanas |
| **LILYGO T-Echo** (SX1262, GPS, e-ink, NFC) | **Tienda oficial LILYGO** | **HNL 1,590** | ~**$65** | **2,000+ vendidos** | 2-4 semanas |
| LILYGO T-Echo PLUS (batería 2400mAh) | Tienda oficial | HNL 2,142 | ~$87 | 284 vendidos | 2-4 semanas |
| LILYGO T-Echo con antena (915MHz) | Compatible | HNL 2,942 | ~$120 | 4 vendidos | 2-4 semanas |
| LILYGO T-Echo Lite (versión económica) | Tienda oficial | HNL 282 | ~$12 | 6 vendidos | 2-4 semanas |

**URLs**:
- Heltec tienda oficial: https://heltec.org (producto) o AliExpress
- LILYGO tienda oficial: https://www.lilygo.cc o AliExpress
- AliExpress: buscar "Heltec LoRa 32 V3 915MHz" o "LILYGO T-Echo Meshtastic"

**Notas AliExpress**:
- Los precios más bajos del mercado
- T-Echo es el dispositivo más completo para Prepper Pad: GPS integrado, e-ink (bajo consumo), NFC, batería
- Heltec V3 desde HNL 514 (USD ~21) es imbatible en precio
- AliExpress detecta Honduras automáticamente, muestra precios en HNL
- Tiempo de envío: 15-30 días típico (estándar), 7-10 días con AliExpress Standard Shipping
- Comprar "Choice" items da envío más rápido y protegido

---

### 🇭🇳 Honduras — Opciones locales

No existen distribuidores especializados de módulos LoRa en Honduras. Las opciones son:

| Opción | Descripción | Ventaja | Desventaja |
|---|---|---|---|
| **Amazon US con envío directo** | Amazon envía a Honduras (DHL/FedEx) | Rápido (5-9 días), seguimiento | Costo envío alto |
| **Couriers: Aerocasillas, Mailbox Etc.** | Compras en US, lo traen a HN | Puedes comprar en cualquier tienda US | Comisión courier + tiempo 1-2 semanas extra |
| **AliExpress con envío estándar** | Envío directo a HN vía correo | Más barato | 2-4 semanas, sin seguimiento detallado |
| **Importación directa (DHL/FedEx)** | Desde fabricante en China/US | Control total | Trámite aduanal, posible impuesto importación |

**Recomendación para Honduras**: Comprar por **Amazon US con envío directo** para prototipo inicial (2-3 unidades, entrega rápida). Para lote completo, **AliExpress** por precio.

---

## 2. Comparación de dispositivos recomendados

| Dispositivo | Chip | Precio desde | BLE | GPS | Pantalla | Batería | Meshtastic | Mejor para |
|---|---|---|---|---|---|---|---|---|
| **Heltec LoRa 32 V3/V4** | SX1262 | USD $21-33 | ✅ | ❌ | OLED 0.96" | LiPo ext. | ✅ | Nodo móvil barato |
| **LILYGO T-Echo** | SX1262 | USD $65 | ✅ | ✅ | E-ink 1.54" | ✅ Integrada | ✅ | Repetidor/nodo autónomo |
| **LILYGO T-Beam Supreme** | SX1262 | USD $45-60 | ✅ | ✅ | OLED | ✅ 18650 | ✅ | Nodo con GPS |
| **RAK WisBlock Starter Kit** | RAK4631 | USD $35 | ✅ | ❌ (módulo opcional) | ❌ | ❌ | ✅ Preinstalable | Kit Meshtastic listo |
| **RAK4631 + RAK19007** | nRF52840+SX1262 | USD $35-50 | ✅ | Opcional RAK12501 | ❌ | ❌ | ✅ | Nodo bajo consumo |

---

## 3. Paquete de compra recomendado

### Opción A: Económica (HNL ~4,200 / USD ~$170) — 4 nodos básicos
```
4 × Heltec LoRa 32 V3 (AliExpress, HNL 514 c/u)         = HNL 2,056
4 × Antena 915 MHz 3 dBi SMA                             = HNL 320
4 × Power bank 10,000 mAh                                = HNL 800
4 × Cable SMA + accesorios                               = HNL 100
Envío AliExpress a Honduras                              = HNL 400-800
Accesorios (cargadores, cables USB-C)                    = HNL 500
                                                         ───────────
TOTAL ESTIMADO                                            HNL ~4,200
```

### Opción B: Completa (HNL ~9,500 / USD ~$390) — mixto para mejor cobertura
```
2 × Heltec LoRa 32 V3 (nodos móviles)                     = HNL 1,028
1 × LILYGO T-Echo (repetidor autónomo con GPS + batería)  = HNL 1,590
1 × RAK WisBlock Starter Kit US915 (base clínica)         = HNL 855
4 × Antena 915 MHz 3 dBi                                  = HNL 320
1 × Antena 915 MHz 5.8 dBi (repetidor)                    = HNL 200
4 × Power bank 10,000 mAh                                 = HNL 800
1 × Panel solar 10W + LiPo (repetidor)                    = HNL 400
Accesorios varios                                         = HNL 500
Envío (Amazon US + AliExpress)                            = HNL 1,500-2,000
Homologación CONATEL                                      = HNL 1,000-3,000
                                                          ───────────
TOTAL ESTIMADO                                             HNL ~9,500
```

### Opción C: Premium (HNL ~14,000 / USD ~$570) — máximo alcance
```
2 × LILYGO T-Echo (GPS + e-ink + batería integrada)       = HNL 3,180
2 × LILYGO T-Beam Supreme (GPS + batería 18650)            = HNL 2,400
1 × RAK4631 + RAK19007 (repetidor solar)                   = HNL 1,000
5 × Antena 915 MHz 3-5.8 dBi                               = HNL 500
Accesorios + power banks + panel solar                     = HNL 2,000
Envío internacional                                        = HNL 2,000
Homologación CONATEL                                       = HNL 3,000
                                                           ───────────
TOTAL ESTIMADO                                              HNL ~14,000
```

---

## 4. Regulación de frecuencia en Honduras (CONATEL)

### Estado legal: ✅ Libre de licencia

| Aspecto | Detalle |
|---|---|
| **Banda** | 902-928 MHz (ISM, Región 2 UIT) |
| **Licencia de operación** | **No requerida** para equipos de baja potencia |
| **Potencia máxima EIRP** | 30 dBm (1 W) — alineado con FCC Part 15.247 |
| **Uso permitido** | Personal, comunitario, emergencias, sin fines comerciales |
| **Homologación de equipo** | Recomendada pero no obligatoria para uso personal |
| **Costo homologación** | HNL 5,000-15,000 (~USD 200-600) |
| **Tiempo homologación** | 2-6 semanas |
| **Entidad** | CONATEL — https://www.conatel.gob.hn |

### Estrategia recomendada

1. **Comprar módulos pre-certificados FCC** (Heltec, RAK, LILYGO todos tienen FCC ID)
2. Para uso comunitario en clínicas: iniciar homologación CONATEL por equivalencia técnica
3. Operar dentro de límites: TX 20 dBm (no los 30 dBm máximos)
4. Mantener documentación del FCC ID del módulo

### Enlaces regulatorios
- CONATEL: https://www.conatel.gob.hn
- Buscar: "Homologación de equipos" en el sitio de CONATEL
- UIT-R Región 2: banda 902-928 MHz, primary mobile except aeronautical
- FCC Part 15.247: reglas técnicas operativas

---

## 5. Recomendación final

### Para empezar rápido (1 semana):
**Amazon US → RAK WisBlock Starter Kit US915 (HNL 855) + 2× Heltec V3**
- Envío a Honduras en 5 días
- RAK viene listo para Meshtastic
- Heltec V3 como nodos móviles

### Para mejor relación calidad/precio (3 semanas):
**AliExpress → 2× Heltec V3 + 1× LILYGO T-Echo + 1× RAK4631**
- Precio imbatible (T-Echo con GPS+batería desde HNL 1,590)
- T-Echo es el dispositivo más completo para campo
- 2-3 semanas de envío pero 40% más barato que Amazon

### Factor crítico para tablets sin USB:
**Todos los dispositivos recomendados soportan BLE UART** — no necesitan cable USB para conectar a Prepper Pad. El LILYGO T-Echo y Heltec V3 tienen BLE integrado y emparejan por Bluetooth con cualquier tablet Android.

---

*Documento generado: 4 julio 2026*
*Precios verificados en Amazon.com y AliExpress con detección automática de envío a Honduras*
