// Locale service — manages the app language without external dependencies.
// Supports switching between multiple languages at runtime. Persists the
// choice so the app reopens in the same language.
//
// Designed for emergency use: first launch follows the DEVICE language; the
// user can override from Settings and that choice sticks. Translations are a
// single testable registry ([AppStrings.allKeys]) with a strict fallback
// chain: requested language → English → Spanish. Core safety surfaces
// ([AppStrings.coreKeys]) are guaranteed complete in all seven languages by
// test/locale_service_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'prepper_library.dart';

enum AppLanguage {
  es('Español', '🇪🇸', 'es'),
  en('English', '🇺🇸', 'en'),
  pt('Português', '🇧🇷', 'pt'),
  fr('Français', '🇫🇷', 'fr'),
  zh('中文', '🇨🇳', 'zh'),
  ja('日本語', '🇯🇵', 'ja'),
  ht('Kreyòl', '🇭🇹', 'ht');

  final String displayName;
  final String flag;
  final String code;
  const AppLanguage(this.displayName, this.flag, this.code);

  static AppLanguage fromCode(String? code) {
    if (code == null) return es;
    for (final l in AppLanguage.values) {
      if (l.code == code) return l;
    }
    return es;
  }

  /// Best language for a device locale (region/script variants included).
  static AppLanguage fromLocale(Locale? locale) {
    if (locale == null) return es;
    return fromCode(locale.languageCode.toLowerCase());
  }
}

/// Centralized translations. Module content with its own language system
/// (e.g. the emergency guide BODIES, ES/EN assets) stays there; every UI
/// string goes through here.
class AppStrings {
  final AppLanguage lang;
  AppStrings(this.lang);

  /// Requested language → English → Spanish → the key itself (visible in
  /// dev instead of crashing in the field).
  String t(String key) {
    final map = allKeys[key];
    if (map == null) return key;
    return map[lang.code] ?? map['en'] ?? map['es'] ?? key;
  }

  // ── Compatibility getters (existing call sites) ──
  String get emergency => t('emergency');
  String get library => t('library');
  String get assistant => t('assistant');
  String get maps => t('maps');
  String get comms => t('comms');
  String get prep => t('prep');
  String get tools => t('tools');
  String get notes => t('notes');
  String get depot => t('depot');
  String get open => t('open');
  String get close => t('close');
  String get cancel => t('cancel');
  String get save => t('save');
  String get search => t('search');
  String get settings => t('settings');
  String get language => t('language');
  String get sos => t('sos');
  String get sosActive => t('sosActive');
  String get imSafe => t('imSafe');
  String get flashlight => t('flashlight');
  String get whistle => t('whistle');
  String get compass => t('compass');
  String get rcpMetronome => t('rcpMetronome');

  /// Keys that MUST exist in all seven languages: navigation and the
  /// life-critical surfaces (emergency, SOS, mesh). Enforced by test.
  static const List<String> coreKeys = [
    'emergency', 'library', 'assistant', 'maps', 'comms', 'prep', 'tools',
    'notes', 'depot', 'more', 'open', 'close', 'cancel', 'save', 'search',
    'settings', 'language', 'sos', 'sosActive', 'imSafe', 'flashlight',
    'whistle', 'compass', 'rcpMetronome',
  ];

  static const Map<String, Map<String, String>> allKeys = {
    // ── Navigation ──
    'emergency': {
      'es': 'Emergencia', 'en': 'Emergency', 'pt': 'Emergência',
      'fr': 'Urgence', 'zh': '紧急', 'ja': '緊急', 'ht': 'Ijans',
    },
    'library': {
      'es': 'Biblioteca', 'en': 'Library', 'pt': 'Biblioteca',
      'fr': 'Bibliothèque', 'zh': '图书馆', 'ja': 'ライブラリ', 'ht': 'Bibliyotèk',
    },
    'assistant': {
      'es': 'Asistente IA', 'en': 'AI Assistant', 'pt': 'Assistente IA',
      'fr': 'Assistant IA', 'zh': 'AI助手', 'ja': 'AIアシスタント', 'ht': 'Asistan AI',
    },
    'maps': {
      'es': 'Mapas', 'en': 'Maps', 'pt': 'Mapas',
      'fr': 'Cartes', 'zh': '地图', 'ja': '地図', 'ht': 'Kat',
    },
    'comms': {
      'es': 'Comunicación', 'en': 'Communication', 'pt': 'Comunicação',
      'fr': 'Communication', 'zh': '通信', 'ja': '通信', 'ht': 'Kominikasyon',
    },
    'prep': {
      'es': 'Preparación', 'en': 'Preparation', 'pt': 'Preparação',
      'fr': 'Préparation', 'zh': '准备', 'ja': '準備', 'ht': 'Preparasyon',
    },
    'tools': {
      'es': 'Herramientas', 'en': 'Tools', 'pt': 'Ferramentas',
      'fr': 'Outils', 'zh': '工具', 'ja': 'ツール', 'ht': 'Zouti',
    },
    'notes': {
      'es': 'Notas', 'en': 'Notes', 'pt': 'Notas',
      'fr': 'Notes', 'zh': '笔记', 'ja': 'ノート', 'ht': 'Nòt',
    },
    'depot': {
      'es': 'Depósito', 'en': 'Depot', 'pt': 'Depósito',
      'fr': 'Dépôt', 'zh': '仓库', 'ja': 'デポ', 'ht': 'Depo',
    },
    'more': {
      'es': 'Más', 'en': 'More', 'pt': 'Mais',
      'fr': 'Plus', 'zh': '更多', 'ja': 'その他', 'ht': 'Plis',
    },

    // ── Common actions ──
    'open': {
      'es': 'Abrir', 'en': 'Open', 'pt': 'Abrir',
      'fr': 'Ouvrir', 'zh': '打开', 'ja': '開く', 'ht': 'Louvri',
    },
    'close': {
      'es': 'Cerrar', 'en': 'Close', 'pt': 'Fechar',
      'fr': 'Fermer', 'zh': '关闭', 'ja': '閉じる', 'ht': 'Fèmen',
    },
    'cancel': {
      'es': 'Cancelar', 'en': 'Cancel', 'pt': 'Cancelar',
      'fr': 'Annuler', 'zh': '取消', 'ja': 'キャンセル', 'ht': 'Anile',
    },
    'save': {
      'es': 'Guardar', 'en': 'Save', 'pt': 'Salvar',
      'fr': 'Enregistrer', 'zh': '保存', 'ja': '保存', 'ht': 'Sove',
    },
    'search': {
      'es': 'Buscar', 'en': 'Search', 'pt': 'Buscar',
      'fr': 'Rechercher', 'zh': '搜索', 'ja': '検索', 'ht': 'Chèche',
    },
    'settings': {
      'es': 'Configuración', 'en': 'Settings', 'pt': 'Configurações',
      'fr': 'Paramètres', 'zh': '设置', 'ja': '設定', 'ht': 'Konfigirasyon',
    },
    'language': {
      'es': 'Idioma', 'en': 'Language', 'pt': 'Idioma',
      'fr': 'Langue', 'zh': '语言', 'ja': '言語', 'ht': 'Lang',
    },

    // ── Emergency / SOS ──
    'sos': {
      'es': 'SOS', 'en': 'SOS', 'pt': 'SOS',
      'fr': 'SOS', 'zh': 'SOS', 'ja': 'SOS', 'ht': 'SOS',
    },
    'sosActive': {
      'es': 'SOS ACTIVO', 'en': 'SOS ACTIVE', 'pt': 'SOS ATIVO',
      'fr': 'SOS ACTIF', 'zh': 'SOS激活', 'ja': 'SOS発信中', 'ht': 'SOS AKTIF',
    },
    'imSafe': {
      'es': 'ESTOY A SALVO', 'en': "I'M SAFE", 'pt': 'ESTOU BEM',
      'fr': 'JE SUIS EN SÉCURITÉ', 'zh': '我安全了', 'ja': '安全です', 'ht': 'M BYEN',
    },

    // ── Tools ──
    'flashlight': {
      'es': 'Linterna', 'en': 'Flashlight', 'pt': 'Lanterna',
      'fr': 'Lampe', 'zh': '手电筒', 'ja': 'ライト', 'ht': 'Lanp',
    },
    'whistle': {
      'es': 'Silbato', 'en': 'Whistle', 'pt': 'Apito',
      'fr': 'Sifflet', 'zh': '哨子', 'ja': 'ホイッスル', 'ht': 'Siflè',
    },
    'compass': {
      'es': 'Brújula', 'en': 'Compass', 'pt': 'Bússola',
      'fr': 'Boussole', 'zh': '指南针', 'ja': 'コンパス', 'ht': 'Bousol',
    },
    'rcpMetronome': {
      'es': 'RCP Metrónomo', 'en': 'CPR Metronome', 'pt': 'RCP Metrônomo',
      'fr': 'Métronome RCP', 'zh': 'CPR节拍器', 'ja': 'CPRメトロノーム',
      'ht': 'Metwonòm RCP',
    },

    // ── Welcome wizard ──
    'welcomeTitle': {
      'es': 'Bienvenido a Prepper Pad',
      'en': 'Welcome to Prepper Pad',
      'pt': 'Bem-vindo ao Prepper Pad',
      'fr': 'Bienvenue sur Prepper Pad',
    },
  };
}

/// Notifier that holds the current language and persists it.
/// Inject at the top of the widget tree so the entire app rebuilds on change.
class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  AppLanguage _language = AppLanguage.es;
  AppLanguage get language => _language;
  AppStrings get strings => AppStrings(_language);
  Locale get locale => Locale(_language.code);

  bool _inited = false;

  /// Initialize once: a saved explicit choice wins; otherwise follow the
  /// device language. Call from main() with the platform locale.
  void init({Locale? deviceLocale}) {
    if (_inited) return;
    _inited = true;
    final saved = _loadSaved();
    if (saved != null) {
      _language = saved;
    } else if (deviceLocale != null) {
      _language = AppLanguage.fromLocale(deviceLocale);
    }
  }

  AppLanguage? _loadSaved() {
    try {
      final f = _prefsFile();
      if (f == null || !f.existsSync()) return null;
      final json = jsonDecode(f.readAsStringSync());
      final code = json['language'] as String?;
      if (code == null) return null;
      return AppLanguage.fromCode(code);
    } catch (_) {
      return null;
    }
  }

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    _save();
  }

  void _save() {
    try {
      _prefsFile()?.writeAsStringSync('{"language":"${_language.code}"}');
    } catch (_) {}
  }

  /// Prefs live inside the PrepperPad library root, which is
  /// platform-correct everywhere. Deriving it from $HOME broke iOS ($HOME
  /// doesn't exist there → read-only '/', the choice silently never saved).
  File? _prefsFile() {
    try {
      return File('${PrepperLibrary.instance.root.path}/locale.json');
    } catch (_) {
      // PrepperLibrary not initialized (tests) — no persistence, no crash.
      return null;
    }
  }
}

/// InheritedWidget that provides AppStrings to the entire tree.
class LocaleProvider extends InheritedNotifier<LocaleService> {
  const LocaleProvider({
    super.key,
    required LocaleService service,
    required super.child,
  }) : super(notifier: service);

  static AppStrings of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<LocaleProvider>();
    if (widget?.notifier != null) {
      return widget!.notifier!.strings;
    }
    return AppStrings(AppLanguage.es); // fallback
  }

  static LocaleService serviceOf(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<LocaleProvider>();
    return widget?.notifier ?? LocaleService.instance;
  }
}
