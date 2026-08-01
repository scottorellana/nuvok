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

import 'nuvok_library.dart';

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
    // Asistente de conexión: superficie vital — 7 idiomas obligatorios.
    'meshBannerConnected', 'meshBannerSearching', 'meshBannerTapHelp',
    'advisorTitle', 'advisorBtOff', 'advisorBtOffBody',
    'advisorBtPerm', 'advisorBtPermBody', 'advisorHotspot',
    'advisorHotspotBody', 'advisorLora', 'advisorLoraBody',
    'voiceHold', 'voiceMicPermission', 'callEmergency',
    'aiSearchingGuides', 'aiSearchingLibrary', 'aiHintEmergency',
    'aiNoAiNoGuide', 'aiQuickRcp', 'aiQuickChoking', 'aiQuickBleeding',
    'aiQuickBurn', 'aiEmptyHint',
    'calcTitle', 'calcDoseTitle', 'calcWeightKg', 'calcPerDose',
    'calcIbuNotUnder5', 'calcOrsTitle', 'calcLiters', 'calcSugar',
    'calcSalt', 'calcTspNote', 'calcChlorineTitle', 'calcBleachPct',
    'calcCloudy', 'calcDrops', 'calcWait30', 'calcDisclaimer',
    'voiceRead', 'voiceStopRead',
    'tqTitle', 'tqApplied', 'tqWhere', 'tqWhereHint', 'tqStart', 'tqEmpty',
    'tqOkHint', 'tqWarnHint', 'tqCritHint', 'tqShare', 'tqShared', 'tqResolve',
    'iceTitle', 'iceIntro', 'iceName', 'iceBlood', 'iceAllergies', 'iceMeds',
    'iceConditions', 'iceContact1', 'iceContact2', 'iceShow', 'iceShareMesh',
    'dtTitle', 'dtResponds', 'dtBreathing', 'dtHadImpact', 'dtWhatHappens',
    'dtYes', 'dtNo', 'dtChoking', 'dtBleeding', 'dtBurn', 'dtChest',
    'dtSeizure', 'dtPoison',
    'mpTitle', 'mpGo', 'mpArrived', 'mpPending', 'mpNoPositions',
    'beaconActive', 'beaconHint', 'beaconExit', 'beaconOpen',
    'modeBosque', 'modeDesierto', 'modeMar', 'modeMontana', 'modeCiudad',
    'modeRio', 'modePantano', 'modeArtico', 'modesTitle', 'modesIntro',
    'modeActivate', 'modeActive', 'modeDeactivate', 'modeComingSoon',
    'aiQuickModeWater', 'aiQuickModeDanger',
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
          'Nuvok al alcance (no solo tu grupo), hasta que lo canceles.',
      'en': 'Your position and this note will broadcast every minute to ALL '
          'Nuvoks in range (not just your group) until you cancel.',
      'pt': 'Sua posição e esta nota serão transmitidas a cada minuto a '
          'TODOS os Nuvoks ao alcance (não só seu grupo), até cancelar.',
      'fr': 'Votre position et cette note seront diffusées chaque minute à '
          'TOUS les Nuvoks à portée (pas seulement votre groupe), '
          'jusqu\'à annulation.',
      'zh': '您的位置和此备注将每分钟广播给范围内的所有Nuvok（不仅是您的群组），直到您取消。',
      'ja': 'あなたの位置とメモは、キャンセルするまで毎分、範囲内のすべてのNuvokに送信されます（グループ外にも）。',
      'ht': 'Pozisyon ou ak nòt sa a ap difize chak minit bay TOUT Nuvok '
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
      'es': 'Pega el código NUVOK1:…', 'en': 'Paste the NUVOK1:… code',
      'pt': 'Cole o código NUVOK1:…', 'fr': 'Collez le code NUVOK1:…',
      'zh': '粘贴 NUVOK1:… 代码', 'ja': 'NUVOK1:… コードを貼り付け',
      'ht': 'Kole kòd NUVOK1:… a',
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
      'es': 'Nuvok Link', 'en': 'Nuvok Link', 'pt': 'Nuvok Link',
      'fr': 'Nuvok Link', 'zh': 'Nuvok Link', 'ja': 'Nuvok Link',
      'ht': 'Nuvok Link',
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

    // ── AI assistant status (ES/EN/PT/FR) ──
    'aiSearchingGuides': {
      'es': 'Buscando en las guías…', 'en': 'Searching the guides…',
      'pt': 'Buscando nos guias…', 'fr': 'Recherche dans les guides…',
      'zh': '正在搜索指南…', 'ja': 'ガイドを検索中…', 'ht': 'K ap chèche nan gid yo…',
    },
    'aiSearchingLibrary': {
      'es': 'Buscando en la biblioteca…', 'en': 'Searching the library…',
      'pt': 'Buscando na biblioteca…', 'fr': 'Recherche dans la bibliothèque…',
      'zh': '正在搜索图书馆…', 'ja': 'ライブラリを検索中…',
      'ht': 'K ap chèche nan bibliyotèk la…',
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
      'es': 'Bienvenido a Nuvok',
      'en': 'Welcome to Nuvok',
      'pt': 'Bem-vindo ao Nuvok',
      'fr': 'Bienvenue sur Nuvok',
    },
    'welcomeBodyIos': {
      'es': 'Nuvok guarda tu biblioteca de conocimiento sin conexión dentro '
          'de la app (visible también en la app Archivos). Desde Depósito '
          'descargas lo que necesites — mapas por país, Wikipedia médica, '
          'guías — y queda disponible sin internet. Todo vive en tu '
          'dispositivo; nada se sube a ningún servidor.',
      'en': 'Nuvok keeps your offline knowledge library inside the app '
          '(also visible in the Files app). From Depot you download what you '
          'need — country maps, medical Wikipedia, guides — and it stays '
          'available without internet. Everything lives on your device; '
          'nothing is uploaded to any server.',
      'pt': 'O Nuvok guarda sua biblioteca de conhecimento offline '
          'dentro do app (visível também no app Arquivos). No Depósito você '
          'baixa o que precisar — mapas por país, Wikipédia médica, guias — '
          'e fica disponível sem internet. Tudo vive no seu dispositivo; '
          'nada é enviado a nenhum servidor.',
      'fr': 'Nuvok garde votre bibliothèque de connaissances hors '
          'ligne dans l\'app (visible aussi dans l\'app Fichiers). Depuis '
          'Dépôt, téléchargez ce qu\'il vous faut — cartes par pays, '
          'Wikipédia médical, guides — disponible sans internet. Tout reste '
          'sur votre appareil ; rien n\'est envoyé à aucun serveur.',
    },
    'welcomeBodyDesktop': {
      'es': 'Tu biblioteca de conocimiento sin conexión vive en la carpeta '
          'Nuvok de tu usuario. Esta instalación ya trae un paquete '
          'base sin conexión incluido: mapas, Wikipedia médica, una mini '
          'Wikipedia y un modelo IA liviano. En el primer arranque se copian '
          'automáticamente a esa carpeta para que funcionen sin internet y '
          'puedas copiarlos a otros dispositivos por USB.\n\nDesde Depósito '
          'puedes agregar más países, ZIMs o modelos grandes cuando tengas '
          'internet o por transferencia local.',
      'en': 'Your offline knowledge library lives in the Nuvok folder '
          'of your user. This install already includes a base offline pack: '
          'maps, medical Wikipedia, a mini Wikipedia and a light AI model. '
          'On first launch they are copied there automatically so they work '
          'without internet and you can copy them to other devices over '
          'USB.\n\nFrom Depot you can add more countries, ZIMs or bigger '
          'models when you have internet or via local transfer.',
      'pt': 'Sua biblioteca de conhecimento offline vive na pasta Nuvok '
          'do seu usuário. Esta instalação já inclui um pacote base offline: '
          'mapas, Wikipédia médica, uma mini Wikipédia e um modelo IA leve. '
          'Na primeira execução eles são copiados automaticamente para '
          'funcionar sem internet e poder copiá-los a outros dispositivos '
          'por USB.\n\nNo Depósito você pode adicionar mais países, ZIMs ou '
          'modelos maiores com internet ou por transferência local.',
      'fr': 'Votre bibliothèque hors ligne vit dans le dossier Nuvok de '
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
          'Nuvok Link usará el mismo protocolo de mensajes.',
      'en': '1) Enable Bluetooth. 2) If using multiple devices, share a hotspot '
          'or the same Wi‑Fi even without internet. 3) On Android, Wi‑Fi Direct '
          'finds peers without a router. 4) If you connect a compatible LoRa radio, '
          'Nuvok Link will use the same message protocol.',
      'pt': '1) Ative o Bluetooth. 2) Se houver vários equipamentos, use um hotspot '
          'ou o mesmo Wi‑Fi sem internet. 3) No Android, o Wi‑Fi Direct encontra '
          'pares sem roteador. 4) Se conectar um rádio LoRa compatível, o Nuvok '
          'Mesh usará o mesmo protocolo.',
      'fr': '1) Activez le Bluetooth. 2) Si plusieurs appareils, utilisez un hotspot '
          'ou le même Wi‑Fi sans internet. 3) Sur Android, Wi‑Fi Direct trouve des '
          'pairs sans routeur. 4) Si vous connectez une radio LoRa compatible, '
          'Nuvok Link utilisera le même protocole.',
      'zh': '1) 启用蓝牙。2) 如果有多台设备，即使没有互联网也可使用热点或相同Wi-Fi。'
          '3) 在Android上，Wi-Fi Direct无需路由器即可查找设备。4) 如果连接兼容的LoRa收音机，'
          'Nuvok Link将使用相同的消息协议。',
      'ja': '1) Bluetoothを有効にする。2) 複数デバイス使用時はホットスポットや同じWi-Fiを共有。'
          '3) AndroidではWi-Fi Directがルーターなしでピアを検索。4) 互換LoRAラジオを接続すると'
          'Nuvok Linkが同じプロトコルを使用。',
      'ht': '1) Aktive Bluetooth. 2) Si gen plizyè aparèy, itilize yon hotspot oswa '
          'menm Wi‑Fi a menm san entènèt. 3) Sou Android, Wi‑Fi Direct jwenn pè san routeur. '
          '4) Si ou konekte yon radyo LoRa ki konpatib, Nuvok Link ap itilize menm pwotokòl mesaj.',
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
      'es': 'Canal abierto SIN cifrar: lo lee cualquier Nuvok cercano. '
          'Úsalo para pedir o dar ayuda.',
      'en': 'Open channel, NOT encrypted: any nearby Nuvok can read it. '
          'Use it to ask for or give help.',
      'pt': 'Canal aberto SEM criptografia: qualquer Nuvok próximo pode lê-lo. '
          'Use para pedir ou dar ajuda.',
      'fr': 'Canal ouvert SANS chiffrement : tout Nuvok proche peut le lire. '
          'Utilisez-le pour demander ou offrir de l\'aide.',
      'zh': '开放频道，未加密：附近任何Nuvok均可读取。用于求助或提供帮助。',
      'ja': '暗号化なしの公開チャンネル：近くのNuvokなら誰でも読めます。助けを求めたり提供したりするために使用してください。',
      'ht': 'Kanal ouvè SANS chifraj: nenpòt Nuvok toupre ka li li. '
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
    // ── Asistente de conexión (banner + hoja de pasos) ──
    'meshBannerConnected': {
      'es': '{n} dispositivos conectados', 'en': '{n} devices connected',
      'pt': '{n} dispositivos conectados', 'fr': '{n} appareils connectés',
      'zh': '已连接 {n} 台设备', 'ja': '{n}台のデバイスが接続中',
      'ht': '{n} aparèy konekte',
    },
    'meshBannerSearching': {
      'es': 'Buscando dispositivos…', 'en': 'Searching for devices…',
      'pt': 'Procurando dispositivos…', 'fr': 'Recherche d’appareils…',
      'zh': '正在搜索设备…', 'ja': 'デバイスを検索中…', 'ht': 'K ap chèche aparèy…',
    },
    'meshBannerTapHelp': {
      'es': 'Toca para ver qué falta', 'en': 'Tap to see what’s missing',
      'pt': 'Toque para ver o que falta',
      'fr': 'Touchez pour voir ce qui manque',
      'zh': '点按查看缺少什么', 'ja': 'タップして不足を確認',
      'ht': 'Peze pou wè sa ki manke',
    },
    'advisorTitle': {
      'es': 'Asistente de conexión', 'en': 'Connection assistant',
      'pt': 'Assistente de conexão', 'fr': 'Assistant de connexion',
      'zh': '连接助手', 'ja': '接続アシスタント', 'ht': 'Asistan koneksyon',
    },
    'advisorBtOff': {
      'es': 'Enciende Bluetooth', 'en': 'Turn on Bluetooth',
      'pt': 'Ligue o Bluetooth', 'fr': 'Activez le Bluetooth',
      'zh': '打开蓝牙', 'ja': 'Bluetoothをオンにする', 'ht': 'Limen Bluetooth',
    },
    'advisorBtOffBody': {
      'es': 'Abre Ajustes → Bluetooth y actívalo. Los dispositivos cercanos '
          'se encontrarán solos, sin internet.',
      'en': 'Open Settings → Bluetooth and turn it on. Nearby devices will '
          'find each other automatically, no internet needed.',
      'pt': 'Abra Ajustes → Bluetooth e ative-o. Os dispositivos próximos se '
          'encontrarão sozinhos, sem internet.',
      'fr': 'Ouvrez Réglages → Bluetooth et activez-le. Les appareils proches '
          'se trouveront seuls, sans internet.',
      'zh': '打开 设置 → 蓝牙 并启用。附近的设备会自动互相发现，无需互联网。',
      'ja': '設定 → Bluetooth を開いてオンにしてください。近くのデバイスは'
          'インターネットなしで自動的に見つかります。',
      'ht': 'Ouvri Paramèt → Bluetooth epi limen li. Aparèy ki tou pre yo ap '
          'jwenn youn lòt poukont yo, san entènèt.',
    },
    'advisorBtPerm': {
      'es': 'Permite el acceso a Bluetooth', 'en': 'Allow Bluetooth access',
      'pt': 'Permita o acesso ao Bluetooth',
      'fr': 'Autorisez l’accès Bluetooth',
      'zh': '允许蓝牙权限', 'ja': 'Bluetoothへのアクセスを許可',
      'ht': 'Pèmèt aksè Bluetooth',
    },
    'advisorBtPermBody': {
      'es': 'La app no tiene permiso de Bluetooth. Abre Ajustes → Apps → '
          'Nuvok → Permisos y permite Bluetooth / Dispositivos cercanos.',
      'en': 'The app has no Bluetooth permission. Open Settings → Apps → '
          'Nuvok → Permissions and allow Bluetooth / Nearby devices.',
      'pt': 'O app não tem permissão de Bluetooth. Abra Ajustes → Apps → '
          'Nuvok → Permissões e permita Bluetooth / Dispositivos '
          'próximos.',
      'fr': 'L’app n’a pas la permission Bluetooth. Ouvrez Réglages → Apps → '
          'Nuvok → Autorisations et autorisez Bluetooth / Appareils à '
          'proximité.',
      'zh': '应用没有蓝牙权限。打开 设置 → 应用 → Nuvok → 权限，'
          '允许蓝牙/附近的设备。',
      'ja': 'アプリにBluetooth権限がありません。設定 → アプリ → Nuvok → '
          '権限 で Bluetooth/付近のデバイス を許可してください。',
      'ht': 'App la pa gen pèmisyon Bluetooth. Ouvri Paramèt → App → '
          'Nuvok → Pèmisyon epi pèmèt Bluetooth / Aparèy tou pre.',
    },
    'advisorHotspot': {
      'es': 'Crea un punto de acceso (hotspot)', 'en': 'Create a hotspot',
      'pt': 'Crie um ponto de acesso (hotspot)',
      'fr': 'Créez un point d’accès (hotspot)',
      'zh': '创建热点', 'ja': 'テザリング（ホットスポット）を作成',
      'ht': 'Kreye yon hotspot',
    },
    'advisorHotspotBody': {
      'es': 'Sin router, un teléfono puede ser la red:\n\n1. En UN teléfono: '
          'Ajustes → Punto de acceso / Compartir internet → actívalo (no '
          'importa que no haya internet).\n2. En LOS DEMÁS dispositivos: '
          'Ajustes → WiFi → únete a esa red.\n3. Vuelve aquí: se encontrarán '
          'solos en segundos.',
      'en': 'Without a router, one phone can be the network:\n\n1. On ONE '
          'phone: Settings → Hotspot / Tethering → turn it on (it doesn’t '
          'matter that there is no internet).\n2. On the OTHER devices: '
          'Settings → WiFi → join that network.\n3. Come back here: they '
          'will find each other in seconds.',
      'pt': 'Sem roteador, um telefone pode ser a rede:\n\n1. Em UM telefone: '
          'Ajustes → Ponto de acesso → ative-o (não importa que não haja '
          'internet).\n2. Nos OUTROS dispositivos: Ajustes → WiFi → entre '
          'nessa rede.\n3. Volte aqui: eles se encontrarão em segundos.',
      'fr': 'Sans routeur, un téléphone peut être le réseau :\n\n1. Sur UN '
          'téléphone : Réglages → Partage de connexion → activez-le (peu '
          'importe s’il n’y a pas d’internet).\n2. Sur les AUTRES appareils : '
          'Réglages → WiFi → rejoignez ce réseau.\n3. Revenez ici : ils se '
          'trouveront en quelques secondes.',
      'zh': '没有路由器时，一部手机就是网络：\n\n1. 在一部手机上：设置 → 个人热点 → '
          '开启（没有互联网也没关系）。\n2. 在其他设备上：设置 → WiFi → 加入该网络。'
          '\n3. 回到这里：几秒钟内它们就会互相发现。',
      'ja': 'ルーターがなくても、1台のスマホがネットワークになれます：\n\n1. 1台の'
          'スマホで：設定 → テザリング → オンにする（インターネットがなくてもOK）。'
          '\n2. 他のデバイスで：設定 → WiFi → そのネットワークに接続。\n3. ここに'
          '戻る：数秒でお互いを見つけます。',
      'ht': 'San routeur, yon telefòn ka sèvi kòm rezo a:\n\n1. Sou YON '
          'telefòn: Paramèt → Hotspot → limen li (pa gen pwoblèm si pa gen '
          'entènèt).\n2. Sou LÒT aparèy yo: Paramèt → WiFi → antre nan rezo '
          'sa a.\n3. Tounen isit la: y ap jwenn youn lòt nan kèk segond.',
    },
    'advisorLora': {
      'es': '¿Necesitas kilómetros de alcance?',
      'en': 'Need kilometers of range?',
      'pt': 'Precisa de quilômetros de alcance?',
      'fr': 'Besoin de kilomètres de portée ?',
      'zh': '需要数公里的通信距离？', 'ja': '数kmの通信距離が必要？',
      'ht': 'Bezwen plizyè kilomèt distans?',
    },
    'aiRamWarn': {
      'es': 'Este modelo pesa {size} y tu memoria libre aproximada es {free}. Cargarlo puede hacer lenta la máquina. ¿Continuar?',
      'en': 'This model weighs {size} and your approximate free memory is {free}. Loading it may slow the machine down. Continue?',
      'pt': 'Este modelo pesa {size} e sua memória livre aproximada é {free}. Carregá-lo pode deixar a máquina lenta. Continuar?',
      'fr': 'Ce modèle pèse {size} et votre mémoire libre approximative est {free}. Le charger peut ralentir la machine. Continuer ?',
      'zh': '该模型大小为 {size}，您的可用内存约为 {free}。加载它可能使设备变慢。继续吗？',
      'ja': 'このモデルは {size} で、空きメモリは約 {free} です。読み込むと動作が遅くなる可能性があります。続行しますか？',
      'ht': 'Modèl sa a peze {size} epi memwa lib ou apeprè {free}. Chaje li ka ralanti machin nan. Kontinye?',
    },
    'aiRefreshModels': {
      'es': 'Actualizar modelos', 'en': 'Refresh models',
      'pt': 'Atualizar modelos', 'fr': 'Actualiser les modèles',
      'zh': '刷新模型', 'ja': 'モデルを更新', 'ht': 'Aktyalize modèl yo',
    },
    'aiNoModels': {
      'es': 'No hay modelos de IA todavía.\n\nDescarga uno desde el Depósito o copia un archivo .gguf a:',
      'en': 'No AI models yet.\n\nDownload one from the Depot or copy a .gguf file to:',
      'pt': 'Ainda não há modelos de IA.\n\nBaixe um do Depósito ou copie um arquivo .gguf para:',
      'fr': 'Pas encore de modèles d\'IA.\n\nTéléchargez-en un depuis le Dépôt ou copiez un fichier .gguf vers :',
      'zh': '还没有AI模型。\n\n从仓库下载一个，或将 .gguf 文件复制到：',
      'ja': 'AIモデルがまだありません。\n\nデポからダウンロードするか、.ggufファイルを次の場所にコピーしてください：',
      'ht': 'Poko gen modèl IA.\n\nTelechaje youn nan Depo a oswa kopye yon fichye .gguf nan:',
    },
    'aiHintAsk': {
      'es': 'Escribe tu pregunta…', 'en': 'Type your question…',
      'pt': 'Escreva sua pergunta…', 'fr': 'Écrivez votre question…',
      'zh': '输入您的问题…', 'ja': '質問を入力…', 'ht': 'Ekri kesyon ou…',
    },
    'aiHintLoad': {
      'es': 'Carga un modelo para chatear', 'en': 'Load a model to chat',
      'pt': 'Carregue um modelo para conversar', 'fr': 'Chargez un modèle pour discuter',
      'zh': '加载模型后开始聊天', 'ja': 'チャットするにはモデルを読み込んでください', 'ht': 'Chaje yon modèl pou pale',
    },
    'aiHintEmergency': {
      'es': 'Pregunta de emergencia (las guías responden sin modelo)',
      'en': 'Emergency question (the guides answer without a model)',
      'pt': 'Pergunta de emergência (os guias respondem sem modelo)',
      'fr': 'Question d\'urgence (les guides répondent sans modèle)',
      'zh': '紧急问题（无需模型，指南直接回答）',
      'ja': '緊急の質問（モデルなしでもガイドが回答）',
      'ht': 'Kesyon ijans (gid yo reponn san modèl)',
    },
    'aiNoModelSelected': {
      'es': 'sin modelo seleccionado', 'en': 'no model selected',
      'pt': 'sem modelo selecionado', 'fr': 'aucun modèle sélectionné',
      'zh': '未选择模型', 'ja': 'モデル未選択', 'ht': 'pa gen modèl chwazi',
    },
    'aiStatusStopped': {
      'es': 'Pulsa Cargar arriba para iniciar el modelo local.',
      'en': 'Tap Load above to start the local model.',
      'pt': 'Toque em Carregar acima para iniciar o modelo local.',
      'fr': 'Touchez Charger ci-dessus pour démarrer le modèle local.',
      'zh': '点按上方的加载以启动本地模型。', 'ja': '上の読み込みをタップしてローカルモデルを起動。',
      'ht': 'Peze Chaje anlè a pou demare modèl lokal la.',
    },
    'aiStatusStarting': {
      'es': 'Cargando el modelo local… puede tardar varios minutos.',
      'en': 'Loading the local model… this can take several minutes.',
      'pt': 'Carregando o modelo local… pode levar vários minutos.',
      'fr': 'Chargement du modèle local… cela peut prendre plusieurs minutes.',
      'zh': '正在加载本地模型…可能需要几分钟。', 'ja': 'ローカルモデルを読み込み中…数分かかることがあります。',
      'ht': 'K ap chaje modèl lokal la… sa ka pran plizyè minit.',
    },
    'aiStatusReady': {
      'es': 'Modelo listo. Escribe tu pregunta abajo.',
      'en': 'Model ready. Type your question below.',
      'pt': 'Modelo pronto. Escreva sua pergunta abaixo.',
      'fr': 'Modèle prêt. Écrivez votre question ci-dessous.',
      'zh': '模型就绪。在下方输入您的问题。', 'ja': 'モデル準備完了。下に質問を入力してください。',
      'ht': 'Modèl pare. Ekri kesyon ou anba a.',
    },
    'aiStatusError': {
      'es': 'El motor de IA reportó un error.', 'en': 'The AI engine reported an error.',
      'pt': 'O motor de IA relatou um erro.', 'fr': 'Le moteur d\'IA a signalé une erreur.',
      'zh': 'AI引擎报告了一个错误。', 'ja': 'AIエンジンがエラーを報告しました。', 'ht': 'Motè IA a rapòte yon erè.',
    },
    'aiModelFound': {
      'es': 'Modelo local encontrado', 'en': 'Local model found',
      'pt': 'Modelo local encontrado', 'fr': 'Modèle local trouvé',
      'zh': '找到本地模型', 'ja': 'ローカルモデルが見つかりました', 'ht': 'Modèl lokal jwenn',
    },
    'aiEmptyHint': {
      'es': 'En una emergencia activa el interruptor Emergencia: las guías responden al instante incluso sin modelo.',
      'en': 'In an emergency, flip the Emergency switch: the guides answer instantly even without a model.',
      'pt': 'Em uma emergência, ative o interruptor Emergência: os guias respondem na hora mesmo sem modelo.',
      'fr': 'En cas d\'urgence, activez l\'interrupteur Urgence : les guides répondent instantanément même sans modèle.',
      'zh': '紧急情况下打开“紧急”开关：即使没有模型，指南也会立即回答。',
      'ja': '緊急時は「緊急」スイッチをオンに：モデルがなくてもガイドが即座に回答します。',
      'ht': 'Nan yon ijans, limen switch Ijans lan: gid yo reponn menm san modèl.',
    },
    'aiNoAiNoGuide': {
      'es': 'Sin IA local y sin guía que coincida. Abre la pestaña Emergencia y busca ahí.',
      'en': 'No local AI and no matching guide. Open the Emergency tab and search there.',
      'pt': 'Sem IA local e sem guia correspondente. Abra a aba Emergência e busque lá.',
      'fr': 'Pas d\'IA locale ni de guide correspondant. Ouvrez l\'onglet Urgence et cherchez-y.',
      'zh': '没有本地AI也没有匹配的指南。请打开紧急标签页搜索。',
      'ja': 'ローカルAIも該当ガイドもありません。緊急タブを開いて検索してください。',
      'ht': 'Pa gen IA lokal ni gid ki matche. Ouvri tab Ijans lan epi chèche la.',
    },
    'aiSources': {
      'es': 'Fuentes de la biblioteca:', 'en': 'Library sources:',
      'pt': 'Fontes da biblioteca:', 'fr': 'Sources de la bibliothèque :',
      'zh': '图书馆来源：', 'ja': 'ライブラリの出典：', 'ht': 'Sous bibliyotèk:',
    },
    // ── Especialistas (agentes locales) ──
    'agentsTitle': {
      'es': 'Especialistas', 'en': 'Specialists', 'pt': 'Especialistas',
      'fr': 'Spécialistes', 'zh': '专家', 'ja': 'スペシャリスト', 'ht': 'Espesyalis',
    },
    'agentPick': {
      'es': 'Elige un especialista', 'en': 'Choose a specialist',
      'pt': 'Escolha um especialista', 'fr': 'Choisis un spécialiste',
      'zh': '选择一位专家', 'ja': 'スペシャリストを選ぶ', 'ht': 'Chwazi yon espesyalis',
    },
    'agentReady': {
      'es': 'Listo', 'en': 'Ready', 'pt': 'Pronto',
      'fr': 'Prêt', 'zh': '就绪', 'ja': '準備完了', 'ht': 'Pare',
    },
    'agentDownload': {
      'es': 'Descargar', 'en': 'Download', 'pt': 'Baixar',
      'fr': 'Télécharger', 'zh': '下载', 'ja': 'ダウンロード', 'ht': 'Telechaje',
    },
    'agentLiteMode': {
      'es': 'Modo ligero', 'en': 'Lite mode', 'pt': 'Modo leve',
      'fr': 'Mode léger', 'zh': '轻量模式', 'ja': '軽量モード', 'ht': 'Mòd lejè',
    },
    'agentUpgrade': {
      'es': 'Mejorar IA', 'en': 'Upgrade AI', 'pt': 'Melhorar IA',
      'fr': "Améliorer l'IA", 'zh': '升级AI', 'ja': 'AIを強化',
      'ht': 'Amelyore AI',
    },
    'agentLiteBanner': {
      'es': 'Respuestas básicas (modelo ligero). Descarga el especialista '
          'completo para respuestas de verdad.',
      'en': 'Basic answers (lite model). Download the full specialist for '
          'real answers.',
      'pt': 'Respostas básicas (modelo leve). Baixe o especialista completo '
          'para respostas de verdade.',
      'fr': 'Réponses basiques (modèle léger). Télécharge le spécialiste '
          'complet pour de vraies réponses.',
      'zh': '基础回答（轻量模型）。下载完整专家以获得真正的回答。',
      'ja': '基本的な回答（軽量モデル）。本格的な回答には完全版をダウンロード。',
      'ht': 'Repons debaz (modèl lejè). Telechaje espesyalis konplè a pou '
          'vrè repons.',
    },
    'agentSwitching': {
      'es': 'Cambiando de especialista…', 'en': 'Switching specialist…',
      'pt': 'Trocando de especialista…', 'fr': 'Changement de spécialiste…',
      'zh': '正在切换专家…', 'ja': 'スペシャリストを切り替え中…', 'ht': 'Chanje espesyalis…',
    },
    'modelLicenseNotice': {
      'es': 'con condiciones del proveedor',
      'en': "with the provider's terms",
      'pt': 'com condições do fornecedor',
      'fr': 'avec les conditions du fournisseur',
      'zh': '附提供方条款', 'ja': '提供元の条件あり',
      'ht': 'ak kondisyon founisè a',
    },
    'creditsTitle': {
      'es': 'Créditos y licencias', 'en': 'Credits and licenses',
      'pt': 'Créditos e licenças', 'fr': 'Crédits et licences',
      'zh': '致谢与许可', 'ja': 'クレジットとライセンス', 'ht': 'Kredi ak lisans',
    },
    'creditsIntro': {
      'es': 'Nuvok se apoya en trabajo abierto de mucha gente. Estos son los créditos que sus licencias exigen.',
      'en': 'Nuvok stands on open work by many people. These are the credits their licenses require.',
      'pt': 'O Nuvok se apoia no trabalho aberto de muita gente. Estes são os créditos exigidos por suas licenças.',
      'fr': "Nuvok repose sur le travail ouvert de nombreuses personnes. Voici les crédits exigés par leurs licences.",
      'zh': 'Nuvok 建立在许多人的开放成果之上。以下是其许可证要求的署名。',
      'ja': 'Nuvok は多くの人のオープンな成果の上に成り立っています。以下はライセンスが求める表示です。',
      'ht': 'Nuvok kanpe sou travay ouvè anpil moun. Men kredi lisans yo egzije.',
    },
    'creditsModelsTitle': {
      'es': 'Modelos que descargas tú', 'en': 'Models you download',
      'pt': 'Modelos que você baixa', 'fr': 'Modèles que vous téléchargez',
      'zh': '你下载的模型', 'ja': 'あなたがダウンロードするモデル',
      'ht': 'Modèl ou telechaje',
    },
    'creditsModelsBody': {
      'es': 'En Depósito puedes descargar otros modelos de IA. Cada uno tiene su propia licencia, que se muestra junto al modelo: al descargarlo aceptas esa licencia, no la de Nuvok. Los modelos incluidos en la instalación son Apache 2.0.',
      'en': 'In Depot you can download other AI models. Each has its own license, shown next to it: downloading means accepting that license, not Nuvok\'s. The models bundled with the install are Apache 2.0.',
      'pt': 'No Depósito você pode baixar outros modelos de IA. Cada um tem sua própria licença, exibida ao lado: baixar significa aceitá-la, não a do Nuvok. Os modelos incluídos na instalação são Apache 2.0.',
      'fr': "Dans Dépôt, vous pouvez télécharger d'autres modèles d'IA. Chacun a sa licence, affichée à côté : la télécharger revient à l'accepter. Les modèles inclus sont en Apache 2.0.",
      'zh': '在“仓库”中可以下载其他 AI 模型。每个模型都有各自的许可证并显示在旁边：下载即表示接受该许可证。随安装包附带的模型为 Apache 2.0。',
      'ja': '「デポ」では他の AI モデルをダウンロードできます。各モデルには独自のライセンスがあり、隣に表示されます。同梱モデルは Apache 2.0 です。',
      'ht': 'Nan Depo ou ka telechaje lòt modèl AI. Chak gen pwòp lisans li, ki parèt akote l. Modèl ki vini ak enstalasyon an se Apache 2.0.',
    },
    'creditsSoftware': {
      'es': 'Licencias de software', 'en': 'Software licenses',
      'pt': 'Licenças de software', 'fr': 'Licences logicielles',
      'zh': '软件许可', 'ja': 'ソフトウェアライセンス', 'ht': 'Lisans lojisyèl',
    },
    // GPL v3 §5(d): la app debe mostrar el aviso legal en su interfaz —
    // copyright, ausencia de garantía y derecho a redistribuir. No es
    // decorativo: sin esto, distribuir Nuvok incumple su propia licencia.
    'creditsNuvokTitle': {
      'es': 'Nuvok es software libre', 'en': 'Nuvok is free software',
      'pt': 'O Nuvok é software livre', 'fr': 'Nuvok est un logiciel libre',
      'zh': 'Nuvok 是自由软件', 'ja': 'Nuvok はフリーソフトウェアです',
      'ht': 'Nuvok se lojisyèl lib',
    },
    'creditsNuvokBody': {
      'es': 'Copyright © 2026 Scott Orellana.\n\nNuvok se distribuye bajo la Licencia Pública General de GNU, versión 3. Puedes usarlo, estudiar su código, modificarlo y redistribuirlo bajo esos mismos términos.\n\nSe entrega SIN NINGUNA GARANTÍA, ni siquiera la garantía implícita de comerciabilidad o idoneidad para un fin determinado.\n\nCódigo fuente y texto completo de la licencia: github.com/scottorellana/nuvok',
      'en': 'Copyright © 2026 Scott Orellana.\n\nNuvok is distributed under the GNU General Public License, version 3. You may use it, study its code, modify it and redistribute it under those same terms.\n\nIt comes with ABSOLUTELY NO WARRANTY, not even the implied warranty of merchantability or fitness for a particular purpose.\n\nSource code and full license text: github.com/scottorellana/nuvok',
      'pt': 'Copyright © 2026 Scott Orellana.\n\nO Nuvok é distribuído sob a Licença Pública Geral GNU, versão 3. Você pode usá-lo, estudar seu código, modificá-lo e redistribuí-lo nos mesmos termos.\n\nÉ fornecido SEM NENHUMA GARANTIA, nem mesmo a garantia implícita de comercialização ou adequação a um fim específico.\n\nCódigo-fonte e texto completo da licença: github.com/scottorellana/nuvok',
      'fr': "Copyright © 2026 Scott Orellana.\n\nNuvok est distribué sous la Licence publique générale GNU, version 3. Vous pouvez l'utiliser, étudier son code, le modifier et le redistribuer selon les mêmes termes.\n\nIl est fourni SANS AUCUNE GARANTIE, pas même la garantie implicite de qualité marchande ou d'adéquation à un usage particulier.\n\nCode source et texte complet de la licence : github.com/scottorellana/nuvok",
      'zh': '版权所有 © 2026 Scott Orellana。\n\nNuvok 依据 GNU 通用公共许可证第 3 版发布。你可以使用、研究、修改并在相同条款下再分发本软件。\n\n本软件不提供任何担保，甚至不包括适销性或特定用途适用性的默示担保。\n\n源代码与许可证全文：github.com/scottorellana/nuvok',
      'ja': 'Copyright © 2026 Scott Orellana.\n\nNuvok は GNU 一般公衆ライセンス第3版のもとで配布されています。同じ条件のもとで、使用・コードの調査・改変・再配布ができます。\n\n本ソフトウェアは一切の保証なしに提供されます。商品性や特定目的への適合性の黙示の保証もありません。\n\nソースコードとライセンス全文: github.com/scottorellana/nuvok',
      'ht': 'Copyright © 2026 Scott Orellana.\n\nNuvok distribye anba Lisans Piblik Jeneral GNU, vèsyon 3. Ou ka sèvi avè l, etidye kòd li, modifye l epi redistribye l anba menm kondisyon yo.\n\nLi bay SAN OKENN GARANTI, menm pa garanti implisit pou komès oswa pou yon rezon patikilye.\n\nKòd sous ak tèks konplè lisans lan: github.com/scottorellana/nuvok',
    },
    // "Prepara tu Nuvok": el primer arranque del instalador ligero. La app
    // llega sin IA/mapas/enciclopedia y esta pantalla propone descargarlos.
    'setupTitle': {
      'es': 'Prepara tu Nuvok', 'en': 'Set up your Nuvok',
      'pt': 'Prepare seu Nuvok', 'fr': 'Préparez votre Nuvok',
      'zh': '准备你的 Nuvok', 'ja': 'Nuvok の準備', 'ht': 'Prepare Nuvok ou',
    },
    'setupIntro': {
      'es': 'Nuvok se instala ligero a propósito: el conocimiento lo eliges tú. Descárgalo ahora que hay internet y quedará disponible para siempre sin conexión. Nada se sube a ningún servidor.',
      'en': 'Nuvok installs light on purpose: you choose the knowledge. Download it now while you have internet and it stays available offline forever. Nothing is uploaded to any server.',
      'pt': 'O Nuvok se instala leve de propósito: o conhecimento é você quem escolhe. Baixe agora que há internet e ficará disponível offline para sempre. Nada é enviado a nenhum servidor.',
      'fr': "Nuvok s'installe léger à dessein : c'est vous qui choisissez le savoir. Téléchargez-le maintenant, tant qu'il y a internet, et il restera disponible hors ligne pour toujours. Rien n'est envoyé à aucun serveur.",
      'zh': 'Nuvok 刻意保持轻量安装：知识由你来选择。趁现在有网络下载，它将永远离线可用。任何内容都不会上传到服务器。',
      'ja': 'Nuvok はあえて軽量にインストールされます。知識はあなたが選びます。インターネットがある今ダウンロードすれば、ずっとオフラインで使えます。サーバーには何も送信されません。',
      'ht': 'Nuvok enstale lejè espre: se ou ki chwazi konesans lan. Telechaje l kounye a pandan gen entènèt, epi l ap rete disponib san koneksyon pou tout tan. Anyen pa monte sou okenn sèvè.',
    },
    'setupAiTitle': {
      'es': 'Asistente de IA', 'en': 'AI assistant', 'pt': 'Assistente de IA',
      'fr': 'Assistant IA', 'zh': 'AI 助手', 'ja': 'AI アシスタント',
      'ht': 'Asistan AI',
    },
    'setupAiSubtitle': {
      'es': 'Elegido para tu equipo según su memoria',
      'en': 'Picked for your device based on its memory',
      'pt': 'Escolhido para seu aparelho conforme a memória',
      'fr': "Choisi pour votre appareil selon sa mémoire",
      'zh': '根据设备内存自动选择', 'ja': '端末のメモリに合わせて自動選択',
      'ht': 'Chwazi pou aparèy ou dapre memwa li',
    },
    'setupWikiTitle': {
      'es': 'Wikipedia médica', 'en': 'Medical Wikipedia',
      'pt': 'Wikipédia médica', 'fr': 'Wikipédia médicale',
      'zh': '医学维基百科', 'ja': '医療ウィキペディア', 'ht': 'Wikipedya medikal',
    },
    'setupWikiSearching': {
      'es': 'Buscando la edición para tu idioma…',
      'en': 'Finding the edition for your language…',
      'pt': 'Procurando a edição para seu idioma…',
      'fr': 'Recherche de l’édition pour votre langue…',
      'zh': '正在查找你语言的版本…', 'ja': 'あなたの言語の版を探しています…',
      'ht': 'N ap chèche edisyon pou lang ou…',
    },
    'setupWikiOffline': {
      'es': 'Sin internet ahora. Descárgala luego desde Depósito → Esenciales.',
      'en': 'No internet right now. Download it later from Depot → Essentials.',
      'pt': 'Sem internet agora. Baixe depois em Depósito → Essenciais.',
      'fr': "Pas d'internet pour l'instant. Téléchargez-la plus tard depuis Dépôt → Essentiels.",
      'zh': '当前没有网络。稍后可在 仓库 → 必备 中下载。',
      'ja': '現在インターネットがありません。あとで「デポ → 基本」からダウンロードできます。',
      'ht': 'Pa gen entènèt kounye a. Telechaje l pita nan Depo → Esansyèl.',
    },
    'setupMapTitle': {
      'es': 'Mapa sin conexión', 'en': 'Offline map', 'pt': 'Mapa offline',
      'fr': 'Carte hors ligne', 'zh': '离线地图', 'ja': 'オフライン地図',
      'ht': 'Kat san koneksyon',
    },
    'setupMapPick': {
      'es': 'Elegir en Mapas', 'en': 'Choose in Maps',
      'pt': 'Escolher em Mapas', 'fr': 'Choisir dans Cartes',
      'zh': '在地图中选择', 'ja': 'マップで選ぶ', 'ht': 'Chwazi nan Kat',
    },
    // Espacio en disco: una descarga de 3.4 GB que muere al 90% quema datos
    // móviles y deja a la persona creyendo que ya está preparada.
    'setupNoSpace': {
      'es': 'No hay espacio suficiente. Libera {n} y vuelve a intentarlo.',
      'en': 'Not enough space. Free up {n} and try again.',
      'pt': 'Espaço insuficiente. Libere {n} e tente de novo.',
      'fr': "Espace insuffisant. Libérez {n} et réessayez.",
      'zh': '空间不足。请释放 {n} 后重试。',
      'ja': '空き容量が足りません。{n} を空けてからもう一度お試しください。',
      'ht': 'Pa gen ase espas. Libere {n} epi eseye ankò.',
    },
    'setupTightSpace': {
      'es': 'Cabe, pero tu equipo quedará casi lleno.',
      'en': 'It fits, but your device will be nearly full.',
      'pt': 'Cabe, mas seu aparelho ficará quase cheio.',
      'fr': "Ça tient, mais votre appareil sera presque plein.",
      'zh': '空间够用，但设备将几乎占满。',
      'ja': '入りますが、端末の空き容量がほぼなくなります。',
      'ht': 'Li antre, men aparèy ou ap prèske plen.',
    },
    'setupDownloadAll': {
      'es': 'Descargar todo', 'en': 'Download all', 'pt': 'Baixar tudo',
      'fr': 'Tout télécharger', 'zh': '全部下载', 'ja': 'すべてダウンロード',
      'ht': 'Telechaje tout',
    },
    'setupSkip': {
      'es': 'Ahora no', 'en': 'Not now', 'pt': 'Agora não',
      'fr': 'Pas maintenant', 'zh': '暂不', 'ja': '今はしない',
      'ht': 'Pa kounye a',
    },
    'mapAttribution': {
      'es': '© OpenStreetMap · ODbL',
      'en': '© OpenStreetMap · ODbL',
      'pt': '© OpenStreetMap · ODbL', 'fr': '© OpenStreetMap · ODbL',
      'zh': '© OpenStreetMap · ODbL', 'ja': '© OpenStreetMap · ODbL',
      'ht': '© OpenStreetMap · ODbL',
    },
    'shareAppTitle': {
      'es': 'Pasar Nuvok a otro teléfono', 'en': 'Send Nuvok to another phone',
      'pt': 'Passar o Nuvok para outro telefone',
      'fr': 'Envoyer Nuvok à un autre téléphone',
      'zh': '把 Nuvok 传给另一台手机', 'ja': 'Nuvok を他のスマホに渡す',
      'ht': 'Voye Nuvok bay yon lòt telefòn',
    },
    'shareAppIntro': {
      'es': 'Sin internet nadie puede descargar Nuvok — pero tú ya la tienes. Comparte tu WiFi o enciende tu punto de acceso y pásala directo.',
      'en': 'With no internet nobody can download Nuvok — but you already have it. Share your WiFi or turn on your hotspot and pass it along.',
      'pt': 'Sem internet ninguém consegue baixar o Nuvok — mas você já tem. Compartilhe seu WiFi ou ligue seu ponto de acesso e passe adiante.',
      'fr': "Sans internet, personne ne peut télécharger Nuvok — mais vous l'avez déjà. Partagez votre WiFi ou activez votre point d'accès.",
      'zh': '没有网络就无法下载 Nuvok——但你已经有了。共享你的 WiFi 或开热点，直接传给对方。',
      'ja': 'インターネットがないと誰も Nuvok をダウンロードできません。あなたのWiFiやテザリングで直接渡せます。',
      'ht': 'San entènèt pèsonn pa ka telechaje Nuvok — men ou genyen l deja. Pataje WiFi ou oswa limen pwen aksè ou.',
    },
    'shareAppStart': {
      'es': 'Empezar a compartir', 'en': 'Start sharing',
      'pt': 'Começar a compartilhar', 'fr': 'Commencer le partage',
      'zh': '开始共享', 'ja': '共有を開始', 'ht': 'Kòmanse pataje',
    },
    'shareAppStop': {
      'es': 'Dejar de compartir', 'en': 'Stop sharing',
      'pt': 'Parar de compartilhar', 'fr': 'Arrêter le partage',
      'zh': '停止共享', 'ja': '共有を停止', 'ht': 'Sispann pataje',
    },
    'shareAppSteps': {
      'es': '1. El otro teléfono se conecta a tu misma red o a tu punto de acceso.\n2. Apunta la cámara del teléfono al código (o escribe la dirección en el navegador).\n3. Instala el archivo descargado. Puede pedirte permitir "instalar apps desconocidas".',
      'en': '1. The other phone joins your network or hotspot.\n2. Point the phone camera at the code (or type the address in the browser).\n3. Install the downloaded file. It may ask to allow "install unknown apps".',
      'pt': '1. O outro telefone entra na sua rede ou ponto de acesso.\n2. Aponte a câmera do telefone para o código (ou digite o endereço no navegador).\n3. Instale o arquivo baixado. Pode pedir para permitir "instalar apps desconhecidos".',
      'fr': "1. L'autre téléphone rejoint votre réseau ou point d'accès.\n2. Pointez l'appareil photo vers le code (ou saisissez l'adresse).\n3. Installez le fichier téléchargé.",
      'zh': '1. 另一台手机连接你的网络或热点。\n2. 用手机相机对准二维码（或在浏览器输入地址）。\n3. 安装下载的文件，可能需要允许“安装未知应用”。',
      'ja': '1. 相手のスマホをあなたのネットワークかテザリングに接続。\n2. スマホのカメラをコードに向ける（またはアドレスを入力）。\n3. ダウンロードしたファイルをインストール。',
      'ht': '1. Lòt telefòn nan konekte sou rezo ou.\n2. Vize kamera telefòn nan sou kòd la (oswa tape adrès la).\n3. Enstale fichye a.',
    },
    'shareAppFailed': {
      'es': 'No se pudo empezar. Revisa que estés conectado a una red WiFi o que tu punto de acceso esté encendido.',
      'en': 'Could not start. Check that you are on a WiFi network or that your hotspot is on.',
      'pt': 'Não foi possível iniciar. Verifique se está numa rede WiFi ou se o ponto de acesso está ligado.',
      'fr': "Impossible de démarrer. Vérifiez votre WiFi ou votre point d'accès.",
      'zh': '无法启动。请检查是否连接了 WiFi 或已开启热点。',
      'ja': '開始できませんでした。WiFi 接続かテザリングを確認してください。',
      'ht': 'Pa t kapab kòmanse. Tcheke WiFi ou oswa pwen aksè a.',
    },
    'shareAppIosTitle': {
      'es': 'Desde iPhone no se puede pasar la app',
      'en': 'iPhone cannot pass the app along',
      'pt': 'Do iPhone não dá para passar o app',
      'fr': "Depuis l'iPhone, impossible de transmettre l'app",
      'zh': 'iPhone 无法直接传递应用', 'ja': 'iPhone からアプリは渡せません',
      'ht': 'Soti nan iPhone ou pa ka pase app la',
    },
    'shareAppIosBody': {
      'es': 'Apple no permite que una app instale otra. Comparte este enlace: con internet se descarga en un momento. Un teléfono Android SÍ puede pasarla sin internet.',
      'en': 'Apple does not let one app install another. Share this link: with internet it downloads in a moment. An Android phone CAN pass it along without internet.',
      'pt': 'A Apple não permite que um app instale outro. Compartilhe este link. Um telefone Android CONSEGUE passá-lo sem internet.',
      'fr': "Apple n'autorise pas une app à en installer une autre. Partagez ce lien. Un téléphone Android PEUT le transmettre sans internet.",
      'zh': '苹果不允许一个应用安装另一个应用。请分享此链接。安卓手机则可以在没有网络时直接传递。',
      'ja': 'Apple はアプリによるアプリのインストールを許可していません。このリンクを共有してください。Android なら通信なしで渡せます。',
      'ht': 'Apple pa pèmèt yon app enstale yon lòt. Pataje lyen sa a. Yon telefòn Android KA pase l san entènèt.',
    },
    'sosAlarmTitle': {
      'es': '⚠ SOS RECIBIDO ⚠', 'en': '⚠ SOS RECEIVED ⚠',
      'pt': '⚠ SOS RECEBIDO ⚠', 'fr': '⚠ SOS REÇU ⚠',
      'zh': '⚠ 收到求救 ⚠', 'ja': '⚠ SOS を受信 ⚠', 'ht': '⚠ SOS RESEVWA ⚠',
    },
    'sosAlarmFrom': {
      'es': 'De:', 'en': 'From:', 'pt': 'De:', 'fr': 'De :',
      'zh': '来自：', 'ja': '差出人：', 'ht': 'Soti nan:',
    },
    'sosAlarmAck': {
      'es': 'ENTENDIDO', 'en': 'GOT IT', 'pt': 'ENTENDIDO',
      'fr': 'COMPRIS', 'zh': '知道了', 'ja': '了解', 'ht': 'MWEN KONPRANN',
    },
    'sosAlarmSilence': {
      'es': 'Toca para silenciar la alarma',
      'en': 'Tap to silence the alarm',
      'pt': 'Toque para silenciar o alarme',
      'fr': "Touchez pour couper l'alarme",
      'zh': '点击静音警报', 'ja': 'タップで警報を消音',
      'ht': 'Peze pou fèmen alam nan',
    },
    'sosAlarmA11y': {
      'es': 'Alarma SOS activa', 'en': 'SOS alarm active',
      'pt': 'Alarme SOS ativo', 'fr': 'Alarme SOS active',
      'zh': 'SOS 警报已启动', 'ja': 'SOS 警報作動中', 'ht': 'Alam SOS aktif',
    },
    'sosAlarmNote': {
      'es': 'Nota', 'en': 'Note', 'pt': 'Nota', 'fr': 'Note',
      'zh': '备注', 'ja': 'メモ', 'ht': 'Nòt',
    },
    'diagTitle': {
      'es': 'Diagnóstico de la malla', 'en': 'Mesh diagnostics',
      'pt': 'Diagnóstico da malha', 'fr': 'Diagnostic du maillage',
      'zh': '网状网络诊断', 'ja': 'メッシュ診断', 'ht': 'Dyagnostik rezo a',
    },
    'diagIntro': {
      'es': 'Muestra qué vías están activas y si de verdad pasó tráfico por cada una. Copia el reporte si necesitas ayuda.',
      'en': 'Shows which links are active and whether traffic really flowed through each. Copy the report if you need help.',
      'pt': 'Mostra quais vias estão ativas e se realmente passou tráfego por cada uma. Copie o relatório se precisar de ajuda.',
      'fr': "Montre quelles voies sont actives et si du trafic est vraiment passé. Copiez le rapport si besoin d'aide.",
      'zh': '显示哪些链路处于活动状态以及是否真的有流量通过。需要帮助时可复制报告。',
      'ja': 'どの経路が有効か、実際に通信が流れたかを表示します。サポートが必要なときはレポートをコピー。',
      'ht': 'Montre ki chemen ki aktif e si trafik reyèlman pase. Kopye rapò a si ou bezwen èd.',
    },
    'diagTransports': {
      'es': 'Vías', 'en': 'Links', 'pt': 'Vias', 'fr': 'Voies',
      'zh': '链路', 'ja': '経路', 'ht': 'Chemen',
    },
    'diagTraffic': {
      'es': 'Tráfico real', 'en': 'Actual traffic', 'pt': 'Tráfego real',
      'fr': 'Trafic réel', 'zh': '实际流量', 'ja': '実際の通信',
      'ht': 'Trafik reyèl',
    },
    'diagEvents': {
      'es': 'Eventos recientes', 'en': 'Recent events',
      'pt': 'Eventos recentes', 'fr': 'Événements récents',
      'zh': '最近事件', 'ja': '最近の出来事', 'ht': 'Evènman resan',
    },
    'diagNoTransports': {
      'es': 'Ninguna vía activa', 'en': 'No active links',
      'pt': 'Nenhuma via ativa', 'fr': 'Aucune voie active',
      'zh': '没有活动链路', 'ja': '有効な経路なし', 'ht': 'Pa gen chemen aktif',
    },
    'diagNoTraffic': {
      'es': 'Sin tráfico todavía', 'en': 'No traffic yet',
      'pt': 'Sem tráfego ainda', 'fr': 'Pas encore de trafic',
      'zh': '暂无流量', 'ja': 'まだ通信なし', 'ht': 'Poko gen trafik',
    },
    'diagNoEvents': {
      'es': 'Sin eventos', 'en': 'No events', 'pt': 'Sem eventos',
      'fr': 'Aucun événement', 'zh': '无事件', 'ja': '出来事なし',
      'ht': 'Pa gen evènman',
    },
    'diagCopy': {
      'es': 'Copiar reporte', 'en': 'Copy report', 'pt': 'Copiar relatório',
      'fr': 'Copier le rapport', 'zh': '复制报告', 'ja': 'レポートをコピー',
      'ht': 'Kopye rapò a',
    },
    'diagCopied': {
      'es': 'Reporte copiado', 'en': 'Report copied', 'pt': 'Relatório copiado',
      'fr': 'Rapport copié', 'zh': '报告已复制', 'ja': 'レポートをコピーしました',
      'ht': 'Rapò kopye',
    },
    'diagClear': {
      'es': 'Borrar bitácora', 'en': 'Clear log', 'pt': 'Limpar registro',
      'fr': 'Effacer le journal', 'zh': '清除日志', 'ja': 'ログを消去',
      'ht': 'Efase jounal la',
    },
    'bgMeshTitle': {
      'es': 'Escuchar con la app cerrada', 'en': 'Listen with the app closed',
      'pt': 'Ouvir com o app fechado', 'fr': "Écouter l'app fermée",
      'zh': '关闭应用后继续接收', 'ja': 'アプリを閉じても受信',
      'ht': 'Koute ak app la fèmen',
    },
    'bgMeshSubtitle': {
      'es': 'Un SOS cercano te avisa aunque no tengas Nuvok abierta. Ajusta la radio según la batería.',
      'en': 'A nearby SOS alerts you even with Nuvok closed. Tunes the radio to your battery.',
      'pt': 'Um SOS próximo avisa mesmo com o Nuvok fechado. Ajusta o rádio à bateria.',
      'fr': "Un SOS proche vous alerte même Nuvok fermé. Adapte la radio à la batterie.",
      'zh': '附近的 SOS 即使 Nuvok 已关闭也会提醒你，并根据电量调节射频。',
      'ja': 'Nuvok を閉じていても近くの SOS を通知。電池残量に応じて無線を調整。',
      'ht': 'Yon SOS toupre avèti ou menm si Nuvok fèmen. Ajiste radyo a selon batri.',
    },
    'modelPickTitle': {
      'es': 'Modelo de IA', 'en': 'AI model', 'pt': 'Modelo de IA',
      'fr': "Modèle d'IA", 'zh': 'AI 模型', 'ja': 'AI モデル', 'ht': 'Modèl AI',
    },
    'modelPickSubtitle': {
      'es': 'Se usa en el chat general y en los especialistas.',
      'en': 'Used by the general chat and the specialists.',
      'pt': 'Usado no chat geral e nos especialistas.',
      'fr': 'Utilisé par le chat général et les spécialistes.',
      'zh': '用于通用聊天和各专家。',
      'ja': '汎用チャットと専門家で使用されます。',
      'ht': 'Itilize nan chat jeneral la ak espesyalis yo.',
    },
    'modelPickDownloadMore': {
      'es': 'Descargar más modelos', 'en': 'Download more models',
      'pt': 'Baixar mais modelos', 'fr': 'Télécharger plus de modèles',
      'zh': '下载更多模型', 'ja': 'モデルを追加ダウンロード',
      'ht': 'Telechaje plis modèl',
    },
    'modelPickActive': {
      'es': 'Activo', 'en': 'Active', 'pt': 'Ativo', 'fr': 'Actif',
      'zh': '使用中', 'ja': '使用中', 'ht': 'Aktif',
    },
    'agentAdvancedModel': {
      'es': 'Modelo manual (avanzado)', 'en': 'Manual model (advanced)',
      'pt': 'Modelo manual (avançado)', 'fr': 'Modèle manuel (avancé)',
      'zh': '手动模型（高级）', 'ja': '手動モデル（詳細）', 'ht': 'Modèl manyèl (avanse)',
    },
    'agentCrisisNotice': {
      'es': 'Si estás en peligro, pulsa SOS o busca ayuda de inmediato.',
      'en': 'If you are in danger, tap SOS or seek help immediately.',
      'pt': 'Se você está em perigo, toque em SOS ou busque ajuda imediatamente.',
      'fr': "Si tu es en danger, appuie sur SOS ou cherche de l'aide immédiatement.",
      'zh': '如果你有危险，请按 SOS 或立即求助。',
      'ja': '危険を感じたら SOS を押すか、すぐに助けを求めてください。',
      'ht': 'Si ou an danje, peze SOS oswa chèche èd touswit.',
    },
    'aiQuickRcp': {
      'es': '¿Cómo hago RCP a un adulto?', 'en': 'How do I do CPR on an adult?',
      'pt': 'Como faço RCP em um adulto?', 'fr': 'Comment faire un massage cardiaque à un adulte ?',
      'zh': '如何对成人进行心肺复苏？', 'ja': '大人への心肺蘇生のやり方は？', 'ht': 'Kijan pou m fè RCP sou yon granmoun?',
    },
    'aiQuickChoking': {
      'es': 'Se está atragantando, ¿qué hago?', 'en': 'Someone is choking, what do I do?',
      'pt': 'Está engasgado, o que faço?', 'fr': 'Quelqu\'un s\'étouffe, que faire ?',
      'zh': '有人噎住了，怎么办？', 'ja': '喉に詰まらせています、どうすれば？', 'ht': 'Yon moun ap trangle, kisa pou m fè?',
    },
    'aiQuickBleeding': {
      'es': 'Sangra mucho, ¿cómo lo detengo?', 'en': 'Heavy bleeding, how do I stop it?',
      'pt': 'Sangra muito, como paro?', 'fr': 'Saignement abondant, comment l\'arrêter ?',
      'zh': '大量出血，如何止血？', 'ja': '大出血しています、止血方法は？', 'ht': 'L ap senyen anpil, kijan pou m rete l?',
    },
    'aiQuickBurn': {
      'es': 'Se quemó, ¿qué hago primero?', 'en': 'Someone got burned, what first?',
      'pt': 'Se queimou, o que faço primeiro?', 'fr': 'Brûlure : que faire en premier ?',
      'zh': '烧伤了，先做什么？', 'ja': 'やけどしました、まず何を？', 'ht': 'Li boule, kisa pou m fè anvan?',
    },
    'calcTitle': {
      'es': 'Calculadoras de emergencia', 'en': 'Emergency calculators',
      'pt': 'Calculadoras de emergência', 'fr': 'Calculatrices d\'urgence',
      'zh': '应急计算器', 'ja': '緊急計算ツール', 'ht': 'Kalkilatris ijans',
    },
    'calcDoseTitle': {
      'es': 'Dosis pediátrica por peso', 'en': 'Pediatric dose by weight',
      'pt': 'Dose pediátrica por peso', 'fr': 'Dose pédiatrique par poids',
      'zh': '儿童按体重剂量', 'ja': '小児の体重別用量', 'ht': 'Dòz timoun selon pwa',
    },
    'calcWeightKg': {
      'es': 'Peso del niño', 'en': 'Child\'s weight',
      'pt': 'Peso da criança', 'fr': 'Poids de l\'enfant',
      'zh': '儿童体重', 'ja': '子どもの体重', 'ht': 'Pwa timoun nan',
    },
    'calcPerDose': {
      'es': 'por dosis, cada', 'en': 'per dose, every',
      'pt': 'por dose, a cada', 'fr': 'par dose, toutes les',
      'zh': '每次剂量，每隔', 'ja': '1回量、間隔', 'ht': 'pa dòz, chak',
    },
    'calcIbuNotUnder5': {
      'es': 'NO en menores de 3 meses (~5 kg) sin médico',
      'en': 'NOT under 3 months (~5 kg) without a doctor',
      'pt': 'NÃO em menores de 3 meses (~5 kg) sem médico',
      'fr': 'PAS avant 3 mois (~5 kg) sans médecin',
      'zh': '3个月以下（约5公斤）没有医生指导时禁用',
      'ja': '生後3か月未満（約5kg）には医師なしで使用不可',
      'ht': 'PA pou pi piti pase 3 mwa (~5 kg) san doktè',
    },
    'calcOrsTitle': {
      'es': 'Suero de rehidratación oral (OMS)', 'en': 'Oral rehydration solution (WHO)',
      'pt': 'Soro de reidratação oral (OMS)', 'fr': 'Solution de réhydratation orale (OMS)',
      'zh': '口服补液盐（世卫）', 'ja': '経口補水液（WHO）', 'ht': 'Sewòm oral (OMS)',
    },
    'calcLiters': {
      'es': 'Litros de agua segura', 'en': 'Liters of safe water',
      'pt': 'Litros de água segura', 'fr': 'Litres d\'eau sûre',
      'zh': '安全饮用水（升）', 'ja': '安全な水（リットル）', 'ht': 'Lit dlo ki bon',
    },
    'calcSugar': {
      'es': 'Azúcar (cditas rasas)', 'en': 'Sugar (level tsp)',
      'pt': 'Açúcar (colheres rasas)', 'fr': 'Sucre (c. à café rases)',
      'zh': '糖（平茶匙）', 'ja': '砂糖（すり切り小さじ）', 'ht': 'Sik (ti kiyè plat)',
    },
    'calcSalt': {
      'es': 'Sal (cditas rasas)', 'en': 'Salt (level tsp)',
      'pt': 'Sal (colheres rasas)', 'fr': 'Sel (c. à café rases)',
      'zh': '盐（平茶匙）', 'ja': '塩（すり切り小さじ）', 'ht': 'Sèl (ti kiyè plat)',
    },
    'calcTspNote': {
      'es': 'Cucharaditas RASAS. Prueba: no más salado que las lágrimas.',
      'en': 'LEVEL teaspoons. Test: no saltier than tears.',
      'pt': 'Colheres RASAS. Teste: não mais salgado que lágrimas.',
      'fr': 'Cuillères RASES. Test : pas plus salé que des larmes.',
      'zh': '必须是平匙。测试：不能比眼泪更咸。',
      'ja': 'すり切りで。目安：涙より塩辛くないこと。',
      'ht': 'Ti kiyè PLAT. Tès: pa pi sale pase dlo je.',
    },
    'calcChlorineTitle': {
      'es': 'Purificar agua con lejía', 'en': 'Purify water with bleach',
      'pt': 'Purificar água com água sanitária', 'fr': 'Purifier l\'eau avec de l\'eau de Javel',
      'zh': '用漂白水净化饮用水', 'ja': '漂白剤で水を浄化', 'ht': 'Pirifye dlo ak klowòks',
    },
    'calcBleachPct': {
      'es': 'Concentración de la lejía', 'en': 'Bleach concentration',
      'pt': 'Concentração da água sanitária', 'fr': 'Concentration de la Javel',
      'zh': '漂白水浓度', 'ja': '漂白剤の濃度', 'ht': 'Konsantrasyon klowòks la',
    },
    'calcCloudy': {
      'es': 'Agua turbia', 'en': 'Cloudy water',
      'pt': 'Água turva', 'fr': 'Eau trouble',
      'zh': '浑浊水', 'ja': '濁った水', 'ht': 'Dlo twoub',
    },
    'calcDrops': {
      'es': 'gotas · esperar 30 minutos', 'en': 'drops · wait 30 minutes',
      'pt': 'gotas · aguardar 30 minutos', 'fr': 'gouttes · attendre 30 minutes',
      'zh': '滴 · 等待30分钟', 'ja': '滴 · 30分待つ', 'ht': 'gout · tann 30 minit',
    },
    'calcWait30': {
      'es': 'Lejía SIN perfume ni jabón. Si tras 30 min no huele levemente a cloro, repite la dosis una vez.',
      'en': 'UNSCENTED bleach only. If after 30 min there is no slight chlorine smell, repeat the dose once.',
      'pt': 'Água sanitária SEM perfume. Se após 30 min não houver leve cheiro de cloro, repita a dose uma vez.',
      'fr': 'Javel SANS parfum. Si après 30 min aucune légère odeur de chlore, répétez la dose une fois.',
      'zh': '仅用无香型漂白水。30分钟后若无轻微氯味，再加一次剂量。',
      'ja': '無香料の漂白剤のみ。30分後に微かな塩素臭がなければ、もう一度だけ追加。',
      'ht': 'Klowòks SAN pafen sèlman. Si apre 30 minit pa gen ti sant klò, repete dòz la yon fwa.',
    },
    'calcDisclaimer': {
      'es': 'Fórmulas estándar OMS/CDC. No sustituyen atención médica: busca ayuda profesional en cuanto exista.',
      'en': 'Standard WHO/CDC formulas. They do not replace medical care: seek professional help as soon as it exists.',
      'pt': 'Fórmulas padrão OMS/CDC. Não substituem atendimento médico: procure ajuda profissional assim que existir.',
      'fr': 'Formules standard OMS/CDC. Elles ne remplacent pas les soins : cherchez de l\'aide professionnelle dès que possible.',
      'zh': '世卫/CDC标准配方。不能替代医疗：一旦有条件请立即就医。',
      'ja': 'WHO/CDC標準式。医療の代わりにはなりません：可能になり次第、専門家の助けを求めてください。',
      'ht': 'Fòmil estanda OMS/CDC. Yo pa ranplase swen medikal: chèche èd pwofesyonèl kou li posib.',
    },
    'voiceRead': {
      'es': 'Leer en voz alta (manos libres)', 'en': 'Read aloud (hands-free)',
      'pt': 'Ler em voz alta (mãos livres)', 'fr': 'Lire à voix haute (mains libres)',
      'zh': '朗读（解放双手）', 'ja': '読み上げ（ハンズフリー）', 'ht': 'Li awotvwa (men lib)',
    },
    'voiceStopRead': {
      'es': 'Detener lectura', 'en': 'Stop reading',
      'pt': 'Parar leitura', 'fr': 'Arrêter la lecture',
      'zh': '停止朗读', 'ja': '読み上げを停止', 'ht': 'Rete lekti a',
    },
    'tqTitle': {
      'es': 'Cronómetro de torniquete', 'en': 'Tourniquet timer',
      'pt': 'Cronômetro de torniquete', 'fr': 'Minuteur de garrot',
      'zh': '止血带计时器', 'ja': '止血帯タイマー', 'ht': 'Kwonomèt tounikè',
    },
    'tqApplied': {
      'es': 'APLIQUÉ TORNIQUETE', 'en': 'TOURNIQUET APPLIED',
      'pt': 'APLIQUEI TORNIQUETE', 'fr': 'GARROT POSÉ',
      'zh': '已上止血带', 'ja': '止血帯を装着', 'ht': 'MWEN METE TOUNIKÈ',
    },
    'tqWhere': {
      'es': '¿Dónde y a quién?', 'en': 'Where and on whom?',
      'pt': 'Onde e em quem?', 'fr': 'Où et sur qui ?',
      'zh': '部位和伤者？', 'ja': '部位と対象者は？', 'ht': 'Ki kote e sou kilès?',
    },
    'tqWhereHint': {
      'es': 'Pierna derecha - Juan', 'en': 'Right leg - John',
      'pt': 'Perna direita - João', 'fr': 'Jambe droite - Jean',
      'zh': '右腿 - 小明', 'ja': '右脚 - 田中', 'ht': 'Janm dwat - Jan',
    },
    'tqStart': {
      'es': 'Iniciar cronómetro', 'en': 'Start timer',
      'pt': 'Iniciar cronômetro', 'fr': 'Démarrer',
      'zh': '开始计时', 'ja': '計測開始', 'ht': 'Kòmanse',
    },
    'tqEmpty': {
      'es': 'Sin torniquetes activos.\n\nAl aplicar uno, toca el botón rojo: la HORA de aplicación es un dato que el médico necesitará.',
      'en': 'No active tourniquets.\n\nWhen you apply one, tap the red button: the time of application is data the doctor will need.',
      'pt': 'Sem torniquetes ativos.\n\nAo aplicar um, toque no botão vermelho: a HORA de aplicação é um dado que o médico precisará.',
      'fr': 'Aucun garrot actif.\n\nQuand vous en posez un, touchez le bouton rouge : l\'heure de pose est une donnée dont le médecin aura besoin.',
      'zh': '没有活动的止血带。\n\n上止血带后请点红色按钮：上带时间是医生需要的数据。',
      'ja': '使用中の止血帯はありません。\n\n装着したら赤いボタンを：装着時刻は医師に必要なデータです。',
      'ht': 'Pa gen tounikè aktif.\n\nLè ou mete youn, peze bouton wouj la: LÈ ou mete l se yon done doktè a ap bezwen.',
    },
    'tqOkHint': {
      'es': 'Anota la hora en la piel o cinta si puedes.',
      'en': 'Write the time on skin or tape if you can.',
      'pt': 'Anote a hora na pele ou fita se puder.',
      'fr': 'Notez l\'heure sur la peau ou du ruban si possible.',
      'zh': '如有可能，把时间写在皮肤或胶带上。',
      'ja': '可能なら皮膚かテープに時刻を書いてください。',
      'ht': 'Ekri lè a sou po a oswa yon riban si ou kapab.',
    },
    'tqWarnHint': {
      'es': '⚠️ +90 min: prioriza llegar a atención médica YA.',
      'en': '⚠️ +90 min: prioritize reaching medical care NOW.',
      'pt': '⚠️ +90 min: priorize chegar a atendimento médico JÁ.',
      'fr': '⚠️ +90 min : priorité absolue aux soins médicaux MAINTENANT.',
      'zh': '⚠️ 超过90分钟：立即优先送医。',
      'ja': '⚠️ 90分超：今すぐ医療機関へ。',
      'ht': '⚠️ +90 min: pryorite rive kay doktè KOUNYE A.',
    },
    'tqCritHint': {
      'es': '🔴 +2 h: riesgo del miembro. SOLO personal médico decide aflojarlo.',
      'en': '🔴 +2 h: limb at risk. ONLY medical personnel decide to loosen it.',
      'pt': '🔴 +2 h: risco do membro. SÓ pessoal médico decide afrouxá-lo.',
      'fr': '🔴 +2 h : membre en danger. SEUL le personnel médical décide de le desserrer.',
      'zh': '🔴 超过2小时：肢体有风险。只有医务人员能决定放松。',
      'ja': '🔴 2時間超：四肢のリスク。緩める判断は医療者のみ。',
      'ht': '🔴 +2 è: manm nan an danje. SÈLMAN pèsonèl medikal deside lache l.',
    },
    'tqShare': {
      'es': 'Avisar al grupo', 'en': 'Alert the group',
      'pt': 'Avisar o grupo', 'fr': 'Alerter le groupe',
      'zh': '通知小组', 'ja': 'グループに通知', 'ht': 'Avèti gwoup la',
    },
    'tqShared': {
      'es': 'Enviado al canal de emergencia', 'en': 'Sent to the emergency channel',
      'pt': 'Enviado ao canal de emergência', 'fr': 'Envoyé sur le canal d\'urgence',
      'zh': '已发送到紧急频道', 'ja': '緊急チャンネルに送信済み', 'ht': 'Voye nan kanal ijans lan',
    },
    'tqResolve': {
      'es': 'Resuelto', 'en': 'Resolved',
      'pt': 'Resolvido', 'fr': 'Résolu',
      'zh': '已处理', 'ja': '解決', 'ht': 'Rezoud',
    },
    'iceTitle': {
      'es': 'Ficha médica ICE', 'en': 'ICE medical card',
      'pt': 'Ficha médica ICE', 'fr': 'Fiche médicale ICE',
      'zh': '紧急医疗卡（ICE）', 'ja': '緊急医療カード（ICE）', 'ht': 'Fich medikal ICE',
    },
    'iceIntro': {
      'es': 'Si te encuentran inconsciente, esta ficha habla por ti. Muéstrala grande, compártela al grupo o imprime el QR para tu billetera.',
      'en': 'If you are found unconscious, this card speaks for you. Show it big, share it with the group, or print the QR for your wallet.',
      'pt': 'Se te encontrarem inconsciente, esta ficha fala por você. Mostre-a grande, compartilhe com o grupo ou imprima o QR para a carteira.',
      'fr': 'Si l\'on vous trouve inconscient, cette fiche parle pour vous. Affichez-la en grand, partagez-la au groupe ou imprimez le QR pour votre portefeuille.',
      'zh': '若你被发现昏迷，这张卡替你说话。放大显示、分享给小组，或打印二维码放入钱包。',
      'ja': '意識不明で発見されたとき、このカードがあなたの代わりに伝えます。大きく表示、グループに共有、またはQRを印刷して財布に。',
      'ht': 'Si yo jwenn ou san konesans, fich sa a pale pou ou. Montre l gwo, pataje l ak gwoup la, oswa enprime QR a pou bous ou.',
    },
    'iceName': {
      'es': 'Nombre', 'en': 'Name', 'pt': 'Nome', 'fr': 'Nom',
      'zh': '姓名', 'ja': '氏名', 'ht': 'Non',
    },
    'iceBlood': {
      'es': 'Tipo de sangre', 'en': 'Blood type', 'pt': 'Tipo sanguíneo',
      'fr': 'Groupe sanguin', 'zh': '血型', 'ja': '血液型', 'ht': 'Gwoup san',
    },
    'iceAllergies': {
      'es': 'Alergias', 'en': 'Allergies', 'pt': 'Alergias',
      'fr': 'Allergies', 'zh': '过敏', 'ja': 'アレルギー', 'ht': 'Alèji',
    },
    'iceMeds': {
      'es': 'Medicamentos', 'en': 'Medications', 'pt': 'Medicamentos',
      'fr': 'Médicaments', 'zh': '用药', 'ja': '服用中の薬', 'ht': 'Medikaman',
    },
    'iceConditions': {
      'es': 'Condiciones médicas', 'en': 'Medical conditions',
      'pt': 'Condições médicas', 'fr': 'Antécédents médicaux',
      'zh': '疾病史', 'ja': '既往症', 'ht': 'Kondisyon medikal',
    },
    'iceContact1': {
      'es': 'Contacto de emergencia', 'en': 'Emergency contact',
      'pt': 'Contato de emergência', 'fr': 'Contact d\'urgence',
      'zh': '紧急联系人', 'ja': '緊急連絡先', 'ht': 'Kontak ijans',
    },
    'iceContact2': {
      'es': 'Contacto 2 (opcional)', 'en': 'Contact 2 (optional)',
      'pt': 'Contato 2 (opcional)', 'fr': 'Contact 2 (facultatif)',
      'zh': '联系人2（可选）', 'ja': '連絡先2（任意）', 'ht': 'Kontak 2 (si ou vle)',
    },
    'iceShow': {
      'es': 'Mostrar al rescatista (grande + QR)', 'en': 'Show to rescuer (big + QR)',
      'pt': 'Mostrar ao socorrista (grande + QR)', 'fr': 'Montrer au secouriste (grand + QR)',
      'zh': '向救援者展示（大字+二维码）', 'ja': '救助者に表示（大きく＋QR）', 'ht': 'Montre sekouris la (gwo + QR)',
    },
    'iceShareMesh': {
      'es': 'Compartir al grupo por el mesh', 'en': 'Share to the group over the mesh',
      'pt': 'Compartilhar com o grupo pelo mesh', 'fr': 'Partager au groupe via le mesh',
      'zh': '通过网状网络分享给小组', 'ja': 'メッシュでグループに共有', 'ht': 'Pataje ak gwoup la sou mesh la',
    },
    'dtTitle': {
      'es': '¿Qué hago? — Guía rápida', 'en': 'What do I do? — Quick guide',
      'pt': 'O que faço? — Guia rápido', 'fr': 'Que faire ? — Guide rapide',
      'zh': '我该怎么办？——快速指引', 'ja': 'どうすれば？——クイックガイド', 'ht': 'Kisa pou m fè? — Gid rapid',
    },
    'dtResponds': {
      'es': '¿La persona RESPONDE?\n(háblale fuerte y sacúdela suave)',
      'en': 'Does the person RESPOND?\n(speak loudly and shake gently)',
      'pt': 'A pessoa RESPONDE?\n(fale alto e sacuda de leve)',
      'fr': 'La personne RÉPOND-elle ?\n(parlez fort, secouez doucement)',
      'zh': '这个人有反应吗？\n（大声呼喊并轻摇）',
      'ja': '反応はありますか？\n（大声で呼びかけ、軽く揺する）',
      'ht': 'Èske moun nan REPONN?\n(pale fò epi souke l dousman)',
    },
    'dtBreathing': {
      'es': '¿RESPIRA normalmente?\n(mira el pecho 10 segundos)',
      'en': 'Is the person BREATHING normally?\n(watch the chest for 10 seconds)',
      'pt': 'RESPIRA normalmente?\n(olhe o peito por 10 segundos)',
      'fr': 'RESPIRE-t-elle normalement ?\n(regardez le thorax 10 secondes)',
      'zh': '呼吸正常吗？\n（观察胸部10秒）',
      'ja': '正常に呼吸していますか？\n（胸を10秒観察）',
      'ht': 'Èske l ap RESPIRE nòmalman?\n(gade pwatrin li 10 segond)',
    },
    'dtHadImpact': {
      'es': '¿Hubo golpe fuerte o caída?', 'en': 'Was there a hard impact or fall?',
      'pt': 'Houve pancada forte ou queda?', 'fr': 'Y a-t-il eu un choc violent ou une chute ?',
      'zh': '有剧烈撞击或坠落吗？', 'ja': '強い衝撃や転落はありましたか？', 'ht': 'Èske te gen gwo frap oswa tonbe?',
    },
    'dtWhatHappens': {
      'es': '¿Qué está pasando?', 'en': 'What is happening?',
      'pt': 'O que está acontecendo?', 'fr': 'Que se passe-t-il ?',
      'zh': '发生了什么？', 'ja': '何が起きていますか？', 'ht': 'Kisa k ap pase?',
    },
    'dtYes': {
      'es': 'SÍ', 'en': 'YES', 'pt': 'SIM', 'fr': 'OUI',
      'zh': '是', 'ja': 'はい', 'ht': 'WI',
    },
    'dtNo': {
      'es': 'NO', 'en': 'NO', 'pt': 'NÃO', 'fr': 'NON',
      'zh': '否', 'ja': 'いいえ', 'ht': 'NON',
    },
    'dtChoking': {
      'es': 'Se atraganta', 'en': 'Choking', 'pt': 'Engasgado',
      'fr': 'S\'étouffe', 'zh': '噎住了', 'ja': '喉に詰まった', 'ht': 'L ap trangle',
    },
    'dtBleeding': {
      'es': 'Sangra mucho', 'en': 'Heavy bleeding', 'pt': 'Sangra muito',
      'fr': 'Saigne beaucoup', 'zh': '大出血', 'ja': '大量出血', 'ht': 'L ap senyen anpil',
    },
    'dtBurn': {
      'es': 'Quemadura', 'en': 'Burn', 'pt': 'Queimadura',
      'fr': 'Brûlure', 'zh': '烧伤', 'ja': 'やけど', 'ht': 'Boule',
    },
    'dtChest': {
      'es': 'Dolor de pecho / habla raro', 'en': 'Chest pain / odd speech',
      'pt': 'Dor no peito / fala estranha', 'fr': 'Douleur thoracique / parole étrange',
      'zh': '胸痛/言语异常', 'ja': '胸痛・ろれつが回らない', 'ht': 'Doulè pwatrin / pale dwòl',
    },
    'dtSeizure': {
      'es': 'Convulsiona', 'en': 'Seizure', 'pt': 'Convulsão',
      'fr': 'Convulsions', 'zh': '抽搐', 'ja': 'けいれん', 'ht': 'Kriz',
    },
    'dtPoison': {
      'es': 'Intoxicación', 'en': 'Poisoning', 'pt': 'Intoxicação',
      'fr': 'Intoxication', 'zh': '中毒', 'ja': '中毒', 'ht': 'Anpwazonnman',
    },
    'mpTitle': {
      'es': 'Punto de encuentro', 'en': 'Meeting point',
      'pt': 'Ponto de encontro', 'fr': 'Point de rassemblement',
      'zh': '集合点', 'ja': '集合場所', 'ht': 'Pwen randevou',
    },
    'mpGo': {
      'es': 'IR', 'en': 'GO', 'pt': 'IR', 'fr': 'Y ALLER',
      'zh': '前往', 'ja': '向かう', 'ht': 'ALE',
    },
    'mpArrived': {
      'es': 'Llegaron', 'en': 'Arrived', 'pt': 'Chegaram',
      'fr': 'Arrivés', 'zh': '已到达', 'ja': '到着', 'ht': 'Rive',
    },
    'mpPending': {
      'es': 'Faltan', 'en': 'Pending', 'pt': 'Faltam',
      'fr': 'Manquants', 'zh': '未到', 'ja': '未着', 'ht': 'Poko rive',
    },
    'mpNoPositions': {
      'es': 'Aún sin posiciones del grupo (se comparten por el mesh al activar posición).',
      'en': 'No group positions yet (shared over the mesh when position sharing is on).',
      'pt': 'Ainda sem posições do grupo (compartilhadas pelo mesh ao ativar posição).',
      'fr': 'Pas encore de positions du groupe (partagées via le mesh quand la position est activée).',
      'zh': '尚无小组位置（开启位置共享后经网状网络同步）。',
      'ja': 'グループの位置情報はまだありません（位置共有をオンにするとメッシュ経由で共有）。',
      'ht': 'Poko gen pozisyon gwoup la (yo pataje sou mesh la lè pozisyon aktive).',
    },
    'beaconActive': {
      'es': 'BALIZA SOS ACTIVA', 'en': 'SOS BEACON ACTIVE',
      'pt': 'BALIZA SOS ATIVA', 'fr': 'BALISE SOS ACTIVE',
      'zh': 'SOS信标已启动', 'ja': 'SOSビーコン作動中', 'ht': 'BALIZ SOS AKTIF',
    },
    'beaconHint': {
      'es': 'Pantalla al mínimo y radio emitiendo tu posición cada minuto. Deja el teléfono quieto y visible; con batería crítica envía tu última posición sola.',
      'en': 'Screen at minimum and radio transmitting your position every minute. Keep the phone still and visible; on critical battery it sends your last position by itself.',
      'pt': 'Tela no mínimo e rádio transmitindo sua posição a cada minuto. Deixe o telefone quieto e visível; com bateria crítica envia sua última posição sozinho.',
      'fr': 'Écran au minimum et radio émettant votre position chaque minute. Laissez le téléphone immobile et visible ; sur batterie critique il envoie seul votre dernière position.',
      'zh': '屏幕调至最低，无线电每分钟发送您的位置。保持手机静止且可见；电量危急时会自动发送最后位置。',
      'ja': '画面は最小、電波は毎分あなたの位置を送信。電話は動かさず見える所に。電池切れ寸前には最後の位置を自動送信します。',
      'ht': 'Ekran nan minimòm epi radyo a ap voye pozisyon ou chak minit. Kite telefòn nan an plas e vizib; ak batri kritik li voye dènye pozisyon ou poukont li.',
    },
    'beaconExit': {
      'es': 'Salir del modo baliza', 'en': 'Exit beacon mode',
      'pt': 'Sair do modo baliza', 'fr': 'Quitter le mode balise',
      'zh': '退出信标模式', 'ja': 'ビーコンモードを終了', 'ht': 'Soti nan mòd baliz',
    },
    'beaconOpen': {
      'es': 'Modo baliza SOS (ultra-ahorro)', 'en': 'SOS beacon mode (ultra-saver)',
      'pt': 'Modo baliza SOS (ultra-economia)', 'fr': 'Mode balise SOS (ultra-éco)',
      'zh': 'SOS信标模式（超级省电）', 'ja': 'SOSビーコン（超省電力）', 'ht': 'Mòd baliz SOS (ultra-ekonomi)',
    },
    'modeBosque': {
      'es': 'Bosque / Selva', 'en': 'Forest / Jungle', 'pt': 'Floresta / Selva',
      'fr': 'Forêt / Jungle', 'zh': '森林/丛林', 'ja': '森林・ジャングル', 'ht': 'Forè / Jeng',
    },
    'modeDesierto': {
      'es': 'Desierto', 'en': 'Desert', 'pt': 'Deserto', 'fr': 'Désert',
      'zh': '沙漠', 'ja': '砂漠', 'ht': 'Dezè',
    },
    'modeMar': {
      'es': 'Mar / Costa', 'en': 'Sea / Coast', 'pt': 'Mar / Costa',
      'fr': 'Mer / Côte', 'zh': '海洋/海岸', 'ja': '海・海岸', 'ht': 'Lanmè / Kòt',
    },
    'modeMontana': {
      'es': 'Montaña / Nieve', 'en': 'Mountain / Snow', 'pt': 'Montanha / Neve',
      'fr': 'Montagne / Neige', 'zh': '山地/雪地', 'ja': '山岳・雪', 'ht': 'Mòn / Nèj',
    },
    'modeCiudad': {
      'es': 'Ciudad colapsada', 'en': 'Collapsed city', 'pt': 'Cidade colapsada',
      'fr': 'Ville effondrée', 'zh': '瘫痪城市', 'ja': '崩壊した都市', 'ht': 'Vil kraze',
    },
    'modeRio': {
      'es': 'Río / Inundación', 'en': 'River / Flood', 'pt': 'Rio / Inundação',
      'fr': 'Rivière / Inondation', 'zh': '河流/洪水', 'ja': '河川・洪水', 'ht': 'Rivyè / Inondasyon',
    },
    'modePantano': {
      'es': 'Pantano / Manglar', 'en': 'Swamp / Mangrove', 'pt': 'Pântano / Mangue',
      'fr': 'Marais / Mangrove', 'zh': '沼泽/红树林', 'ja': '湿地・マングローブ', 'ht': 'Marekaj / Mangwov',
    },
    'modeArtico': {
      'es': 'Ártico / Frío extremo', 'en': 'Arctic / Extreme cold', 'pt': 'Ártico / Frio extremo',
      'fr': 'Arctique / Froid extrême', 'zh': '极地/极寒', 'ja': '極地・極寒', 'ht': 'Aktik / Fredi ekstrèm',
    },
    'modesTitle': {
      'es': 'Modos de supervivencia', 'en': 'Survival modes',
      'pt': 'Modos de sobrevivência', 'fr': 'Modes de survie',
      'zh': '生存模式', 'ja': 'サバイバルモード', 'ht': 'Mòd siviv',
    },
    'modesIntro': {
      'es': 'Elige TU entorno: verás su paquete de guías y la IA priorizará técnicas de ese lugar.',
      'en': 'Pick YOUR environment: you get its guide pack and the AI prioritizes techniques for that place.',
      'pt': 'Escolha SEU ambiente: verá seu pacote de guias e a IA priorizará técnicas desse lugar.',
      'fr': 'Choisissez VOTRE environnement : vous verrez son pack de guides et l\'IA priorisera ce lieu.',
      'zh': '选择你所处的环境：将显示该环境的指南包，AI也会优先该环境的技巧。',
      'ja': '自分の環境を選択：その環境のガイドパックが表示され、AIもその場所の技術を優先します。',
      'ht': 'Chwazi anviwònman OU: w ap wè pakè gid li yo epi IA a ap bay teknik kote sa a priyorite.',
    },
    'modeActivate': {
      'es': 'Activar este modo', 'en': 'Activate this mode',
      'pt': 'Ativar este modo', 'fr': 'Activer ce mode',
      'zh': '启用此模式', 'ja': 'このモードを有効化', 'ht': 'Aktive mòd sa a',
    },
    'modeActive': {
      'es': 'MODO ACTIVO', 'en': 'ACTIVE MODE', 'pt': 'MODO ATIVO',
      'fr': 'MODE ACTIF', 'zh': '当前模式', 'ja': '有効なモード', 'ht': 'MÒD AKTIF',
    },
    'modeDeactivate': {
      'es': 'Desactivar', 'en': 'Deactivate', 'pt': 'Desativar',
      'fr': 'Désactiver', 'zh': '停用', 'ja': '無効化', 'ht': 'Dezaktive',
    },
    'modeComingSoon': {
      'es': 'Paquete completo en camino — ya incluye las guías generales de este entorno',
      'en': 'Full pack on the way — already includes the general guides for this environment',
      'pt': 'Pacote completo a caminho — já inclui os guias gerais deste ambiente',
      'fr': 'Pack complet en route — inclut déjà les guides généraux de cet environnement',
      'zh': '完整包即将推出——已包含此环境的通用指南',
      'ja': '完全パックは準備中——この環境の一般ガイドはすでに利用可能',
      'ht': 'Pakè konplè ap vini — li deja gen gid jeneral anviwònman sa a',
    },
    'aiQuickModeWater': {
      'es': '¿Dónde encuentro agua en {mode}?', 'en': 'Where do I find water in {mode}?',
      'pt': 'Onde encontro água em {mode}?', 'fr': 'Où trouver de l\'eau en {mode} ?',
      'zh': '在{mode}哪里能找到水？', 'ja': '{mode}で水はどこで見つかる？', 'ht': 'Ki kote pou m jwenn dlo nan {mode}?',
    },
    'aiQuickModeDanger': {
      'es': '¿Peligros mortales en {mode}?', 'en': 'Deadly dangers in {mode}?',
      'pt': 'Perigos mortais em {mode}?', 'fr': 'Dangers mortels en {mode} ?',
      'zh': '{mode}有哪些致命危险？', 'ja': '{mode}の致命的な危険は？', 'ht': 'Danje mòtèl nan {mode}?',
    },
    'egPageTitle': {
      'es': 'Guías de Emergencia', 'en': 'Emergency Guides',
      'pt': 'Guias de Emergência', 'fr': "Guides d'urgence",
      'zh': '急救指南', 'ja': '緊急ガイド', 'ht': 'Gid Ijans',
    },
    'callEmergency': {
      'es': 'LLAMAR', 'en': 'CALL', 'pt': 'LIGAR', 'fr': 'APPELER',
      'zh': '拨打', 'ja': '発信', 'ht': 'RELE',
    },
    'voiceHold': {
      'es': 'Mantén presionado para hablar', 'en': 'Hold to talk',
      'pt': 'Segure para falar', 'fr': 'Maintenez pour parler',
      'zh': '按住说话', 'ja': '長押しで話す', 'ht': 'Kenbe peze pou pale',
    },
    'voiceMicPermission': {
      'es': 'Permite el micrófono en los ajustes de la app para enviar notas de voz',
      'en': 'Allow the microphone in the app settings to send voice notes',
      'pt': 'Permita o microfone nos ajustes do app para enviar notas de voz',
      'fr': 'Autorisez le micro dans les réglages de l’app pour envoyer des notes vocales',
      'zh': '请在应用设置中允许麦克风以发送语音消息',
      'ja': '音声メモを送るには、アプリ設定でマイクを許可してください',
      'ht': 'Pèmèt mikwo a nan paramèt app la pou voye nòt vwa',
    },
    'advisorLoraBody': {
      'es': 'Con una radio LoRa (módulo Nordic UART por Bluetooth) el mesh '
          'alcanza kilómetros sin ninguna red. Conecta la radio y activa LoRa '
          'en Comunicación → ajustes.',
      'en': 'With a LoRa radio (Nordic UART module over Bluetooth) the mesh '
          'reaches kilometers with no network at all. Connect the radio and '
          'enable LoRa in Communication → settings.',
      'pt': 'Com um rádio LoRa (módulo Nordic UART por Bluetooth) o mesh '
          'alcança quilômetros sem nenhuma rede. Conecte o rádio e ative '
          'LoRa em Comunicação → ajustes.',
      'fr': 'Avec une radio LoRa (module Nordic UART en Bluetooth), le mesh '
          'atteint des kilomètres sans aucun réseau. Connectez la radio et '
          'activez LoRa dans Communication → réglages.',
      'zh': '使用LoRa电台（通过蓝牙的Nordic UART模块），无需任何网络即可达到数公里。'
          '连接电台并在 通信 → 设置 中启用LoRa。',
      'ja': 'LoRa無線（Bluetooth経由のNordic UARTモジュール）でネットワークなしで'
          '数km届きます。無線を接続し、通信 → 設定 でLoRaを有効にしてください。',
      'ht': 'Avèk yon radyo LoRa (modil Nordic UART sou Bluetooth) mesh la '
          'rive plizyè kilomèt san okenn rezo. Konekte radyo a epi aktive '
          'LoRa nan Kominikasyon → paramèt.',
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

  /// Prefs live inside the Nuvok library root, which is
  /// platform-correct everywhere. Deriving it from $HOME broke iOS ($HOME
  /// doesn't exist there → read-only '/', the choice silently never saved).
  File? _prefsFile() {
    try {
      return File('${NuvokLibrary.instance.root.path}/locale.json');
    } catch (_) {
      // NuvokLibrary not initialized (tests) — no persistence, no crash.
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
