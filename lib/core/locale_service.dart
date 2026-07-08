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
    'sosFrom', 'position', 'noGps', 'viewOnMap', 'moreModules',
    'lowBattery', 'lowBatteryHint',
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

    // ── SOS dialog (core: must be readable in every language) ──
    'sosFrom': {
      'es': '¡SOS de', 'en': 'SOS from', 'pt': 'SOS de',
      'fr': 'SOS de', 'zh': 'SOS来自', 'ja': 'SOS発信者:', 'ht': 'SOS soti nan',
    },
    'position': {
      'es': 'Posición', 'en': 'Position', 'pt': 'Posição',
      'fr': 'Position', 'zh': '位置', 'ja': '位置', 'ht': 'Pozisyon',
    },
    'noGps': {
      'es': 'Sin posición GPS (fuera de cobertura)',
      'en': 'No GPS position (out of coverage)',
      'pt': 'Sem posição GPS (fora de cobertura)',
      'fr': 'Pas de position GPS (hors couverture)',
      'zh': '无GPS位置（超出范围）',
      'ja': 'GPS位置なし（圏外）',
      'ht': 'Pa gen pozisyon GPS',
    },
    'viewOnMap': {
      'es': 'Ver en mapa', 'en': 'View on map', 'pt': 'Ver no mapa',
      'fr': 'Voir sur la carte', 'zh': '在地图上查看', 'ja': '地図で見る',
      'ht': 'Gade sou kat la',
    },
    'moreModules': {
      'es': 'Más módulos', 'en': 'More modules', 'pt': 'Mais módulos',
      'fr': 'Plus de modules', 'zh': '更多模块', 'ja': 'その他のモジュール',
      'ht': 'Plis modil',
    },

    // ── Mesh / Communication (core: the emergency chat itself) ──
    'meshTitle': {
      'es': 'Comunicación (sin internet)', 'en': 'Communication (no internet)',
      'pt': 'Comunicação (sem internet)', 'fr': 'Communication (sans internet)',
      'zh': '通信（无需互联网）', 'ja': '通信（インターネット不要）',
      'ht': 'Kominikasyon (san entènèt)',
    },
    'nearby': {
      'es': 'cerca', 'en': 'nearby', 'pt': 'por perto',
      'fr': 'à proximité', 'zh': '附近', 'ja': '近く', 'ht': 'toupre',
    },
    'searchingDevices': {
      'es': 'buscando dispositivos…', 'en': 'searching for devices…',
      'pt': 'procurando dispositivos…', 'fr': 'recherche d\'appareils…',
      'zh': '正在搜索设备…', 'ja': 'デバイスを検索中…', 'ht': 'ap chèche aparèy…',
    },
    'queuedNoReach': {
      'es': 'en cola (sin alcance)', 'en': 'queued (out of reach)',
      'pt': 'na fila (fora de alcance)', 'fr': 'en attente (hors de portée)',
      'zh': '排队中（无法送达）', 'ja': '送信待ち（圏外）',
      'ht': 'nan liy (pa gen rive)',
    },
    'emergencyAskHelp': {
      'es': 'Emergencia — pedir ayuda', 'en': 'Emergency — ask for help',
      'pt': 'Emergência — pedir ajuda', 'fr': 'Urgence — demander de l\'aide',
      'zh': '紧急情况 — 求助', 'ja': '緊急 — 助けを求める',
      'ht': 'Ijans — mande èd',
    },
    'activateSosQ': {
      'es': '¿Activar SOS?', 'en': 'Activate SOS?', 'pt': 'Ativar SOS?',
      'fr': 'Activer le SOS ?', 'zh': '激活SOS？', 'ja': 'SOSを発信しますか？',
      'ht': 'Aktive SOS?',
    },
    'sosBody': {
      'es': 'Tu posición y esta nota se difundirán cada minuto a TODOS los '
          'Prepper Pad al alcance (no solo tu grupo), hasta que lo canceles.',
      'en': 'Your position and this note will broadcast every minute to ALL '
          'Prepper Pads in range (not just your group) until you cancel.',
      'pt': 'Sua posição e esta nota serão transmitidas a cada minuto a '
          'TODOS os Prepper Pads ao alcance (não só seu grupo), até cancelar.',
      'fr': 'Votre position et cette note seront diffusées chaque minute à '
          'TOUS les Prepper Pads à portée (pas seulement votre groupe), '
          'jusqu\'à annulation.',
      'zh': '您的位置和此备注将每分钟广播给范围内的所有Prepper Pad（不仅是您的群组），直到您取消。',
      'ja': 'あなたの位置とメモは、キャンセルするまで毎分、範囲内のすべてのPrepper Padに送信されます（グループ外にも）。',
      'ht': 'Pozisyon ou ak nòt sa a ap difize chak minit bay TOUT Prepper '
          'Pad ki nan zòn nan, jiskaske ou anile li.',
    },
    'sosNoteHint': {
      'es': 'Nota (opcional): ¿qué pasa?', 'en': 'Note (optional): what\'s happening?',
      'pt': 'Nota (opcional): o que houve?', 'fr': 'Note (optionnel) : que se passe-t-il ?',
      'zh': '备注（可选）：发生了什么？', 'ja': 'メモ（任意）：何が起きていますか？',
      'ht': 'Nòt (si ou vle): kisa k ap pase?',
    },
    'activateSos': {
      'es': 'ACTIVAR SOS', 'en': 'ACTIVATE SOS', 'pt': 'ATIVAR SOS',
      'fr': 'ACTIVER SOS', 'zh': '激活SOS', 'ja': 'SOS発信',
      'ht': 'AKTIVE SOS',
    },
    'imSafeCancelSos': {
      'es': 'ESTOY A SALVO (cancelar SOS)', 'en': "I'M SAFE (cancel SOS)",
      'pt': 'ESTOU BEM (cancelar SOS)', 'fr': 'JE SUIS EN SÉCURITÉ (annuler)',
      'zh': '我安全了（取消SOS）', 'ja': '安全です（SOS解除）',
      'ht': 'M BYEN (anile SOS)',
    },
    'shareMyPosition': {
      'es': 'Compartir mi posición', 'en': 'Share my position',
      'pt': 'Compartilhar minha posição', 'fr': 'Partager ma position',
      'zh': '分享我的位置', 'ja': '位置を共有', 'ht': 'Pataje pozisyon mwen',
    },
    'channels': {
      'es': 'Canales', 'en': 'Channels', 'pt': 'Canais',
      'fr': 'Canaux', 'zh': '频道', 'ja': 'チャンネル', 'ht': 'Kanal',
    },
    'createChannel': {
      'es': 'Crear canal', 'en': 'Create channel', 'pt': 'Criar canal',
      'fr': 'Créer un canal', 'zh': '创建频道', 'ja': 'チャンネル作成',
      'ht': 'Kreye kanal',
    },
    'joinChannel': {
      'es': 'Unirse a un canal', 'en': 'Join a channel',
      'pt': 'Entrar em um canal', 'fr': 'Rejoindre un canal',
      'zh': '加入频道', 'ja': 'チャンネルに参加', 'ht': 'Antre nan yon kanal',
    },
    'join': {
      'es': 'Unirme', 'en': 'Join', 'pt': 'Entrar',
      'fr': 'Rejoindre', 'zh': '加入', 'ja': '参加', 'ht': 'Antre',
    },
    'create': {
      'es': 'Crear', 'en': 'Create', 'pt': 'Criar',
      'fr': 'Créer', 'zh': '创建', 'ja': '作成', 'ht': 'Kreye',
    },
    'done': {
      'es': 'Listo', 'en': 'Done', 'pt': 'Pronto',
      'fr': 'Terminé', 'zh': '完成', 'ja': '完了', 'ht': 'Fini',
    },
    'copyCode': {
      'es': 'Copiar código', 'en': 'Copy code', 'pt': 'Copiar código',
      'fr': 'Copier le code', 'zh': '复制代码', 'ja': 'コードをコピー',
      'ht': 'Kopye kòd la',
    },
    'codeCopied': {
      'es': 'Código copiado', 'en': 'Code copied', 'pt': 'Código copiado',
      'fr': 'Code copié', 'zh': '代码已复制', 'ja': 'コードをコピーしました',
      'ht': 'Kòd kopye',
    },
    'invalidCode': {
      'es': 'Código inválido — revisa que esté completo.',
      'en': 'Invalid code — check that it\'s complete.',
      'pt': 'Código inválido — verifique se está completo.',
      'fr': 'Code invalide — vérifiez qu\'il est complet.',
      'zh': '代码无效 — 请检查是否完整。',
      'ja': 'コードが無効です — 完全か確認してください。',
      'ht': 'Kòd la pa bon — verifye li konplè.',
    },
    'groupNameHint': {
      'es': 'Nombre del grupo (ej. Familia)', 'en': 'Group name (e.g. Family)',
      'pt': 'Nome do grupo (ex. Família)', 'fr': 'Nom du groupe (ex. Famille)',
      'zh': '群组名称（如：家人）', 'ja': 'グループ名（例：家族）',
      'ht': 'Non gwoup la (egz. Fanmi)',
    },
    'pasteCodeHint': {
      'es': 'Pega el código PPMESH1:…', 'en': 'Paste the PPMESH1:… code',
      'pt': 'Cole o código PPMESH1:…', 'fr': 'Collez le code PPMESH1:…',
      'zh': '粘贴 PPMESH1:… 代码', 'ja': 'PPMESH1:… コードを貼り付け',
      'ht': 'Kole kòd PPMESH1:… a',
    },
    'askCreator': {
      'es': 'Pídelo al que creó el canal', 'en': 'Ask the channel creator',
      'pt': 'Peça a quem criou o canal', 'fr': 'Demandez au créateur du canal',
      'zh': '向频道创建者索取', 'ja': 'チャンネル作成者に聞いてください',
      'ht': 'Mande moun ki kreye kanal la',
    },
    'joinInstructions': {
      'es': 'En el otro dispositivo: Comunicación → Unirse y pega este '
          'código. El QR sirve para copiarlo con un lector externo.',
      'en': 'On the other device: Communication → Join and paste this code. '
          'The QR lets you copy it with an external reader.',
      'pt': 'No outro dispositivo: Comunicação → Entrar e cole este código. '
          'O QR serve para copiá-lo com um leitor externo.',
      'fr': 'Sur l\'autre appareil : Communication → Rejoindre et collez ce '
          'code. Le QR permet de le copier avec un lecteur externe.',
      'zh': '在另一台设备上：通信 → 加入，粘贴此代码。二维码可用外部扫码器复制。',
      'ja': '他のデバイスで：通信 → 参加でこのコードを貼り付け。QRは外部リーダーでのコピー用です。',
      'ht': 'Sou lòt aparèy la: Kominikasyon → Antre epi kole kòd sa a.',
    },
    'joinedChannel': {
      'es': 'Unido a', 'en': 'Joined', 'pt': 'Entrou em',
      'fr': 'Rejoint', 'zh': '已加入', 'ja': '参加しました:', 'ht': 'Ou antre nan',
    },
    'channelWord': {
      'es': 'Canal', 'en': 'Channel', 'pt': 'Canal',
      'fr': 'Canal', 'zh': '频道', 'ja': 'チャンネル', 'ht': 'Kanal',
    },
    'meshOnboardTitle': {
      'es': 'Prepper Mesh', 'en': 'Prepper Mesh', 'pt': 'Prepper Mesh',
      'fr': 'Prepper Mesh', 'zh': 'Prepper Mesh', 'ja': 'Prepper Mesh',
      'ht': 'Prepper Mesh',
    },
    'meshOnboardSubtitle': {
      'es': 'Conexión de emergencia sin internet',
      'en': 'Emergency connection without internet',
      'pt': 'Conexão de emergência sem internet',
      'fr': 'Connexion d\'urgence sans internet',
      'zh': '无需互联网的紧急连接',
      'ja': 'インターネット不要の緊急通信',
      'ht': 'Koneksyon ijans san entènèt',
    },
    'deviceNameLabel': {
      'es': 'Nombre de este dispositivo', 'en': 'Name of this device',
      'pt': 'Nome deste dispositivo', 'fr': 'Nom de cet appareil',
      'zh': '此设备的名称', 'ja': 'このデバイスの名前',
      'ht': 'Non aparèy sa a',
    },
    'deviceNameHint': {
      'es': 'ej. Tablet de Ana', 'en': 'e.g. Ana\'s tablet',
      'pt': 'ex. Tablet da Ana', 'fr': 'ex. Tablette d\'Ana',
      'zh': '如：安娜的平板', 'ja': '例：アナのタブレット',
      'ht': 'egz. Tablèt Ana',
    },
    'start': {
      'es': 'Empezar', 'en': 'Start', 'pt': 'Começar',
      'fr': 'Commencer', 'zh': '开始', 'ja': '開始', 'ht': 'Kòmanse',
    },
    'loraTitle': {
      'es': 'Radio LoRa (largo alcance)', 'en': 'LoRa radio (long range)',
      'pt': 'Rádio LoRa (longo alcance)', 'fr': 'Radio LoRa (longue portée)',
      'zh': 'LoRa 无线电（远距离）', 'ja': 'LoRa 無線（長距離）',
      'ht': 'Radyo LoRa (long distans)',
    },
    'loraSubtitle': {
      'es': 'Conecta un módulo LoRa por Bluetooth para alcance de kilómetros.',
      'en': 'Pair a LoRa module over Bluetooth for kilometer-range reach.',
      'pt': 'Conecte um módulo LoRa por Bluetooth para alcance de km.',
      'fr': 'Associez un module LoRa en Bluetooth pour une portée de km.',
      'zh': '通过蓝牙配对 LoRa 模块，实现公里级覆盖。',
      'ja': 'BluetoothでLoRaモジュールを接続し、キロ単位の到達距離。',
      'ht': 'Konekte yon modil LoRa sou Bluetooth pou plizyè kilomèt.',
    },

    // ── Empty states: download-in-place (ES/EN/PT/FR) ──
    'emptyMapsTitle': {
      'es': 'Descarga el mapa de tu país',
      'en': 'Download your country map',
      'pt': 'Baixe o mapa do seu país',
      'fr': 'Téléchargez la carte de votre pays',
    },
    'emptyMapsBody': {
      'es': 'Un toque y queda guardado en este dispositivo: funciona para '
          'siempre sin internet, con búsqueda y rutas.',
      'en': 'One tap and it lives on this device: works forever without '
          'internet, with search and routing.',
      'pt': 'Um toque e fica salvo neste dispositivo: funciona para sempre '
          'sem internet, com busca e rotas.',
      'fr': 'Un geste et elle reste sur cet appareil : fonctionne pour '
          'toujours sans internet, avec recherche et itinéraires.',
    },
    'downloadMap': {
      'es': 'Descargar mapa', 'en': 'Download map',
      'pt': 'Baixar mapa', 'fr': 'Télécharger la carte',
    },
    'moreCountries': {
      'es': 'Más países y regiones en el Depósito',
      'en': 'More countries and regions in the Depot',
      'pt': 'Mais países e regiões no Depósito',
      'fr': 'Plus de pays et régions dans le Dépôt',
    },
    'needInternetOnce': {
      'es': 'Necesitas internet solo para esta descarga.',
      'en': 'You need internet only for this download.',
      'pt': 'Você precisa de internet só para este download.',
      'fr': 'Internet n\'est requis que pour ce téléchargement.',
    },
    'emptyLibraryTitle': {
      'es': 'Tu biblioteca está vacía',
      'en': 'Your library is empty',
      'pt': 'Sua biblioteca está vazia',
      'fr': 'Votre bibliothèque est vide',
    },
    'emptyLibraryBody': {
      'es': 'Descarga primeros auxilios, supervivencia y Wikipedia médica '
          'con un toque. Después funcionan sin internet.',
      'en': 'Download first aid, survival and medical Wikipedia in one tap. '
          'They work offline afterwards.',
      'pt': 'Baixe primeiros socorros, sobrevivência e Wikipédia médica com '
          'um toque. Depois funcionam sem internet.',
      'fr': 'Téléchargez premiers secours, survie et Wikipédia médical en un '
          'geste. Ensuite tout fonctionne hors ligne.',
    },
    'downloadStarterPack': {
      'es': 'Descargar paquete inicial', 'en': 'Download starter pack',
      'pt': 'Baixar pacote inicial', 'fr': 'Télécharger le pack de départ',
    },
    'browseCatalog': {
      'es': 'Ver catálogo completo', 'en': 'Browse full catalog',
      'pt': 'Ver catálogo completo', 'fr': 'Voir le catalogue complet',
    },

    // ── Battery banner (core: safety-relevant) ──
    'lowBattery': {
      'es': 'Batería baja', 'en': 'Low battery', 'pt': 'Bateria fraca',
      'fr': 'Batterie faible', 'zh': '电量低', 'ja': 'バッテリー残量低下',
      'ht': 'Batri fèb',
    },
    'lowBatteryHint': {
      'es': 'Activa el ahorro para durar más.',
      'en': 'Turn on saver mode to last longer.',
      'pt': 'Ative a economia para durar mais.',
      'fr': 'Activez l\'économie pour durer plus.',
      'zh': '开启省电模式以延长续航。',
      'ja': '省電力モードで長持ちさせましょう。',
      'ht': 'Aktive mòd ekonomi pou dire pi lontan.',
    },

    // ── Tools / Notes / Prep (ES/EN/PT/FR) ──
    'batterySaverTitle': {
      'es': 'Modo Ahorro Batería', 'en': 'Battery Saver Mode',
      'pt': 'Modo Economia de Bateria', 'fr': 'Mode économie de batterie',
    },
    'lowerBrightness': {
      'es': 'Bajar brillo de pantalla', 'en': 'Lower screen brightness',
      'pt': 'Reduzir brilho da tela', 'fr': 'Baisser la luminosité',
    },
    'pauseRadios': {
      'es': 'Pausar radios de comunicación', 'en': 'Pause communication radios',
      'pt': 'Pausar rádios de comunicação', 'fr': 'Suspendre les radios',
    },
    'pauseAi': {
      'es': 'Pausar asistente de IA', 'en': 'Pause AI assistant',
      'pt': 'Pausar assistente de IA', 'fr': 'Suspendre l\'assistant IA',
    },
    'deactivateRestore': {
      'es': 'Desactivar y restaurar configuración',
      'en': 'Deactivate and restore settings',
      'pt': 'Desativar e restaurar configuração',
      'fr': 'Désactiver et restaurer les réglages',
    },
    'emergencyWhistle': {
      'es': 'Silbato de Emergencia', 'en': 'Emergency Whistle',
      'pt': 'Apito de Emergência', 'fr': 'Sifflet d\'urgence',
    },
    'calibrateCompass': {
      'es': 'Calibrar brújula', 'en': 'Calibrate compass',
      'pt': 'Calibrar bússola', 'fr': 'Calibrer la boussole',
    },
    'selectOrCreateNote': {
      'es': 'Selecciona o crea una nota', 'en': 'Select or create a note',
      'pt': 'Selecione ou crie uma nota', 'fr': 'Sélectionnez ou créez une note',
    },
    'deleteNoteQ': {
      'es': '¿Eliminar nota?', 'en': 'Delete note?',
      'pt': 'Excluir nota?', 'fr': 'Supprimer la note ?',
    },
    'delete': {
      'es': 'Eliminar', 'en': 'Delete', 'pt': 'Excluir', 'fr': 'Supprimer',
    },
    'writeMarkdown': {
      'es': 'Escribe en markdown…', 'en': 'Write in markdown…',
      'pt': 'Escreva em markdown…', 'fr': 'Écrivez en markdown…',
    },
    'familyPrep': {
      'es': 'Preparación Familiar', 'en': 'Family Preparation',
      'pt': 'Preparação Familiar', 'fr': 'Préparation familiale',
    },

    // ── Depot tabs (ES/EN/PT/FR) ──
    'essentials': {
      'es': 'Esenciales', 'en': 'Essentials',
      'pt': 'Essenciais', 'fr': 'Essentiels',
    },
    'aiModels': {
      'es': 'Modelos IA', 'en': 'AI Models',
      'pt': 'Modelos IA', 'fr': 'Modèles IA',
    },
    'downloads': {
      'es': 'Descargas', 'en': 'Downloads',
      'pt': 'Downloads', 'fr': 'Téléchargements',
    },
    'appTab': {
      'es': 'App', 'en': 'App', 'pt': 'App', 'fr': 'App',
    },

    // ── AI / Updates (ES/EN/PT/FR) ──
    'load': {
      'es': 'Cargar', 'en': 'Load', 'pt': 'Carregar', 'fr': 'Charger',
    },
    'loadAnyway': {
      'es': 'Cargar igual', 'en': 'Load anyway',
      'pt': 'Carregar mesmo assim', 'fr': 'Charger quand même',
    },
    'discard': {
      'es': 'Descartar', 'en': 'Discard', 'pt': 'Descartar', 'fr': 'Rejeter',
    },
    'stop': {
      'es': 'Detener', 'en': 'Stop', 'pt': 'Parar', 'fr': 'Arrêter',
    },
    'tightMemory': {
      'es': 'Memoria ajustada', 'en': 'Tight memory',
      'pt': 'Memória apertada', 'fr': 'Mémoire limitée',
    },
    'model': {
      'es': 'Modelo', 'en': 'Model', 'pt': 'Modelo', 'fr': 'Modèle',
    },
    'downloadReady': {
      'es': 'Descarga lista.', 'en': 'Download ready.',
      'pt': 'Download pronto.', 'fr': 'Téléchargement prêt.',
    },
    'saveAndSearch': {
      'es': 'Guardar y buscar', 'en': 'Save and check',
      'pt': 'Salvar e buscar', 'fr': 'Enregistrer et vérifier',
    },
    'installNow': {
      'es': 'Instalar ahora', 'en': 'Install now',
      'pt': 'Instalar agora', 'fr': 'Installer maintenant',
    },
    'updateServer': {
      'es': 'Servidor de actualizaciones', 'en': 'Update server',
      'pt': 'Servidor de atualizações', 'fr': 'Serveur de mises à jour',
    },
    'server': {
      'es': 'Servidor', 'en': 'Server', 'pt': 'Servidor', 'fr': 'Serveur',
    },
    'upToDate': {
      'es': 'Ya tienes la última versión.', 'en': 'You have the latest version.',
      'pt': 'Você já tem a versão mais recente.',
      'fr': 'Vous avez la dernière version.',
    },

    // ── Welcome wizard ──
    'welcomeTitle': {
      'es': 'Bienvenido a Prepper Pad',
      'en': 'Welcome to Prepper Pad',
      'pt': 'Bem-vindo ao Prepper Pad',
      'fr': 'Bienvenue sur Prepper Pad',
    },
    'welcomeBodyIos': {
      'es': 'Prepper Pad guarda tu biblioteca de conocimiento offline dentro '
          'de la app (visible también en la app Archivos). Desde Depósito '
          'descargas lo que necesites — mapas por país, Wikipedia médica, '
          'guías — y queda disponible sin internet. Todo vive en tu '
          'dispositivo; nada se sube a ningún servidor.',
      'en': 'Prepper Pad keeps your offline knowledge library inside the app '
          '(also visible in the Files app). From Depot you download what you '
          'need — country maps, medical Wikipedia, guides — and it stays '
          'available without internet. Everything lives on your device; '
          'nothing is uploaded to any server.',
      'pt': 'O Prepper Pad guarda sua biblioteca de conhecimento offline '
          'dentro do app (visível também no app Arquivos). No Depósito você '
          'baixa o que precisar — mapas por país, Wikipédia médica, guias — '
          'e fica disponível sem internet. Tudo vive no seu dispositivo; '
          'nada é enviado a nenhum servidor.',
      'fr': 'Prepper Pad garde votre bibliothèque de connaissances hors '
          'ligne dans l\'app (visible aussi dans l\'app Fichiers). Depuis '
          'Dépôt, téléchargez ce qu\'il vous faut — cartes par pays, '
          'Wikipédia médical, guides — disponible sans internet. Tout reste '
          'sur votre appareil ; rien n\'est envoyé à aucun serveur.',
    },
    'welcomeBodyDesktop': {
      'es': 'Tu biblioteca de conocimiento offline vive en la carpeta '
          'PrepperPad de tu usuario. Esta instalación ya trae un paquete '
          'base offline incluido: mapas, Wikipedia médica, una mini '
          'Wikipedia y un modelo IA liviano. En el primer arranque se copian '
          'automáticamente a esa carpeta para que funcionen sin internet y '
          'puedas copiarlos a otros dispositivos por USB.\n\nDesde Depósito '
          'puedes agregar más países, ZIMs o modelos grandes cuando tengas '
          'internet o por transferencia local.',
      'en': 'Your offline knowledge library lives in the PrepperPad folder '
          'of your user. This install already includes a base offline pack: '
          'maps, medical Wikipedia, a mini Wikipedia and a light AI model. '
          'On first launch they are copied there automatically so they work '
          'without internet and you can copy them to other devices over '
          'USB.\n\nFrom Depot you can add more countries, ZIMs or bigger '
          'models when you have internet or via local transfer.',
      'pt': 'Sua biblioteca de conhecimento offline vive na pasta PrepperPad '
          'do seu usuário. Esta instalação já inclui um pacote base offline: '
          'mapas, Wikipédia médica, uma mini Wikipédia e um modelo IA leve. '
          'Na primeira execução eles são copiados automaticamente para '
          'funcionar sem internet e poder copiá-los a outros dispositivos '
          'por USB.\n\nNo Depósito você pode adicionar mais países, ZIMs ou '
          'modelos maiores com internet ou por transferência local.',
      'fr': 'Votre bibliothèque hors ligne vit dans le dossier PrepperPad de '
          'votre utilisateur. Cette installation inclut déjà un pack de '
          'base : cartes, Wikipédia médical, une mini Wikipédia et un modèle '
          'IA léger. Au premier lancement ils y sont copiés automatiquement '
          'pour fonctionner sans internet et pouvoir être copiés sur '
          'd\'autres appareils par USB.\n\nDepuis Dépôt, ajoutez plus de '
          'pays, ZIMs ou modèles avec internet ou par transfert local.',
    },
    'viewStarterPack': {
      'es': 'Ver Paquete inicial', 'en': 'View Starter Pack',
      'pt': 'Ver Pacote inicial', 'fr': 'Voir le pack de départ',
    },
    'explore': {
      'es': 'Explorar', 'en': 'Explore', 'pt': 'Explorar', 'fr': 'Explorer',
    },

    // ── Mesh UI — strings that were previously hardcoded in mesh_page.dart ──
    'emergencyChannelSubtitle': {
      'es': 'Abierto a todos los dispositivos cercanos',
      'en': 'Open to all nearby devices',
      'pt': 'Aberto para todos os dispositivos próximos',
      'fr': 'Ouvert à tous les appareils à proximité',
      'zh': '对所有附近设备开放',
      'ja': '近くの全デバイスに開放',
      'ht': 'Ouvè pou tout aparèy toupre',
    },
    'noChannelsHint': {
      'es': 'Crea un canal para tu familia o grupo y compártelo por código QR. '
          'Los mensajes van cifrados: solo quien tiene el código puede leerlos.',
      'en': 'Create a channel for your family or group and share it via QR code. '
          'Messages are encrypted: only those with the code can read them.',
      'pt': 'Crie um canal para sua família ou grupo e compartilhe pelo código QR. '
          'As mensagens são criptografadas: só quem tem o código pode lê-las.',
      'fr': 'Créez un canal pour votre famille ou groupe et partagez-le via QR. '
          'Les messages sont chiffrés : seul celui qui a le code peut les lire.',
      'zh': '为家人或群组创建频道并通过二维码分享。消息已加密：只有持有代码的人才能阅读。',
      'ja': '家族やグループ用チャンネルを作成しQRコードで共有。メッセージは暗号化され、コードを持つ人だけが読めます。',
      'ht': 'Kreye yon kanal pou fanmi ou gwoup ou epi pataje l pa kòd QR. '
          'Mesaj yo chifre: sèlman moun ki gen kòd la ka li yo.',
    },
    'meshOnboardDesc': {
      'es': 'Chatea, comparte tu posición y lanza SOS entre dispositivos cercanos '
          'SIN internet (misma red WiFi o hotspot). ¿Cómo quieres que te vean los demás?',
      'en': 'Chat, share your position and launch SOS between nearby devices '
          'WITHOUT internet (same WiFi or hotspot). How do you want others to see you?',
      'pt': 'Converse, compartilhe sua posição e envie SOS entre dispositivos próximos '
          'SEM internet (mesma rede WiFi ou hotspot). Como quer que os outros te vejam?',
      'fr': 'Discutez, partagez votre position et lancez SOS entre appareils proches '
          'SANS internet (même WiFi ou hotspot). Comment voulez-vous que les autres vous voient?',
      'zh': '在附近设备之间聊天、分享位置和发送SOS，无需互联网（同一WiFi或热点）。您希望别人如何看到您？',
      'ja': '近くのデバイス間でインターネットなしでチャット、位置共有、SOS発信。他の人にどう見られたいですか？',
      'ht': 'Tchate, pataje pozisyon ou epi voye SOS ant aparèy toupre SANS entènèt '
          '(menm rezo WiFi oswa hotspot). Ki jan ou vle lòt moun wè ou?',
    },
    'sosActiveDesc': {
      'es': 'SOS ACTIVO — difundiendo tu posición cada minuto a todos los dispositivos al alcance.',
      'en': 'SOS ACTIVE — broadcasting your position every minute to all devices in range.',
      'pt': 'SOS ATIVO — transmitindo sua posição a cada minuto para todos os dispositivos ao alcance.',
      'fr': 'SOS ACTIF — diffusion de votre position chaque minute à tous les appareils à portée.',
      'zh': 'SOS激活 — 每分钟向范围内所有设备广播您的位置。',
      'ja': 'SOS発信中 — 毎分、範囲内の全デバイスに位置を送信中。',
      'ht': 'SOS AKTIF — ap difize pozisyon ou chak minit bay tout aparèy ki nan zòn nan.',
    },
    'sosCardSubtitle': {
      'es': 'Difunde tu posición a cualquier dispositivo cercano, sin claves',
      'en': 'Broadcast your position to any nearby device, no keys needed',
      'pt': 'Difunda sua posição para qualquer dispositivo próximo, sem chaves',
      'fr': 'Diffusez votre position à tout appareil proche, sans clé',
      'zh': '向任何附近设备广播您的位置，无需密钥',
      'ja': '近くのデバイスに位置を送信、鍵不要',
      'ht': 'Difize pozisyon ou bay nenpòt aparèy toupre, san kle',
    },
    'meshInstructions': {
      'es': '1) Activa Bluetooth. 2) Si hay varios equipos, usa un hotspot o '
          'la misma Wi‑Fi aunque no tenga internet. 3) En Android, Wi‑Fi Direct '
          'busca pares sin router. 4) Si conectas radio LoRa compatible, '
          'Prepper Mesh usará el mismo protocolo de mensajes.',
      'en': '1) Enable Bluetooth. 2) If using multiple devices, share a hotspot '
          'or the same Wi‑Fi even without internet. 3) On Android, Wi‑Fi Direct '
          'finds peers without a router. 4) If you connect a compatible LoRa radio, '
          'Prepper Mesh will use the same message protocol.',
      'pt': '1) Ative o Bluetooth. 2) Se houver vários equipamentos, use um hotspot '
          'ou o mesmo Wi‑Fi sem internet. 3) No Android, o Wi‑Fi Direct encontra '
          'pares sem roteador. 4) Se conectar um rádio LoRa compatível, o Prepper '
          'Mesh usará o mesmo protocolo.',
      'fr': '1) Activez le Bluetooth. 2) Si plusieurs appareils, utilisez un hotspot '
          'ou le même Wi‑Fi sans internet. 3) Sur Android, Wi‑Fi Direct trouve des '
          'pairs sans routeur. 4) Si vous connectez une radio LoRa compatible, '
          'Prepper Mesh utilisera le même protocole.',
      'zh': '1) 启用蓝牙。2) 如果有多台设备，即使没有互联网也可使用热点或相同Wi-Fi。'
          '3) 在Android上，Wi-Fi Direct无需路由器即可查找设备。4) 如果连接兼容的LoRa收音机，'
          'Prepper Mesh将使用相同的消息协议。',
      'ja': '1) Bluetoothを有効にする。2) 複数デバイス使用時はホットスポットや同じWi-Fiを共有。'
          '3) AndroidではWi-Fi Directがルーターなしでピアを検索。4) 互換LoRAラジオを接続すると'
          'Prepper Meshが同じプロトコルを使用。',
      'ht': '1) Aktive Bluetooth. 2) Si gen plizyè aparèy, itilize yon hotspot oswa '
          'menm Wi‑Fi a menm san entènèt. 3) Sou Android, Wi‑Fi Direct jwenn pè san routeur. '
          '4) Si ou konekte yon radyo LoRa ki konpatib, Prepper Mesh ap itilize menm pwotokòl mesaj.',
    },
    'emergencyChannelTitle': {
      'es': 'EMERGENCIA (todos)',
      'en': 'EMERGENCY (everyone)',
      'pt': 'EMERGÊNCIA (todos)',
      'fr': 'URGENCE (tout le monde)',
      'zh': '紧急（所有人）',
      'ja': '緊急（全員）',
      'ht': 'IJANS (tout moun)',
    },
    'emergencyChannelTitleAll': {
      'es': 'EMERGENCIA (todos los cercanos)',
      'en': 'EMERGENCY (all nearby)',
      'pt': 'EMERGÊNCIA (todos próximos)',
      'fr': 'URGENCE (tous proches)',
      'zh': '紧急（所有附近）',
      'ja': '緊急（近くの全員）',
      'ht': 'IJANS (tout moun toupre)',
    },
    'emergencyWarning': {
      'es': 'Canal abierto SIN cifrar: lo lee cualquier Prepper Pad cercano. '
          'Úsalo para pedir o dar ayuda.',
      'en': 'Open channel, NOT encrypted: any nearby Prepper Pad can read it. '
          'Use it to ask for or give help.',
      'pt': 'Canal aberto SEM criptografia: qualquer Prepper Pad próximo pode lê-lo. '
          'Use para pedir ou dar ajuda.',
      'fr': 'Canal ouvert SANS chiffrement : tout Prepper Pad proche peut le lire. '
          'Utilisez-le pour demander ou offrir de l\'aide.',
      'zh': '开放频道，未加密：附近任何Prepper Pad均可读取。用于求助或提供帮助。',
      'ja': '暗号化なしの公開チャンネル：近くのPrepper Padなら誰でも読めます。助けを求めたり提供したりするために使用してください。',
      'ht': 'Kanal ouvè SANS chifraj: nenpòt Prepper Pad toupre ka li li. '
          'Itilize l pou mande oswa bay èd.',
    },
    'noMessagesHint': {
      'es': 'Sin mensajes. ¡Escribe el primero!',
      'en': 'No messages yet. Write the first one!',
      'pt': 'Sem mensagens. Escreva a primeira!',
      'fr': 'Aucun message. Rédigez le premier !',
      'zh': '暂无消息。写第一条！',
      'ja': 'メッセージなし。最初のメッセージを書いてください！',
      'ht': 'Pa gen mesaj. Ekri premye a!',
    },
    'noDevicesHint': {
      'es': 'Sin dispositivos al alcance.\nLos mensajes que envíes quedarán en '
          'cola y se entregarán cuando alguien aparezca.',
      'en': 'No devices in range.\nMessages you send will be queued and delivered '
          'when someone appears.',
      'pt': 'Sem dispositivos ao alcance.\nAs mensagens que você enviar ficarão '
          'na fila e serão entregues quando alguém aparecer.',
      'fr': 'Aucun appareil à portée.\nLes messages envoyés seront mis en file '
          'd\'attente et livrés quand quelqu\'un apparaîtra.',
      'zh': '没有设备在范围内。\n您发送的消息将排队等待，当有人出现时送达。',
      'ja': '範囲内にデバイスなし。\n送信したメッセージはキューに入り、誰かが現れたとき届きます。',
      'ht': 'Pa gen aparèy nan pòte.\nMesaj ou voye yo ap nan liy epi yo ap livre lè yon moun parèt.',
    },
    'messageHint': {
      'es': 'Mensaje…', 'en': 'Message…', 'pt': 'Mensagem…',
      'fr': 'Message…', 'zh': '消息…', 'ja': 'メッセージ…', 'ht': 'Mesaj…',
    },
    'messageHintEmergency': {
      'es': 'Mensaje para TODOS los cercanos…',
      'en': 'Message for ALL nearby…',
      'pt': 'Mensagem para TODOS os próximos…',
      'fr': 'Message pour TOUS les proches…',
      'zh': '给附近所有人发消息…',
      'ja': '近くの全員へメッセージ…',
      'ht': 'Mesaj pou TOUT moun toupre…',
    },
    'online': {
      'es': 'en línea', 'en': 'online', 'pt': 'online',
      'fr': 'en ligne', 'zh': '在线', 'ja': 'オンライン', 'ht': 'anliy',
    },
    'noneInRange': {
      'es': 'nadie al alcance', 'en': 'no one in range',
      'pt': 'ninguém ao alcance', 'fr': 'personne à portée',
      'zh': '没有人在范围内', 'ja': '範囲内にいません', 'ht': 'pèsonn nan pòte',
    },
    'showChannelCodeTooltip': {
      'es': 'Mostrar código / QR para invitar',
      'en': 'Show code / QR to invite',
      'pt': 'Mostrar código / QR para convidar',
      'fr': 'Afficher le code / QR pour inviter',
      'zh': '显示代码/二维码邀请',
      'ja': 'コード/QRを表示して招待',
      'ht': 'Montre kòd / QR pou envite',
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

/// Shorthand for call sites: `tr(context, 'key')`.
String tr(BuildContext context, String key) =>
    LocaleProvider.of(context).t(key);

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
