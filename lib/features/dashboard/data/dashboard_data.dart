/// Datos agregados para la home, devueltos por `sf_get_dashboard_data()`.

class DashboardData {
  DashboardData({
    required this.role,
    required this.inCustodyCents,
    required this.activeWorks,
    required this.newWorksThisMonth,
    required this.urgentTasks,
    required this.activePacts,
    this.nextRelease,
  });

  /// 'promotor' | 'constructor' | 'tecnico' | 'admin'
  final String role;

  /// Suma del balance de los depósitos en custodia del usuario.
  final int inCustodyCents;

  /// Cuenta de pacts activos donde soy parte.
  final int activeWorks;

  /// Pacts nuevos creados este mes donde soy parte.
  final int newWorksThisMonth;

  /// Próxima liberación de pago (cert/hito validado o aprobado).
  /// `null` si no hay ninguna pendiente.
  final DashboardNextRelease? nextRelease;

  /// Hasta 5 tareas urgentes pendientes de mi acción.
  final List<DashboardUrgentTask> urgentTasks;

  /// Hasta 5 obras activas del usuario.
  final List<DashboardActivePact> activePacts;

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    return DashboardData(
      role: (j['role'] as String?) ?? 'promotor',
      inCustodyCents: ((j['in_custody_cents'] as num?) ?? 0).toInt(),
      activeWorks: ((j['active_works'] as num?) ?? 0).toInt(),
      newWorksThisMonth: ((j['new_works_this_month'] as num?) ?? 0).toInt(),
      nextRelease: j['next_release'] != null
          ? DashboardNextRelease.fromJson(
              j['next_release'] as Map<String, dynamic>)
          : null,
      urgentTasks: (j['urgent_tasks'] as List<dynamic>? ?? const [])
          .map((e) => DashboardUrgentTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      activePacts: (j['active_pacts'] as List<dynamic>? ?? const [])
          .map((e) => DashboardActivePact.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Estado vacío inicial mientras se carga (evita parpadeos visuales).
  factory DashboardData.empty() => DashboardData(
        role: 'promotor',
        inCustodyCents: 0,
        activeWorks: 0,
        newWorksThisMonth: 0,
        urgentTasks: const [],
        activePacts: const [],
      );
}

/// Detalle de la próxima certificación/hito por liberar.
class DashboardNextRelease {
  DashboardNextRelease({
    required this.amountCents,
    required this.pactId,
    required this.pactTitle,
    this.targetDate,
    this.milestoneName,
    this.ordinal,
  });

  final int amountCents;
  final DateTime? targetDate;
  final String pactId;
  final String pactTitle;
  final String? milestoneName;
  final int? ordinal;

  factory DashboardNextRelease.fromJson(Map<String, dynamic> j) {
    return DashboardNextRelease(
      amountCents: ((j['amount_cents'] as num?) ?? 0).toInt(),
      targetDate: j['target_date'] != null
          ? DateTime.parse(j['target_date'] as String)
          : null,
      pactId: j['pact_id'] as String,
      pactTitle: j['pact_title'] as String,
      milestoneName: j['milestone_name'] as String?,
      ordinal: (j['ordinal'] as num?)?.toInt(),
    );
  }
}

/// Una tarea urgente pendiente de acción.
class DashboardUrgentTask {
  DashboardUrgentTask({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.pactId,
    required this.badgeLabel,
  });

  /// 'addendum_sign' | 'contract_sign' | 'accept_invite'
  final String kind;
  final String title;
  final String subtitle;
  final String pactId;
  final String badgeLabel;

  factory DashboardUrgentTask.fromJson(Map<String, dynamic> j) {
    return DashboardUrgentTask(
      kind: j['kind'] as String,
      title: j['title'] as String,
      subtitle: j['subtitle'] as String? ?? '',
      pactId: j['pact_id'] as String,
      badgeLabel: j['badge_label'] as String? ?? '',
    );
  }
}

/// Un pacto activo resumido para la lista de la home.
class DashboardActivePact {
  DashboardActivePact({
    required this.id,
    required this.displayId,
    required this.title,
    required this.state,
    required this.city,
    required this.totalAmountCents,
    required this.progressPct,
    required this.modelVersion,
  });

  final String id;
  final String displayId;
  final String title;
  final String state;
  final String city;
  final int totalAmountCents;
  final int progressPct;
  final String modelVersion;

  bool get isV2 => modelVersion == 'v2';

  factory DashboardActivePact.fromJson(Map<String, dynamic> j) {
    return DashboardActivePact(
      id: j['id'] as String,
      displayId: j['display_id'] as String,
      title: j['title'] as String,
      state: j['state'] as String,
      city: j['city'] as String? ?? '',
      totalAmountCents: ((j['total_amount_cents'] as num?) ?? 0).toInt(),
      progressPct: ((j['progress_pct'] as num?) ?? 0).toInt(),
      modelVersion: (j['model_version'] as String?) ?? 'v1',
    );
  }
}
