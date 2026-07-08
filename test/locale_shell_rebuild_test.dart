import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/locale_service.dart';

// Reproduce el bug visto en vivo: al cambiar idioma, las páginas (Ajustes)
// se repintaban pero el NavigationRail del shell seguía en español. El shell
// debe reetiquetarse igual que cualquier página.
//
// Se testea con un mini-shell equivalente (mismo mecanismo: rail dentro de
// LayoutBuilder que lee LocaleProvider.of(context)) para no arrancar toda la
// app (mesh, batería, archivos) en un widget test.
class _MiniShell extends StatelessWidget {
  const _MiniShell();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: 0,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final key in const ['emergency', 'maps', 'comms'])
                    NavigationRailDestination(
                      icon: const Icon(Icons.circle),
                      label: Text(LocaleProvider.of(context).t(key)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      const Expanded(child: SizedBox()),
    ]);
  }
}

void main() {
  testWidgets('cambiar idioma reetiqueta el NavigationRail al instante',
      (tester) async {
    final service = LocaleService.instance;
    service.setLanguage(AppLanguage.es);

    await tester.pumpWidget(ListenableBuilder(
      listenable: service,
      builder: (context, _) => MaterialApp(
        locale: service.locale,
        supportedLocales: [
          for (final l in AppLanguage.values) Locale(l.code),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supported) {
          if (locale?.languageCode == 'ht') return const Locale('fr');
          return supported.firstWhere(
              (s) => s.languageCode == locale?.languageCode,
              orElse: () => const Locale('es'));
        },
        home: LocaleProvider(service: service, child: const _MiniShell()),
      ),
    ));

    expect(find.text('Emergencia'), findsOneWidget);

    service.setLanguage(AppLanguage.zh);
    await tester.pumpAndSettle();

    expect(find.text('紧急'), findsOneWidget,
        reason: 'el rail debe reetiquetarse al cambiar idioma');
    expect(find.text('Emergencia'), findsNothing);

    service.setLanguage(AppLanguage.es); // no contaminar otros tests
  });
}
