/// Detalle completo de un hito + sus evidencias activas.
///
/// Mapea al JSON devuelto por `sf_get_milestone_detail(p_milestone_id)`.
class MilestoneDetail {
  MilestoneDetail({
    required this.milestone,
    required this.evidences,
  });

  final MilestoneFull milestone;
  final List<MilestoneEvidence> evidences;

  factory MilestoneDetail.fromJson(Map<String, dynamic> json) {
    return MilestoneDetail(
      milestone:
          MilestoneFull.fromJson(json['milestone'] as Map<String, dynamic>),
      evidences: (json['evidences'] as List<dynamic>)
          .map((e) => MilestoneEvidence.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Hito con datos del pacto padre y rol del usuario actual.
class MilestoneFull {
  MilestoneFull({
    required this.id,
    required this.pactId,
    required this.pactDisplayId,
    required this.pactTitle,
    required this.pactType,
    required this.displayId,
    required this.ordinal,
    required this.name,
    required this.amountCents,
    required this.state,
    required this.stateUpdatedAt,
    required this.myRole,
    this.description,
    this.targetDate,
    this.startedAt,
    this.submittedAt,
    this.validatedAt,
    this.approvedByPromotorAt,
    this.rejectedAt,
    this.paidAt,
  });

  final String id;
  final String pactId;
  final String pactDisplayId;
  final String pactTitle;
  final String pactType;
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
  final String myRole;

  bool get canUploadEvidence =>
      myRole == 'constructor' &&
      (state == 'in_execution' || state == 'ready_for_review');

  bool get canSubmitForReview =>
      myRole == 'constructor' && state == 'in_execution';

  /// El técnico puede revisar técnicamente el hito (solo obra mayor).
  bool get canTechReview =>
      myRole == 'tecnico' &&
      pactType == 'obra_mayor' &&
      state == 'ready_for_review';

  /// El promotor puede decidir.
  /// Obra mayor: tras técnico (awaiting_promotor).
  /// Obra menor: directamente desde ready_for_review (sin técnico).
  bool get canPromotorDecide {
    if (myRole != 'promotor') return false;
    if (pactType == 'obra_menor') {
      return state == 'ready_for_review' || state == 'awaiting_promotor';
    }
    return state == 'awaiting_promotor';
  }

  /// Si el constructor debe re-trabajar el hito (rechazo o info pedida).
  bool get needsConstructorRework =>
      myRole == 'constructor' &&
      (state == 'rejected_by_tech' || state == 'info_requested');

  /// Etiquetas humanas
  bool get isPaid => state == 'paid';
  bool get isInDispute => state == 'disputed';

  factory MilestoneFull.fromJson(Map<String, dynamic> j) {
    return MilestoneFull(
      id: j['id'] as String,
      pactId: j['pact_id'] as String,
      pactDisplayId: j['pact_display_id'] as String,
      pactTitle: j['pact_title'] as String,
      pactType: j['pact_type'] as String,
      displayId: j['display_id'] as String,
      ordinal: (j['ordinal'] as num).toInt(),
      name: j['name'] as String,
      description: j['description'] as String?,
      amountCents: (j['amount_cents'] as num).toInt(),
      targetDate: _parseDt(j['target_date']),
      state: j['state'] as String,
      stateUpdatedAt: DateTime.parse(j['state_updated_at'] as String),
      startedAt: _parseDt(j['started_at']),
      submittedAt: _parseDt(j['submitted_at']),
      validatedAt: _parseDt(j['validated_at']),
      approvedByPromotorAt: _parseDt(j['approved_by_promotor_at']),
      rejectedAt: _parseDt(j['rejected_at']),
      paidAt: _parseDt(j['paid_at']),
      myRole: j['my_role'] as String,
    );
  }

  static DateTime? _parseDt(dynamic v) =>
      v != null ? DateTime.parse(v as String) : null;
}

/// Evidencia de un hito (foto, video, doc).
class MilestoneEvidence {
  MilestoneEvidence({
    required this.id,
    required this.evidenceType,
    required this.storagePath,
    required this.sha256Hash,
    required this.serverTimestamp,
    required this.uploadedByUserId,
    required this.isMine,
    required this.isSuperseded,
    this.fileSizeBytes,
    this.mimeType,
    this.description,
    this.gpsLatitude,
    this.gpsLongitude,
    this.gpsAccuracyMeters,
    this.clientTimestamp,
    this.uploadedByName,
  });

  final String id;
  final String evidenceType; // 'photo' | 'video' | 'audio' | 'document' | 'note'
  final String storagePath;
  final int? fileSizeBytes;
  final String? mimeType;
  final String sha256Hash;
  final String? description;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final double? gpsAccuracyMeters;
  final DateTime? clientTimestamp;
  final DateTime serverTimestamp;
  final String uploadedByUserId;
  final String? uploadedByName;
  final bool isMine;
  final bool isSuperseded;

  bool get isImage =>
      evidenceType == 'photo' ||
      (mimeType ?? '').startsWith('image/');

  bool get isVideo =>
      evidenceType == 'video' ||
      (mimeType ?? '').startsWith('video/');

  bool get isPdf =>
      evidenceType == 'document' && (mimeType ?? '').contains('pdf');

  bool get hasGps => gpsLatitude != null && gpsLongitude != null;

  factory MilestoneEvidence.fromJson(Map<String, dynamic> j) {
    return MilestoneEvidence(
      id: j['id'] as String,
      evidenceType: j['evidence_type'] as String,
      storagePath: j['storage_path'] as String,
      fileSizeBytes: j['file_size_bytes'] != null
          ? (j['file_size_bytes'] as num).toInt()
          : null,
      mimeType: j['mime_type'] as String?,
      sha256Hash: j['sha256_hash'] as String,
      description: j['description'] as String?,
      gpsLatitude: j['gps_latitude'] != null
          ? (j['gps_latitude'] as num).toDouble()
          : null,
      gpsLongitude: j['gps_longitude'] != null
          ? (j['gps_longitude'] as num).toDouble()
          : null,
      gpsAccuracyMeters: j['gps_accuracy_meters'] != null
          ? (j['gps_accuracy_meters'] as num).toDouble()
          : null,
      clientTimestamp: j['client_timestamp'] != null
          ? DateTime.parse(j['client_timestamp'] as String)
          : null,
      serverTimestamp: DateTime.parse(j['server_timestamp'] as String),
      uploadedByUserId: j['uploaded_by_user_id'] as String,
      uploadedByName: j['uploaded_by_name'] as String?,
      isMine: j['is_mine'] as bool? ?? false,
      isSuperseded: j['is_superseded'] as bool? ?? false,
    );
  }
}
