// Flashlight / SOS light — toggles the device torch (camera LED) on/off, or
// blinks an SOS Morse pattern (...---...) with it.
//
// Real LED via torch_light on phones that have a flash. On any device WITHOUT
// an LED (laptops, tablets/phones without flash), it falls back to a
// full-screen pure-white "flashlight" that blinks the same SOS — so the tool
// is useful everywhere, which is the whole point in an emergency.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';

enum FlashlightMode { off, on, sos }

class FlashlightController extends ChangeNotifier {
  FlashlightController._();
  static final FlashlightController instance = FlashlightController._();

  FlashlightMode _mode = FlashlightMode.off;
  FlashlightMode get mode => _mode;

  // Whether a real camera LED torch is present. When false, the UI uses the
  // white-screen fallback for both steady light and SOS.
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
      _available = await TorchLight.isTorchAvailable();
    } catch (_) {
      // No LED (desktop, or a phone/tablet without flash) — the white-screen
      // fallback takes over.
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
    if (!_available) return; // no LED — the white-screen fallback handles it
    try {
      if (on) {
        TorchLight.enableTorch();
      } else {
        TorchLight.disableTorch();
      }
    } catch (_) {
      // Torch became unavailable mid-use — degrade to the screen fallback.
      _available = false;
      notifyListeners();
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
    // Rebuild whenever the controller's mode/availability changes, otherwise
    // tapping to turn on/off wouldn't repaint the screen.
    _controller.addListener(_onControllerChange);
    if (!_controller.available) {
      _startUiSos();
    }
    _controller.checkAvailable();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
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
        appBar: AppBar(
            title: const Text('Linterna'),
            backgroundColor: Colors.black),
        body: GestureDetector(
          onTap: () => _controller.setMode(FlashlightMode.on),
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.flashlight_on,
                    color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('Toca para encender',
                    style: TextStyle(color: Colors.white54, fontSize: 18)),
              ],
            ),
          ),
        ),
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
