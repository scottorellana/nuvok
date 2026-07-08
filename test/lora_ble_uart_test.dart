import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/mesh/lora_ble_uart.dart';
import 'package:prepper_pad/modules/mesh/lora_transport.dart';

// El driver LoRa BLE-UART es lo que enchufa un adaptador LoRa real (tipo
// Meshtastic/Nordic UART) al mesh: la app escanea el módulo, se conecta y el
// transporte LoRa se activa solo. El puerto BLE se inyecta como seam para
// probar toda la lógica sin hardware.
class FakeUartPort implements BleUartPort {
  final _incoming = StreamController<Uint8List>.broadcast();
  final written = <Uint8List>[];
  bool connected = false;
  bool connectResult = true;
  int connectCalls = 0;

  @override
  bool get isConnected => connected;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Future<bool> connect() async {
    connectCalls++;
    connected = connectResult;
    return connected;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<bool> write(Uint8List data) async {
    if (!connected) return false;
    written.add(data);
    return true;
  }

  void deviceSends(Uint8List frame) => _incoming.add(frame);
}

void main() {
  test('open() conecta el puerto y available lo refleja', () async {
    final port = FakeUartPort();
    final driver = BleUartLoraDriver(port: port);
    expect(driver.available, isFalse, reason: 'sin conectar aún');
    expect(await driver.open(), isTrue);
    expect(driver.available, isTrue);
    expect(port.connectCalls, 1);
  });

  test('writeFrame pasa el frame tal cual al puerto BLE', () async {
    final port = FakeUartPort();
    final driver = BleUartLoraDriver(port: port);
    await driver.open();
    final frame = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(await driver.writeFrame(frame), isTrue);
    expect(port.written.single, frame);
  });

  test('onFrame entrega lo que el radio envía', () async {
    final port = FakeUartPort();
    final driver = BleUartLoraDriver(port: port);
    await driver.open();
    final got = <Uint8List>[];
    final sub = driver.onFrame.listen(got.add);
    port.deviceSends(Uint8List.fromList([9, 8, 7]));
    await Future<void>.delayed(Duration.zero);
    expect(got.single, [9, 8, 7]);
    await sub.cancel();
  });

  test('si el puerto no conecta, open() falla y no queda disponible',
      () async {
    final port = FakeUartPort()..connectResult = false;
    final driver = BleUartLoraDriver(port: port);
    expect(await driver.open(), isFalse);
    expect(driver.available, isFalse);
  });

  test('close() desconecta el puerto', () async {
    final port = FakeUartPort();
    final driver = BleUartLoraDriver(port: port);
    await driver.open();
    await driver.close();
    expect(port.connected, isFalse);
    expect(driver.available, isFalse);
  });

  test('integración: LoraTransport sobre el driver mueve un datagrama real',
      () async {
    // Dos puertos "por el aire": lo que A escribe llega al incoming de B y
    // viceversa. Prueba que un datagrama viaja
    // transport→driver→BLE→driver→transport intacto, con fragmentación LoRa.
    final airA = StreamController<Uint8List>.broadcast();
    final airB = StreamController<Uint8List>.broadcast();
    final portA = _LoopPort(rx: airA, tx: airB);
    final portB = _LoopPort(rx: airB, tx: airA);
    final a = LoraTransport(link: BleUartLoraDriver(port: portA));
    final b = LoraTransport(link: BleUartLoraDriver(port: portB));
    await a.start();
    await b.start();
    final got = <Uint8List>[];
    final sub = b.onData.listen(got.add);
    final msg = Uint8List.fromList(List.generate(500, (i) => i % 256));
    await a.send(msg); // 500B → varios frames LoRa
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(got.single, msg, reason: 'datagrama reensamblado idéntico');
    await sub.cancel();
    await a.stop();
    await b.stop();
    await airA.close();
    await airB.close();
  });
}

/// Puerto de loopback: escribe al aire [tx] del peer, recibe del aire [rx].
class _LoopPort implements BleUartPort {
  _LoopPort({required this.rx, required this.tx});
  final StreamController<Uint8List> rx;
  final StreamController<Uint8List> tx;
  bool _connected = false;

  @override
  bool get isConnected => _connected;
  @override
  Stream<Uint8List> get incoming => rx.stream;

  @override
  Future<bool> connect() async {
    _connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  Future<bool> write(Uint8List data) async {
    if (!_connected) return false;
    tx.add(data);
    return true;
  }
}
