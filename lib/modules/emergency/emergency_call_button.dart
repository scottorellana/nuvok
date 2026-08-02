// Botón "LLAMAR {911}" — si la red celular sigue viva, la llamada real al
// sistema de emergencias sigue siendo lo más efectivo que existe. El número
// se resuelve offline por el país del dispositivo (emergency_numbers.dart).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_service.dart';
import 'emergency_numbers.dart';

/// Marca [number] de verdad. Si el aparato no tiene marcador (tablet, macOS,
/// Windows) muestra el número enorme para copiarlo a ojo desde otro teléfono.
///
/// Vive fuera del widget porque el directorio de teléfonos también debe
/// marcar: copiar al portapapeles obliga a salir de Nuvok, abrir el marcador
/// y pegar — tres pasos con las manos temblando.
Future<void> dialEmergencyNumber(BuildContext context, String number) async {
  final clean = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
  if (clean.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: clean);
  var ok = false;
  try {
    ok = await launchUrl(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showEmergencyNumberFallback(context, clean);
}

/// El número GRANDE, legible a un brazo de distancia, para marcarlo desde
/// cualquier otro aparato.
void showEmergencyNumberFallback(BuildContext context, String number) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(ctx, 'callEmergency')),
      content: Text(
        number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr(ctx, 'close')),
        ),
      ],
    ),
  );
}

class EmergencyCallButton extends StatelessWidget {
  const EmergencyCallButton({super.key, this.countryOverride});

  /// Para tests: fuerza un país en vez de leer el locale del dispositivo.
  final String? countryOverride;

  String get _number {
    final country = countryOverride ??
        EmergencyNumbers.countryFromLocale(
            WidgetsBinding.instance.platformDispatcher.locale.toString());
    return EmergencyNumbers.primaryFor(country);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        onPressed: () => dialEmergencyNumber(context, _number),
        icon: const Icon(Icons.phone, size: 26),
        label: Text('${tr(context, 'callEmergency')} $_number'),
      ),
    );
  }
}
