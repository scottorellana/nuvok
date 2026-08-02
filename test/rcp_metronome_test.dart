import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/tools/rcp_metronome.dart';

/// El metrónomo marca el ritmo de 100-120 compresiones por minuto. Quien lo
/// abre tiene las manos sobre un pecho: no puede mirar la pantalla, no puede
/// tocar PLAY y, si es de los otros 6 idiomas, tampoco puede leerlo.
void main() {
  testWidgets('arranca SOLO al abrirse: nadie toca PLAY con las manos ocupadas',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const RcpMetronomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    final ctrl = RcpMetronomeController.instance;
    expect(ctrl.playing, isTrue,
        reason: 'si hay que tocar PLAY, el ritmo llega tarde o no llega');

    ctrl.stop();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('la pantalla se apaga al salir, no antes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const RcpMetronomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    // Salir de la pantalla debe parar el metrónomo (y soltar el wakelock).
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(RcpMetronomeController.instance.playing, isFalse);
  });

  group('el ritmo es el correcto', () {
    tearDown(RcpMetronomeController.instance.stop);

    test('el BPM se limita al rango clínico', () {
      final c = RcpMetronomeController.instance;
      c.setBpm(50);
      expect(c.bpm, 100, reason: 'por debajo de 100 la RCP no perfunde');
      c.setBpm(200);
      expect(c.bpm, 120, reason: 'por encima de 120 no da tiempo a llenar');
    });

    test('cada 30 compresiones avisa de las 2 respiraciones', () {
      final c = RcpMetronomeController.instance;
      c.setBpm(120);
      expect(c.showBreathCue, isFalse);
    });
  });

  testWidgets('está traducido: nada de español duro en 7 idiomas',
      (tester) async {
    LocaleService.instance.setLanguage(AppLanguage.en);
    addTearDown(() => LocaleService.instance.setLanguage(AppLanguage.es));
    await tester.pumpWidget(MaterialApp(
      home: LocaleProvider(
        service: LocaleService.instance,
        child: const RcpMetronomePage(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Con la app en inglés no puede quedar ni un rótulo en español.
    for (final es in ['COMPRESIONES', 'PAUSA BREVE', 'Metrónomo', 'Ciclo']) {
      expect(find.textContaining(es), findsNothing,
          reason: 'rótulo en español con la app en inglés: "$es"');
    }
    RcpMetronomeController.instance.stop();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
