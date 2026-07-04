// Client for the public Kiwix OPDS catalog (library.kiwix.org) — the same
// content source Project NOMAD uses: Wikipedia, medical guides, ebooks, etc.
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

class CatalogItem {
  CatalogItem({
    required this.title,
    required this.summary,
    required this.url,
    required this.sizeBytes,
    this.iconUrl,
    this.language,
  });

  final String title;
  final String summary;
  final String url;
  final int? sizeBytes;
  final String? iconUrl;
  final String? language;
}

class KiwixCatalog {
  static const String base = 'https://library.kiwix.org';

  /// Searches the catalog. [lang] is an ISO 639-3 code like 'spa' or 'eng'.
  static Future<List<CatalogItem>> search({
    String query = '',
    String lang = '',
    int count = 40,
  }) async {
    final params = <String, String>{
      'count': '$count',
      if (query.isNotEmpty) 'q': query,
      if (lang.isNotEmpty) 'lang': lang,
    };
    final uri = Uri.parse('$base/catalog/v2/entries')
        .replace(queryParameters: params);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('Catálogo respondió HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return _parseOpds(body);
    } finally {
      client.close();
    }
  }

  static List<CatalogItem> _parseOpds(String xmlBody) {
    final doc = XmlDocument.parse(xmlBody);
    final items = <CatalogItem>[];
    for (final entry in doc.findAllElements('entry')) {
      final title = entry.getElement('title')?.innerText ?? 'Sin título';
      final summary = entry.getElement('summary')?.innerText ?? '';
      final language = entry.getElement('language')?.innerText;
      String? zimUrl;
      int? size;
      String? iconUrl;
      for (final link in entry.findElements('link')) {
        final rel = link.getAttribute('rel') ?? '';
        final href = link.getAttribute('href') ?? '';
        if (rel.contains('acquisition')) {
          zimUrl = href.endsWith('.meta4')
              ? href.substring(0, href.length - 6)
              : href;
          size = int.tryParse(link.getAttribute('length') ?? '');
        } else if (rel == 'http://opds-spec.org/image/thumbnail') {
          iconUrl = href.startsWith('http') ? href : '$base$href';
        }
      }
      if (zimUrl == null) continue;
      items.add(CatalogItem(
        title: title,
        summary: summary,
        url: zimUrl,
        sizeBytes: size,
        iconUrl: iconUrl,
        language: language,
      ));
    }
    return items;
  }
}

/// Curated GGUF models that run well on modest hardware. MoE models give the
/// best intelligence-per-RAM ratio (they activate only a fraction of their
/// weights per token).
class CuratedModel {
  const CuratedModel({
    required this.name,
    required this.description,
    required this.url,
    required this.approxBytes,
    this.minRamGb,
    this.languages = const ['EN'],
    this.tags = const [],
    this.recommended = false,
  });

  final String name;
  final String description;
  final String url;
  final int approxBytes;
  final int? minRamGb;
  final List<String> languages;
  final List<String> tags;
  final bool recommended;

  /// Filename extracted from the HuggingFace URL.
  String get fileName => Uri.parse(url).pathSegments.last;
}

const curatedModels = <CuratedModel>[
  CuratedModel(
    name: 'Llama 3.2 3B Instruct (Q4_K_M)',
    description:
        'Ligero y rápido — ideal para equipos con poca RAM o Raspberry Pi 5. '
        'Buen español.',
    url:
        'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    approxBytes: 2020000000,
    minRamGb: 4,
    languages: ['EN', 'ES'],
    tags: ['Rápido', 'Baja RAM'],
  ),
  CuratedModel(
    name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
    description:
        'Ultraligero — cabe en cualquier dispositivo, incluso tablets '
        'antiguas. Calidad limitada pero siempre disponible.',
    url:
        'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
    approxBytes: 442000000,
    minRamGb: 1,
    languages: ['EN', 'ES', 'ZH'],
    tags: ['Ultraligero'],
  ),
  CuratedModel(
    name: 'Qwen2.5 7B Instruct (Q4_K_M)',
    description:
        'Equilibrio calidad/velocidad para Mac con 16-18GB de RAM. '
        'Multilingüe sólido.',
    url:
        'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf',
    approxBytes: 4680000000,
    minRamGb: 8,
    languages: ['EN', 'ES', 'ZH', 'FR', 'DE'],
    tags: ['Recomendado', 'Multilingüe'],
    recommended: true,
  ),
  CuratedModel(
    name: 'Qwen2.5 14B Instruct (Q4_K_M)',
    description:
        'Mayor calidad de razonamiento. Requiere ~10GB de RAM libre — '
        'úsalo con pocas apps abiertas.',
    url:
        'https://huggingface.co/bartowski/Qwen2.5-14B-Instruct-GGUF/resolve/main/Qwen2.5-14B-Instruct-Q4_K_M.gguf',
    approxBytes: 8990000000,
    minRamGb: 16,
    languages: ['EN', 'ES', 'ZH', 'FR', 'DE'],
    tags: ['Alta calidad'],
  ),
  CuratedModel(
    name: 'Llama 3.2 1B Instruct (Q4_K_M)',
    description:
        'Compacto y capaz — el punto dulce para tablets Android. '
        'Razona bien en español e inglés con solo 1GB.',
    url:
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    approxBytes: 808000000,
    minRamGb: 2,
    languages: ['EN', 'ES'],
    tags: ['Tablet'],
  ),
];
