import 'package:flutter_test/flutter_test.dart';
import 'package:prepper_pad/modules/emergency/emergency_calculators.dart';

void main() {
  group('dosis pediátrica (OMS: paracetamol 10-15 mg/kg, ibuprofeno 5-10)', () {
    test('paracetamol 18 kg', () {
      final d = EmergencyCalculators.paracetamolDose(18);
      expect(d.minMg, 180);
      expect(d.maxMg, 270);
      expect(d.maxDosesPerDay, 4);
    });
    test('ibuprofeno 10 kg', () {
      final d = EmergencyCalculators.ibuprofenDose(10);
      expect(d.minMg, 50);
      expect(d.maxMg, 100);
      expect(d.maxDosesPerDay, 3);
    });
    test('rechaza pesos absurdos', () {
      expect(() => EmergencyCalculators.paracetamolDose(0), throwsArgumentError);
      expect(() => EmergencyCalculators.paracetamolDose(-3), throwsArgumentError);
      expect(
          () => EmergencyCalculators.ibuprofenDose(300), throwsArgumentError);
    });
    test('ibuprofeno bloqueado bajo 3 meses/5kg (seguridad)', () {
      expect(() => EmergencyCalculators.ibuprofenDose(4), throwsArgumentError);
    });
  });

  group('suero de rehidratación oral (receta casera OMS por litro)', () {
    test('1 litro', () {
      final r = EmergencyCalculators.oralRehydration(1.0);
      expect(r.sugarTsp, 6);
      expect(r.saltTsp, 0.5);
    });
    test('2 litros escala lineal', () {
      final r = EmergencyCalculators.oralRehydration(2.0);
      expect(r.sugarTsp, 12);
      expect(r.saltTsp, 1.0);
    });
  });

  group('cloro para purificar agua (base: 2 gotas/L con lejía al 5%)', () {
    test('lejía 5%, 1 L agua clara', () {
      expect(EmergencyCalculators.chlorineDrops(liters: 1, bleachPercent: 5),
          2);
    });
    test('agua turbia duplica', () {
      expect(
          EmergencyCalculators.chlorineDrops(
              liters: 1, bleachPercent: 5, cloudy: true),
          4);
    });
    test('lejía 2.5% duplica gotas; 10 L escala', () {
      expect(EmergencyCalculators.chlorineDrops(liters: 1, bleachPercent: 2.5),
          4);
      expect(EmergencyCalculators.chlorineDrops(liters: 10, bleachPercent: 5),
          20);
    });
    test('concentraciones fuera de rango se rechazan', () {
      expect(
          () => EmergencyCalculators.chlorineDrops(
              liters: 1, bleachPercent: 0),
          throwsArgumentError);
      expect(
          () => EmergencyCalculators.chlorineDrops(
              liters: 1, bleachPercent: 30),
          throwsArgumentError);
    });
  });
}
