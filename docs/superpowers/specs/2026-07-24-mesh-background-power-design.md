# Malla en segundo plano + política de energía (Android e iOS)

Inspirado en la ARQUITECTURA de bitchat-android (permissionlesstech). Su
código es GPL v3 y Nuvok es propietario ($99): NO se copia código, solo se
aprenden ideas (no protegidas por copyright) y se implementa propio.

## Problema
1. Un SOS cercano solo llega si Nuvok está abierta: el SO mata el proceso
   (Android) o suspende la app (iOS).
2. El BLE de Android escanea siempre en SCAN_MODE_LOW_LATENCY (máximo
   consumo). En un apagón, la batería es la vida.

## Componentes

### 1. PowerPolicy (Dart puro, testeable) — ambas plataformas
`resolvePowerMode({batteryLevel, charging, sosActive})` → PowerMode.

| Situación | Modo | Ciclo (on/off ms) |
|---|---|---|
| sosActive (cualquier batería) | performance | continuo |
| charging o batería > 50 | performance | continuo |
| 20–50 | balanced | 3000 / 2000 |
| 10–20 | saver | 2000 / 8000 |
| < 10 | critical | 1000 / 15000 |
| batería desconocida (-1) | balanced | 3000 / 2000 |

REGLA PROPIA DE NUVOK: un SOS activo (propio o de un vecino) anula el ahorro.
Un teléfono que ahorra batería y se pierde el rescate no sirve.

Se alimenta del BatterySaverController existente (expone batteryLevel) y del
MeshService (sosActive). Un cambio de modo se empuja al puente nativo.

### 2. Android: servicio en primer plano
- `MeshForegroundService.kt`: mantiene vivo el proceso → el mesh Dart sigue
  corriendo → la notificación ya cableada dispara. Reutiliza todo lo actual.
- Notificación permanente discreta + acción "Detener".
- `foregroundServiceType="connectedDevice"` y permiso
  FOREGROUND_SERVICE_CONNECTED_DEVICE (falta hoy; obligatorio en Android 14+).
- `BootCompletedReceiver`: al reiniciar el teléfono la malla vuelve sola, solo
  si el usuario dejó el interruptor activado (RECEIVE_BOOT_COMPLETED).
- Interruptor en Ajustes: "Mantener la malla activa en segundo plano",
  ENCENDIDO por defecto (app de emergencias), apagable en dos toques.

### 3. Radio consciente de la batería
- Android `BleMeshBridge.kt`: método `setPowerMode(mode)` → aplica ScanSettings
  (LOW_LATENCY / BALANCED / LOW_POWER) y ciclo on/off con Handler.
- iOS `BleMeshBridge.swift`: CoreBluetooth no expone scanMode; el ciclo se
  implementa con stopScan()/scanForPeripherals() por temporizador.

### 4. iOS: hasta donde permite Apple (honesto)
- iOS NO permite un servicio permanente. El techo es:
  - UIBackgroundModes bluetooth-central/peripheral (ya declarados)
  - Restauración de estado BLE (ya implementada): iOS relanza la app en
    segundo plano ante actividad BLE del mesh.
- Android quedará más robusto que iOS en esto. Es una restricción de
  plataforma, no una decisión de diseño.

## Pruebas
- Unitarias (PowerPolicy): cada franja de batería → modo esperado; sosActive
  anula el ahorro en batería crítica; batería desconocida → balanced.
- Unitarias: el ciclo on/off nunca es 0 y off > 0 solo en modos de ahorro.
- En dispositivo (no automatizable): SOS de un aparato a otro con la app
  cerrada, en Android y en iPhone.

## Fuera de alcance (siguiente iteración)
- Guardar-y-reenviar mensajes de OTROS a pares que llegan después.
- Sincronización tipo gossip (GCS) para ponerse al día.
- Noise / secreto futuro; relleno anti-análisis de tráfico.
