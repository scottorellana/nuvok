import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/mesh/sos_auth.dart';

/// El canal de emergencia va en claro para que cualquiera pueda OÍR un grito
/// de auxilio. Esa apertura no puede significar que cualquiera pueda CALLARLO.
void main() {
  test('quien lanzó el SOS puede cancelarlo', () {
    final secret = newSosSecret();
    final commitment = sosCommitmentFor(secret);
    expect(sosCancelIsAuthentic(commitment: commitment, secret: secret), isTrue);
  });

  test('quien solo OYÓ el SOS no puede cancelarlo', () {
    final secret = newSosSecret();
    final commitment = sosCommitmentFor(secret);
    // El atacante ve la huella pasar por el aire: es lo único que viaja.
    expect(sosCancelIsAuthentic(commitment: commitment, secret: commitment),
        isFalse,
        reason: 'reenviar la huella como si fuera el secreto no puede colar');
    expect(
        sosCancelIsAuthentic(commitment: commitment, secret: newSosSecret()),
        isFalse);
  });

  test('sin huella conocida se rechaza, no se acepta a ciegas', () {
    final secret = newSosSecret();
    expect(sosCancelIsAuthentic(commitment: null, secret: secret), isFalse,
        reason: 'ante la duda, seguir buscando a la persona');
    expect(sosCancelIsAuthentic(commitment: '', secret: secret), isFalse);
  });

  test('una cancelación sin secreto se rechaza', () {
    final commitment = sosCommitmentFor(newSosSecret());
    expect(sosCancelIsAuthentic(commitment: commitment, secret: null), isFalse);
    expect(sosCancelIsAuthentic(commitment: commitment, secret: ''), isFalse);
  });

  test('dos secretos nunca coinciden', () {
    final vistos = {for (var i = 0; i < 500; i++) newSosSecret()};
    expect(vistos, hasLength(500), reason: 'secreto predecible = sin defensa');
  });

  test('la huella no revela el secreto', () {
    final secret = newSosSecret();
    final commitment = sosCommitmentFor(secret);
    expect(commitment, isNot(contains(secret)));
    expect(commitment.length, 32);
  });

  group('SosCommitments', () {
    test('recuerda por remitente y solo acepta a su dueño', () {
      final store = SosCommitments();
      final ana = newSosSecret();
      final beto = newSosSecret();
      store.remember('ana', sosCommitmentFor(ana));
      store.remember('beto', sosCommitmentFor(beto));

      expect(store.accepts('ana', ana), isTrue);
      expect(store.accepts('ana', beto), isFalse,
          reason: 'el secreto de Beto no puede callar el SOS de Ana');
      expect(store.accepts('beto', beto), isTrue);
    });

    test('un remitente desconocido no puede cancelar nada', () {
      final store = SosCommitments();
      expect(store.accepts('nadie', newSosSecret()), isFalse);
    });

    test('un SOS nuevo del mismo emisor renueva la huella', () {
      final store = SosCommitments();
      final primero = newSosSecret();
      store.remember('ana', sosCommitmentFor(primero));
      final segundo = newSosSecret();
      store.remember('ana', sosCommitmentFor(segundo));

      expect(store.accepts('ana', segundo), isTrue);
      expect(store.accepts('ana', primero), isFalse,
          reason: 'el secreto de un SOS ya cerrado no vale para el siguiente');
    });

    test('una huella vacía no borra la que ya había', () {
      final store = SosCommitments();
      final s = newSosSecret();
      store.remember('ana', sosCommitmentFor(s));
      store.remember('ana', null);
      store.remember('ana', '');
      expect(store.accepts('ana', s), isTrue,
          reason: 'un sobre viejo sin huella no puede desarmar la defensa');
    });
  });
}
