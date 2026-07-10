import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/emergency/ice_profile.dart';

void main() {
  test('persiste y recarga la ficha', () {
    final dir = Directory.systemTemp.createTempSync('ice').path;
    final store = IceStore(dir);
    expect(store.profile, isNull);

    store.save(const IceProfile(
      name: 'Scott O.',
      bloodType: 'O+',
      allergies: 'Penicilina',
      medications: 'Ninguna',
      conditions: 'Asma leve',
      contact1: 'Ana +504 9999-0000',
      contact2: '',
    ));

    final again = IceStore(dir).profile;
    expect(again, isNotNull);
    expect(again!.bloodType, 'O+');
    expect(again.allergies, 'Penicilina');
  });

  test('el texto de rescate incluye lo vital y omite campos vacíos', () {
    const p = IceProfile(
      name: 'Ana',
      bloodType: 'A-',
      allergies: 'Mariscos',
      medications: '',
      conditions: 'Diabetes tipo 1',
      contact1: 'Luis +504 8888-1111',
      contact2: '',
    );
    final txt = p.rescueText();
    expect(txt, contains('ICE'));
    expect(txt, contains('Ana'));
    expect(txt, contains('A-'));
    expect(txt, contains('Mariscos'));
    expect(txt, contains('Diabetes'));
    expect(txt, contains('Luis'));
    expect(txt.contains('Medicamentos'), isFalse); // vacío → no aparece
  });
}
