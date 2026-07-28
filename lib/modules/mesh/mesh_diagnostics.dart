// Diagnóstico del mesh: contadores por transporte y una bitácora corta de
// eventos, con un reporte copiable.
//
// Por qué existe: Nuvok funciona sin internet, así que cuando algo falla NO
// se le pueden pedir registros al usuario ni mirar un servidor. La app tiene
// que poder decir por sí misma "el Bluetooth se está anunciando pero nadie
// responde". Sin esto, diagnosticar es adivinar — y adivinar cuesta horas.
//
// Todo acotado en memoria: un teléfono en emergencia no puede permitirse que
// la bitácora crezca sin límite.
import 'package:flutter/foundation.dart';

/// Tráfico observado en un transporte.
class TransportCounters {
  int sent = 0;
  int sentBytes = 0;
  int received = 0;
  int receivedBytes = 0;
}

/// Un evento con su marca de tiempo.
@immutable
class DiagEvent {
  const DiagEvent(this.at, this.message);
  final DateTime at;
  final String message;

  String get hhmmss =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}';
}

class MeshDiagnostics extends ChangeNotifier {
  MeshDiagnostics._();
  static final MeshDiagnostics instance = MeshDiagnostics._();

  /// Tope de la bitácora. Lo suficiente para ver qué pasó, sin comerse la RAM.
  static const int maxEvents = 200;

  final Map<String, TransportCounters> counters = {};
  final List<DiagEvent> events = [];

  TransportCounters _for(String transport) =>
      counters.putIfAbsent(transport, TransportCounters.new);

  void recordSent(String transport, int bytes) {
    final c = _for(transport)
      ..sent += 1
      ..sentBytes += bytes;
    if (c.sent == 1) log('primer envío por $transport');
    notifyListeners();
  }

  void recordReceived(String transport, int bytes) {
    final c = _for(transport)
      ..received += 1
      ..receivedBytes += bytes;
    // El PRIMER dato recibido por una vía es la señal más valiosa del
    // diagnóstico: prueba que esa radio realmente está entregando tráfico.
    if (c.received == 1) log('PRIMER DATO recibido por $transport ✓');
    notifyListeners();
  }

  void log(String message) {
    events.add(DiagEvent(DateTime.now(), message));
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    notifyListeners();
  }

  void reset() {
    counters.clear();
    events.clear();
    notifyListeners();
  }

  /// Reporte en texto plano para copiar y pegar (soporte por WhatsApp, etc.).
  String snapshotText({
    required int peers,
    required int queued,
    required List<String> transports,
  }) {
    final b = StringBuffer()
      ..writeln('--- Diagnóstico Nuvok ---')
      ..writeln('Vecinos: $peers · En cola: $queued')
      ..writeln('')
      ..writeln('Vías:');
    if (transports.isEmpty) {
      b.writeln('  (ninguna activa)');
    } else {
      for (final t in transports) {
        b.writeln('  $t');
      }
    }
    b
      ..writeln('')
      ..writeln('Tráfico:');
    if (counters.isEmpty) {
      b.writeln('  (sin tráfico todavía)');
    } else {
      for (final e in counters.entries) {
        b.writeln('  ${e.key}: ↑${e.value.sent} (${e.value.sentBytes}B) '
            '↓${e.value.received} (${e.value.receivedBytes}B)');
      }
    }
    b
      ..writeln('')
      ..writeln('Eventos recientes:');
    if (events.isEmpty) {
      b.writeln('  (sin eventos)');
    } else {
      for (final e in events.reversed.take(40)) {
        b.writeln('  ${e.hhmmss}  ${e.message}');
      }
    }
    return b.toString();
  }
}
