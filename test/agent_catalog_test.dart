import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvok/modules/ai/agents/agent_spec.dart';
import 'package:nuvok/modules/ai/agents/agent_catalog.dart';

void main() {
  test('AgentSpec expone rol y system prompt por idioma con fallback', () {
    const spec = AgentSpec(
      id: 'test',
      nameProper: 'Tester',
      roleByLang: {'es': 'Rol', 'en': 'Role'},
      avatar: Icons.person,
      accent: Color(0xFF000000),
      modelId: 'general-1.7b',
      grounding: GroundingMode.none,
      temperature: 0.7,
      systemByLang: {'es': 'sys es', 'en': 'sys en'},
      quickChipKeys: [],
    );
    expect(spec.role('es'), 'Rol');
    expect(spec.role('zh'), 'Role'); // fallback a inglés
    expect(spec.system('es'), 'sys es');
    expect(spec.system('zh'), 'sys en'); // fallback a inglés
    expect(spec.crisisGuardrails, isFalse);
  });

  test('los 6 agentes existen con rol y system en los 7 idiomas', () {
    const langs = ['es', 'en', 'pt', 'fr', 'zh', 'ja', 'ht'];
    expect(AgentCatalog.all.map((a) => a.id).toSet(), {
      'medic',
      'psychologist',
      'engineer',
      'survival',
      'translator',
      'librarian',
    });
    for (final a in AgentCatalog.all) {
      for (final l in langs) {
        expect(a.roleByLang[l], isNotNull, reason: '${a.id} rol sin $l');
        expect(a.systemByLang[l]?.trim(), isNotEmpty,
            reason: '${a.id} system sin $l');
      }
    }
  });

  test('el system prompt fija el idioma de respuesta por su nombre nativo', () {
    final vera = AgentCatalog.byId('medic')!;
    expect(vera.system('es'), contains('SIEMPRE en español'));
    expect(vera.system('fr'), contains('SIEMPRE en français'));
    expect(vera.system('ja'), contains('SIEMPRE en 日本語'));
  });

  test('byId encuentra y devuelve null si no existe', () {
    expect(AgentCatalog.byId('medic')?.nameProper, 'Vera');
    expect(AgentCatalog.byId('nope'), isNull);
  });

  test('el psicólogo activa guardrails de crisis', () {
    expect(AgentCatalog.byId('psychologist')!.crisisGuardrails, isTrue);
  });
}
