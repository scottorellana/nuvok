# Prepper Pad — Offline communications production protocol

Status: code-level verified. Field production requires real-device testing on the exact target tablets/phones and LoRa radio hardware before promising life-safety reliability.

## Emergency connection goal

A non-technical person should be able to connect devices with no internet, no cell service, and no central server:

1. Open **Comunicación (sin internet)** on each device.
2. Set a visible name: `Ana`, `Radio 1`, `Clínica`, etc.
3. Keep devices awake for 10 seconds so discovery bursts run.
4. For private group chat, one device taps **Crear**, shows the QR/code, and the other taps **Unirse** and scans/pastes `PPMESH1:...`.
5. For urgent help, tap **SOS**. SOS uses the open `EMERGENCIA` channel and does not require joining a private group.
6. Leave the app open while moving. The mesh relays messages with hop limits and store-and-forward.

## Transport order and use cases

| Transport | Infrastructure | Best for | Production behavior |
| --- | --- | --- | --- |
| LAN / hotspot UDP | Existing Wi‑Fi LAN or one phone/tablet hotspot; no internet required | Fast local camp/clinic/shelter mesh | Multicast + broadcast + learned unicast fallback |
| Wi‑Fi Direct / Nearby | Android device-to-device, no router | Higher bandwidth direct Android links | Discovery + advertising simultaneously; listener-before-start to avoid missed first peer |
| BLE | Short-range, no router, no internet | Last-meter emergency text/SOS when Wi‑Fi is unavailable | Fragmented frames, reassembly, listener-before-start, waits initial connect before first send |
| LoRa | External radio over USB serial or BLE UART | Long-range low-bandwidth SOS/chat relay | Protocol, fragmentation, reassembly and driver seam are implemented/tested; physical driver/hardware validation still required |

## Wire protocol

All transports carry the same `MeshEnvelope`:

- Magic: `PM01`
- Random 63-bit `msgId`
- Channel id: first 4 bytes of `sha256(name + key)`
- Sender id/name
- Type: `chat`, `position`, `sos`, `sosCancel`, `ack`, `beacon`
- Hop limit for controlled flooding
- Timestamp
- Payload

Security:

- Private channels use AES-256-GCM.
- `EMERGENCIA` is deliberately plaintext so strangers nearby can receive SOS.
- Shareable private channel codes use `PPMESH1:base64url(name\nkeyhex)` for QR/copy-paste.

Reliability:

- Dedup by `msgId`.
- Relay with decreasing hop limit.
- Store-and-forward outbox when no peers are confirmed.
- ACKs for chat and retransmit up to `MeshService.maxChatSends`.
- Outbox capped at `MeshRouter.maxOutboxDatagrams` to avoid RAM/disk runaway.
- Beacons trigger immediate outbox flush.

## LoRa hardware contract

A real LoRa driver must implement `LoraLinkDriver`:

- `available`: true only when a supported radio is attached and ready.
- `open()`: opens USB serial or BLE UART and performs any radio handshake.
- `onFrame`: emits raw LoRa frames up to `loraMaxFrameSize`.
- `writeFrame(frame)`: writes one frame and returns false if the radio cannot accept it.
- `close()`: closes the device cleanly.

Do not set `available=true` until hardware has passed the field checklist below.

## Field production checklist

Run these with at least 3 devices, in airplane mode, with internet disabled:

1. LAN/hotspot:
   - Device A creates hotspot with mobile data off.
   - Devices B/C join hotspot.
   - A/B/C exchange chat both directions.
   - Turn B screen off/on; verify beacons recover and outbox flushes.
2. Wi‑Fi Direct Android:
   - No router/hotspot.
   - Start app on two Android devices.
   - Verify discovery under 10 seconds and bidirectional chat.
   - Move out of range, send 3 messages, move back, verify delivery/ACKs.
3. BLE:
   - Disable Wi‑Fi.
   - Keep Bluetooth on.
   - Verify short message and SOS within 10 seconds at close range.
   - Verify large payload fragmentation test via app logs or diagnostics if available.
4. LoRa:
   - Attach supported radio to both devices.
   - Driver reports available.
   - Send SOS and chat at 100 m, 500 m, and obstructed line-of-sight.
   - Power-cycle one radio, reconnect, verify store-and-forward and dedup.
5. Mixed mesh:
   - A↔B over BLE, B↔C over LAN/hotspot or LoRa.
   - A sends SOS with hop limit; C receives once.
6. Battery/low RAM:
   - Leave mesh running 2 hours.
   - Verify no unbounded outbox growth, no app crash, and app resumes with beacons.

## Current automated verification

- Unit/simulation tests cover BLE fragmentation/reassembly, Wi‑Fi Direct early discovery, LoRa fragmentation/reassembly, fake LoRa driver round-trip, mesh dedup, ACK, outbox, relay and two-device offline chat.
- These tests prove protocol behavior without internet.
- They do **not** replace real RF/hardware field testing.
