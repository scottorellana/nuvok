// Settings page — language selector and app configuration.
// Accessible from the nav rail or the welcome dialog.
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/bundled_library.dart';
import '../../core/locale_service.dart';
import '../../core/prepper_library.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<_SettingsInfo> _settingsInfo;

  @override
  void initState() {
    super.initState();
    _settingsInfo = _SettingsInfo.load();
  }

  @override
  Widget build(BuildContext context) {
    final service = LocaleProvider.serviceOf(context);
    final strings = LocaleProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Language selector ──
          _SectionCard(
            icon: Icons.language,
            title: strings.language,
            color: const Color(0xFF8C9E5E),
          ),
          const SizedBox(height: 8),
          ...AppLanguage.values.map((lang) {
            final isSelected = service.language == lang;
            // Material (not a colored Container) hosts the tile so the tap
            // ink splash is actually visible — Flutter warns otherwise.
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFF8C9E5E) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Material(
                color: isSelected
                    ? const Color(0xFF242B18)
                    : const Color(0xFF1A1F12),
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                leading: Text(lang.flag, style: const TextStyle(fontSize: 28)),
                title: Text(
                  lang.displayName,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFA8C277)
                        : const Color(0xFFE8F0D8),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF8C9E5E))
                    : null,
                onTap: () {
                  service.setLanguage(lang);
                },
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── About ──
          _SectionCard(
            icon: Icons.info_outline,
            title: 'Prepper Pad',
            color: const Color(0xFF5EB89E),
          ),
          const SizedBox(height: 8),
          FutureBuilder<_SettingsInfo>(
            future: _settingsInfo,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const _AboutStatusCard.loading();
              }
              return _AboutStatusCard(info: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }
}

class OfflineReadinessSummary {
  const OfflineReadinessSummary({
    required this.maps,
    required this.zims,
    required this.models,
    required this.notes,
    required this.totalBytes,
  });

  final int maps;
  final int zims;
  final int models;
  final int notes;
  final int totalBytes;

  bool get hasCoreStarterPack => maps > 0 && zims > 0 && models > 0;

  String get bundleLabel => '$maps mapas • $zims ZIM • $models IA';

  String get sizeLabel => humanSize(totalBytes);

  factory OfflineReadinessSummary.fromManifest(
    BundledLibraryManifest manifest,
  ) {
    var maps = 0;
    var zims = 0;
    var models = 0;
    var notes = 0;
    var totalBytes = 0;
    for (final entry in manifest.entries) {
      totalBytes += entry.bytes;
      switch (entry.kind) {
        case 'maps':
          maps++;
        case 'zim':
          zims++;
        case 'models':
          models++;
        case 'notes':
          notes++;
      }
    }
    return OfflineReadinessSummary(
      maps: maps,
      zims: zims,
      models: models,
      notes: notes,
      totalBytes: totalBytes,
    );
  }
}

class _SettingsInfo {
  const _SettingsInfo({
    required this.versionLabel,
    required this.libraryPath,
    required this.offlineSummary,
  });

  final String versionLabel;
  final String libraryPath;
  final OfflineReadinessSummary offlineSummary;

  static Future<_SettingsInfo> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final manifest = await BundledLibraryManifest.load();
    final summary = OfflineReadinessSummary.fromManifest(manifest);
    final buildSuffix =
        packageInfo.buildNumber.isEmpty ? '' : ' (${packageInfo.buildNumber})';
    return _SettingsInfo(
      versionLabel: '${packageInfo.version}$buildSuffix',
      libraryPath: PrepperLibrary.instance.root.path,
      offlineSummary: summary,
    );
  }
}

class _AboutStatusCard extends StatelessWidget {
  const _AboutStatusCard({required this.info}) : loading = false;

  const _AboutStatusCard.loading()
      : info = null,
        loading = true;

  final _SettingsInfo? info;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final loadedInfo = info;
    final summary = loadedInfo?.offlineSummary;
    final offlineOk = summary?.hasCoreStarterPack ?? false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backpack, color: Color(0xFF8C9E5E)),
            title: Text(
              loading
                  ? 'Prepper Pad'
                  : 'Prepper Pad v${loadedInfo!.versionLabel}',
              style: const TextStyle(color: Color(0xFFE8F0D8)),
            ),
            subtitle: const Text(
              'Biblioteca de conocimiento offline',
              style: TextStyle(color: Color(0xFF8A9070)),
            ),
          ),
          ListTile(
            leading: Icon(
              offlineOk ? Icons.offline_bolt : Icons.pending_outlined,
              color:
                  offlineOk ? const Color(0xFF5EB89E) : const Color(0xFFE4B363),
            ),
            title: Text(
              loading
                  ? 'Verificando paquete offline…'
                  : offlineOk
                      ? 'Paquete offline incluido'
                      : 'Paquete offline incompleto',
              style: const TextStyle(color: Color(0xFFE8F0D8)),
            ),
            subtitle: Text(
              loading
                  ? 'Comprobando mapas, biblioteca y modelo IA incluidos.'
                  : '${summary!.bundleLabel} • ${summary.sizeLabel}',
              style: const TextStyle(color: Color(0xFF8A9070)),
            ),
          ),
          if (!loading && loadedInfo != null)
            ListTile(
              leading: const Icon(Icons.folder_copy, color: Color(0xFFA8C277)),
              title: const Text('Carpeta portable',
                  style: TextStyle(color: Color(0xFFE8F0D8))),
              subtitle: Text(
                loadedInfo.libraryPath,
                style: const TextStyle(color: Color(0xFF8A9070)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
