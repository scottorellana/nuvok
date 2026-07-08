// Tools page — quick survival tools accessible from the nav rail.
// Groups battery saver, flashlight, compass, whistle, RCP metronome, and GPS track.
// All cards use a consistent dark palette matching the app theme.
import 'package:flutter/material.dart';

import 'battery_saver.dart';
import 'compass.dart';
import 'flashlight.dart';
import 'rcp_metronome.dart';
import 'whistle.dart';
import '../maps/gpx_recorder.dart';
import '../../core/locale_service.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  // Consistent card surface for the dark olive theme.
  static const _cardSurface = Color(0xFF1A1F12);
  static const _dimText = Color(0xFF8A9070);
  static const _brightText = Color(0xFFE8F0D8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'tools'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Battery saver ──
          ListenableBuilder(
            listenable: BatterySaverController.instance,
            builder: (context, _) {
              final b = BatterySaverController.instance;
              final low = b.batteryKnown && b.batteryLevel <= 20;
              return _ToolCard(
                icon: b.isCharging
                    ? Icons.battery_charging_full
                    : Icons.battery_saver,
                iconColor:
                    low ? const Color(0xFFEF5350) : const Color(0xFF8C9E5E),
                title: b.batteryKnown
                    ? 'Batería: ${b.batteryLevel}%'
                        '${b.isCharging ? ' · cargando' : ''}'
                    : 'Ahorro de batería',
                subtitle: low
                    ? '⚠️ Batería baja. Activa el ahorro para durar más.'
                    : 'Maximiza la autonomía en una emergencia.',
                subtitleColor: low ? const Color(0xFFEF5350) : _dimText,
                buttonText: 'Abrir',
                onPressed: () => _push(context, const BatterySaverPage()),
              );
            },
          ),

          // ── Whistle ──
          _ToolCard(
            icon: Icons.campaign,
            iconColor: const Color(0xFFEF5350),
            title: 'Silbato de Emergencia',
            subtitle:
                'Silbato digital de alta frecuencia (3 kHz) audible a larga '
                'distancia. Incluye modo pulsado y flash de pantalla.',
            buttonText: 'Activar',
            buttonColor: const Color(0xFFC62828),
            onPressed: () => _push(context, const WhistleScreen()),
          ),

          // ── RCP Metronome ──
          _ToolCard(
            icon: Icons.monitor_heart,
            iconColor: const Color(0xFFE57373),
            title: 'RCP Metrónomo',
            subtitle:
                'Mantiene el ritmo correcto de compresiones (100-120 BPM) '
                'con contador y aviso de respiraciones 30:2.',
            buttonText: 'Iniciar',
            buttonColor: const Color(0xFFC62828),
            onPressed: () => _push(context, const RcpMetronomePage()),
          ),

          // ── GPS Track Recorder ──
          _ToolCard(
            icon: Icons.route,
            iconColor: const Color(0xFF8C9E5E),
            title: 'GPS Track + GPX',
            subtitle: null,
            extra: const GpxRecorderWidget(),
            footerText: 'Graba tu ruta y expórtala como GPX 1.1 para usarla '
                'en otros mapas o dispositivos Garmin.',
            onPressed: null,
          ),

          // ── Flashlight ──
          _ToolCard(
            icon: Icons.flashlight_on,
            iconColor: const Color(0xFFFFAB40),
            title: 'Linterna / SOS luminoso',
            subtitle: 'Ilumina con el flash de la cámara. Activa SOS para '
                'señal luminosa en código Morse (...---...).',
            buttonText: 'Abrir',
            onPressed: () => _push(context, const FlashlightScreen()),
          ),

          // ── Compass ──
          _ToolCard(
            icon: Icons.explore,
            iconColor: const Color(0xFF8C9E5E),
            title: 'Brújula',
            subtitle: null,
            extra: const Padding(
              padding: EdgeInsets.only(top: 20),
              child: CompassWidget(),
            ),
            onPressed: null,
          ),

          const SizedBox(height: 8),

          // ── Tip ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4A4A2A), width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Color(0xFFFFAB40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Consejo: calibra la brújula moviendo el dispositivo '
                      'en forma de 8 antes de usarla. En emergencias, la '
                      'linterna en modo SOS es visible a kilómetros en la '
                      'oscuridad.',
                      style: const TextStyle(color: _dimText, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

/// A consistent tool card with dark surface, bright title, dim subtitle,
/// and an optional action button. Eliminates the rainbow of card colors
/// that previously broke the dark theme.
class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.buttonText,
    this.buttonColor,
    this.onPressed,
    this.extra,
    this.footerText,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final String? buttonText;
  final Color? buttonColor;
  final VoidCallback? onPressed;
  final Widget? extra;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ToolsPage._cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ToolsPage._brightText,
                    ),
                  ),
                ),
                if (buttonText != null && onPressed != null)
                  FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(buttonText!),
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonColor,
                    ),
                  ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: subtitleColor ?? ToolsPage._dimText),
              ),
            ],
            if (extra != null) extra!,
            if (footerText != null) ...[
              const SizedBox(height: 8),
              Text(
                footerText!,
                style: const TextStyle(color: ToolsPage._dimText, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
