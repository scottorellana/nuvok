import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';
import 'package:nuvok/modules/emergency/emergency_guides.dart';
import 'package:nuvok/modules/emergency/emergency_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('emergency guides start in the active runtime language',
      (tester) async {
    final service = LocaleService.instance;
    final original = service.language;
    addTearDown(() => service.setLanguage(original));
    service.setLanguage(AppLanguage.ja);

    await tester.pumpWidget(
      LocaleProvider(
        service: service,
        child: const MaterialApp(home: EmergencyPage()),
      ),
    );
    await tester.pumpAndSettle();

    final selector = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('emergency-guide-language-selector')),
    );
    expect(selector.value, 'ja');
    expect(
      selector.items!.map((item) => item.value).toSet(),
      AppLanguage.values.map((language) => language.code).toSet(),
    );
  });

  testWidgets('late language load cannot overwrite the current language',
      (tester) async {
    final service = LocaleService.instance;
    final original = service.language;
    addTearDown(() => service.setLanguage(original));
    service.setLanguage(AppLanguage.es);

    final pending = <String, Completer<List<EmergencyGuide>>>{};
    Future<List<EmergencyGuide>> loader(String language) =>
        (pending[language] ??= Completer<List<EmergencyGuide>>()).future;
    EmergencyGuide guide(String language, String title) => EmergencyGuide(
          id: 'test_$language',
          lang: language,
          title: title,
          keywords: const ['test'],
          priority: 1,
          body: '## Test',
        );

    await tester.pumpWidget(
      LocaleProvider(
        service: service,
        child: MaterialApp(home: EmergencyPage(guideLoader: loader)),
      ),
    );
    await tester.pump();

    var selector = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('emergency-guide-language-selector')),
    );
    selector.onChanged!('pt');
    await tester.pump();
    selector = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('emergency-guide-language-selector')),
    );
    selector.onChanged!('fr');
    await tester.pump();

    pending['fr']!.complete([guide('fr', 'Guide français')]);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(find.text('Guide français'), findsOneWidget);

    pending['pt']!.complete([guide('pt', 'Guia portuguesa atrasada')]);
    await tester.pumpAndSettle();
    expect(find.text('Guide français'), findsOneWidget);
    expect(find.text('Guia portuguesa atrasada'), findsNothing);

    pending['es']!.complete([guide('es', 'Guía española atrasada')]);
    await tester.pump();
  });
}
