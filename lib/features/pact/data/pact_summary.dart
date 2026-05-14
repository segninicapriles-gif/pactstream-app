/// Resumen de un pacto para mostrar en la lista "Mis obras".
///
/// Mapea 1:1 con la fila devuelta por `sf_list_my_pacts()`.
class PactSummary {
  PactSummary({
    required this.pactId,
    required this.displayId,
    required this.title,
    required this.pactType,
    required this.state,
    required this.stateUpdatedAt,
    required this.totalAmountCents,
    required this.myRole,
    required this.partiesTotal,
    required this.partiesAccepted,
    required this.milestonesTotal,
    required this.milestonesPaid,
    required this.createdAt,
    this.obraCity,
    this.obraProvince,
    this.nextMilestoneName,
    this.nextMilestoneAmountCents,
    this.nextMilestoneTargetDate,
  });

  final String pactId;
  final String displayId;
  final String title;
  final String pactType; // 'obra_mayor' | 'obra_menor'
  final String state; // 'draft' | 'inviting' | 'signed' | 'funding' | ...
  final DateTime stateUpdatedAt;
  final String? obraCity;
  final String? obraProvince;
  final int totalAmountCents;
  final String myRole; // 'promotor' | 'constructor' | 'tecnico'
  final int partiesTotal;
  final int partiesAccepted;
  final int milestonesTotal;
  final int milestonesPaid;
  final String? nextMilestoneName;
  final int? nextMilestoneAmountCents;
  final DateTime? nextMilestoneTargetDate;
  final DateTime createdAt;

  factory PactSummary.fromRpcRow(Map<String, dynamic> row) {
    return PactSummary(
      pactId: row['pact_id'] as String,
      displayId: row['display_id'] as String,
      title: row['title'] as String,
      pactType: row['pact_type'] as String,
      state: row['state'] as String,
      stateUpdatedAt: DateTime.parse(row['state_updated_at'] as String),
      obraCity: row['obra_city'] as String?,
      obraProvince: row['obra_province'] as String?,
      totalAmountCents: (row['total_amount_cents'] as num).toInt(),
      myRole: row['my_role'] as String,
      partiesTotal: (row['parties_total'] as num).toInt(),
      partiesAccepted: (row['parties_accepted'] as num).toInt(),
      milestonesTotal: (row['milestones_total'] as num).toInt(),
      milestonesPaid: (row['milestones_paid'] as num).toInt(),
      nextMilestoneName: row['next_milestone_name'] as String?,
      nextMilestoneAmountCents: row['next_milestone_amount_cents'] != null
          ? (row['next_milestone_amount_cents'] as num).toInt()
          : null,
      nextMilestoneTargetDate: row['next_milestone_target_date'] != null
          ? DateTime.parse(row['next_milestone_target_date'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  // === Helpers de presentación ===

  /// Progreso del pacto en hitos pagados / total. 0..1
  double get progress =>
      milestonesTotal == 0 ? 0 : milestonesPaid / milestonesTotal;

  /// Localización abreviada para mostrar en la card.
  String get locationShort {
    if ((obraCity ?? '').isNotEmpty) return obraCity!;
    if ((obraProvince ?? '').isNotEmpty) return obraProvince!;
    return '—';
  }
}
