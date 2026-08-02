// Cross-module navigation: lets any page jump the shell to another module
// (e.g. an empty Library offering "download the starter pack" must land the
// user in Depósito → Esenciales with one tap). Same notifier pattern as
// MapFocus: pages fire, HomeShell listens.
import 'package:flutter/foundation.dart';

class ShellNavRequest {
  const ShellNavRequest(this.moduleIndex, {this.depotTab});
  final int moduleIndex;
  final int? depotTab;
}

class ShellNav {
  ShellNav._();

  static final ValueNotifier<ShellNavRequest?> request = ValueNotifier(null);

  /// Module indexes as wired in HomeShell._pages.
  static const int maps = 3;
  static const int comms = 4;
  static const int tools = 6;
  static const int depot = 8;

  /// Pestañas del Depósito, en el orden en que las pinta DepotPage.
  static const int depotTabLibrary = 1;
  static const int depotTabModels = 2;
  static const int depotTabMaps = 3;

  static void goDepot({int tab = 0}) =>
      request.value = ShellNavRequest(depot, depotTab: tab);

  static void goMaps() => request.value = const ShellNavRequest(maps);

  /// Salto genérico a un módulo del shell.
  static void go(int moduleIndex) =>
      request.value = ShellNavRequest(moduleIndex);
}
