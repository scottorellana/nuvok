import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/screen_awake.dart';

/// Hay funciones de Nuvok que DEBEN sobrevivir al apagado automático de
/// pantalla: la linterna que alumbra un derrumbe, el SOS Morse que alguien
/// busca desde lejos, la baliza que emite tu posición. Antes se apagaban
/// solas a los 30 segundos del sistema — y el usuario creía que seguían
/// funcionando porque la app se veía "encendida" al desbloquear.
///
/// Contador de razones: varias pantallas pueden pedirlo a la vez y la
/// pantalla solo vuelve a dormirse cuando TODAS lo sueltan.
void main() {
  setUp(ScreenAwake.debugReset);

  test('una razón mantiene la pantalla despierta', () async {
    final fake = _FakeAwake();
    ScreenAwake.debugSink = fake;
    await ScreenAwake.acquire('linterna');
    expect(fake.awake, isTrue);
  });

  test('soltar la única razón la deja dormir', () async {
    final fake = _FakeAwake();
    ScreenAwake.debugSink = fake;
    await ScreenAwake.acquire('linterna');
    await ScreenAwake.release('linterna');
    expect(fake.awake, isFalse);
  });

  test('dos razones: soltar una NO apaga', () async {
    // La linterna alumbrando mientras la baliza emite: cerrar la linterna no
    // puede dejar que la pantalla se duerma y mate la baliza.
    final fake = _FakeAwake();
    ScreenAwake.debugSink = fake;
    await ScreenAwake.acquire('linterna');
    await ScreenAwake.acquire('baliza');
    await ScreenAwake.release('linterna');
    expect(fake.awake, isTrue);
    await ScreenAwake.release('baliza');
    expect(fake.awake, isFalse);
  });

  test('pedir dos veces la misma razón no requiere soltar dos veces', () async {
    final fake = _FakeAwake();
    ScreenAwake.debugSink = fake;
    await ScreenAwake.acquire('linterna');
    await ScreenAwake.acquire('linterna');
    await ScreenAwake.release('linterna');
    expect(fake.awake, isFalse, reason: 'las razones son un conjunto');
  });

  test('soltar una razón que nunca se pidió no rompe nada', () async {
    final fake = _FakeAwake();
    ScreenAwake.debugSink = fake;
    await ScreenAwake.release('fantasma');
    expect(fake.awake, isFalse);
  });

  test('un fallo de plataforma no tumba la función', () async {
    // Si el wakelock no está disponible, la linterna DEBE seguir alumbrando.
    ScreenAwake.debugSink = _ThrowingAwake();
    await ScreenAwake.acquire('linterna');
    await ScreenAwake.release('linterna');
  });
}

class _FakeAwake implements AwakeSink {
  bool awake = false;
  @override
  Future<void> setAwake(bool value) async => awake = value;
}

class _ThrowingAwake implements AwakeSink {
  @override
  Future<void> setAwake(bool value) async => throw StateError('sin plugin');
}
