import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/utils/formatters.dart';
import 'pact_detail.dart';

/// Generador del texto del contrato a firmar.
///
/// Genera una versión human-readable del acuerdo tripartito (o bipartito
/// en obra menor) usando los datos consolidados del pacto. Cuando
/// integremos Signaturit, sustituiremos este texto por un PDF generado
/// con plantilla legal real.
///
/// Importante: el hash SHA-256 del texto se firma junto con el timestamp
/// y user-agent, garantizando que cualquier cambio posterior al texto
/// sea detectable.
class ContractTextBuilder {
  ContractTextBuilder({required this.detail});

  final PactDetail detail;

  /// Construye el cuerpo completo del contrato.
  String build() {
    final p = detail.pact;
    final isMenor = p.pactType == 'obra_menor';

    final buf = StringBuffer();

    // Encabezado
    buf.writeln('CONTRATO DE EJECUCIÓN DE OBRA CON CUSTODIA POR HITOS');
    buf.writeln('Identificador: ${p.displayId}');
    buf.writeln('Fecha: ${_today()}');
    buf.writeln('Plataforma: PactStream (custodia y validación)');
    buf.writeln('');

    // Reunidos
    buf.writeln('REUNIDOS');
    buf.writeln('');
    for (final party in detail.parties) {
      buf.writeln('${_roleLabel(party.role)}:');
      buf.writeln('  Nombre: ${party.snapshotFullName ?? '—'}');
      buf.writeln('  Email: ${party.snapshotEmail ?? '—'}');
      buf.writeln('');
    }

    // Exponen
    buf.writeln('EXPONEN');
    buf.writeln('');
    buf.writeln(
        'Que las partes han alcanzado un acuerdo para la ejecución de la siguiente obra:');
    buf.writeln('');
    buf.writeln('  Denominación: ${p.title}');
    buf.writeln(
        '  Localización: ${p.obraAddressLine}${p.obraCity != null ? ", ${p.obraCity}" : ""}'
        '${p.obraProvince != null && p.obraProvince != p.obraCity ? " (${p.obraProvince})" : ""}');
    if (p.description != null && p.description!.trim().isNotEmpty) {
      buf.writeln('  Alcance: ${p.description!.trim()}');
    }
    buf.writeln('  Tipo de obra: ${isMenor ? "Obra menor (no estructural)" : "Obra mayor"}');
    if (p.estimatedStartDate != null) {
      buf.writeln('  Inicio estimado: ${_date(p.estimatedStartDate!)}');
    }
    if (p.estimatedEndDate != null) {
      buf.writeln('  Fin estimado: ${_date(p.estimatedEndDate!)}');
    }
    buf.writeln('');

    // Cláusulas
    buf.writeln('CLÁUSULAS');
    buf.writeln('');

    buf.writeln('PRIMERA · Objeto del contrato');
    buf.writeln(
        'Las partes acuerdan ejecutar la obra descrita conforme a los hitos detallados en este contrato. '
        'PactStream actúa como plataforma de custodia y validación de pagos por hitos, sin ser parte del contrato.');
    buf.writeln('');

    buf.writeln('SEGUNDA · Importe total y comisión');
    buf.writeln(
        'El presupuesto total asciende a ${AppFormatters.moneyLong(p.totalAmountCents)}'
        ' (IVA ${p.ivaIncluded == true ? "incluido" : "no incluido"}, tipo ${p.ivaRatePct ?? 21}%).');
    buf.writeln(
        'PactStream cobrará una comisión del ${p.platformFeePct}% sobre cada hito liberado, '
        'detraída en el momento del pago al constructor.');
    buf.writeln('');

    buf.writeln('TERCERA · Hitos del proyecto');
    buf.writeln(
        'El presupuesto se divide en ${detail.milestones.length} hitos secuenciales:');
    for (final m in detail.milestones) {
      buf.writeln(
          '  · Hito ${m.ordinal}: ${m.name} — ${AppFormatters.moneyLong(m.amountCents)}'
          '${m.targetDate != null ? " (fecha objetivo: ${_date(m.targetDate!)})" : ""}');
      if (m.description != null && m.description!.trim().isNotEmpty) {
        buf.writeln('      ${m.description!.trim()}');
      }
    }
    buf.writeln('');

    buf.writeln('CUARTA · Custodia y depósito');
    buf.writeln(
        'El promotor depositará el importe correspondiente a cada hito en una cuenta de custodia '
        'gestionada por PactStream. El importe permanece bloqueado hasta su liberación tras la '
        'validación correspondiente.');
    buf.writeln('');

    buf.writeln('QUINTA · Validación de hitos');
    if (isMenor) {
      buf.writeln(
          'En esta obra menor, el promotor valida directamente cada hito tras revisar las evidencias '
          'aportadas por el constructor. El promotor declara expresamente que la obra no afecta a la '
          'estructura del inmueble ni requiere licencia de obra mayor, asumiendo la responsabilidad '
          'de dicha declaración.');
    } else {
      buf.writeln(
          'El arquitecto técnico valida cada hito tras revisar las evidencias aportadas por el constructor. '
          'Una vez validado técnicamente, el promotor dispone de un plazo de objeción de 48 horas hábiles. '
          'Pasado el plazo sin objeción, el hito se considera aprobado tácitamente y se libera el pago.');
    }
    buf.writeln('');

    buf.writeln('SEXTA · Resolución de disputas');
    buf.writeln(
        'En caso de objeción del promotor o discrepancia entre las partes, el hito queda en estado de '
        'disputa. Las partes intentarán resolver el conflicto de buena fe en un plazo de 10 días. '
        'Si no se alcanza acuerdo, se someterán a la jurisdicción ordinaria del lugar de la obra.');
    buf.writeln('');

    buf.writeln('SÉPTIMA · Protección de datos');
    buf.writeln(
        'Las partes consienten el tratamiento de sus datos por PactStream conforme a la política de '
        'privacidad disponible en pactstream.es/legal. Se aplica el RGPD y la LOPDGDD.');
    buf.writeln('');

    buf.writeln('OCTAVA · Aceptación');
    buf.writeln(
        'Las partes manifiestan haber leído, entendido y aceptado las cláusulas anteriores, prestando '
        'su consentimiento de forma libre, inequívoca y consciente mediante la firma electrónica que '
        'sigue. Cada firma queda registrada con fecha, hora, dispositivo y un identificador único '
        'verificable en PactStream.');
    buf.writeln('');

    buf.writeln('---');
    buf.writeln(
        'Este documento se firma electrónicamente. La firma electrónica avanzada cumple con el '
        'Reglamento (UE) 910/2014 (eIDAS) y la Ley 6/2020 española, equiparándose a la firma manuscrita.');

    return buf.toString();
  }

  /// Hash SHA-256 del texto, en hex. Se firma junto con la firma para
  /// garantizar la integridad del contenido aceptado.
  String hash() {
    final bytes = utf8.encode(build());
    return sha256.convert(bytes).toString();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _roleLabel(String role) {
    switch (role) {
      case 'promotor':
        return 'EL PROMOTOR';
      case 'constructor':
        return 'EL CONSTRUCTOR';
      case 'tecnico':
        return 'EL ARQUITECTO TÉCNICO';
      default:
        return role.toUpperCase();
    }
  }
}
