/// Modelos del detalle completo de un pacto (v1 + v2.0).
///
/// Mapean al JSON devuelto por `sf_get_pact_detail(p_pact_id)`.
/// Los campos marcados como "v2" solo vienen poblados para pacts creados
/// con `sf_create_pact_v2` (model_version='v2'). En v1 son null/0.

class PactDetail {
  PactDetail({
    required this.pact,
    required this.parties,
    required this.milestones,
    required this.addendums,
    required this.depositMovements,
  });

  final PactCore pact;
  final List<PactParty> parties;
  final List<PactMilestone> milestones;
  final List<PactAddendum> addendums;
  final List<DepositMovement> depositMovements;

  factory PactDetail.fromJson(Map<String, dynamic> json) {
    return PactDetail(
      pact: PactCore.fromJson(json['pact'] as Map<String, dynamic>),
      parties: (json['parties'] as List<dynamic>? ?? const [])
          .map((e) => PactParty.fromJson(e as Map<String, dynamic>))
          .toList(),
      milestones: (json['milestones'] as List<dynamic>? ?? const [])
          .map((e) => PactMilestone.fromJson(e as Map<String, dynamic>))
          .toList(),
      addendums: (json['addendums'] as List<dynamic>? ?? const [])
          .map((e) => PactAddendum.fromJson(e as Map<String, dynamic>))
          .toList(),
      depositMovements: (json['deposit_movements'] as List<dynamic>? ?? const [])
          .map((e) => DepositMovement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // === Helpers de presentación ===

  /// Total de hitos / certificaciones pagados.
  int get milestonesPaid =>
      milestones.where((m) => m.state == 'paid').length;

  /// Importe total ya liberado a través de certificaciones pagadas.
  int get amountReleasedCents => milestones
      .where((m) => m.state == 'paid')
      .fold<int>(0, (acc, m) => acc + m.amountCents);

  /// Importe de certificaciones en curso (validadas o aprobadas, no pagadas).
  int get amountInCustodyCents => milestones
      .where((m) => m.state != 'paid' && m.state != 'pending')
      .fold<int>(0, (acc, m) => acc + m.amountCents);

  /// Próxima certificación pendiente de acción.
  PactMilestone? get nextMilestone {
    for (final m in milestones) {
      if (m.state != 'paid') return m;
    }
    return null;
  }

  /// Mi parte (donde is_me == true).
  PactParty? get me {
    for (final p in parties) {
      if (p.isMe) return p;
    }
    return null;
  }

  // === Helpers v2.0 ===

  /// Anexos activos (impactan el presupuesto).
  List<PactAddendum> get activeAddendums =>
      addendums.where((a) => a.state == 'active').toList();

  /// Anexos pendientes de firma.
  List<PactAddendum> get pendingAddendums => addendums
      .where((a) => a.state == 'proposed' || a.state == 'signing')
      .toList();

  /// Suma de todos los anexos activos en céntimos.
  int get addendumsTotalCents =>
      activeAddendums.fold<int>(0, (acc, a) => acc + a.extraAmountCents);

  /// Presupuesto efectivo (total + anexos activos).
  int get effectiveBudgetCents =>
      pact.totalAmountCents + addendumsTotalCents;

  /// % del depósito consumido respecto al requerido.
  double get depositConsumedPct {
    if (!pact.isV2 || pact.depositRequiredCents == 0) return 0;
    final consumed =
        pact.depositRequiredCents - pact.depositCurrentCents;
    if (consumed <= 0) return 0;
    return (consumed / pact.depositRequiredCents * 100).clamp(0, 100).toDouble();
  }

  /// El depósito está "bajo" cuando queda menos del 25 % del requerido.
  bool get isDepositLow {
    if (!pact.isV2 || pact.depositRequiredCents == 0) return false;
    return pact.depositCurrentCents < pact.depositRequiredCents * 0.25;
  }
}

/// Información core del pacto.
class PactCore {
  PactCore({
    required this.id,
    required this.displayId,
    required this.title,
    required this.pactType,
    required this.state,
    required this.stateUpdatedAt,
    required this.obraAddressLine,
    required this.totalAmountCents,
    required this.platformFeePct,
    required this.createdByUserId,
    required this.createdAt,
    required this.isCreator,
    required this.myUserId,
    required this.modelVersion,
    required this.depositCurrentCents,
    required this.budgetConsumedCents,
    this.description,
    this.obraPostalCode,
    this.obraCity,
    this.obraProvince,
    this.obraType,
    this.ivaRatePct,
    this.ivaIncluded,
    this.estimatedStartDate,
    this.estimatedEndDate,
    this.depositRequiredPct,
    this.certificationFrequencyText,
  });

  final String id;
  final String displayId;
  final String title;
  final String? description;
  final String pactType;
  final String state;
  final DateTime stateUpdatedAt;
  final String obraAddressLine;
  final String? obraPostalCode;
  final String? obraCity;
  final String? obraProvince;
  final String? obraType;
  final int totalAmountCents;
  final num? ivaRatePct;
  final bool? ivaIncluded;
  final num platformFeePct;
  final DateTime? estimatedStartDate;
  final DateTime? estimatedEndDate;
  final String createdByUserId;
  final DateTime createdAt;
  final bool isCreator;
  final String myUserId;

  // === Campos v2.0 ===
  /// 'v1' o 'v2'. 'v1' por defecto para pacts antiguos.
  final String modelVersion;
  /// % del presupuesto que el promotor debe depositar al firmar (null en v1).
  final num? depositRequiredPct;
  /// Balance actual del depósito en céntimos. 0 si todavía no se depositó.
  final int depositCurrentCents;
  /// Importe total ya certificado y consumido (suma de certificaciones pagadas).
  final int budgetConsumedCents;
  /// Texto libre de la frecuencia de certificación acordada.
  final String? certificationFrequencyText;

  bool get isV2 => modelVersion == 'v2';

  /// Importe que el promotor tiene que mantener en custodia.
  int get depositRequiredCents {
    if (depositRequiredPct == null) return 0;
    return (totalAmountCents * depositRequiredPct! / 100).round();
  }

  factory PactCore.fromJson(Map<String, dynamic> j) {
    return PactCore(
      id: j['id'] as String,
      displayId: j['display_id'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      pactType: j['pact_type'] as String,
      state: j['state'] as String,
      stateUpdatedAt: DateTime.parse(j['state_updated_at'] as String),
      obraAddressLine: j['obra_address_line'] as String,
      obraPostalCode: j['obra_postal_code'] as String?,
      obraCity: j['obra_city'] as String?,
      obraProvince: j['obra_province'] as String?,
      obraType: j['obra_type'] as String?,
      totalAmountCents: (j['total_amount_cents'] as num).toInt(),
      ivaRatePct: j['iva_rate_pct'] as num?,
      ivaIncluded: j['iva_included'] as bool?,
      platformFeePct: j['platform_fee_pct'] as num,
      estimatedStartDate: j['estimated_start_date'] != null
          ? DateTime.parse(j['estimated_start_date'] as String)
          : null,
      estimatedEndDate: j['estimated_end_date'] != null
          ? DateTime.parse(j['estimated_end_date'] as String)
          : null,
      createdByUserId: j['created_by_user_id'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      isCreator: j['is_creator'] as bool? ?? false,
      myUserId: j['my_user_id'] as String,
      // v2
      modelVersion: (j['model_version'] as String?) ?? 'v1',
      depositRequiredPct: j['deposit_required_pct'] as num?,
      depositCurrentCents:
          ((j['deposit_current_cents'] as num?) ?? 0).toInt(),
      budgetConsumedCents:
          ((j['budget_consumed_cents'] as num?) ?? 0).toInt(),
      certificationFrequencyText: j['certification_frequency_text'] as String?,
    );
  }
}

/// Una parte del pacto (promotor / constructor / técnico).
class PactParty {
  PactParty({
    required this.id,
    required this.role,
    required this.isMe,
    this.userId,
    this.snapshotFullName,
    this.snapshotEmail,
    this.invitedAt,
    this.acceptedAt,
    this.signedAt,
    this.signatureState,
    this.signatureId,
  });

  final String id;
  final String role;
  final String? userId;
  final bool isMe;
  final String? snapshotFullName;
  final String? snapshotEmail;
  final DateTime? invitedAt;
  final DateTime? acceptedAt;
  final DateTime? signedAt;
  final String? signatureState;
  final String? signatureId;

  bool get hasAccepted => acceptedAt != null;
  bool get hasSigned => signedAt != null;

  factory PactParty.fromJson(Map<String, dynamic> j) {
    return PactParty(
      id: j['id'] as String,
      role: j['role'] as String,
      userId: j['user_id'] as String?,
      isMe: j['is_me'] as bool? ?? false,
      snapshotFullName: j['snapshot_full_name'] as String?,
      snapshotEmail: j['snapshot_email'] as String?,
      invitedAt: j['invited_at'] != null
          ? DateTime.parse(j['invited_at'] as String)
          : null,
      acceptedAt: j['accepted_at'] != null
          ? DateTime.parse(j['accepted_at'] as String)
          : null,
      signedAt: j['signed_at'] != null
          ? DateTime.parse(j['signed_at'] as String)
          : null,
      signatureState: j['signature_state'] as String?,
      signatureId: j['signature_id'] as String?,
    );
  }
}

/// Un hito (v1) o una certificación (v2) del pacto.
class PactMilestone {
  PactMilestone({
    required this.id,
    required this.displayId,
    required this.ordinal,
    required this.name,
    required this.amountCents,
    required this.state,
    required this.stateUpdatedAt,
    required this.version,
    this.description,
    this.targetDate,
    this.startedAt,
    this.submittedAt,
    this.validatedAt,
    this.approvedByPromotorAt,
    this.rejectedAt,
    this.paidAt,
    this.previousVersionId,
    this.invoiceNumber,
    this.invoiceStoragePath,
    this.invoiceSha256,
    this.invoiceSizeBytes,
    this.detailedDocStoragePath,
    this.detailedDocSha256,
    this.detailedDocMimeType,
    this.detailedDocSizeBytes,
  });

  final String id;
  final String displayId;
  final int ordinal;
  final String name;
  final String? description;
  final int amountCents;
  final DateTime? targetDate;
  final String state;
  final DateTime stateUpdatedAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? validatedAt;
  final DateTime? approvedByPromotorAt;
  final DateTime? rejectedAt;
  final DateTime? paidAt;

  // === Campos v2.0 ===
  /// Versión de la certificación. Empieza en 1; incrementa al editar tras rechazo.
  final int version;
  final String? previousVersionId;
  /// Número de factura adjunta (v2 lo exige para enviar a validación).
  final String? invoiceNumber;
  final String? invoiceStoragePath;
  final String? invoiceSha256;
  final int? invoiceSizeBytes;
  /// Documento detallado opcional (obligatorio en obra mayor > 50K€).
  final String? detailedDocStoragePath;
  final String? detailedDocSha256;
  final String? detailedDocMimeType;
  final int? detailedDocSizeBytes;

  bool get hasInvoice => invoiceStoragePath != null;
  bool get hasDetailedDoc => detailedDocStoragePath != null;
  bool get isEdited => version > 1;

  factory PactMilestone.fromJson(Map<String, dynamic> j) {
    return PactMilestone(
      id: j['id'] as String,
      displayId: j['display_id'] as String,
      ordinal: (j['ordinal'] as num).toInt(),
      name: j['name'] as String,
      description: j['description'] as String?,
      amountCents: (j['amount_cents'] as num).toInt(),
      targetDate: j['target_date'] != null
          ? DateTime.parse(j['target_date'] as String)
          : null,
      state: j['state'] as String,
      stateUpdatedAt: DateTime.parse(j['state_updated_at'] as String),
      startedAt: _parseDt(j['started_at']),
      submittedAt: _parseDt(j['submitted_at']),
      validatedAt: _parseDt(j['validated_at']),
      approvedByPromotorAt: _parseDt(j['approved_by_promotor_at']),
      rejectedAt: _parseDt(j['rejected_at']),
      paidAt: _parseDt(j['paid_at']),
      // v2
      version: ((j['version'] as num?) ?? 1).toInt(),
      previousVersionId: j['previous_version_id'] as String?,
      invoiceNumber: j['invoice_number'] as String?,
      invoiceStoragePath: j['invoice_storage_path'] as String?,
      invoiceSha256: j['invoice_sha256'] as String?,
      invoiceSizeBytes: (j['invoice_size_bytes'] as num?)?.toInt(),
      detailedDocStoragePath: j['detailed_doc_storage_path'] as String?,
      detailedDocSha256: j['detailed_doc_sha256'] as String?,
      detailedDocMimeType: j['detailed_doc_mime_type'] as String?,
      detailedDocSizeBytes: (j['detailed_doc_size_bytes'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDt(dynamic v) =>
      v != null ? DateTime.parse(v as String) : null;
}

/// Un anexo formal al pacto (modelo v2.0).
/// Se propone por una parte y debe ser firmado por todas para activarse.
class PactAddendum {
  PactAddendum({
    required this.id,
    required this.displayId,
    required this.ordinal,
    required this.title,
    required this.extraAmountCents,
    required this.extraDays,
    required this.proposedByUserId,
    required this.proposedByRole,
    required this.state,
    required this.createdAt,
    this.description,
    this.justification,
    this.detailedDocStoragePath,
    this.detailedDocSha256,
    this.detailedDocMimeType,
    this.detailedDocSizeBytes,
    this.signedAtPromotor,
    this.signedAtConstructor,
    this.signedAtTecnico,
    this.activatedAt,
    this.cancelledAt,
  });

  final String id;
  final String displayId;
  final int ordinal;
  final String title;
  final String? description;
  /// Variación del importe del pacto. Puede ser positivo o negativo.
  final int extraAmountCents;
  /// Días extra al calendario (puede ser 0).
  final int extraDays;
  final String? justification;
  final String? detailedDocStoragePath;
  final String? detailedDocSha256;
  final String? detailedDocMimeType;
  final int? detailedDocSizeBytes;
  final String proposedByUserId;
  final String proposedByRole;
  /// 'proposed' | 'signing' | 'active' | 'cancelled'
  final String state;
  final DateTime? signedAtPromotor;
  final DateTime? signedAtConstructor;
  final DateTime? signedAtTecnico;
  final DateTime? activatedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  bool get hasDoc => detailedDocStoragePath != null;
  bool get isActive => state == 'active';
  bool get isPending => state == 'proposed' || state == 'signing';

  /// Devuelve true si la parte indicada (rol) ya firmó.
  bool signedByRole(String role) {
    switch (role) {
      case 'promotor':
        return signedAtPromotor != null;
      case 'constructor':
        return signedAtConstructor != null;
      case 'tecnico':
        return signedAtTecnico != null;
      default:
        return false;
    }
  }

  factory PactAddendum.fromJson(Map<String, dynamic> j) {
    return PactAddendum(
      id: j['id'] as String,
      displayId: j['display_id'] as String,
      ordinal: (j['ordinal'] as num).toInt(),
      title: j['title'] as String,
      description: j['description'] as String?,
      extraAmountCents: (j['extra_amount_cents'] as num).toInt(),
      extraDays: ((j['extra_days'] as num?) ?? 0).toInt(),
      justification: j['justification'] as String?,
      detailedDocStoragePath: j['detailed_doc_storage_path'] as String?,
      detailedDocSha256: j['detailed_doc_sha256'] as String?,
      detailedDocMimeType: j['detailed_doc_mime_type'] as String?,
      detailedDocSizeBytes: (j['detailed_doc_size_bytes'] as num?)?.toInt(),
      proposedByUserId: j['proposed_by_user_id'] as String,
      proposedByRole: j['proposed_by_role'] as String,
      state: j['state'] as String,
      signedAtPromotor: _parseDt(j['signed_at_promotor']),
      signedAtConstructor: _parseDt(j['signed_at_constructor']),
      signedAtTecnico: _parseDt(j['signed_at_tecnico']),
      activatedAt: _parseDt(j['activated_at']),
      cancelledAt: _parseDt(j['cancelled_at']),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  static DateTime? _parseDt(dynamic v) =>
      v != null ? DateTime.parse(v as String) : null;
}

/// Un movimiento del depósito en custodia (append-only).
class DepositMovement {
  DepositMovement({
    required this.id,
    required this.movementType,
    required this.amountCents,
    required this.balanceBeforeCents,
    required this.balanceAfterCents,
    required this.triggeredByUserId,
    required this.createdAt,
    this.milestoneId,
    this.notes,
  });

  final String id;
  /// 'initial_deposit' | 'release_to_constructor' | 'replenishment' |
  /// 'refund_to_promotor' | 'fee_to_platform'
  final String movementType;
  final int amountCents;
  final int balanceBeforeCents;
  final int balanceAfterCents;
  final String? milestoneId;
  final String triggeredByUserId;
  final String? notes;
  final DateTime createdAt;

  /// Signo del movimiento para la UI: +/-
  bool get isCredit =>
      movementType == 'initial_deposit' || movementType == 'replenishment';

  factory DepositMovement.fromJson(Map<String, dynamic> j) {
    return DepositMovement(
      id: j['id'] as String,
      movementType: j['movement_type'] as String,
      amountCents: (j['amount_cents'] as num).toInt(),
      balanceBeforeCents: ((j['balance_before_cents'] as num?) ?? 0).toInt(),
      balanceAfterCents: ((j['balance_after_cents'] as num?) ?? 0).toInt(),
      milestoneId: j['milestone_id'] as String?,
      triggeredByUserId: j['triggered_by_user_id'] as String,
      notes: j['notes'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}
