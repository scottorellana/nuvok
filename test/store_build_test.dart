import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/build_flags.dart';
import 'package:nuvok/modules/depot/depot_page.dart';

// Store builds (App Store / Google Play) must not self-update — the stores
// own updates (Apple 2.5.2). Direct builds keep the LAN update system.
void main() {
  test('por defecto NO es build de tienda (canal directo conserva updates)',
      () {
    expect(kStoreBuild, isFalse,
        reason: 'sin --dart-define=STORE_BUILD=true el canal directo manda');
  });

  test('la pestaña de updates del Depósito se decide por bandera/plataforma',
      () {
    // Build directo en desktop/Android: la pestaña App existe.
    expect(DepotPage.showUpdatesTab(storeBuild: false, isIOS: false), isTrue);
    // Build de tienda: nunca.
    expect(DepotPage.showUpdatesTab(storeBuild: true, isIOS: false), isFalse);
    // iPhone: nunca — en iOS no existe sideload, toda instalación es de la
    // App Store, así que ofrecer updates propios violaría 2.5.2 siempre.
    expect(DepotPage.showUpdatesTab(storeBuild: false, isIOS: true), isFalse);
  });
}
