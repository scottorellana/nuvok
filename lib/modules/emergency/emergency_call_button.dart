// Botón "LLAMAR {911}" — si la red celular sigue viva, la llamada real al
// sistema de emergencias sigue siendo lo más efectivo que existe. El número
// se resuelve offline por el país del dispositivo (emergency_numbers.dart).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_service.dart';
import 'emergency_numbers.dart';

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

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _number);
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) _showFallback(context);
    } catch (_) {
      if (context.mounted) _showFallback(context);
    }
  }

  void _showFallback(BuildContext context) {
    // Sin app de teléfono (tablet/desktop): mostrar el número GRANDE para
    // marcarlo desde cualquier otro aparato.
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'callEmergency')),
        content: Text(
          _number,
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
        onPressed: () => _call(context),
        icon: const Icon(Icons.phone, size: 26),
        label: Text('${tr(context, 'callEmergency')} $_number'),
      ),
    );
  }
}
