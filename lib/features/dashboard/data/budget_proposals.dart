import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/supabase/supabase_client.dart';

/// Presupuesto de CostPact enviado al promotor (tabla `budget_proposals`).
///
/// El constructor lo envía desde CostPact; el promotor lo acepta aquí y
/// entonces se crea el pacto a su nombre (`sf_accept_budget_proposal`).
class BudgetProposal {
  const BudgetProposal({
    required this.id,
    required this.title,
    required this.constructorName,
    required this.totalAmountCents,
    required this.planItems,
    required this.createdAt,
  });

  factory BudgetProposal.fromJson(Map<String, dynamic> json) {
    final milestones = (json['payload'] as Map<String, dynamic>?)?['milestones'];
    return BudgetProposal(
      id: json['id'] as String,
      title: json['title'] as String,
      constructorName: json['constructor_name'] as String,
      totalAmountCents: (json['total_amount_cents'] as num).toInt(),
      planItems: milestones is List ? milestones.length : 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String title;
  final String constructorName;
  final int totalAmountCents;
  final int planItems;
  final DateTime createdAt;
}

/// Propuestas pendientes del usuario (la RLS ya filtra por su email).
final budgetProposalsProvider =
    FutureProvider.autoDispose<List<BudgetProposal>>((ref) async {
  final rows = await SupabaseConfig.client
      .from('budget_proposals')
      .select('id, title, constructor_name, total_amount_cents, payload, created_at')
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return rows.map(BudgetProposal.fromJson).toList();
});

/// Acepta la propuesta y devuelve el id del pacto creado (en borrador).
Future<String> acceptBudgetProposal(String proposalId) async {
  final res = await SupabaseConfig.client.rpc(
    'sf_accept_budget_proposal',
    params: {'p_proposal_id': proposalId},
  ) as Map<String, dynamic>;
  return res['pact_id'] as String;
}

Future<void> declineBudgetProposal(String proposalId) async {
  await SupabaseConfig.client.rpc(
    'sf_decline_budget_proposal',
    params: {'p_proposal_id': proposalId},
  );
}
