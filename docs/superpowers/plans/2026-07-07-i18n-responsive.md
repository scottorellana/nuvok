# Idiomas del sistema + responsive — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline; sin subagentes por RAM). Steps use checkbox (`- [ ]`) syntax.

**Goal:** La app sigue el idioma del dispositivo (7 idiomas, núcleo perfecto), toda la interfaz pasa por AppStrings, y queda optimizada para teléfono/tablet/computadora, lista para App Store.

**Architecture:** Se adopta el WIP existente (LocaleService/AppStrings/LocaleProvider/Settings). AppStrings se vuelve data-driven (mapa estático `_map` de claves → traducciones, getters delgados `t('clave')`) para poder testear cobertura. MaterialApp gana locale reactivo + delegados de flutter_localizations. Migración módulo por módulo reemplazando literales por `LocaleProvider.of(context).xxx`.

**Tech Stack:** flutter_localizations (SDK), patrón InheritedNotifier existente. Sin codegen.

---

### Task 1: Base sólida (fallback, prefs iOS-safe, MaterialApp, tests)

**Files:** Modify `lib/core/locale_service.dart`, `lib/app.dart`, `pubspec.yaml`; Create `test/locale_service_test.dart`.

- [ ] Test primero (`test/locale_service_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/core/locale_service.dart';

void main() {
  test('fromLocale detecta variantes regionales', () {
    expect(AppLanguage.fromLocale(const Locale('pt', 'BR')), AppLanguage.pt);
    expect(AppLanguage.fromLocale(const Locale.fromSubtags(
        languageCode: 'zh', scriptCode: 'Hans')), AppLanguage.zh);
    expect(AppLanguage.fromLocale(const Locale('de')), AppLanguage.es,
        reason: 'idioma no soportado cae a español (público principal)');
  });

  test('fallback: idioma → en → es (nunca español fijo para un usuario zh)',
      () {
    // 'welcome' existe solo es/en/pt/fr en el mapa (no core).
    final zh = AppStrings(AppLanguage.zh);
    expect(zh.t('welcomeTitle'), AppStrings(AppLanguage.en).t('welcomeTitle'),
        reason: 'clave sin zh debe caer a inglés');
  });

  test('cobertura: toda clave tiene es+en; las core tienen los 7', () {
    for (final entry in AppStrings.allKeys.entries) {
      expect(entry.value['es'], isNotNull, reason: 'falta es en ${entry.key}');
      expect(entry.value['en'], isNotNull, reason: 'falta en en ${entry.key}');
    }
    for (final key in AppStrings.coreKeys) {
      final map = AppStrings.allKeys[key]!;
      for (final lang in AppLanguage.values) {
        expect(map[lang.code], isNotNull,
            reason: 'clave core $key sin ${lang.code}');
      }
    }
  });
}
```

- [ ] Implementación en `locale_service.dart`:
  - `_t`/`t(key)`: `map[lang.code] ?? map['en'] ?? map['es']!`.
  - Refactor a `static const Map<String, Map<String, String>> allKeys` +
    `static const List<String> coreKeys` (nav + SOS + emergencia + mesh) +
    `String t(String key)`; los getters existentes delegan a `t(...)`.
  - Prefs: usar `PrepperLibrary.instance.root.path` (NO $HOME — en iOS eso es
    la raíz de solo-lectura y el idioma elegido jamás se guardaría).
- [ ] `pubspec.yaml`: `flutter_localizations: {sdk: flutter}`.
- [ ] `lib/app.dart` MaterialApp:

```dart
      locale: Locale(service.language.code),
      supportedLocales: [
        for (final l in AppLanguage.values) Locale(l.code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Kreyòl no existe en Flutter: el chrome del sistema cae a francés
      // (nuestros AppStrings sí muestran kreyòl).
      localeResolutionCallback: (locale, supported) {
        final code = locale?.languageCode;
        if (code == 'ht') return const Locale('fr');
        for (final s in supported) {
          if (s.languageCode == code) return s;
        }
        return const Locale('es');
      },
```

- [ ] `flutter test test/locale_service_test.dart` PASS + analyze + commit
  `feat(i18n): base de idiomas — detección del sistema, fallback en→es, prefs iOS-safe`
  (incluye adoptar lib/core/locale_service.dart y lib/modules/settings/).

### Task 2: Shell + wizard + banners (7 idiomas core)

**Files:** `lib/app.dart` (destinos ya usan strings? verificar; wizard, SOS dialog, "Más"), `lib/core/locale_service.dart` (claves nuevas).

- [ ] Migrar: títulos de navegación (ya existen), wizard de bienvenida (2
  variantes iOS/desktop), diálogo SOS entrante ('¡SOS de X!', 'Ver en mapa',
  'Cerrar', 'Sin posición GPS'), banner batería baja, banner update, pestaña
  'Más'. Claves core (7 idiomas). Suite + commit.

### Task 3: Emergencia + Comunicación (7 idiomas core)

**Files:** `lib/modules/emergency/emergency_page.dart` (chrome: MODO
EMERGENCIA, buscador, acceso rápido, teléfonos, descargo), `lib/modules/mesh/mesh_page.dart`
(onboarding, canales, chat hint, SOS activar/cancelar, presencia, unirse/crear).

- [ ] Migrar con claves core (7 idiomas). OJO: emergency_page tiene WIP de
  otra sesión — tocar SOLO literales de UI, no su estructura. Suite + commit.

### Task 4: Herramientas + Ahorro batería (ES/EN/PT/FR)

**Files:** `lib/modules/tools/*.dart` (tools_page, battery_saver, flashlight,
whistle, compass, cpr_metronome, etc.).

- [ ] Migrar literales visibles. Suite + commit.

### Task 5: Depósito + Updates + Ajustes (ES/EN/PT/FR)

**Files:** `lib/modules/depot/depot_page.dart` (6 tabs, diálogos servidor
local/URL/importar), `lib/modules/update/update_page.dart`, settings_page.

- [ ] Migrar. Suite + commit.

### Task 6: Mapas + Notas + IA (ES/EN/PT/FR)

**Files:** `lib/modules/maps/maps_page.dart` (chrome/búsqueda/capas),
`lib/modules/notes/notes_page.dart`, `lib/modules/ai/ai_page.dart` (incl.
mensaje iOS).

- [ ] Migrar. Suite + commit.

### Task 7: Responsive en 3 tamaños + verificación de idioma en vivo

- [ ] macOS (ventana grande + angosta), iPhone sim (390pt) y **iPad sim**:
  correr, navegar módulos, buscar overflows/textos cortados (grep del log:
  'OVERFLOW'). Arreglar lo encontrado (patrón Row→Wrap / SingleChildScrollView).
- [ ] Prueba de idioma real: simulador con locale en-US → app arranca en
  inglés; cambiar a 中文 en Ajustes → navegación cambia al instante.
  Capturas de evidencia.

### Task 8: Cierre App Store

- [ ] `ios/Runner/Info.plist`: `CFBundleLocalizations` (array con es, en, pt,
  fr, zh, ja, ht) + `CFBundleDevelopmentRegion` = es.
- [ ] pubspec `version: 0.3.0+1`. Suite completa + analyze. Builds: sim iOS +
  macOS. Commit + push + memoria.
