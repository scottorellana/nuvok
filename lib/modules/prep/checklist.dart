// Family Preparedness Checklist — a guided, persistent checklist that helps
// families prepare for emergencies. Progress is saved in the portable library
// so it travels with the device.
//
// Categories follow FEMA/Red Cross recommendations adapted for Latin America.
// Perishable items (food, medicine, batteries) carry an expiryMonths hint so
// the app can warn when it's time to rotate supplies.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/nuvok_library.dart';

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.category,
    required this.textEs,
    required this.textEn,
    this.expiryMonths = 0,
  });

  final String id;
  final String category;
  final String textEs;
  final String textEn;

  /// How long this supply typically lasts before it should be rotated.
  /// 0 = does not expire (documents, tools, plans).
  final int expiryMonths;

  String text(String lang) => lang == 'es' ? textEs : textEn;

  bool get isPerishable => expiryMonths > 0;
}

class ChecklistCategory {
  final String id;
  final String nameEs;
  final String nameEn;
  final String icon;
  const ChecklistCategory({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.icon,
  });

  String name(String lang) => lang == 'es' ? nameEs : nameEn;
}

const categories = [
  ChecklistCategory(id: 'water', nameEs: 'Agua', nameEn: 'Water', icon: '💧'),
  ChecklistCategory(
      id: 'food', nameEs: 'Alimentos', nameEn: 'Food', icon: '🍜'),
  ChecklistCategory(
      id: 'medical', nameEs: 'Salud', nameEn: 'Health', icon: '🏥'),
  ChecklistCategory(
      id: 'docs', nameEs: 'Documentos', nameEn: 'Documents', icon: '📄'),
  ChecklistCategory(
      id: 'shelter', nameEs: 'Refugio', nameEn: 'Shelter', icon: '🏕️'),
  ChecklistCategory(
      id: 'comms', nameEs: 'Comunicación', nameEn: 'Communication', icon: '📡'),
  ChecklistCategory(
      id: 'tools', nameEs: 'Herramientas', nameEn: 'Tools', icon: '🔧'),
  ChecklistCategory(
      id: 'plan',
      nameEs: 'Plan familiar',
      nameEn: 'Family plan',
      icon: '👨‍👩‍👧‍👦'),
];

const checklistItems = [
  // Water — rotate stored water every 6 months
  ChecklistItem(
      id: 'water_1',
      category: 'water',
      textEs: '4 litros de agua por persona por día (mínimo 3 días)',
      textEn: '4 liters of water per person per day (minimum 3 days)',
      expiryMonths: 6),
  ChecklistItem(
      id: 'water_2',
      category: 'water',
      textEs: 'Filtro de agua o pastillas purificadoras',
      textEn: 'Water filter or purification tablets',
      expiryMonths: 24),
  ChecklistItem(
      id: 'water_3',
      category: 'water',
      textEs: 'Bidón/cuba para almacenar agua (60L+)',
      textEn: 'Large container for water storage (60L+)'),

  // Food — rotate every 6 months
  ChecklistItem(
      id: 'food_1',
      category: 'food',
      textEs: '3 días de comida no perecedera (atún, frijoles, arroz)',
      textEn: '3 days of non-perishable food (canned tuna, beans, rice)',
      expiryMonths: 6),
  ChecklistItem(
      id: 'food_2',
      category: 'food',
      textEs: 'Snacks altos en energía (nueces, barras, galletas)',
      textEn: 'High-energy snacks (nuts, bars, crackers)',
      expiryMonths: 6),
  ChecklistItem(
      id: 'food_3',
      category: 'food',
      textEs: 'Fórmula/comida para bebés si aplica',
      textEn: 'Baby formula/food if applicable',
      expiryMonths: 6),
  ChecklistItem(
      id: 'food_4',
      category: 'food',
      textEs: 'Comida para mascotas (7 días)',
      textEn: 'Pet food (7 days)',
      expiryMonths: 6),

  // Medical — rotate every 12 months
  ChecklistItem(
      id: 'med_1',
      category: 'medical',
      textEs: 'Botiquín de primeros auxilios completo',
      textEn: 'Complete first aid kit',
      expiryMonths: 12),
  ChecklistItem(
      id: 'med_2',
      category: 'medical',
      textEs: 'Medicamentos recetados (7 días extra)',
      textEn: 'Prescription medications (7+ days extra)',
      expiryMonths: 6),
  ChecklistItem(
      id: 'med_3',
      category: 'medical',
      textEs: 'Paracetamol, ibuprofeno, antialérgico',
      textEn: 'Paracetamol, ibuprofen, antihistamine',
      expiryMonths: 12),
  ChecklistItem(
      id: 'med_4',
      category: 'medical',
      textEs: 'Alcohol (70%), gasas, esparadrapo, torniquete',
      textEn: 'Rubbing alcohol (70%), gauze, tape, tourniquet',
      expiryMonths: 12),
  ChecklistItem(
      id: 'med_5',
      category: 'medical',
      textEs: 'Termómetro, tijeras, pinzas, guantes',
      textEn: 'Thermometer, scissors, tweezers, gloves',
      expiryMonths: 12),

  // Documents
  ChecklistItem(
      id: 'doc_1',
      category: 'docs',
      textEs: 'Copias de identificaciones (DNI/pasaporte) en bolsa impermeable',
      textEn: 'Copies of IDs (passport/national ID) in waterproof bag'),
  ChecklistItem(
      id: 'doc_2',
      category: 'docs',
      textEs: 'Actas de nacimiento y matrimonio',
      textEn: 'Birth and marriage certificates'),
  ChecklistItem(
      id: 'doc_3',
      category: 'docs',
      textEs: 'Pólizas de seguro, títulos de propiedad',
      textEn: 'Insurance policies, property titles'),
  ChecklistItem(
      id: 'doc_4',
      category: 'docs',
      textEs: 'Lista de contactos de emergencia en papel',
      textEn: 'Emergency contact list on paper'),
  ChecklistItem(
      id: 'doc_5',
      category: 'docs',
      textEs: 'Dinero en efectivo (billetes pequeños)',
      textEn: 'Cash in small bills'),

  // Shelter
  ChecklistItem(
      id: 'shelter_1',
      category: 'shelter',
      textEs: 'Tienda de campaña o lona impermeable',
      textEn: 'Tent or waterproof tarp'),
  ChecklistItem(
      id: 'shelter_2',
      category: 'shelter',
      textEs: 'Sleeping bags o mantas para cada persona',
      textEn: 'Sleeping bags or blankets for each person'),
  ChecklistItem(
      id: 'shelter_3',
      category: 'shelter',
      textEs: 'Ropa de cambio (3 días) en bolsa sellada',
      textEn: 'Change of clothes (3 days) in sealed bag'),
  ChecklistItem(
      id: 'shelter_4',
      category: 'shelter',
      textEs: 'Zapatos resistentes extra',
      textEn: 'Extra sturdy shoes'),

  // Communication
  ChecklistItem(
      id: 'comm_1',
      category: 'comms',
      textEs: 'Radio de batería o manivela (AM/FM)',
      textEn: 'Battery or hand-crank radio (AM/FM)'),
  ChecklistItem(
      id: 'comm_2',
      category: 'comms',
      textEs: 'Nuvok cargado y actualizado ✅',
      textEn: 'Nuvok loaded and updated ✅'),
  ChecklistItem(
      id: 'comm_3',
      category: 'comms',
      textEs: 'Power bank (20,000mAh+) cargado',
      textEn: 'Power bank (20,000mAh+) charged'),
  ChecklistItem(
      id: 'comm_4',
      category: 'comms',
      textEs: 'Panel solar pequeño para cargar dispositivos',
      textEn: 'Small solar panel for charging devices'),
  ChecklistItem(
      id: 'comm_5',
      category: 'comms',
      textEs: 'Silbato para señalar rescate (3 sonidos = SOS)',
      textEn: 'Whistle to signal rescue (3 blasts = SOS)'),

  // Tools
  ChecklistItem(
      id: 'tool_1',
      category: 'tools',
      textEs: 'Linterna frontal o de mano (LED)',
      textEn: 'Headlamp or handheld flashlight (LED)'),
  ChecklistItem(
      id: 'tool_2',
      category: 'tools',
      textEs: 'Cuchillo multiusos / navaja suiza',
      textEn: 'Multi-tool / Swiss army knife'),
  ChecklistItem(
      id: 'tool_3',
      category: 'tools',
      textEs: 'Fósforos en bolsa impermeable + encendedor',
      textEn: 'Matches in waterproof bag + lighter'),
  ChecklistItem(
      id: 'tool_4',
      category: 'tools',
      textEs: 'Cinta adhesiva (duct tape)',
      textEn: 'Duct tape'),
  ChecklistItem(
      id: 'tool_5',
      category: 'tools',
      textEs: 'Cuerda/soga (15 metros)',
      textEn: 'Rope/cord (15 meters)'),
  ChecklistItem(
      id: 'tool_6',
      category: 'tools',
      textEs: 'Pilas de repuesto (AA, AAA)',
      textEn: 'Spare batteries (AA, AAA)',
      expiryMonths: 24),

  // Family plan
  ChecklistItem(
      id: 'plan_1',
      category: 'plan',
      textEs: 'Punto de reunión familiar definido (cerca y lejos)',
      textEn: 'Family meeting point defined (near and far)'),
  ChecklistItem(
      id: 'plan_2',
      category: 'plan',
      textEs: 'Ruta de evacuación conocida por todos',
      textEn: 'Evacuation route known by all'),
  ChecklistItem(
      id: 'plan_3',
      category: 'plan',
      textEs: 'Contacto fuera de la ciudad/zona de riesgo',
      textEn: 'Out-of-area emergency contact'),
  ChecklistItem(
      id: 'plan_4',
      category: 'plan',
      textEs: 'Plan para mascotas y animales',
      textEn: 'Plan for pets and animals'),
  ChecklistItem(
      id: 'plan_5',
      category: 'plan',
      textEs: 'Práctica de evacuación al menos 1 vez al año',
      textEn: 'Evacuation drill at least once a year'),
  ChecklistItem(
      id: 'plan_6',
      category: 'plan',
      textEs: 'Ubicación de llaves de gas/electricidad/agua conocida',
      textEn: 'Know where gas/electric/water shutoffs are'),
];

/// Entry returned by expiry queries — the item plus its stored date.
class ExpiringItem {
  final ChecklistItem item;
  final DateTime expiryDate;
  final int daysRemaining;

  const ExpiringItem({
    required this.item,
    required this.expiryDate,
    required this.daysRemaining,
  });

  bool get isExpired => daysRemaining < 0;
}

class ChecklistProgress {
  ChecklistProgress._(this._rootDir);
  static final ChecklistProgress instance = ChecklistProgress._(null);

  /// Constructor for tests — uses [dirPath] instead of the global library.
  @visibleForTesting
  factory ChecklistProgress.forTest(String dirPath) {
    return ChecklistProgress._(dirPath);
  }

  final String? _rootDir;

  File get _file {
    final root = _rootDir ?? NuvokLibrary.instance.root.path;
    return File('$root/checklist.json');
  }

  Set<String> _done = {};
  Map<String, String> _expiry = {}; // itemId → ISO date string
  bool _loaded = false;

  Set<String> get done {
    if (!_loaded) _load();
    return Set.of(_done);
  }

  void _load() {
    _loaded = true;
    try {
      if (!_file.existsSync()) return;
      final raw = jsonDecode(_file.readAsStringSync());
      if (raw is List) {
        // Old format: bare list of completed ids.
        _done = {for (final s in raw) s.toString()};
        _expiry = {};
        return;
      }
      if (raw is Map<String, dynamic>) {
        final doneList = raw['done'];
        if (doneList is List) {
          _done = {for (final s in doneList) s.toString()};
        }
        final expiryMap = raw['expiry'];
        if (expiryMap is Map) {
          _expiry = {
            for (final e in expiryMap.entries)
              e.key.toString(): e.value.toString(),
          };
        }
      }
    } catch (_) {
      _done = {};
      _expiry = {};
    }
  }

  void toggle(String itemId) {
    final item = checklistItems.where((i) => i.id == itemId).firstOrNull;
    if (_done.contains(itemId)) {
      _done.remove(itemId);
      // Clear expiry when un-checking.
      _expiry.remove(itemId);
    } else {
      _done.add(itemId);
      // Auto-assign suggested expiry for perishable items.
      if (item != null && item.isPerishable && !_expiry.containsKey(itemId)) {
        final suggested =
            DateTime.now().add(Duration(days: 30 * item.expiryMonths));
        _expiry[itemId] = _toIsoDate(suggested);
      }
    }
    _save();
  }

  // ── Expiry API ──

  /// Sets the expiry/rotation date for an item.
  void setExpiry(String itemId, DateTime date) {
    _expiry[itemId] = _toIsoDate(date);
    _save();
  }

  /// Clears the expiry date for an item.
  void clearExpiry(String itemId) {
    _expiry.remove(itemId);
    _save();
  }

  /// Gets the stored expiry date, or null if not set.
  DateTime? getExpiry(String itemId) {
    if (!_loaded) _load();
    final s = _expiry[itemId];
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  /// Days remaining until expiry. Positive = future, negative = past.
  /// Null if no expiry date is set.
  int? daysUntilExpiry(String itemId) {
    final date = getExpiry(itemId);
    if (date == null) return null;
    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  /// True if the item is past its expiry date.
  bool isExpired(String itemId) {
    final d = daysUntilExpiry(itemId);
    return d != null && d < 0;
  }

  /// True if the item expires within 30 days.
  bool isNearExpiry(String itemId) {
    final d = daysUntilExpiry(itemId);
    return d != null && d >= 0 && d <= 30;
  }

  /// All items expiring within [withinDays] days (not yet expired).
  List<ExpiringItem> expiringItems({int withinDays = 30}) {
    final result = <ExpiringItem>[];
    for (final item in checklistItems) {
      final d = daysUntilExpiry(item.id);
      if (d == null) continue;
      if (d >= 0 && d <= withinDays) {
        result.add(ExpiringItem(
          item: item,
          expiryDate: getExpiry(item.id)!,
          daysRemaining: d,
        ));
      }
    }
    result.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return result;
  }

  /// All items that are already past their expiry date.
  List<ExpiringItem> expiredItems() {
    final result = <ExpiringItem>[];
    for (final item in checklistItems) {
      final d = daysUntilExpiry(item.id);
      if (d != null && d < 0) {
        result.add(ExpiringItem(
          item: item,
          expiryDate: getExpiry(item.id)!,
          daysRemaining: d,
        ));
      }
    }
    result.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return result;
  }

  /// Computes a suggested expiry date for an item based on its
  /// [expiryMonths] hint. Returns now for non-perishable items.
  static DateTime suggestedExpiryForItem(ChecklistItem item) {
    return DateTime.now().add(Duration(days: 30 * item.expiryMonths));
  }

  /// Forces a write to disk. Used by tests.
  void saveNow() => _save();

  void _save() {
    try {
      final dir = _file.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode({
        'done': _done.toList()..sort(),
        'expiry': _expiry,
      }));
    } catch (_) {}
  }

  static String _toIsoDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  double percentComplete() {
    if (checklistItems.isEmpty) return 0;
    return _done.length / checklistItems.length;
  }

  int completedCount() => _done.length;
  int totalCount() => checklistItems.length;

  List<ChecklistItem> itemsForCategory(String categoryId) {
    return checklistItems.where((i) => i.category == categoryId).toList();
  }

  int completedInCategory(String categoryId) {
    return checklistItems
        .where((i) => i.category == categoryId && _done.contains(i.id))
        .length;
  }

  int totalInCategory(String categoryId) {
    return checklistItems.where((i) => i.category == categoryId).length;
  }
}
