import Foundation
import UIKit
import UserNotifications

/// Detecta un SOS entrante EN LA CAPA NATIVA y lanza la notificación sin
/// depender del motor Dart.
///
/// Por qué existe: cuando iOS manda la app a segundo plano, el isolate de
/// Dart queda suspendido. La radio BLE sigue entregando datos al lado Swift,
/// pero nadie los procesa: el SOS de un vecino se perdía justo cuando más
/// falta hace. Aquí reimplementamos lo MÍNIMO del protocolo (reensamblado +
/// cabecera del sobre) para reconocer un SOS y avisar de inmediato.
///
/// El canal EMERGENCIA viaja en texto plano por diseño (un SOS debe llegar a
/// desconocidos), así que no hace falta descifrar nada.
///
/// Formato del sobre (little-endian), espejo de mesh_envelope.dart:
///   magic 'PM01'(4) | msgId(8) | channelId(4) | senderId(8) | type(1)
///   | hopLimit(1) | timestampMs(8) | nameLen(1)+nombre | payloadLen(2)+payload
///
/// Fragmentación (frag.dart): [u32 fragId][u16 seq][u16 total][trozo]
enum SosSniffer {
    private static let magic: [UInt8] = [0x50, 0x4D, 0x30, 0x31] // 'PM01'
    private static let fragHeaderLen = 8
    private static let typeSos: UInt8 = 2 // enum MeshType: chat,position,sos…

    /// Reensamblado parcial, acotado para no crecer sin límite.
    private final class Partial {
        let total: Int
        var parts: [Int: Data] = [:]
        let started = Date()
        init(total: Int) { self.total = total }
    }

    private static var partials: [UInt32: Partial] = [:]
    private static var notifiedMsgIds = Set<UInt64>()
    private static let lock = NSLock()

    /// Entrada única: cada trozo que llega por BLE pasa por aquí.
    /// No interfiere con Dart — solo observa.
    static func inspect(_ data: Data) {
        guard let full = reassemble(data) else { return }
        guard let sos = parseSos(full) else { return }
        notify(sos)
    }

    // MARK: - Reensamblado

    private static func reassemble(_ frame: Data) -> Data? {
        // Un mensaje corto puede venir sin fragmentar: si ya parece un sobre
        // completo, se usa tal cual.
        if frame.count >= 4, Array(frame.prefix(4)) == magic { return frame }
        guard frame.count > fragHeaderLen else { return nil }

        let fragId = frame.readU32(0)
        let seq = Int(frame.readU16(4))
        let total = Int(frame.readU16(6))
        guard total > 0, total <= 512, seq < total else { return nil }
        let chunk = frame.subdata(in: fragHeaderLen..<frame.count)

        lock.lock()
        defer { lock.unlock() }

        // Higiene: soltar parciales viejos (el mesh reintenta igual).
        let cutoff = Date().addingTimeInterval(-30)
        partials = partials.filter { $0.value.started > cutoff }
        if partials.count > 24 { partials.removeAll() }

        let p = partials[fragId] ?? Partial(total: total)
        p.parts[seq] = chunk
        partials[fragId] = p
        guard p.parts.count == p.total else { return nil }

        var out = Data()
        for i in 0..<p.total {
            guard let part = p.parts[i] else { return nil }
            out.append(part)
        }
        partials.removeValue(forKey: fragId)
        return out
    }

    // MARK: - Parseo del sobre

    struct Sos {
        let msgId: UInt64
        let sender: String
        let note: String?
        let lat: Double?
        let lon: Double?
    }

    private static func parseSos(_ d: Data) -> Sos? {
        // magic(4)+msgId(8)+channel(4)+sender(8)+type(1)+hop(1)+ts(8)+nameLen(1)
        let minLen = 4 + 8 + 4 + 8 + 1 + 1 + 8 + 1 + 2
        guard d.count >= minLen, Array(d.prefix(4)) == magic else { return nil }
        var o = 4
        let msgId = d.readU64(o); o += 8
        o += 4 // channelId (no hace falta: el filtro real es el tipo + payload)
        o += 8 // senderId
        let type = d[d.startIndex + o]; o += 1
        guard type == typeSos else { return nil }
        o += 1 // hopLimit
        o += 8 // timestampMs
        let nameLen = Int(d[d.startIndex + o]); o += 1
        guard d.count >= o + nameLen + 2 else { return nil }
        let name = String(
            data: d.subdata(in: o..<(o + nameLen)), encoding: .utf8) ?? "?"
        o += nameLen
        let payloadLen = Int(d.readU16(o)); o += 2
        guard d.count >= o + payloadLen else { return nil }
        let payload = d.subdata(in: o..<(o + payloadLen))

        // Solo el canal EMERGENCIA va en claro: si no parsea como JSON es un
        // canal cifrado y no nos toca (Dart lo abrirá cuando despierte).
        guard let json = try? JSONSerialization.jsonObject(with: payload)
                as? [String: Any] else { return nil }

        return Sos(
            msgId: msgId,
            sender: name,
            note: (json["note"] as? String)?.trimmingCharacters(
                in: .whitespacesAndNewlines),
            lat: json["lat"] as? Double,
            lon: json["lon"] as? Double,
        )
    }

    // MARK: - Notificación nativa

    private static func notify(_ sos: Sos) {
        lock.lock()
        let alreadySeen = notifiedMsgIds.contains(sos.msgId)
        if !alreadySeen {
            notifiedMsgIds.insert(sos.msgId)
            if notifiedMsgIds.count > 64 { notifiedMsgIds.removeAll() }
        }
        lock.unlock()
        guard !alreadySeen else { return }

        DispatchQueue.main.async {
            // Con la app en pantalla ya hay alarma a pantalla completa; una
            // notificación encima sería ruido duplicado.
            guard UIApplication.shared.applicationState != .active else { return }

            let spanish = (Locale.preferredLanguages.first ?? "es")
                .hasPrefix("es")
            let content = UNMutableNotificationContent()
            content.title = spanish
                ? "🚨 SOS — \(sos.sender)"
                : "🚨 SOS — \(sos.sender)"
            var body = sos.note?.isEmpty == false
                ? sos.note!
                : (spanish ? "Pide ayuda cerca de ti" : "Needs help near you")
            if let la = sos.lat, let lo = sos.lon {
                body += String(format: "\n%.5f, %.5f", la, lo)
            }
            content.body = body
            content.sound = .defaultCritical
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

            let request = UNNotificationRequest(
                identifier: "nuvok.sos.\(sos.msgId)",
                content: content,
                trigger: nil, // inmediata
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    NSLog("PPMESH SOS nativo NO notificó: %@",
                          error.localizedDescription)
                } else {
                    NSLog("PPMESH SOS nativo notificado de %@", sos.sender)
                }
            }
        }
    }
}

// MARK: - Lectura little-endian sin depender de alineación

private extension Data {
    func readU16(_ offset: Int) -> UInt16 {
        let i = startIndex + offset
        return UInt16(self[i]) | (UInt16(self[i + 1]) << 8)
    }

    func readU32(_ offset: Int) -> UInt32 {
        let i = startIndex + offset
        var v: UInt32 = 0
        for k in 0..<4 { v |= UInt32(self[i + k]) << (8 * UInt32(k)) }
        return v
    }

    func readU64(_ offset: Int) -> UInt64 {
        let i = startIndex + offset
        var v: UInt64 = 0
        for k in 0..<8 { v |= UInt64(self[i + k]) << (8 * UInt64(k)) }
        return v
    }
}
