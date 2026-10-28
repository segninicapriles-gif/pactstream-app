import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pactstream/features/pact/data/costpact_importer.dart';

void main() {
  group('CostPactImporter', () {
    final payload = {
      'source': 'costpact',
      'costpact_presupuesto_id': ' 7f3c0d2e-0000-4000-8000-000000000001 ',
      'costpact_proyecto_numero': 'P-2026-014',
      'title': 'Reforma integral',
      'total_amount_cents': 4500000,
      'milestones': [
        {'name': 'Anticipo', 'amount_cents': 900000, 'trigger': 'firma_contrato'},
        {'name': 'Estructura', 'amount_cents': 1800000.4, 'percentage': 40},
        {'name': 'Retención', 'amount_cents': 225000, 'trigger': 'fin_garantia'},
      ],
    };

    test('guarda el presupuesto de origen y los hitos como plan', () {
      final result = CostPactImporter.parse(jsonEncode(payload));

      expect(result.data.hasCostpactBudget, isTrue);
      expect(result.data.costpactPresupuestoId,
          '7f3c0d2e-0000-4000-8000-000000000001',);
      expect(result.data.costpactPlan, hasLength(3));
      expect(result.data.costpactPlan[0]['trigger'], 'firma_contrato');
      expect(result.data.costpactPlan[1]['amount_cents'], 1800000);
      expect(result.milestoneCount, 3);
    });

    test('sin presupuesto de origen no hay enlace', () {
      final sinId = Map<String, dynamic>.from(payload)
        ..remove('costpact_presupuesto_id');
      final result = CostPactImporter.parse(jsonEncode(sinId));

      expect(result.data.hasCostpactBudget, isFalse);
    });

    test('no invita al cliente (es quien importa); sí al constructor', () {
      final soloCliente = CostPactImporter.parse(jsonEncode({
        ...payload,
        'client': {'name': 'Cliente', 'email': 'cliente@x.es'},
      }));
      expect(soloCliente.data.invites, isEmpty);

      final conConstructor = CostPactImporter.parse(jsonEncode({
        ...payload,
        'client': {'name': 'Cliente', 'email': 'cliente@x.es'},
        'constructor': {'name': 'Obras SL', 'email': 'obras@x.es'},
      }));
      expect(conConstructor.data.invites, hasLength(1));
      expect(conConstructor.data.invites.single.role, 'constructor');
      expect(conConstructor.data.invites.single.email, 'obras@x.es');
    });
  });
}
