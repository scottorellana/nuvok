import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/disk_space.dart';

/// Nuvok pide descargas de hasta 3.4 GB (Gemma 4 E2B) en teléfonos que suelen
/// estar llenos de fotos. Antes no se comprobaba NADA: la descarga corría 40
/// minutos y moría sin espacio, desperdiciando datos móviles y — peor — dejando
/// al usuario creyendo que su kit estaba listo.
///
/// Estas reglas son puras para poder verificarlas sin tocar disco.
void main() {
  const gb = 1024 * 1024 * 1024;

  group('¿cabe la descarga?', () {
    test('sobra espacio → adelante', () {
      final v = checkSpaceFor(needBytes: 3 * gb, freeBytes: 20 * gb);
      expect(v.fits, isTrue);
      expect(v.tight, isFalse);
    });

    test('no cabe → se avisa ANTES de gastar datos', () {
      final v = checkSpaceFor(needBytes: 3 * gb, freeBytes: 2 * gb);
      expect(v.fits, isFalse);
      expect(v.missingBytes, 1 * gb);
    });

    test('cabe justo pero deja el equipo al límite → advertencia', () {
      // Reserva: un teléfono sin margen no puede ni actualizar el sistema
      // ni guardar una foto de la emergencia.
      final v = checkSpaceFor(needBytes: 3 * gb, freeBytes: (3.3 * gb).round());
      expect(v.fits, isTrue);
      expect(v.tight, isTrue,
          reason: 'queda menos que la reserva mínima: hay que avisar');
    });

    test('el borde de la reserva es exacto', () {
      final justo = checkSpaceFor(
          needBytes: 1 * gb, freeBytes: 1 * gb + minFreeReserveBytes);
      expect(justo.fits, isTrue);
      expect(justo.tight, isFalse);

      final unByteMenos = checkSpaceFor(
          needBytes: 1 * gb, freeBytes: 1 * gb + minFreeReserveBytes - 1);
      expect(unByteMenos.tight, isTrue);
    });

    test('espacio desconocido no bloquea la descarga', () {
      // Si la plataforma no sabe reportar espacio, NO se puede impedir que el
      // usuario se prepare: se deja pasar en silencio.
      final v = checkSpaceFor(needBytes: 3 * gb, freeBytes: null);
      expect(v.fits, isTrue);
      expect(v.unknown, isTrue);
      expect(v.tight, isFalse);
    });

    test('una descarga a medias solo necesita lo que le falta', () {
      // Reanudar tras un corte no debe exigir el tamaño completo otra vez.
      final v = checkSpaceFor(
          needBytes: 3 * gb, freeBytes: 2 * gb, alreadyBytes: 2 * gb);
      expect(v.fits, isTrue, reason: 'solo faltaba 1 GB y hay 2 GB');
    });
  });

  group('mensaje para el usuario', () {
    test('dice cuánto falta en unidades humanas, no en bytes', () {
      final v = checkSpaceFor(needBytes: 3 * gb, freeBytes: 1 * gb);
      expect(v.shortfallText, contains('GB'));
      expect(v.shortfallText, isNot(contains('2147483648')));
    });

    test('sin faltante no hay texto de faltante', () {
      expect(checkSpaceFor(needBytes: 1 * gb, freeBytes: 9 * gb).shortfallText,
          isEmpty);
    });
  });
}
