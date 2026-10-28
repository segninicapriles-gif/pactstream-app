import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pactstream/features/dashboard/data/budget_proposals.dart';
import 'package:pactstream/features/dashboard/presentation/widgets/budget_proposals_section.dart';

// Presupuestos enviados desde CostPact (puente D, 28-oct): el promotor los ve
// en su panel y crea la obra al aceptarlos.

Map<String, dynamic> _row({List<dynamic>? milestones}) => {
      'id': 'bp1',
      'title': 'Reforma Mayor 1',
      'constructor_name': 'Construcciones Demo',
      'total_amount_cents': 12000000,
      'payload': {'milestones': milestones},
      'created_at': '2026-10-28T12:00:00Z',
    };

Widget _section(List<BudgetProposal> proposals) => ProviderScope(
      overrides: [
        budgetProposalsProvider.overrideWith((ref) async => proposals),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BudgetProposalsSection())),
      ),
    );

void main() {
  test('fromJson cuenta los hitos del plan', () {
    final p = BudgetProposal.fromJson(_row(milestones: [{}, {}, {}]));
    expect(p.planItems, 3);
    expect(p.totalAmountCents, 12000000);
    expect(BudgetProposal.fromJson(_row()).planItems, 0);
  });

  testWidgets('sin propuestas no ocupa sitio', (tester) async {
    await tester.pumpWidget(_section(const []));
    await tester.pumpAndSettle();
    expect(find.text('Presupuestos recibidos'), findsNothing);
  });

  testWidgets('muestra la propuesta con aceptar y rechazar', (tester) async {
    await tester.pumpWidget(
        _section([BudgetProposal.fromJson(_row(milestones: [{}, {}]))]));
    await tester.pumpAndSettle();
    expect(find.text('Presupuestos recibidos'), findsOneWidget);
    expect(find.text('Reforma Mayor 1'), findsOneWidget);
    expect(find.text('Construcciones Demo · 2 hitos'), findsOneWidget);
    expect(find.text('Crear la obra'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });
}
