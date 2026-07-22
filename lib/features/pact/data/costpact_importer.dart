import 'dart:convert';

import 'pact_creation_data.dart';

class CostPactImportResult {
  CostPactImportResult({
    required this.data,
    required this.presupuestoId,
    required this.proyectoNumero,
    required this.clientName,
    required this.clientEmail,
    required this.milestoneCount,
  });

  final PactCreationData data;
  final String presupuestoId;
  final String proyectoNumero;
  final String clientName;
  final String clientEmail;
  final int milestoneCount;
}

class CostPactImporter {
  CostPactImporter._();

  static CostPactImportResult parse(String jsonString) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
        'El archivo no contiene JSON válido.',
      );
    }

    if (json['source'] != 'costpact') {
      throw const FormatException(
        'Este archivo no fue exportado desde CostPact.',
      );
    }

    final data = PactCreationData();

    final obraType = json['obra_type'] as String? ?? 'reforma_integral';
    data.pactType = obraType.startsWith('obra_menor') ? 'obra_menor' : 'obra_mayor';

    data.title = json['title'] as String? ?? 'Obra importada';
    data.description = json['description'] as String? ?? '';
    data.totalAmountCents = json['total_amount_cents'] as int? ?? 0;
    data.ivaRatePct = (json['iva_rate_pct'] as num?)?.toDouble() ?? 10;
    data.ivaIncluded = json['iva_included'] as bool? ?? true;
    data.advancePct = (json['advance_pct'] as num?)?.toDouble() ?? 30;
    data.certificationFrequency =
        json['certification_frequency'] as String? ?? 'mensual';

    if (data.pactType == 'obra_menor') {
      final suffix = obraType.replaceFirst('obra_menor_', '');
      data.minorWorkCategory = suffix.isNotEmpty ? suffix : 'otra';
      data.minorWorkDeclaration = true;
    }

    final client = json['client'] as Map<String, dynamic>? ?? {};
    final clientName = client['name'] as String? ?? '';
    final clientEmail = client['email'] as String? ?? '';

    if (clientEmail.isNotEmpty) {
      data.invites.add(PartyInvite(
        role: 'constructor',
        email: clientEmail,
        fullName: clientName,
      ));
    }

    final milestones = json['milestones'] as List<dynamic>? ?? [];

    return CostPactImportResult(
      data: data,
      presupuestoId: json['costpact_presupuesto_id'] as String? ?? '',
      proyectoNumero: json['costpact_proyecto_numero'] as String? ?? '',
      clientName: clientName,
      clientEmail: clientEmail,
      milestoneCount: milestones.length,
    );
  }
}
