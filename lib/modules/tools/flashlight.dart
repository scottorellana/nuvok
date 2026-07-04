// Flashlight / SOS light — toggles the device torch on/off, or activates
// an SOS Morse code pattern (...---...) using the camera flash.
//
// On platforms without torch access (desktop), shows a full-screen white
// screen as a fallback "flashlight" that's surprisingly useful in the dark.
//
// Platform note: torch control requires the torch_light or camera plugin on
// mobile. On desktop we fall back to screen brightness. The torch state is
// managed here so the UI is identical across platforms.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// MethodChannel for torch control (native Android/macOS code not yet wired,
// but the interface is here for future integration).
const _torchChannel = MethodChannel('prepper/torch');

enum FlashlightMode { off, on, sos }

class FlashlightController extends ChangeNotifier {
  FlashlightController._();
  static final FlashlightController instance = FlashlightController._();

  FlashlightMode _mode = FlashlightMode.off;
  FlashlightMode get mode => _mode;

  bool _available = false;
  bool get available => _available;

  Timer? _sosTimer;
  int _sosStep = 0;

  // SOS Morse pattern: ...---... (dot=200ms, dash=600ms, gap=200ms,
  // letter gap=600ms, word gap=1400ms). Total cycle ~7 seconds.
  // Public so tests can verify timing.
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
    try {
      _available = await _torchChannel.invokeMethod('isAvailable') ?? false;
    } catch (_) {
      _available = false;
    }
    notifyListeners();
  }

  Future<void> setMode(FlashlightMode newMode) async {
    _sosTimer?.cancel();
    _sosTimer = null;
    _mode = newMode;

    switch (newMode) {
      case FlashlightMode.off:
        _setTorch(false);
        break;
      case FlashlightMode.on:
        _setTorch(true);
        break;
      case FlashlightMode.sos:
        _sosStep = 0;
        _runSos();
        break;
    }
    notifyListeners();
  }

  void _runSos() {
    final on = _sosStep.isEven;
    _setTorch(on);
    final delay = sosPattern[_sosStep % sosPattern.length];
    _sosTimer = Timer(delay, () {
      _sosStep++;
      if (_mode == FlashlightMode.sos) _runSos();
    });
  }

  void _setTorch(bool on) {
    try {
      _torchChannel.invokeMethod('toggle', {'on': on});
    } catch (_) {
      // No native torch on this platform — screen fallback handles it.
    }
  }

  void disposeTimer() {
    _sosTimer?.cancel();
    _sosTimer = null;
  }
}

/// Full-screen flashlight widget (fallback when no torch is available).
/// Shows pure white (max brightness) or blinks SOS in Morse.
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
    if (!_controller.available) {
      _startUiSos();
    }
    _controller.checkAvailable();
  }

  @override
  void dispose() {
    _uiSosTimer?.cancel();
    _controller.setMode(FlashlightMode.off);
    super.dispose();
  }

  void _startUiSos() {
    if (_controller.mode != FlashlightMode.sos) return;
    _uiStep = 0;
    _runUiSos();
  }

  void _runUiSos() {
    _uiOn = _uiStep.isEven;
    if (mounted) setState(() {});
    final delay = FlashlightController.sosPattern[_uiStep %
        FlashlightController.sosPattern.length];
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
    if (mode == FlashlightMode.off) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Linterna'), backgroundColor: Colors.black),
        body: const Center(child: Text('Linterna apagada', style: TextStyle(color: Colors.white54))),
      );
    }

    // Full-screen white for "on" mode, blinking for SOS
    final showWhite = mode == FlashlightMode.on ||
        (mode == FlashlightMode.sos && _uiOn && !_controller.available);

    return GestureDetector(
      onTap: () {
        // Cycle through modes on tap
        final next = switch (mode) {
          FlashlightMode.off => FlashlightMode.on,
          FlashlightMode.on => FlashlightMode.sos,
          FlashlightMode.sos => FlashlightMode.off,
        };
        _controller.setMode(next);
        if (next == FlashlightMode.sos && !_controller.available) {
          _startUiSos();
        }
      },
      child: Scaffold(
        backgroundColor: showWhite ? Colors.white : Colors.black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (mode == FlashlightMode.sos)
                const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Text(
                    'SOS ●●● ──── ●●●',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Text(
                  mode == FlashlightMode.on ? 'Toca para SOS' : 'Toca para apagar',
                  style: TextStyle(
                    color: showWhite ? Colors.black54 : Colors.white54,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
