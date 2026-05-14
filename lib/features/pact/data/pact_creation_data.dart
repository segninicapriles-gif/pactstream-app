/// Estado del wizard de creación de pacto (modelo v2.0).
/// Se mantiene en memoria mientras el usuario navega entre los 4 pasos.
///
/// Wizard v2.0 (4 pasos):
///   Step 1: información de la obra (tipo, título, dirección, fechas)
///   Step 2: presupuesto y depósito (importe, IVA, % depósito, frecuencia)
///   Step 3: equipo (invitar a las partes que faltan)
///   Step 4: resumen y crear
///
/// Diferencias clave con v1.0:
///   - NO se predefinen hitos al crear el pacto (los crea el constructor
///     durante la ejecución, por demanda).
///   - El promotor deposita un % del presupuesto al firmar (15-40 %,
///     default 30 %) en lugar del importe del primer hito.
///   - Se exige una frecuencia de certificación textual acordada por las
///     partes (ej. "mensual", "por avance > 20 %").
class PactCreationData {
  // === Paso 1 — Información de la obra ===

  /// 'obra_mayor' | 'obra_menor'
  String? pactType;

  /// Nombre interno del pacto (e.g. "Reforma Malasaña")
  String title = '';

  /// Descripción breve del alcance
  String description = '';

  /// Dirección completa (calle, número, etc.)
  String addressLine = '';

  /// Provincia (Madrid, Barcelona, etc.)
  String province = '';

  /// Código postal
  String postalCode = '';

  /// Fecha estimada de inicio
  DateTime? estimatedStartDate;

  /// Fecha estimada de fin
  DateTime? estimatedEndDate;

  // Campos solo obra_menor
  /// Tipo de obra menor declarada (e.g. 'pintura', 'cocina', 'baño')
  String? minorWorkCategory;

  /// Declaración de que la obra no es estructural (obligatorio obra_menor)
  bool minorWorkDeclaration = false;

  // === Paso 2 — Presupuesto y depósito ===

  /// Presupuesto total en céntimos
  int totalAmountCents = 0;

  /// Tipo de IVA aplicable (10 reformas vivienda · 21 obra nueva)
  double ivaRatePct = 10;

  /// Si el importe total ya incluye IVA o no
  bool ivaIncluded = true;

  /// % del presupuesto que el promotor depositará al firmar (15-40, default 30).
  double depositPct = 30;

  /// Frecuencia de certificación acordada (texto libre).
  /// Ej: "mensual", "cada 20% de avance", "según hitos del proyecto"
  String certificationFrequency = '';

  // === Paso 3 — Equipo ===

  /// Invitaciones por rol. La parte que crea ya es el primer participante.
  /// Roles posibles: 'promotor', 'constructor', 'tecnico'
  final List<PartyInvite> invites = [];

  // === Validaciones por paso ===

  bool get step1Valid =>
      pactType != null &&
      title.trim().isNotEmpty &&
      addressLine.trim().isNotEmpty &&
      province.trim().isNotEmpty &&
      postalCode.trim().length >= 4 &&
      // Si es obra menor exigimos declaración + categoría
      (pactType != 'obra_menor' ||
          (minorWorkDeclaration && (minorWorkCategory ?? '').isNotEmpty));

  /// Paso 2 — Presupuesto y depósito.
  /// Reglas v2:
  ///   - presupuesto mínimo 500 €
  ///   - % depósito entre 15 y 40
  ///   - frecuencia de certificación no vacía
  bool get step2Valid {
    if (totalAmountCents < 50000) return false;
    if (depositPct < 15 || depositPct > 40) return false;
    if (certificationFrequency.trim().isEmpty) return false;
    return true;
  }

  /// Toda invitación cuenta como válida cuando tiene email Y nombre.
  bool _inviteFilled(PartyInvite i) =>
      _isValidEmail(i.email) && i.fullName.trim().isNotEmpty;

  /// Paso 3 — Equipo:
  ///   - obra_mayor: 2 invitaciones válidas (+ el creador = 3 partes)
  ///   - obra_menor: 1 invitación válida (+ el creador = 2 partes)
  bool get step3Valid {
    if (pactType == null) return false;
    final filled = invites.where(_inviteFilled).toList();
    if (pactType == 'obra_menor') return filled.isNotEmpty;
    return filled.length >= 2;
  }

  /// Paso 4 — Resumen y crear: requiere todos los anteriores válidos.
  bool get step4Valid => step1Valid && step2Valid && step3Valid;

  /// Validación básica de email — suficiente para MVP.
  static bool _isValidEmail(String email) {
    final e = email.trim();
    if (e.length < 5) return false;
    final at = e.indexOf('@');
    if (at < 1) return false;
    final dot = e.lastIndexOf('.');
    return dot > at + 1 && dot < e.length - 1;
  }

  // === Helpers ===

  /// Céntimos que el promotor depositará al firmar.
  int get depositRequiredCents =>
      (totalAmountCents * depositPct / 100).round();

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
    depositPct = 30;
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

  /// 'promotor' | 'constructor' | 'tecnico'
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
