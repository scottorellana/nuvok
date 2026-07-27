import CoreBluetooth
#if canImport(FlutterMacOS)
import FlutterMacOS
#else
import Flutter
#endif

/// Apple-native BLE bridge for Nuvok Link (mirror of BleMeshBridge.kt).
///
/// Speaks the exact same channel protocol as the Android bridge so the Dart
/// transport is one code path everywhere:
///   MethodChannel  "nuvok/ble_mesh":        start / stop / connect(id) /
///                                             disconnect(id) / send(id, bytes)
///   EventChannel   "nuvok/ble_mesh/events": {type:"peer", id}
///                                             {type:"data", id, bytes}
///
/// Both halves run at once: CBPeripheralManager advertises the Nuvok GATT
/// service (TX ffe1 write-in, RX ffe2 notify-out), and CBCentralManager scans
/// for the same service on others. That is what lets any iPhone↔Android or
/// iPhone↔iPhone pair find each other with zero infrastructure.
class BleMeshBridge: NSObject, FlutterStreamHandler {
    private static let serviceUuid = CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb")
    private static let txUuid = CBUUID(string: "0000ffe1-0000-1000-8000-00805f9b34fb")
    private static let rxUuid = CBUUID(string: "0000ffe2-0000-1000-8000-00805f9b34fb")

    private var sink: FlutterEventSink?
    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    private var rxCharacteristic: CBMutableCharacteristic?
    private var running = false

    // Política de energía: ciclo de escucha en ms. offMs = 0 → escaneo
    // continuo (rendimiento o SOS activo). Por defecto equilibrado: nunca
    // arrancamos a tope sin saber la batería.
    private var dutyOnMs = 3000
    private var dutyOffMs = 2000
    private var dutyTimer: DispatchWorkItem?

    // Central role: peripherals we discovered/connected to, by identifier.
    private var peripherals: [String: CBPeripheral] = [:]
    private var peerTx: [String: CBCharacteristic] = [:]
    // Peripheral role: centrals subscribed to our RX (the notify return path
    // to devices we cannot connect back to).
    private var subscribedCentrals: [String: CBCentral] = [:]

    /// Instancia ÚNICA del puente. Debe serlo porque la restauración de
    /// estado de iOS obliga a recrear los managers al ARRANCAR la app (ver
    /// restoreIfAuthorized), mucho antes de que Dart registre su canal: si
    /// fueran dos instancias distintas, el estado restaurado moriría en una
    /// que nadie escucha.
    static let shared = BleMeshBridge()

    /// Recrea los managers BLE con sus identificadores de restauración al
    /// lanzar la app.
    ///
    /// SIN esto la restauración no funciona: Apple entrega el estado
    /// restaurado durante didFinishLaunchingWithOptions, y nosotros creábamos
    /// el CBCentralManager recién cuando Dart llamaba a "start" — demasiado
    /// tarde. Por eso un SOS no despertaba el teléfono con la app cerrada.
    ///
    /// Solo si el usuario YA concedió Bluetooth: crear el manager dispara el
    /// diálogo de permiso, y en el primer arranque eso le corresponde a la
    /// app, no a un relanzamiento en segundo plano.
    func restoreIfAuthorized() {
        if #available(iOS 13.1, macOS 11.0, *) {
            guard CBManager.authorization == .allowedAlways else { return }
        }
        ensureManagers()
    }

    /// Crea central y peripheral con identificadores de restauración.
    /// Idempotente: si ya existen, no hace nada.
    private func ensureManagers() {
        if central == nil {
            central = CBCentralManager(
                delegate: self, queue: nil,
                options: [CBCentralManagerOptionRestoreIdentifierKey:
                            "org.nuvok.mesh.central"])
        }
        if peripheral == nil {
            peripheral = CBPeripheralManager(
                delegate: self, queue: nil,
                options: [CBPeripheralManagerOptionRestoreIdentifierKey:
                            "org.nuvok.mesh.peripheral"])
        }
    }

    static func register(messenger: FlutterBinaryMessenger) {
        let bridge = BleMeshBridge.shared
        let methods = FlutterMethodChannel(name: "nuvok/ble_mesh", binaryMessenger: messenger)
        methods.setMethodCallHandler { call, result in
            bridge.handle(call: call, result: result)
        }
        let events = FlutterEventChannel(name: "nuvok/ble_mesh/events", binaryMessenger: messenger)
        events.setStreamHandler(bridge)
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            // If the user explicitly denied Bluetooth, instantiating the
            // managers is useless (and on dev launches TCC can even kill the
            // process). Report unavailable; the mesh keeps running on LAN.
            if #available(macOS 11.0, iOS 13.1, *) {
                NSLog("PPMESH start requested, authorization=%d", CBManager.authorization.rawValue)
                if CBManager.authorization == .denied || CBManager.authorization == .restricted {
                    NSLog("PPMESH bluetooth DENIED — radios not started")
                    result(false)
                    return
                }
            }
            running = true
            // Normalmente ya existen: se crean al arrancar la app
            // (restoreIfAuthorized) para que la restauración de estado de iOS
            // funcione. Aquí solo cubrimos el primer arranque, cuando el
            // usuario acaba de conceder Bluetooth.
            ensureManagers()
            // Radios spin up asynchronously in the poweredOn callbacks.
            result(true)
        case "stop":
            stopRadios()
            result(true)
        case "connect":
            let id = (call.arguments as? [String: Any])?["id"] as? String ?? ""
            result(connect(id: id))
        case "disconnect":
            if let id = (call.arguments as? [String: Any])?["id"] as? String {
                disconnect(id: id)
            }
            result(true)
        case "setPowerMode":
            // CoreBluetooth no expone "scan mode" como Android: el ahorro se
            // consigue apagando y reencendiendo el escaneo por temporizador.
            let args = call.arguments as? [String: Any]
            dutyOnMs = max(500, (args?["onMs"] as? Int) ?? 3000)
            dutyOffMs = max(0, (args?["offMs"] as? Int) ?? 2000)
            applyDutyCycle()
            result(true)
        case "send":
            let args = call.arguments as? [String: Any]
            let id = args?["id"] as? String ?? ""
            let data = (args?["bytes"] as? FlutterStandardTypedData)?.data
            result(send(id: id, bytes: data))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func stopRadios() {
        running = false
        central?.stopScan()
        peripheral?.stopAdvertising()
        peripheral?.removeAllServices()
        for p in peripherals.values {
            central?.cancelPeripheralConnection(p)
        }
        peripherals.removeAll()
        peerTx.removeAll()
        subscribedCentrals.removeAll()
        rxCharacteristic = nil
        central = nil
        peripheral = nil
    }

    private func connect(id: String) -> Bool {
        if id.isEmpty { return false }
        // A subscribed central already has a live data path (notifications) —
        // report it as connected so Dart wires up its incoming stream.
        if subscribedCentrals[id] != nil { return true }
        guard let p = peripherals[id], let c = central else { return false }
        if p.state == .connected { return true }
        c.connect(p, options: nil)
        return true
    }

    private func disconnect(id: String) {
        subscribedCentrals.removeValue(forKey: id)
        peerTx.removeValue(forKey: id)
        if let p = peripherals.removeValue(forKey: id) {
            central?.cancelPeripheralConnection(p)
        }
    }

    private func send(id: String, bytes: Data?) -> Bool {
        guard let bytes = bytes, !id.isEmpty else { return false }
        // Path #1: notify a central subscribed to our RX characteristic.
        if let c = subscribedCentrals[id], let rx = rxCharacteristic {
            let ok = peripheral?.updateValue(bytes, for: rx, onSubscribedCentrals: [c]) ?? false
            NSLog("PPMESH notify-out %d bytes ok=%d (max %d)", bytes.count, ok ? 1 : 0, c.maximumUpdateValueLength)
            return true
        }
        // Path #2: write to the TX characteristic of a peripheral we joined.
        if let p = peripherals[id], let tx = peerTx[id], p.state == .connected {
            p.writeValue(bytes, for: tx, type: .withResponse)
            return true
        }
        return false
    }

    /// Arranca el escaneo y, si el modo lo pide, programa el ciclo de apagado.
    private func startScanningWithDuty() {
        guard running, let c = central, c.state == .poweredOn else { return }
        c.scanForPeripherals(
            withServices: [Self.serviceUuid],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        applyDutyCycle()
    }

    /// Ciclo de escucha: apaga el escaneo tras dutyOnMs y lo reenciende tras
    /// dutyOffMs, para no fundir la batería. offMs = 0 → continuo.
    private func applyDutyCycle() {
        dutyTimer?.cancel()
        dutyTimer = nil
        guard running, dutyOffMs > 0 else { return } // continuo
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.running, let c = self.central else { return }
            c.stopScan()
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(self.dutyOffMs)
            ) { [weak self] in
                self?.startScanningWithDuty()
            }
        }
        dutyTimer = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(dutyOnMs), execute: work)
    }

    private func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.sink?(event)
        }
    }

    // MARK: FlutterStreamHandler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}

// MARK: - Central role: find and join nearby Nuvoks.
extension BleMeshBridge: CBCentralManagerDelegate, CBPeripheralDelegate {
    // iOS relanzó la app en segundo plano por actividad BLE: recuperamos los
    // peripherals que estaban conectados para no perder el enlace del mesh.
    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {
        running = true
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey]
            as? [CBPeripheral] ?? []
        for p in restored {
            peripherals[p.identifier.uuidString] = p
            p.delegate = self
        }
        NSLog("PPMESH central restored %d peripherals", restored.count)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("PPMESH central state=%d", central.state.rawValue)
        // Estado del adaptador → {type:'state'} para TransportHealth en Dart.
        switch central.state {
        case .poweredOn: emit(["type": "state", "value": "on"])
        case .poweredOff: emit(["type": "state", "value": "off"])
        case .unauthorized: emit(["type": "state", "value": "unauthorized"])
        case .unsupported: emit(["type": "state", "value": "unsupported"])
        default: break
        }
        guard running, central.state == .poweredOn else { return }
        NSLog("PPMESH central scanning (duty %d/%d ms)", dutyOnMs, dutyOffMs)
        startScanningWithDuty()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier.uuidString
        if peripherals[id] == nil {
            NSLog("PPMESH discovered peripheral %@", id)
            peripherals[id] = peripheral
            peripheral.delegate = self
            emit(["type": "peer", "id": id])
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUuid])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == Self.serviceUuid {
            peripheral.discoverCharacteristics([Self.txUuid, Self.rxUuid], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let id = peripheral.identifier.uuidString
        for ch in service.characteristics ?? [] {
            if ch.uuid == Self.txUuid {
                peerTx[id] = ch
            } else if ch.uuid == Self.rxUuid {
                peripheral.setNotifyValue(true, for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.rxUuid, let data = characteristic.value else { return }
        emit([
            "type": "data",
            "id": peripheral.identifier.uuidString,
            "bytes": FlutterStandardTypedData(bytes: data),
        ])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        peerTx.removeValue(forKey: id)
        // Keep the CBPeripheral reference: a later connect(id) can retry.
    }
}

// MARK: - Peripheral role: be discoverable and serve the mesh characteristics.
extension BleMeshBridge: CBPeripheralManagerDelegate {
    // iOS relanzó la app: reanudamos el rol de anuncio para seguir siendo
    // descubribles (un teléfono que lanza SOS debe seguir emitiendo aunque
    // esté en segundo plano).
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           willRestoreState dict: [String: Any]) {
        running = true
        NSLog("PPMESH peripheral state restored")
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        NSLog("PPMESH peripheral state=%d", peripheral.state.rawValue)
        guard running, peripheral.state == .poweredOn else { return }
        NSLog("PPMESH advertising start")
        let tx = CBMutableCharacteristic(
            type: Self.txUuid,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let rx = CBMutableCharacteristic(
            type: Self.rxUuid,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: Self.serviceUuid, primary: true)
        service.characteristics = [tx, rx]
        peripheral.removeAllServices()
        peripheral.add(service)
        rxCharacteristic = rx
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUuid],
        ])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == Self.rxUuid else { return }
        let id = central.identifier.uuidString
        NSLog("PPMESH central subscribed %@ maxUpdate=%d", id, central.maximumUpdateValueLength)
        subscribedCentrals[id] = central
        emit(["type": "peer", "id": id])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeValue(forKey: central.identifier.uuidString)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == Self.txUuid, let value = request.value {
                NSLog("PPMESH write-in %d bytes from %@", value.count, request.central.identifier.uuidString)
                emit([
                    "type": "data",
                    "id": request.central.identifier.uuidString,
                    "bytes": FlutterStandardTypedData(bytes: value),
                ])
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
