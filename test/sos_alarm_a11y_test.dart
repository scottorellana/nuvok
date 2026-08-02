import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/emergency/sos_alarm.dart';

/// La alarma SOS es a pantalla completa y solo se calla tocando "Entendido".
/// Con el texto del sistema en grande (personas mayores, visión reducida — el
/// perfil que MÁS usa una app de emergencia) el contenido crecía y el botón
/// quedaba fuera de pantalla: la alarma sonaba y no había forma de callarla.
void main() {
  Future<void> pumpAlarm(WidgetTester tester, double scale) async {
    SosAlarmController.instance.trigger(
      fromName: 'Vecina del 3B',
      note: 'Atrapada bajo un mueble, sangra la pierna',
    );
    addTearDown(() async {
      SosAlarmController.instance.silence();
      // Drenar los timers de parpadeo/escalada antes de que el binding
      // verifique que no quedan pendientes.
      await tester.pump(const Duration(milliseconds: 100));
    });
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: LocaleProvider(
          service: LocaleService.instance,
          child: const SosAlarmWrapper(child: SizedBox.expand()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('el botón de silenciar es alcanzable a textScale $scale',
        (tester) async {
      // Teléfono pequeño: el caso más apretado y el más común.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpAlarm(tester, scale);

      final boton = find.byType(FilledButton);
      expect(boton, findsOneWidget, reason: 'no se encontró el botón');

      // Si está fuera del viewport, hacerlo visible debe ser posible
      // (scroll) — y tras ello debe poder tocarse de verdad.
      // pump fijo, no pumpAndSettle: la alarma parpadea en bucle infinito
      // por diseño y nunca "asienta".
      await tester.ensureVisible(boton);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(boton);
      await tester.pump(const Duration(milliseconds: 200));

      expect(SosAlarmController.instance.alarming, isFalse,
          reason: 'la alarma sigue sonando: el botón no se pudo tocar');
    });
  }

  testWidgets('sin desbordes de layout a textScale 2.0', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await pumpAlarm(tester, 2.0);
    // tester.takeException() captura los RenderFlex overflow.
    expect(tester.takeException(), isNull,
        reason: 'la pantalla que salva vidas no puede desbordar');
    SosAlarmController.instance.silence();
  });
}
