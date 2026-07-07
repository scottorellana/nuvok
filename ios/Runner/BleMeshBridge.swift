import CoreBluetooth
#if canImport(FlutterMacOS)
import FlutterMacOS
#else
import Flutter
#endif

/// Apple-native BLE bridge for Prepper Mesh (mirror of BleMeshBridge.kt).
///
/// Speaks the exact same channel protocol as the Android bridge so the Dart
/// transport is one code path everywhere:
///   MethodChannel  "prepper/ble_mesh":        start / stop / connect(id) /
///                                             disconnect(id) / send(id, bytes)
///   EventChannel   "prepper/ble_mesh/events": {type:"peer", id}
///                                             {type:"data", id, bytes}
///
/// Both halves run at once: CBPeripheralManager advertises the Prepper GATT
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

    // Central role: peripherals we discovered/connected to, by identifier.
    private var peripherals: [String: CBPeripheral] = [:]
    private var peerTx: [String: CBCharacteristic] = [:]
    // Peripheral role: centrals subscribed to our RX (the notify return path
    // to devices we cannot connect back to).
    private var subscribedCentrals: [String: CBCentral] = [:]

    static func register(messenger: FlutterBinaryMessenger) {
        let bridge = BleMeshBridge()
        let methods = FlutterMethodChannel(name: "prepper/ble_mesh", binaryMessenger: messenger)
        methods.setMethodCallHandler { call, result in
            bridge.handle(call: call, result: result)
        }
        let events = FlutterEventChannel(name: "prepper/ble_mesh/events", binaryMessenger: messenger)
        events.setStreamHandler(bridge)
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            running = true
            if central == nil { central = CBCentralManager(delegate: self, queue: nil) }
            if peripheral == nil { peripheral = CBPeripheralManager(delegate: self, queue: nil) }
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
            peripheral?.updateValue(bytes, for: rx, onSubscribedCentrals: [c])
            return true
        }
        // Path #2: write to the TX characteristic of a peripheral we joined.
        if let p = peripherals[id], let tx = peerTx[id], p.state == .connected {
            p.writeValue(bytes, for: tx, type: .withResponse)
            return true
        }
        return false
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

// MARK: - Central role: find and join nearby Prepper Pads.
extension BleMeshBridge: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard running, central.state == .poweredOn else { return }
        central.scanForPeripherals(
            withServices: [Self.serviceUuid],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier.uuidString
        if peripherals[id] == nil {
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
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard running, peripheral.state == .poweredOn else { return }
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
