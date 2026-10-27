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
  });
}
