// Flashlight / SOS light — toggles the device torch (camera LED) on/off, or
// blinks an SOS Morse pattern (...---...) with it.
//
// Real LED via torch_light on phones that have a flash. On any device WITHOUT
// an LED (laptops, tablets/phones without flash), it falls back to a
// full-screen pure-white "flashlight" that blinks the same SOS — so the tool
// is useful everywhere, which is the whole point in an emergency.
//
// Redesigned with clear, labeled buttons for each mode (ON / SOS / OFF)
// instead of the previous opaque tap-to-cycle full-screen approach.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/screen_awake.dart';
import 'package:torch_light/torch_light.dart';

import '../../core/nuvok_colors.dart';

enum FlashlightMode { off, on, sos }

class FlashlightController extends ChangeNotifier {
  FlashlightController._();
  static final FlashlightController instance = FlashlightController._();

  FlashlightMode _mode = FlashlightMode.off;
  FlashlightMode get mode => _mode;

  // Whether a real camera LED torch is present.
  bool _available = false;
  bool get available => _available;

  // If the LED cannot be used (absent or fail), SOS can still run via screen.
  bool _screenFallback = false;
  bool get isScreenFallback => _screenFallback;

  Timer? _sosTimer;
  int _sosStep = 0;

  // SOS Morse pattern: ...---... (dot=200ms, dash=600ms, gap=200ms,
  // letter gap=600ms, word gap=1400ms). Total cycle ~7 seconds.
  static const sosPattern = [
    Duration(milliseconds: 200), Duration(milliseconds: 200), // S .
    Duration(milliseconds: 200), Duration(milliseconds: 200), // S .
    Duration(milliseconds: 200), Duration(milliseconds: 600), // S . (last dot)
    Duration(milliseconds: 600), Duration(milliseconds: 200), // O -
    Duration(milliseconds: 600), Duration(milliseconds: 200), // O -
    Duration(milliseconds: 600), Duration(milliseconds: 600), // O - (last dash)
    Duration(milliseconds: 200), Duration(milliseconds: 200), // S .
    Duration(milliseconds: 200), Duration(milliseconds: 200), // S .
    Duration(milliseconds: 200), Duration(milliseconds: 1400), // S . + long gap
  ];

  Future<void> checkAvailable() async {
    final wasSos = _mode == FlashlightMode.sos;
    final usedFallback = _screenFallback;

    try {
      _available = await TorchLight.isTorchAvailable();
    } catch (_) {
      _available = false;
    }

    if (_available) {
      // If availability recovered and SOS was waiting with fallback,
      // immediately resume LED-driven SOS.
      if (wasSos && usedFallback) {
        _screenFallback = false;
        _sosStep = 0;
        await _runSos();
      } else if (wasSos) {
        _screenFallback = false;
      }
    } else if (wasSos) {
      // Keep SOS visible via UI fallback while re-checking hardware.
      _screenFallback = true;
    }

    notifyListeners();
  }

  Future<void> setMode(FlashlightMode newMode) async {
    _sosTimer?.cancel();
    _sosTimer = null;
    _mode = newMode;
    // La pantalla no puede dormirse mientras alumbras un derrumbe o emites
    // SOS Morse: el sistema la apagaba a los 30 s y la luz moría con ella.
    if (newMode == FlashlightMode.off) {
      unawaited(ScreenAwake.release('flashlight'));
    } else {
      unawaited(ScreenAwake.acquire('flashlight'));
    }
    if (newMode != FlashlightMode.sos) {
      _screenFallback = false;
    }

    switch (newMode) {
      case FlashlightMode.off:
        await _setTorch(false);
        break;
      case FlashlightMode.on:
        final onOk = await _setTorch(true);
        if (!onOk) _screenFallback = true;
        break;
      case FlashlightMode.sos:
        _sosStep = 0;
        if (_available) {
          // If we were previously using screen fallback, drop to LED path now.
          _screenFallback = false;
          await _runSos();
        } else {
          _screenFallback = true;
        }
        break;
    }
    notifyListeners();
  }

  Future<void> _runSos() async {
    final on = _sosStep.isEven;
    final torchOn = await _setTorch(on);
    if (_mode != FlashlightMode.sos) return;
    if (!torchOn || !_available) {
      _screenFallback = true;
      notifyListeners();
      return;
    }

    final delay = sosPattern[_sosStep % sosPattern.length];
    _sosTimer = Timer(delay, () {
      _sosStep++;
      if (_mode == FlashlightMode.sos && !_screenFallback) {
        _runSos();
      }
    });
  }

  Future<bool> _setTorch(bool on) async {
    if (!_available) return false;
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      return true;
    } catch (_) {
      _available = false;
      _screenFallback = true;
      notifyListeners();
      return false;
    }
  }

  void disposeTimer() {
    _sosTimer?.cancel();
    _sosTimer = null;
  }
}

/// Flashlight screen with clear mode buttons (ON / SOS / OFF).
/// The full-screen area acts as the visual flashlight (white screen
/// fallback), but the mode is controlled by explicit labeled buttons
/// at the bottom — no more guesswork.
class FlashlightScreen extends StatefulWidget {
  const FlashlightScreen({super.key});

  @override
  State<FlashlightScreen> createState() => _FlashlightScreenState();
}

class _FlashlightScreenState extends State<FlashlightScreen> {
  final _controller = FlashlightController.instance;
  Timer? _uiSosTimer;
  int _uiStep = 0;
  bool _uiOn = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
    _controller.checkAvailable();
  }

  void _onControllerChange() {
    if (mounted) {
      setState(() {});
      // When entering SOS mode without LED (or with LED failure), start the UI blink.
      if (_controller.mode == FlashlightMode.sos &&
          (_controller.isScreenFallback || !_controller.available)) {
        _startUiSos();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _uiSosTimer?.cancel();
    _controller.setMode(FlashlightMode.off);
    super.dispose();
  }

  void _startUiSos() {
    if (_controller.mode != FlashlightMode.sos) return;
    _uiSosTimer?.cancel();
    _uiStep = 0;
    _runUiSos();
  }

  void _runUiSos() {
    _uiOn = _uiStep.isEven;
    if (mounted) setState(() {});
    final delay = FlashlightController
        .sosPattern[_uiStep % FlashlightController.sosPattern.length];
    _uiSosTimer = Timer(delay, () {
      _uiStep++;
      if (_controller.mode == FlashlightMode.sos) {
        _runUiSos();
      } else if (_controller.mode == FlashlightMode.on) {
        _uiOn = true;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = _controller.mode;

    // Determine if the screen should be white (flashlight on or SOS blink-on)
    final showWhite = mode == FlashlightMode.on ||
        (mode == FlashlightMode.sos &&
            _uiOn &&
            (_controller.isScreenFallback || !_controller.available));

    return Scaffold(
      backgroundColor: showWhite ? Colors.white : Colors.black,
      appBar: AppBar(
        title: Text(
          mode == FlashlightMode.sos
              ? 'SOS Morse Activo'
              : mode == FlashlightMode.on
                  ? 'Linterna Encendida'
                  : 'Linterna',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ── Full-screen visual area (white when on, black when off) ──
          // On phones with a real LED, this area stays black — the LED is
          // the actual light source. On devices without LED, this turns
          // white to act as the flashlight.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              color: showWhite ? Colors.white : Colors.black,
            ),
          ),

          // ── SOS visual indicator (center) ──
          if (mode == FlashlightMode.sos)
            Center(
              child: AnimatedOpacity(
                opacity: _uiOn ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sos,
                        size: 80,
                        color: showWhite ? Colors.black54 : Colors.white54),
                    const SizedBox(height: 12),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: showWhite ? Colors.black54 : Colors.white54,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Mode status text (top center) ──
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(mode),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom control panel with CLEAR labeled buttons ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                // Semi-transparent dark bar so buttons are always visible
                // regardless of whether the screen is white or black.
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ── ON button ──
                    _ModeButton(
                      icon: Icons.flash_on,
                      label: 'ENCENDER',
                      color: Colors.amber,
                      isActive: mode == FlashlightMode.on,
                      onTap: () => _controller.setMode(FlashlightMode.on),
                    ),
                    // ── SOS button ──
                    _ModeButton(
                      icon: Icons.sos,
                      label: 'SOS',
                      color: Colors.red,
                      isActive: mode == FlashlightMode.sos,
                      isLarge: true,
                      onTap: () {
                        _controller.setMode(FlashlightMode.sos);
                        if (!_controller.available) _startUiSos();
                      },
                    ),
                    // ── OFF button ──
                    _ModeButton(
                      icon: Icons.power_settings_new,
                      label: 'APAGAR',
                      color: Colors.grey,
                      isActive: mode == FlashlightMode.off,
                      onTap: () => _controller.setMode(FlashlightMode.off),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(FlashlightMode mode) {
    if (mode == FlashlightMode.off) {
      return _controller.available
          ? 'Linterna lista (LED disponible)'
          : 'Sin LED — usa pantalla como luz';
    } else if (mode == FlashlightMode.on) {
      return _controller.available
          ? 'LED encendido · toca SOS para emergencia'
          : 'Pantalla blanca · toca SOS para emergencia';
    } else {
      return 'Parpadeando SOS en Morse (...---...)';
    }
  }
}

/// A clear, labeled, touchable mode button.
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
    this.isLarge = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 80.0 : 64.0;
    return Semantics(
      button: true,
      selected: isActive,
      label: switch (label) {
        'ENCENDER' => 'Encender linterna',
        'SOS' => 'Activar señal SOS luminosa',
        'APAGAR' => 'Apagar linterna',
        _ => label,
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing ring when active
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? color : Colors.white12,
                    border: Border.all(
                      color: isActive ? color : Colors.white24,
                      width: isActive ? 3 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? NuvokColors.black : NuvokColors.white,
                    size: isLarge ? 36 : 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? color : Colors.white70,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
