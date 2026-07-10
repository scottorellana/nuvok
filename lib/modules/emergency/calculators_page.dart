// Calculadoras OMS de emergencia: dosis pediátrica, suero oral y cloro.
// UI mínima sobre la lógica pura de emergency_calculators.dart.
import 'package:flutter/material.dart';

import '../../core/locale_service.dart';
import 'emergency_calculators.dart';

class CalculatorsPage extends StatefulWidget {
  const CalculatorsPage({super.key});

  @override
  State<CalculatorsPage> createState() => _CalculatorsPageState();
}

class _CalculatorsPageState extends State<CalculatorsPage> {
  double _weightKg = 15;
  double _orsLiters = 1;
  double _chlorLiters = 1;
  double _bleachPct = 5;
  bool _cloudy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'calcTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _doseCard(context),
          const SizedBox(height: 12),
          _orsCard(context),
          const SizedBox(height: 12),
          _chlorineCard(context),
          const SizedBox(height: 12),
          Text(
            tr(context, 'calcDisclaimer'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(value < 10 ? 1 : 0),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _doseCard(BuildContext context) {
    final para = EmergencyCalculators.paracetamolDose(_weightKg);
    PediatricDose? ibu;
    try {
      ibu = EmergencyCalculators.ibuprofenDose(_weightKg);
    } on ArgumentError {
      ibu = null;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💊 ${tr(context, 'calcDoseTitle')}',
                style: Theme.of(context).textTheme.titleMedium),
            _slider(
              label:
                  '${tr(context, 'calcWeightKg')}: ${_weightKg.toStringAsFixed(1)} kg',
              value: _weightKg,
              min: 3,
              max: 60,
              divisions: 114,
              onChanged: (v) => setState(() => _weightKg = v),
            ),
            Text('Paracetamol: ${para.minMg}–${para.maxMg} mg '
                '(${tr(context, 'calcPerDose')} ${para.intervalHours} h, '
                'máx ${para.maxDosesPerDay}/día)'),
            const SizedBox(height: 4),
            Text(ibu == null
                ? 'Ibuprofeno: ${tr(context, 'calcIbuNotUnder5')}'
                : 'Ibuprofeno: ${ibu.minMg}–${ibu.maxMg} mg '
                    '(${tr(context, 'calcPerDose')} ${ibu.intervalHours} h, '
                    'máx ${ibu.maxDosesPerDay}/día)'),
          ],
        ),
      ),
    );
  }

  Widget _orsCard(BuildContext context) {
    final r = EmergencyCalculators.oralRehydration(_orsLiters);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🥤 ${tr(context, 'calcOrsTitle')}',
                style: Theme.of(context).textTheme.titleMedium),
            _slider(
              label:
                  '${tr(context, 'calcLiters')}: ${_orsLiters.toStringAsFixed(1)} L',
              value: _orsLiters,
              min: 0.5,
              max: 5,
              divisions: 9,
              onChanged: (v) => setState(() => _orsLiters = v),
            ),
            Text(
              '${tr(context, 'calcSugar')}: ${r.sugarTsp.toStringAsFixed(1)} '
              '· ${tr(context, 'calcSalt')}: ${r.saltTsp.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(tr(context, 'calcTspNote'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _chlorineCard(BuildContext context) {
    final drops = EmergencyCalculators.chlorineDrops(
      liters: _chlorLiters,
      bleachPercent: _bleachPct,
      cloudy: _cloudy,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💧 ${tr(context, 'calcChlorineTitle')}',
                style: Theme.of(context).textTheme.titleMedium),
            _slider(
              label:
                  '${tr(context, 'calcLiters')}: ${_chlorLiters.toStringAsFixed(0)} L',
              value: _chlorLiters,
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => setState(() => _chlorLiters = v),
            ),
            Row(
              children: [
                Text('${tr(context, 'calcBleachPct')}: '),
                DropdownButton<double>(
                  value: _bleachPct,
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('1%')),
                    DropdownMenuItem(value: 2.5, child: Text('2.5%')),
                    DropdownMenuItem(value: 5.0, child: Text('5%')),
                    DropdownMenuItem(value: 10.0, child: Text('10%')),
                  ],
                  onChanged: (v) =>
                      setState(() => _bleachPct = v ?? 5.0),
                ),
                const Spacer(),
                Text(tr(context, 'calcCloudy')),
                Switch(
                  value: _cloudy,
                  onChanged: (v) => setState(() => _cloudy = v),
                ),
              ],
            ),
            Text(
              '$drops ${tr(context, 'calcDrops')}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(tr(context, 'calcWait30'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
