/// Estado del wizard de creación de pacto (modelo v2.1).
/// Se mantiene en memoria mientras el usuario navega entre los 4 pasos.
///
/// Wizard v2.1 (4 pasos):
///   Step 1: información de la obra (tipo, título, dirección, fechas)
///   Step 2: presupuesto y Adelanto (importe, IVA, % adelanto, frecuencia)
///   Step 3: equipo (invitar a las partes que faltan)
///   Step 4: resumen y crear
///
/// Modelo v2.1 (Adelanto con doble garantía):
///   - El promotor compromete un "Adelanto" entre 10 % y 40 % del presupuesto
///     (default 30 %) que se desglosa internamente en:
///       · 10 % fijo → custodiado como reserva de finiquito
///       · 0-30 % variable → entregado al constructor el día 1
///   - Las certificaciones siguen con pre-depósito obligatorio del neto.
///   - PactStream cubre el adelanto entregado con seguro de caución.
class PactCreationData {
  // === Paso 1 — Información de la obra ===

  /// 'obra_mayor' | 'obra_menor'
  String? pactType;

  String title = '';
  String description = '';
  String addressLine = '';
  String province = '';
  String postalCode = '';
  DateTime? estimatedStartDate;
  DateTime? estimatedEndDate;

  // Solo obra_menor
  String? minorWorkCategory;
  bool minorWorkDeclaration = false;

  // === Paso 2 — Presupuesto y Adelanto ===

  /// Presupuesto total en céntimos
  int totalAmountCents = 0;

  /// Tipo de IVA aplicable (10 reformas vivienda · 21 obra nueva · -1 reforma dual)
  /// -1 significa "IVA reforma": MO al 10 % + materiales al 21 %, ya incluido en el total.
  double ivaRatePct = 10;

  /// Si el importe total ya incluye IVA o no
  bool ivaIncluded = true;

  /// Si el IVA es del tipo "Reforma": MO 10 % + materiales 21 %.
  /// En este caso ivaIncluded = true y el importe entra ya con IVA calculado.
  bool get isIvaReforma => ivaRatePct == -1;

  /// % total del Adelanto que el promotor compromete al firmar.
  /// Rango: 10-40, default 30.
  /// Se descompone en: reserva fija (10 %) + variable al constructor.
  double advancePct = 30;

  /// % fijo del Adelanto que queda custodiado como reserva de finiquito.
  /// En MVP es siempre 10. Negociable en versiones futuras.
  static const double advanceReservePct = 10;

  /// Frecuencia de certificación acordada (texto libre).
  String certificationFrequency = '';

  // === Paso 3 — Equipo ===

  final List<PartyInvite> invites = [];

  // === Validaciones por paso ===

  bool get step1Valid =>
      pactType != null &&
      title.trim().isNotEmpty &&
      addressLine.trim().isNotEmpty &&
      province.trim().isNotEmpty &&
      postalCode.trim().length >= 4 &&
      (pactType != 'obra_menor' ||
          (minorWorkDeclaration && (minorWorkCategory ?? '').isNotEmpty));

  /// Paso 2 — Presupuesto y Adelanto.
  /// Reglas v2.1:
  ///   - presupuesto mínimo 500 €
  ///   - Adelanto entre 10 y 40
  ///   - frecuencia de certificación no vacía
  bool get step2Valid {
    if (totalAmountCents < 50000) return false;
    if (advancePct < 10 || advancePct > 40) return false;
    if (certificationFrequency.trim().isEmpty) return false;
    return true;
  }

  bool _inviteFilled(PartyInvite i) =>
      _isValidEmail(i.email) && i.fullName.trim().isNotEmpty;

  /// Si la obra se guarda como borrador (sin enviar invitaciones aún).
  bool isDraft = false;

  bool get step3Valid {
    if (pactType == null) return false;
    // En modo borrador no se requieren partes — se añaden después.
    if (isDraft) return true;
    final filled = invites.where(_inviteFilled).toList();
    if (pactType == 'obra_menor') return filled.isNotEmpty;
    return filled.length >= 2;
  }

  bool get step4Valid => step1Valid && step2Valid && step3Valid;

  static bool _isValidEmail(String email) {
    final e = email.trim();
    if (e.length < 5) return false;
    final at = e.indexOf('@');
    if (at < 1) return false;
    final dot = e.lastIndexOf('.');
    return dot > at + 1 && dot < e.length - 1;
  }

  // === Helpers v2.1 ===

  /// Céntimos totales del Adelanto (lo que el promotor compromete día 1).
  int get totalAdvanceCents =>
      (totalAmountCents * advancePct / 100).round();

  /// Céntimos custodiados como reserva (siempre el 10 % del presupuesto).
  int get advanceReserveCents =>
      (totalAmountCents * advanceReservePct / 100).round();

  /// Céntimos que se entregan al constructor el día 1 (parte variable).
  /// Puede ser 0 si advancePct == 10 (todo va a reserva).
  int get advanceReleasedCents =>
      totalAdvanceCents - advanceReserveCents;

  /// % del Adelanto que se entrega al constructor (variable).
  double get advanceVariablePct => advancePct - advanceReservePct;

  void reset() {
    pactType = null;
    title = '';
    description = '';
    addressLine = '';
    province = '';
    postalCode = '';
    estimatedStartDate = null;
    estimatedEndDate = null;
    minorWorkCategory = null;
    minorWorkDeclaration = false;
    invites.clear();
    totalAmountCents = 0;
    ivaRatePct = 10;
    ivaIncluded = true;
    isDraft = false;
    advancePct = 30;
    certificationFrequency = '';
  }
}

/// Una invitación a otra parte del pacto.
class PartyInvite {
  PartyInvite({
    required this.role,
    this.email = '',
    this.fullName = '',
  });

  String role;
  String email;
  String fullName;

  Map<String, dynamic> toRpcArgs(String pactId) => {
        'p_pact_id': pactId,
        'p_role': role,
        'p_email': email.trim(),
        'p_full_name': fullName.trim(),
      };
}
