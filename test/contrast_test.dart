import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/nuvok_colors.dart';

/// Contraste WCAG de los colores con los que Nuvok pinta acciones críticas.
/// No es estética: una app de emergencia se usa bajo sol directo, con humo,
/// con la pantalla atenuada al mínimo para ahorrar batería o con la vista
/// cansada por el estrés. Un botón que "se ve bien" en una oficina puede ser
/// ilegible en el momento que importa.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // AA para texto grande y componentes de interfaz.
  const aaLarge = 3.0;
  // AA para texto normal: lo que exigimos a los botones que salvan.
  const aaNormal = 4.5;

  group('texto sobre los fondos de acción', () {
    final casos = <String, (Color fondo, Color texto)>{
      'caution (naranja) con negro': (NuvokColors.caution, NuvokColors.black),
      'safe (verde claro) con negro': (NuvokColors.safe, NuvokColors.black),
      'olive con negro': (NuvokColors.olive, NuvokColors.black),
      'emergencyDeep con blanco': (NuvokColors.emergencyDeep, Colors.white),
      'oliveDark con blanco': (NuvokColors.oliveDark, Colors.white),
    };

    casos.forEach((nombre, par) {
      test('$nombre supera AA normal', () {
        final r = contrast(par.$1, par.$2);
        expect(r, greaterThanOrEqualTo(aaNormal),
            reason: '$nombre da ${r.toStringAsFixed(2)}:1 — ilegible bajo sol '
                'o con la pantalla atenuada al mínimo');
      });
    });
  });

  group('los fondos claros NO deben llevar texto blanco', () {
    for (final entry in {
      'caution': NuvokColors.caution,
      'safe': NuvokColors.safe,
      'olive': NuvokColors.olive,
    }.entries) {
      test('${entry.key} con blanco NO alcanza ni AA grande', () {
        // Este test documenta POR QUÉ el texto de esos botones es negro:
        // si alguien lo cambia a blanco, falla aquí y no en una emergencia.
        expect(contrast(entry.value, Colors.white), lessThan(aaLarge),
            reason: '${entry.key} con blanco parece aceptable pero no lo es');
      });
    }
  });

  test('texto principal sobre el fondo de la app', () {
    expect(contrast(NuvokColors.background, NuvokColors.text),
        greaterThanOrEqualTo(aaNormal));
  });

  _onColorTests();
}

/// El helper que la app usa de verdad para elegir el color de texto.
void _onColorTests() {
  group('NuvokColors.onColor elige el contraste que salva', () {
    test('fondos claros → texto negro', () {
      for (final c in [NuvokColors.caution, NuvokColors.safe, NuvokColors.olive]) {
        expect(NuvokColors.onColor(c), NuvokColors.black);
        expect(contrast(c, NuvokColors.onColor(c)), greaterThanOrEqualTo(4.5));
      }
    });

    test('fondos oscuros → texto blanco', () {
      for (final c in [
        NuvokColors.emergencyDeep,
        NuvokColors.oliveDark,
        NuvokColors.background,
      ]) {
        expect(NuvokColors.onColor(c), NuvokColors.white);
        expect(contrast(c, NuvokColors.onColor(c)), greaterThanOrEqualTo(4.5));
      }
    });

    test('el rojo de emergencia queda legible con lo que elija', () {
      final fg = NuvokColors.onColor(NuvokColors.emergency);
      expect(contrast(NuvokColors.emergency, fg), greaterThanOrEqualTo(4.5),
          reason: 'el botón de SANGRADO FUERTE debe leerse bajo sol');
    });
  });
}
