// Créditos y licencias del contenido y software de terceros.
//
// No es decorativo: los mapas (ODbL), la Wikipedia médica (CC BY-SA) y varias
// librerías EXIGEN atribución. Sin esta pantalla, Nuvok incumple esas
// licencias — y al venderse, eso es un riesgo real, no un tecnicismo.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';

class _Credit {
  const _Credit({
    required this.title,
    required this.license,
    required this.detail,
  });
  final String title;
  final String license;
  final String detail;
}

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  static const _content = <_Credit>[
    _Credit(
      title: 'OpenStreetMap',
      license: 'ODbL 1.0',
      detail: 'Datos de mapa © colaboradores de OpenStreetMap. '
          'Teselas generadas con Protomaps. openstreetmap.org/copyright',
    ),
    _Credit(
      title: 'Wikipedia / Wikipedia médica',
      license: 'CC BY-SA 4.0',
      detail: 'Contenido de Wikipedia y WikiMed, empaquetado por Kiwix. '
          'Se distribuye bajo la misma licencia. kiwix.org',
    ),
    _Credit(
      title: 'Gemma 4 (Google)',
      license: 'Apache 2.0',
      detail: 'Modelo de IA que corre dentro del dispositivo.',
    ),
    _Credit(
      title: 'Qwen 2.5 (Alibaba Cloud)',
      license: 'Apache 2.0',
      detail: 'Modelo de IA de respaldo, incluido en la instalación.',
    ),
    _Credit(
      title: 'llama.cpp (ggml)',
      license: 'MIT',
      detail: 'Motor que ejecuta los modelos de IA sin conexión.',
    ),
    _Credit(
      title: 'Zstandard (Meta)',
      license: 'BSD',
      detail: 'Descompresión de la biblioteca offline.',
    ),
    _Credit(
      title: 'Flutter y paquetes de terceros',
      license: 'BSD / MIT y otras',
      detail: 'La lista completa está en "Licencias de software" (abajo).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'creditsTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr(context, 'creditsIntro')),
            ),
          ),
          const SizedBox(height: 8),
          for (final c in _content)
            Card(
              child: ListTile(
                title: Text(c.title),
                subtitle: Text('${c.license}\n${c.detail}'),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'creditsModelsTitle'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(tr(context, 'creditsModelsBody')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Lista completa generada por Flutter con TODAS las dependencias.
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(tr(context, 'creditsSoftware')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Nuvok',
            ),
          ),
        ],
      ),
    );
  }
}
