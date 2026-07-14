import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/core/locale_service.dart';

void main() {
  test('las claves de UI de agentes existen en los 7 idiomas', () {
    const langs = ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'];
    const keys = [
      'agentsTitle', 'agentPick', 'agentReady', 'agentDownload',
      'agentLiteMode', 'agentSwitching', 'agentAdvancedModel',
      'agentCrisisNotice',
    ];
    for (final k in keys) {
      final map = AppStrings.allKeys[k];
      expect(map, isNotNull, reason: 'falta clave $k');
      for (final l in langs) {
        expect(map![l]?.trim(), isNotEmpty, reason: '$k sin $l');
      }
    }
  });
}
