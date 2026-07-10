import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/frag.dart';

// BLE moves ~180 usable bytes per notification; mesh envelopes are 200-600.
// This layer splits and rebuilds them — a bug here silently corrupts every
// iPhone↔Android message, so it gets exhaustive pure-Dart tests.
void main() {
  test('mensaje corto viaja en un solo fragmento y se rearma', () {
    final msg = Uint8List.fromList(List.generate(100, (i) => i));
    final frags = fragment(msg, mtu: 185);
    expect(frags, hasLength(1));
    final rx = Reassembler();
    expect(rx.accept(frags.single), equals(msg));
  });

  test('mensaje largo se parte y se rearma en cualquier orden', () {
    final msg = Uint8List.fromList(List.generate(1000, (i) => i % 251));
    final frags = fragment(msg, mtu: 185);
    expect(frags.length, greaterThan(1));
    final rx = Reassembler();
    Uint8List? out;
    // Entregar en orden inverso: solo el último accept devuelve el mensaje.
    for (final f in frags.reversed) {
      out = rx.accept(f) ?? out;
    }
    expect(out, equals(msg));
  });

  test('fragmento perdido → nada; mensajes intercalados no se mezclan', () {
    final a = Uint8List.fromList(List.filled(500, 7));
    final b = Uint8List.fromList(List.filled(500, 9));
    final fa = fragment(a, mtu: 185);
    final fb = fragment(b, mtu: 185);
    expect(fa, hasLength(3));
    final rx = Reassembler();
    expect(rx.accept(fa[0]), isNull);
    expect(rx.accept(fb[0]), isNull);
    expect(rx.accept(fb[1]), isNull);
    expect(rx.accept(fa[1]), isNull);
    expect(rx.accept(fb[2]), equals(b));
    // a estaba incompleto; al llegar su último fragmento se completa aparte.
    expect(rx.accept(fa[2]), equals(a));
  });

  test('fragmento duplicado no corrompe el reensamblado', () {
    final msg = Uint8List.fromList(List.generate(400, (i) => i % 256));
    final frags = fragment(msg, mtu: 185);
    final rx = Reassembler();
    expect(rx.accept(frags[0]), isNull);
    expect(rx.accept(frags[0]), isNull); // duplicado
    for (var i = 1; i < frags.length - 1; i++) {
      expect(rx.accept(frags[i]), isNull);
    }
    expect(rx.accept(frags.last), equals(msg));
  });

  test('basura corta o cabecera inválida no revienta', () {
    final rx = Reassembler();
    expect(rx.accept(Uint8List(3)), isNull);
    expect(rx.accept(Uint8List(0)), isNull);
    // total=0 es inválido.
    final bad = Uint8List(12);
    ByteData.sublistView(bad)
      ..setUint32(0, 42, Endian.little)
      ..setUint16(4, 0, Endian.little)
      ..setUint16(6, 0, Endian.little);
    expect(rx.accept(bad), isNull);
  });

  test('memoria acotada: nunca más de maxInFlight mensajes a medias', () {
    final rx = Reassembler(maxInFlight: 4);
    // 10 mensajes incompletos (solo primer fragmento de cada uno).
    for (var m = 0; m < 10; m++) {
      final msg = Uint8List.fromList(List.filled(500, m));
      rx.accept(fragment(msg, mtu: 185).first);
    }
    expect(rx.inFlight, lessThanOrEqualTo(4));
  });
}
