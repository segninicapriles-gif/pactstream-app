/// Modelos de datos para el motor de scoring de PactStream.
///
/// PactHealthScore  → snapshot de salud de un pacto (pact_health_scores).
/// UserReputation   → snapshot de reputación de un usuario (user_reputations).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// =====================================================================
// SHARED COLOR UTILITY
// =====================================================================

/// Devuelve el color interpolado del gradiente rojo→ámbar→verde
/// para un score 0-100, igual que el arco del PactScoreGauge.
///
/// Stops: 0 = gaugeRed, 45 = gaugeAmber, 100 = gaugeGreen.
Color scoreGradientColor(int score) {
  final t = score.clamp(0, 100) / 100.0;
  if (t <= 0.45) {
    return Color.lerp(AppColors.gaugeRed, AppColors.gaugeAmber, t / 0.45)!;
  } else {
    return Color.lerp(
        AppColors.gaugeAmber, AppColors.gaugeGreen, (t - 0.45) / 0.55)!;
  }
}

// =====================================================================
// PACT HEALTH SCORE
// =====================================================================

class PactHealthScore {
  const PactHealthScore({
    required this.id,
    required this.pactId,
    required this.score,
    required this.milestoneCompliancePct,
    required this.evidenceValidityPct,
    required this.validationSpeedPct,
    required this.noDisputesPct,
    required this.iaEvidenceScore,
    required this.calculatedAt,
  });

  final String id;
  final String pactId;
  final int score;
  final double milestoneCompliancePct;
  final double evidenceValidityPct;
  final double validationSpeedPct;
  final double noDisputesPct;
  final double iaEvidenceScore;
  final DateTime calculatedAt;

  /// Etiqueta semántica del score.
  String get label {
    if (score >= 90) return 'Excelente';
    if (score >= 75) return 'Muy saludable';
    if (score >= 60) return 'Saludable';
    if (score >= 40) return 'Con incidencias';
    return 'En riesgo';
  }

  /// Color semántico del score — mismo gradiente que PactScoreGauge.
  Color get color => scoreGradientColor(score);

  /// Factores con nombre, icono, peso y valor.
  List<ScoringFactor> get factors => [
        ScoringFactor(
          key: 'compliance',
          label: 'Cumplimiento de hitos',
          icon: Icons.calendar_today_outlined,
          weightPct: 30,
          valuePct: milestoneCompliancePct,
        ),
        ScoringFactor(
          key: 'evidence',
          label: 'Evidencia válida',
          icon: Icons.photo_camera_outlined,
          weightPct: 25,
          valuePct: evidenceValidityPct,
        ),
        ScoringFactor(
          key: 'speed',
          label: 'Validación rápida',
          icon: Icons.bolt_outlined,
          weightPct: 20,
          valuePct: validationSpeedPct,
        ),
        ScoringFactor(
          key: 'disputes',
          label: 'Sin disputas',
          icon: Icons.shield_outlined,
          weightPct: 15,
          valuePct: noDisputesPct,
        ),
        ScoringFactor(
          key: 'ia',
          label: 'Score IA',
          icon: Icons.smart_toy_outlined,
          weightPct: 10,
          valuePct: iaEvidenceScore,
        ),
      ];

  factory PactHealthScore.fromJson(Map<String, dynamic> json) {
    return PactHealthScore(
      id: json['id'] as String? ?? '',
      pactId: json['pact_id'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      milestoneCompliancePct:
          (json['milestone_compliance_pct'] as num?)?.toDouble() ?? 0,
      evidenceValidityPct:
          (json['evidence_validity_pct'] as num?)?.toDouble() ?? 0,
      validationSpeedPct:
          (json['validation_speed_pct'] as num?)?.toDouble() ?? 0,
      noDisputesPct: (json['no_disputes_pct'] as num?)?.toDouble() ?? 0,
      iaEvidenceScore: (json['ia_evidence_score'] as num?)?.toDouble() ?? 0,
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : DateTime.now(),
    );
  }
}

class ScoringFactor {
  const ScoringFactor({
    required this.key,
    required this.label,
    required this.icon,
    required this.weightPct,
    required this.valuePct,
  });

  final String key;
  final String label;
  final IconData icon;
  final int weightPct;
  final double valuePct;

  Color get color => scoreGradientColor(valuePct.round());
}

// =====================================================================
// USER REPUTATION
// =====================================================================

enum ReputationTier { bronce, plata, oro, platino, elite }

extension ReputationTierX on ReputationTier {
  String get label => switch (this) {
        ReputationTier.bronce  => 'Bronce',
        ReputationTier.plata   => 'Plata',
        ReputationTier.oro     => 'Oro',
        ReputationTier.platino => 'Platino',
        ReputationTier.elite   => 'Elite',
      };

  Color get color => switch (this) {
        ReputationTier.bronce  => AppColors.tierBronce,
        ReputationTier.plata   => AppColors.tierPlata,
        ReputationTier.oro     => AppColors.tierOro,
        ReputationTier.platino => AppColors.tierPlatino,
        ReputationTier.elite   => AppColors.tierElite1,
      };

  Color get bgColor => switch (this) {
        ReputationTier.bronce  => AppColors.tierBronceBg,
        ReputationTier.plata   => AppColors.tierPlataBg,
        ReputationTier.oro     => AppColors.tierOroBg,
        ReputationTier.platino => AppColors.tierPlatinoBg,
        ReputationTier.elite   => AppColors.tierEliteBg,
      };

  static ReputationTier fromString(String s) => switch (s) {
        'plata'   => ReputationTier.plata,
        'oro'     => ReputationTier.oro,
        'platino' => ReputationTier.platino,
        'elite'   => ReputationTier.elite,
        _         => ReputationTier.bronce,
      };
}

class UserReputation {
  const UserReputation({
    required this.id,
    required this.userId,
    required this.role,
    required this.score,
    required this.tier,
    required this.components,
    required this.pactsTotal,
    required this.pactsCompleted,
    required this.pactsDisputed,
    required this.calculatedAt,
  });

  final String id;
  final String userId;
  final String role;
  final int score;
  final ReputationTier tier;
  final Map<String, dynamic> components;
  final int pactsTotal;
  final int pactsCompleted;
  final int pactsDisputed;
  final DateTime calculatedAt;

  /// Shields llenos (1-5) proporcionales al score.
  int get shieldsFilled => ((score / 100) * 5).round().clamp(0, 5);

  /// Resumen en texto del perfil de cada rol.
  String get summaryText {
    switch (role) {
      case 'promotor':
        final speed = (components['payment_speed_pct'] as num?)?.toInt() ?? 0;
        return 'Pagos puntuales en el $speed% de sus obras.';
      case 'constructor':
        final quality =
            (components['evidence_quality_pct'] as num?)?.toInt() ?? 0;
        return 'Evidencias de calidad en el $quality% de sus certificaciones.';
      case 'tecnico':
        final speed =
            (components['validation_speed_pct'] as num?)?.toInt() ?? 0;
        return 'Valida hitos en menos de 3 días el $speed% de las veces.';
      default:
        return 'Perfil verificado PactStream.';
    }
  }

  factory UserReputation.fromJson(Map<String, dynamic> json) {
    return UserReputation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      tier: ReputationTierX.fromString(json['tier'] as String? ?? 'bronce'),
      components: (json['components'] as Map<String, dynamic>?) ?? {},
      pactsTotal: (json['pacts_total'] as num?)?.toInt() ?? 0,
      pactsCompleted: (json['pacts_completed'] as num?)?.toInt() ?? 0,
      pactsDisputed: (json['pacts_disputed'] as num?)?.toInt() ?? 0,
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : DateTime.now(),
    );
  }
}
