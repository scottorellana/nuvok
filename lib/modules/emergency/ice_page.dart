// Ficha ICE: editar, mostrar GRANDE al rescatista (texto + QR con el mismo
// contenido para escanear/imprimir) y compartir al grupo por el mesh.
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/locale_service.dart';
import '../../core/nuvok_library.dart';
import '../mesh/mesh_channel.dart';
import '../mesh/mesh_service.dart';
import 'ice_profile.dart';

class IcePage extends StatefulWidget {
  const IcePage({super.key, this.storeOverride});
  final IceStore? storeOverride;

  @override
  State<IcePage> createState() => _IcePageState();
}

class _IcePageState extends State<IcePage> {
  late final IceStore _store = widget.storeOverride ??
      IceStore('${NuvokLibrary.instance.root.path}/emergency');

  late final _name = TextEditingController(text: _store.profile?.name ?? '');
  late final _blood =
      TextEditingController(text: _store.profile?.bloodType ?? '');
  late final _allergies =
      TextEditingController(text: _store.profile?.allergies ?? '');
  late final _meds =
      TextEditingController(text: _store.profile?.medications ?? '');
  late final _conditions =
      TextEditingController(text: _store.profile?.conditions ?? '');
  late final _c1 = TextEditingController(text: _store.profile?.contact1 ?? '');
  late final _c2 = TextEditingController(text: _store.profile?.contact2 ?? '');

  @override
  void dispose() {
    for (final c in [_name, _blood, _allergies, _meds, _conditions, _c1, _c2]) {
      c.dispose();
    }
    super.dispose();
  }

  IceProfile _current() => IceProfile(
        name: _name.text.trim(),
        bloodType: _blood.text.trim(),
        allergies: _allergies.text.trim(),
        medications: _meds.text.trim(),
        conditions: _conditions.text.trim(),
        contact1: _c1.text.trim(),
        contact2: _c2.text.trim(),
      );

  void _save() {
    _store.save(_current());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, 'save'))));
  }

  void _showRescueView() {
    _store.save(_current());
    final p = _store.profile;
    if (p == null || p.name.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('🆘 ICE')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Texto GRANDE: legible con el teléfono en la mano del
              // rescatista, con guantes y con sol.
              Text(
                p.rescueText(),
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 24),
              // QR con el MISMO texto: escaneable e imprimible para la
              // billetera o la pantalla de bloqueo.
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: p.rescueText(), size: 240),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _field(TextEditingController c, String labelKey,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: tr(context, labelKey),
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🆔 ${tr(context, 'iceTitle')}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(context, 'iceIntro'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          _field(_name, 'iceName'),
          _field(_blood, 'iceBlood', hint: 'O+, A-, …'),
          _field(_allergies, 'iceAllergies'),
          _field(_meds, 'iceMeds'),
          _field(_conditions, 'iceConditions'),
          _field(_c1, 'iceContact1'),
          _field(_c2, 'iceContact2'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              _save();
              _showRescueView();
            },
            icon: const Icon(Icons.badge),
            label: Text(tr(context, 'iceShow')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              _store.save(_current());
              final p = _store.profile;
              if (p == null || p.name.isEmpty) return;
              await MeshService.instance
                  .sendChat(MeshChannel.emergency, p.rescueText());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr(context, 'tqShared'))));
              }
            },
            icon: const Icon(Icons.podcasts),
            label: Text(tr(context, 'iceShareMesh')),
          ),
        ],
      ),
    );
  }
}
