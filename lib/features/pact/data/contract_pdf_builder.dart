import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import 'pact_detail.dart';

/// Generador del PDF del contrato del pacto.
///
/// Diseño:
///   - A4 con márgenes amplios (legibilidad legal)
///   - Cabecera fija con marca PactStream + display_id
///   - Cuerpo en serif (Times-equivalente) para texto legal,
///     monoespaciado para identificadores y hashes
///   - Footer con número de página + hash del contrato
///   - Última página con bloques de firma (cada parte con su PS-SIG-... )
///
/// El hash que se devuelve (sha256) es del TEXTO PLANO consolidado,
/// no del PDF binario. Eso garantiza estabilidad cross-device y
/// coincide con lo que se firma en sf_sign_contract.
class ContractPdfBuilder {
  ContractPdfBuilder({required this.detail});

  final PactDetail detail;

  /// Intenta descargar una fuente de Google Fonts con timeout.
  /// Si falla o tarda más de [timeout], devuelve null.
  static Future<pw.Font?> _tryGoogleFont(
    Future<pw.Font> Function() loader, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await loader().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Construye el PDF y devuelve los bytes listos para descargar/preview.
  Future<Uint8List> buildBytes() async {
    final pdf = pw.Document(
      title: 'Contrato · ${detail.pact.displayId}',
      author: 'PactStream',
      creator: 'PactStream',
      subject: 'Contrato de ejecución de obra con custodia por hitos',
    );

    // Intentar descargar Google Fonts con timeout. Si falla, usar fuentes
    // integradas del PDF (Helvetica / Courier) para que el contrato siempre
    // se genere, aunque sin la tipografía ideal.
    final results = await Future.wait([
      _tryGoogleFont(PdfGoogleFonts.merriweatherRegular),
      _tryGoogleFont(PdfGoogleFonts.merriweatherBold),
      _tryGoogleFont(PdfGoogleFonts.merriweatherItalic),
      _tryGoogleFont(PdfGoogleFonts.jetBrainsMonoRegular),
    ]);

    final font = results[0] ?? pw.Font.helvetica();
    final fontBold = results[1] ?? pw.Font.helveticaBold();
    final fontItalic = results[2] ?? pw.Font.helvetica();
    final fontMono = results[3] ?? pw.Font.courier();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      italic: fontItalic,
    );

    final hash = _hashText();
    final dateLine = _today();
    final isMenor = detail.pact.pactType == 'obra_menor';

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 50,
          marginRight: 50,
          marginTop: 60,
          marginBottom: 60,
        ),
        header: (ctx) => _header(),
        footer: (ctx) => _footer(ctx, hash, fontMono),
        build: (ctx) => [
          // ========== PORTADA ==========
          pw.SizedBox(height: 20),
          pw.Text(
            'CONTRATO DE EJECUCIÓN DE OBRA',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              color: _navy,
              letterSpacing: 0.5,
            ),
          ),
          pw.Text(
            'con custodia por hitos · PactStream',
            style: pw.TextStyle(
              font: fontItalic,
              fontSize: 13,
              color: _ink600,
            ),
          ),
          pw.SizedBox(height: 24),
          _metaTable(fontMono, fontBold),
          pw.SizedBox(height: 24),

          // ========== REUNIDOS ==========
          _sectionTitle('Reunidos', fontBold),
          pw.SizedBox(height: 8),
          ...detail.parties.map((p) => _partyBlock(p, fontBold, fontMono)),

          pw.SizedBox(height: 16),

          // ========== EXPONEN ==========
          _sectionTitle('Exponen', fontBold),
          pw.SizedBox(height: 8),
          _paragraph(
              'Que las partes han alcanzado un acuerdo para la ejecución de la siguiente obra:'),
          pw.SizedBox(height: 8),
          _bullet(
              'Denominación: ${detail.pact.title}', fontBold),
          _bullet(
              'Localización: ${detail.pact.obraAddressLine}'
              '${detail.pact.obraCity != null ? ", ${detail.pact.obraCity}" : ""}'
              '${detail.pact.obraProvince != null && detail.pact.obraProvince != detail.pact.obraCity ? " (${detail.pact.obraProvince})" : ""}',
              fontBold),
          if (detail.pact.description != null &&
              detail.pact.description!.trim().isNotEmpty)
            _bullet('Alcance: ${detail.pact.description!.trim()}', fontBold),
          _bullet(
              'Tipo de obra: ${isMenor ? "Obra menor (no estructural)" : "Obra mayor"}',
              fontBold),
          _bullet(
              'Identificador del pacto: ${detail.pact.displayId}',
              fontBold),
          _bullet('Fecha del acuerdo: $dateLine', fontBold),

          pw.SizedBox(height: 16),

          // ========== CLÁUSULAS ==========
          _sectionTitle('Cláusulas', fontBold),
          pw.SizedBox(height: 8),

          _clause('Primera · Objeto del contrato',
              'Las partes acuerdan ejecutar la obra descrita conforme a los hitos detallados en este contrato. '
              'PactStream actúa como plataforma de custodia y validación de pagos por hitos, sin ser parte del contrato.',
              fontBold),

          _clause('Segunda · Importe total y comisión',
              'El presupuesto total asciende a ${AppFormatters.moneyLong(detail.pact.totalAmountCents)} '
              '(IVA ${detail.pact.ivaIncluded == true ? "incluido" : "no incluido"}, tipo ${detail.pact.ivaRatePct ?? 21}%). '
              'PactStream cobrará una comisión del ${detail.pact.platformFeePct}% sobre cada hito liberado, '
              'detraída en el momento del pago al constructor.',
              fontBold),

          _clauseWithList('Tercera · Hitos del proyecto',
              detail.milestones.length == 1
                  ? 'El presupuesto se ejecuta en 1 hito:'
                  : 'El presupuesto se divide en ${detail.milestones.length} hitos secuenciales:',
              detail.milestones.map((m) =>
                'Hito ${m.ordinal}: ${m.name} — ${AppFormatters.moneyLong(m.amountCents)}'
                '${m.targetDate != null ? " (fecha objetivo: ${_date(m.targetDate!)})" : ""}'
              ).toList(),
              fontBold),

          _clause('Cuarta · Custodia y depósito',
              'El promotor depositará el importe correspondiente a cada hito en una cuenta de custodia '
              'gestionada por PactStream. El importe permanece bloqueado hasta su liberación tras la '
              'validación correspondiente.',
              fontBold),

          _clause('Quinta · Validación de hitos',
              isMenor
                  ? 'En esta obra menor, el promotor valida directamente cada hito tras revisar las evidencias '
                    'aportadas por el constructor. El promotor declara expresamente que la obra no afecta a la '
                    'estructura del inmueble ni requiere licencia de obra mayor, asumiendo la responsabilidad '
                    'de dicha declaración.'
                  : 'El arquitecto técnico valida cada hito tras revisar las evidencias aportadas por el constructor. '
                    'Una vez validado técnicamente, el promotor dispone de un plazo de objeción de 48 horas hábiles. '
                    'Pasado el plazo sin objeción, el hito se considera aprobado tácitamente y se libera el pago.',
              fontBold),

          _clause('Sexta · Resolución de disputas',
              'En caso de objeción del promotor o discrepancia entre las partes, el hito queda en estado de '
              'disputa. Las partes intentarán resolver el conflicto de buena fe en un plazo de 10 días. '
              'Si no se alcanza acuerdo, se someterán a la jurisdicción ordinaria del lugar de la obra.',
              fontBold),

          _clause('Séptima · Protección de datos',
              'Las partes consienten el tratamiento de sus datos por PactStream conforme a la política de '
              'privacidad disponible en pactstream.es/legal. Se aplica el RGPD y la LOPDGDD.',
              fontBold),

          _clause('Octava · Aceptación y firma electrónica',
              'Las partes manifiestan haber leído, entendido y aceptado las cláusulas anteriores, prestando '
              'su consentimiento de forma libre, inequívoca y consciente mediante la firma electrónica que '
              'sigue. Cada firma queda registrada con fecha, hora, dispositivo y un identificador único '
              'verificable en PactStream. La firma electrónica cumple con el Reglamento (UE) 910/2014 (eIDAS) '
              'y la Ley 6/2020 española, equiparándose a la firma manuscrita.',
              fontBold),

          pw.SizedBox(height: 20),
          pw.Divider(color: _ink300),
          pw.SizedBox(height: 14),

          // ========== FIRMAS ==========
          _sectionTitle('Firmas de las partes', fontBold),
          pw.SizedBox(height: 12),
          ...detail.parties.map((p) => _signatureBlock(p, fontBold, fontMono)),
        ],
      ),
    );

    return pdf.save();
  }

  /// Hash SHA-256 del texto consolidado (no del PDF).
  /// Coincide con el que se firma en sf_sign_contract.
  String hash() => _hashText();

  String _hashText() {
    // Reconstruimos el mismo texto que ContractTextBuilder.build() para
    // que el hash sea consistente con lo firmado en la DB.
    final p = detail.pact;
    final isMenor = p.pactType == 'obra_menor';
    final buf = StringBuffer();
    buf.writeln('CONTRATO DE EJECUCIÓN DE OBRA CON CUSTODIA POR HITOS');
    buf.writeln('Identificador: ${p.displayId}');
    buf.writeln('Fecha: ${_today()}');
    buf.writeln('Plataforma: PactStream (custodia y validación)');
    buf.writeln('');
    buf.writeln('REUNIDOS');
    buf.writeln('');
    for (final party in detail.parties) {
      buf.writeln('${_roleUpper(party.role)}:');
      buf.writeln('  Nombre: ${party.snapshotFullName ?? '—'}');
      buf.writeln('  Email: ${party.snapshotEmail ?? '—'}');
      buf.writeln('');
    }
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
    buf.writeln('');
    return sha256.convert(utf8.encode(buf.toString())).toString();
  }

  // === Widgets PDF ===

  pw.Widget _header() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 28,
                height: 28,
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'PS',
                    style: pw.TextStyle(
                      color: _cyan,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text('PactStream',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    fontSize: 11,
                  )),
            ],
          ),
          pw.Text(detail.pact.displayId,
              style: pw.TextStyle(
                fontSize: 9,
                color: _ink500,
              )),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, String hash, pw.Font mono) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _ink200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Hash · ${hash.substring(0, 24)}…',
            style: pw.TextStyle(font: mono, fontSize: 7, color: _ink500),
          ),
          pw.Text(
            'Pág. ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _ink500),
          ),
        ],
      ),
    );
  }

  pw.Widget _metaTable(pw.Font mono, pw.Font bold) {
    final p = detail.pact;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _ink50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _ink200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _metaRow('Identificador', p.displayId, mono, bold),
          _metaRow('Título', p.title, mono, bold),
          _metaRow('Localización',
              '${p.obraAddressLine}${p.obraCity != null ? ", ${p.obraCity}" : ""}',
              mono, bold),
          _metaRow('Importe total',
              AppFormatters.moneyLong(p.totalAmountCents), mono, bold),
          _metaRow('Tipo',
              p.pactType == 'obra_menor' ? 'Obra menor' : 'Obra mayor',
              mono, bold),
        ],
      ),
    );
  }

  pw.Widget _metaRow(String k, String v, pw.Font mono, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(k,
                style: pw.TextStyle(fontSize: 9, color: _ink500)),
          ),
          pw.Expanded(
            child: pw.Text(v,
                style: pw.TextStyle(font: bold, fontSize: 10, color: _ink900)),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String t, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1.2)),
      ),
      child: pw.Text(
        t.toUpperCase(),
        style: pw.TextStyle(
          font: bold,
          fontSize: 11,
          color: _navy,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  pw.Widget _paragraph(String t) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        t,
        style: const pw.TextStyle(fontSize: 10, color: _ink800, lineSpacing: 3),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  pw.Widget _bullet(String t, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontSize: 10, color: _ink800)),
          pw.Expanded(
            child: pw.Text(
              t,
              style: pw.TextStyle(fontSize: 10, color: _ink800),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _partyBlock(PactParty party, pw.Font bold, pw.Font mono) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_roleUpper(party.role),
              style: pw.TextStyle(font: bold, fontSize: 10, color: _navy)),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, top: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nombre: ${party.snapshotFullName ?? "—"}',
                    style: const pw.TextStyle(fontSize: 10, color: _ink800)),
                pw.Text('Email: ${party.snapshotEmail ?? "—"}',
                    style: const pw.TextStyle(fontSize: 10, color: _ink800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _clause(String title, String body, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink900)),
          pw.SizedBox(height: 2),
          pw.Text(body,
              style: const pw.TextStyle(
                fontSize: 10,
                color: _ink800,
                lineSpacing: 3,
              ),
              textAlign: pw.TextAlign.justify),
        ],
      ),
    );
  }

  pw.Widget _clauseWithList(
      String title, String intro, List<String> items, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink900)),
          pw.SizedBox(height: 2),
          pw.Text(intro,
              style: const pw.TextStyle(fontSize: 10, color: _ink800)),
          pw.SizedBox(height: 4),
          ...items.map((it) => _bullet(it, bold)),
        ],
      ),
    );
  }

  pw.Widget _signatureBlock(PactParty party, pw.Font bold, pw.Font mono) {
    final signed = party.hasSigned;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: signed ? _successBg : _ink50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: signed ? _success : _ink300,
          width: signed ? 1.0 : 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(_roleUpper(party.role),
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 10,
                    color: signed ? _success : _ink600,
                    letterSpacing: 1.2,
                  )),
              pw.Spacer(),
              pw.Text(
                signed ? 'FIRMADO' : 'PENDIENTE',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 9,
                  color: signed ? _success : _ink500,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(party.snapshotFullName ?? '—',
              style: pw.TextStyle(font: bold, fontSize: 12, color: _ink900)),
          pw.Text(party.snapshotEmail ?? '—',
              style: const pw.TextStyle(fontSize: 9, color: _ink600)),
          if (signed) ...[
            pw.SizedBox(height: 8),
            pw.Container(height: 0.5, color: _ink300),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text('Firmado: ',
                    style: const pw.TextStyle(fontSize: 8, color: _ink500)),
                pw.Text(
                  party.signedAt != null
                      ? AppFormatters.dateTimeDetail(party.signedAt!)
                      : '—',
                  style: const pw.TextStyle(fontSize: 8, color: _ink800),
                ),
              ],
            ),
            pw.Row(
              children: [
                pw.Text('ID firma: ',
                    style: const pw.TextStyle(fontSize: 8, color: _ink500)),
                pw.Expanded(
                  child: pw.Text(
                    party.signatureId ?? '—',
                    style: pw.TextStyle(
                      font: mono,
                      fontSize: 8,
                      color: _ink800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _roleUpper(String role) {
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

// === Paleta PactStream para el PDF ===
const _navy = PdfColor.fromInt(0xff080D42);
const _cyan = PdfColor.fromInt(0xffA9F3FF);
const _ink900 = PdfColor.fromInt(0xff0A0E2A);
const _ink800 = PdfColor.fromInt(0xff14193D);
const _ink600 = PdfColor.fromInt(0xff4D5380);
const _ink500 = PdfColor.fromInt(0xff767BA3);
const _ink300 = PdfColor.fromInt(0xffD0D3E3);
const _ink200 = PdfColor.fromInt(0xffE7E9F1);
const _ink50 = PdfColor.fromInt(0xffFAFBFD);
const _success = PdfColor.fromInt(0xff00C389);
const _successBg = PdfColor.fromInt(0xffE0F7EE);
