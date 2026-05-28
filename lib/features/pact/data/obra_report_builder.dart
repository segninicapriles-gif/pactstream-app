import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import 'pact_detail.dart';

/// Genera el "Libro de la Obra" — expediente completo en PDF de un pacto
/// terminado (o en cualquier estado).
///
/// Incluye:
///   1. Portada con datos de la obra y partes
///   2. Resumen financiero (presupuesto, anexos, total efectivo, % ejecutado)
///   3. Timeline de la obra (fechas clave)
///   4. Hitos: estado, importes, fechas de ejecución y pago
///   5. Anexos firmados con impacto económico
///   6. Bloque de firmas verificadas de todas las partes
///
/// Uso:
/// ```dart
/// final bytes = await ObraReportBuilder(detail: detail).buildBytes();
/// ```
class ObraReportBuilder {
  ObraReportBuilder({required this.detail});

  final PactDetail detail;

  static Future<pw.Font?> _tryFont(
    Future<pw.Font> Function() loader, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await loader().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> buildBytes() async {
    late final pw.Font font;
    late final pw.Font fontBold;
    late final pw.Font fontItalic;
    late final pw.Font fontMono;

    if (kIsWeb) {
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontItalic = pw.Font.helvetica();
      fontMono = pw.Font.courier();
    } else {
      final results = await Future.wait([
        _tryFont(PdfGoogleFonts.merriweatherRegular),
        _tryFont(PdfGoogleFonts.merriweatherBold),
        _tryFont(PdfGoogleFonts.merriweatherItalic),
        _tryFont(PdfGoogleFonts.jetBrainsMonoRegular),
      ]);
      font = results[0] ?? pw.Font.helvetica();
      fontBold = results[1] ?? pw.Font.helveticaBold();
      fontItalic = results[2] ?? pw.Font.helvetica();
      fontMono = results[3] ?? pw.Font.courier();
    }

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      italic: fontItalic,
    );

    final p = detail.pact;
    final isMenor = p.pactType == 'obra_menor';
    final activeAddendums = detail.activeAddendums;
    final allAddendums = detail.addendums;

    // Cálculos financieros
    final originalBudget = p.totalAmountCents;
    final addendumDelta =
        activeAddendums.fold<int>(0, (acc, a) => acc + a.extraAmountCents);
    final effectiveBudget = originalBudget + addendumDelta;
    final amountPaid = detail.amountReleasedCents;
    final pctExecuted = effectiveBudget > 0
        ? (amountPaid / effectiveBudget * 100).clamp(0, 100).toDouble()
        : 0.0;

    final pdf = pw.Document(
      title: 'Libro de la Obra · ${p.displayId}',
      author: 'PactStream',
      creator: 'PactStream',
      subject: 'Expediente completo de obra con custodia por hitos',
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 50,
          marginRight: 50,
          marginTop: 60,
          marginBottom: 60,
        ),
        header: (ctx) => _header(p, ctx),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          // ══════════════════════════════════════════
          // 1. PORTADA
          // ══════════════════════════════════════════
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LIBRO DE LA OBRA',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 20,
                    color: _cyan,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Expediente completo · PactStream',
                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 11,
                    color: _white70,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Container(height: 0.5, color: _cyan.shade(50)),
                pw.SizedBox(height: 14),
                _coverRow('Referencia', p.displayId, fontBold, fontMono),
                _coverRow('Obra', p.title, fontBold, fontMono),
                _coverRow(
                  'Localización',
                  '${p.obraAddressLine}'
                  '${p.obraCity != null ? ", ${p.obraCity}" : ""}'
                  '${p.obraProvince != null && p.obraProvince != p.obraCity ? " (${p.obraProvince})" : ""}',
                  fontBold,
                  fontMono,
                ),
                _coverRow(
                  'Tipo',
                  isMenor ? 'Obra menor (sin licencia)' : 'Obra mayor',
                  fontBold,
                  fontMono,
                ),
                _coverRow(
                  'Estado',
                  _pactStateLabel(p.state),
                  fontBold,
                  fontMono,
                ),
                _coverRow(
                  'Generado',
                  _dateStr(DateTime.now()),
                  fontBold,
                  fontMono,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Partes
          _sectionTitle('Partes intervinientes', fontBold),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _ink200, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              _tableHeader(['Rol', 'Nombre', 'Email'], fontBold),
              ...detail.parties.map(
                (party) => _tableRow([
                  _roleLabel(party.role),
                  party.snapshotFullName ?? '—',
                  party.snapshotEmail ?? '—',
                ]),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ══════════════════════════════════════════
          // 2. RESUMEN FINANCIERO
          // ══════════════════════════════════════════
          _sectionTitle('Resumen financiero', fontBold),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _finCard(
                  'Presupuesto original',
                  AppFormatters.moneyLong(originalBudget),
                  _ink500,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  'Modificados (anexos activos)',
                  '${addendumDelta >= 0 ? "+" : ""}${AppFormatters.moneyLong(addendumDelta)}',
                  addendumDelta >= 0 ? _success : _error,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  'Presupuesto efectivo',
                  AppFormatters.moneyLong(effectiveBudget),
                  _navy,
                  fontBold,
                  highlight: true,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _finCard(
                  'Importe ejecutado y pagado',
                  AppFormatters.moneyLong(amountPaid),
                  _success,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  'Pendiente de pago',
                  AppFormatters.moneyLong(effectiveBudget - amountPaid),
                  _ink500,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  '% Ejecutado',
                  '${pctExecuted.toStringAsFixed(1)}%',
                  pctExecuted >= 100 ? _success : _navy,
                  fontBold,
                ),
              ),
            ],
          ),

          if (p.ivaRatePct != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'IVA ${p.ivaIncluded == true ? "incluido" : "no incluido"} · '
              'tipo ${p.ivaRatePct}%',
              style: pw.TextStyle(fontSize: 8, color: _ink500),
            ),
          ],

          pw.SizedBox(height: 24),

          // ══════════════════════════════════════════
          // 3. TIMELINE
          // ══════════════════════════════════════════
          _sectionTitle('Cronología de la obra', fontBold),
          pw.SizedBox(height: 10),
          ..._buildTimeline(fontBold, fontMono),

          pw.SizedBox(height: 24),

          // ══════════════════════════════════════════
          // 4. HITOS / CERTIFICACIONES
          // ══════════════════════════════════════════
          _sectionTitle(
            'Hitos y certificaciones (${detail.milestones.length})',
            fontBold,
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _ink200, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(26),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.2),
            },
            children: [
              _tableHeader(
                ['#', 'Descripción', 'Importe', 'Pagado', 'Estado'],
                fontBold,
              ),
              ...detail.milestones.map((m) => _milestoneRow(m)),
            ],
          ),

          pw.SizedBox(height: 24),

          // ══════════════════════════════════════════
          // 5. ANEXOS (solo si existen)
          // ══════════════════════════════════════════
          if (allAddendums.isNotEmpty) ...[
            _sectionTitle(
              'Modificados y anexos (${allAddendums.length})',
              fontBold,
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _ink200, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(30),
                1: pw.FlexColumnWidth(2.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.2),
              },
              children: [
                _tableHeader(
                  ['#', 'Título / Justificación', 'Importe extra', 'Días extra', 'Estado'],
                  fontBold,
                ),
                ...allAddendums.map((a) => _addendumRow(a)),
              ],
            ),
            pw.SizedBox(height: 24),
          ],

          // ══════════════════════════════════════════
          // 6. FIRMAS
          // ══════════════════════════════════════════
          _sectionTitle('Firmas verificadas', fontBold),
          pw.SizedBox(height: 6),
          pw.Text(
            'Las firmas a continuación fueron realizadas mediante firma electrónica '
            'avanzada conforme al Reglamento eIDAS (UE) 910/2014 y la Ley 6/2020 española. '
            'Cada firma quedó registrada con fecha, hora, dispositivo y hash verificable en PactStream.',
            style: pw.TextStyle(fontSize: 9, color: _ink600, lineSpacing: 2),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),
          ...detail.parties.map((party) => _signatureBlock(party, fontBold, fontMono)),

          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _ink50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _ink200, width: 0.5),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Expediente generado por PactStream · pactstream.es · '
                  'Referencia: ${p.displayId}',
                  style: pw.TextStyle(
                    font: fontMono,
                    fontSize: 7.5,
                    color: _ink500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ════════════════════════════════════════════════
  // WIDGETS INTERNOS
  // ════════════════════════════════════════════════

  pw.Widget _header(PactCore p, pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'PS',
                    style: pw.TextStyle(
                      color: _cyan,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'PactStream · Libro de la Obra',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          pw.Text(
            p.displayId,
            style: pw.TextStyle(fontSize: 8, color: _ink500),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _ink200, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento generado el ${_dateStr(DateTime.now())} · uso confidencial',
            style: pw.TextStyle(fontSize: 7, color: _ink500),
          ),
          pw.Text(
            'Pág. ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _ink500),
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
          fontSize: 10,
          color: _navy,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  pw.Widget _coverRow(
    String label,
    String value,
    pw.Font bold,
    pw.Font mono,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: _white70),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: 10, color: _white),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _finCard(
    String label,
    String value,
    PdfColor color,
    pw.Font bold, {
    bool highlight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: highlight ? color.shade(10) : _ink50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: highlight ? color : _ink200,
          width: highlight ? 1.0 : 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _ink500)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold,
              fontSize: 12,
              color: highlight ? color : _ink900,
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildTimeline(pw.Font bold, pw.Font mono) {
    final events = <_TimelineEvent>[];
    final p = detail.pact;

    events.add(_TimelineEvent(p.createdAt, 'Pacto creado', _navy));

    if (p.estimatedStartDate != null) {
      events.add(_TimelineEvent(
          p.estimatedStartDate!, 'Inicio estimado', _ink500, estimated: true));
    }

    for (final m in detail.milestones) {
      if (m.paidAt != null) {
        events.add(_TimelineEvent(
          m.paidAt!,
          'Hito ${m.ordinal} pagado · ${AppFormatters.moneyShort(m.amountCents)}',
          _success,
        ));
      }
    }

    for (final a in detail.activeAddendums) {
      events.add(_TimelineEvent(
        a.createdAt,
        'Anexo #${a.ordinal} activo · ${a.extraAmountCents >= 0 ? "+" : ""}${AppFormatters.moneyShort(a.extraAmountCents)}',
        _warning,
      ));
    }

    if (p.estimatedEndDate != null) {
      events.add(_TimelineEvent(
          p.estimatedEndDate!, 'Fin estimado', _ink500, estimated: true));
    }

    events.sort((a, b) => a.date.compareTo(b.date));

    return events.map((e) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: pw.BoxDecoration(
                color: e.estimated ? _ink200 : e.color,
                shape: pw.BoxShape.circle,
                border: e.estimated
                    ? pw.Border.all(color: e.color, width: 1)
                    : null,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 80,
              child: pw.Text(
                _dateStr(e.date),
                style: pw.TextStyle(
                  font: mono,
                  fontSize: 8,
                  color: e.estimated ? _ink500 : _ink800,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                e.label + (e.estimated ? ' (estimado)' : ''),
                style: pw.TextStyle(
                  fontSize: 9,
                  color: e.estimated ? _ink500 : _ink900,
                  fontStyle:
                      e.estimated ? pw.FontStyle.italic : pw.FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  pw.TableRow _tableHeader(List<String> cells, pw.Font bold) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _ink100),
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 5),
              child: pw.Text(
                c,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 8.5,
                  color: _ink900,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _tableRow(List<String> cells) {
    return pw.TableRow(
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
              child: pw.Text(
                c,
                style: const pw.TextStyle(fontSize: 8.5, color: _ink800),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _milestoneRow(PactMilestone m) {
    final stateColor = m.state == 'paid'
        ? _success
        : (m.state == 'in_execution' ? _warning : _ink500);
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            '${m.ordinal}',
            style: const pw.TextStyle(fontSize: 8.5, color: _ink800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            m.name,
            style: const pw.TextStyle(fontSize: 8.5, color: _ink800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            AppFormatters.moneyShort(m.amountCents),
            style: const pw.TextStyle(fontSize: 8.5, color: _ink800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            m.paidAt != null ? _dateStr(m.paidAt!) : '—',
            style: const pw.TextStyle(fontSize: 8, color: _ink600),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            _milestoneStateLabel(m.state),
            style: pw.TextStyle(
              fontSize: 8,
              color: stateColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _addendumRow(PactAddendum a) {
    final isActive = a.state == 'active';
    final isCancelled = a.state == 'cancelled';
    final stateColor =
        isActive ? _success : (isCancelled ? _ink500 : _warning);

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            '#${a.ordinal}',
            style: const pw.TextStyle(fontSize: 8.5, color: _ink800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                a.title,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink900),
              ),
              if (a.justification != null)
                pw.Text(
                  a.justification!,
                  style: const pw.TextStyle(fontSize: 7.5, color: _ink600),
                ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            '${a.extraAmountCents >= 0 ? "+" : ""}${AppFormatters.moneyShort(a.extraAmountCents)}',
            style: pw.TextStyle(
              fontSize: 8.5,
              color: a.extraAmountCents >= 0 ? _success : _error,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            a.extraDays != 0
                ? '${a.extraDays > 0 ? "+" : ""}${a.extraDays}d'
                : '—',
            style: const pw.TextStyle(fontSize: 8.5, color: _ink800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            isActive
                ? 'Activo'
                : isCancelled
                    ? 'Cancelado'
                    : 'Pendiente',
            style: pw.TextStyle(
              fontSize: 8,
              color: stateColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _signatureBlock(PactParty party, pw.Font bold, pw.Font mono) {
    final signed = party.hasSigned;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: signed ? _successBg : _ink50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: signed ? _success : _ink300,
          width: signed ? 1.0 : 0.5,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _roleLabel(party.role).toUpperCase(),
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 8.5,
                    color: signed ? _success : _ink600,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  party.snapshotFullName ?? '—',
                  style: pw.TextStyle(
                      font: bold, fontSize: 11, color: _ink900),
                ),
                pw.Text(
                  party.snapshotEmail ?? '—',
                  style: const pw.TextStyle(fontSize: 8.5, color: _ink600),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                signed ? '✓  FIRMADO' : 'PENDIENTE',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 9,
                  color: signed ? _success : _ink400,
                ),
              ),
              if (party.signedAt != null)
                pw.Text(
                  AppFormatters.dateTimeDetail(party.signedAt!),
                  style: pw.TextStyle(
                      font: mono, fontSize: 7.5, color: _ink600),
                ),
              if (party.signatureId != null)
                pw.Text(
                  'ID: ${party.signatureId!.substring(0, party.signatureId!.length.clamp(0, 20))}…',
                  style: pw.TextStyle(
                      font: mono, fontSize: 7, color: _ink500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════

  String _dateStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _roleLabel(String role) {
    switch (role) {
      case 'promotor':
        return 'Promotor';
      case 'constructor':
        return 'Constructor';
      case 'tecnico':
        return 'Arquitecto técnico';
      default:
        return role;
    }
  }

  String _pactStateLabel(String state) {
    switch (state) {
      case 'draft':
        return 'Borrador';
      case 'signing':
        return 'En firma';
      case 'active':
        return 'En ejecución';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'disputed':
        return 'En disputa';
      default:
        return state;
    }
  }

  String _milestoneStateLabel(String state) {
    switch (state) {
      case 'pending':
        return 'Pendiente';
      case 'in_execution':
        return 'En ejecución';
      case 'ready_for_review':
        return 'En revisión';
      case 'validated':
        return 'Validado';
      case 'approved':
        return 'Aprobado';
      case 'paid':
        return 'Pagado';
      case 'disputed':
        return 'En disputa';
      default:
        return state;
    }
  }
}

class _TimelineEvent {
  _TimelineEvent(this.date, this.label, this.color, {this.estimated = false});
  final DateTime date;
  final String label;
  final PdfColor color;
  final bool estimated;
}

// ════════════════════════════════════════════════
// PALETA PDF
// ════════════════════════════════════════════════
const _navy = PdfColor.fromInt(0xff080D42);
const _cyan = PdfColor.fromInt(0xffA9F3FF);
const _white = PdfColors.white;
const _white70 = PdfColor.fromInt(0xb3ffffff);
const _ink900 = PdfColor.fromInt(0xff0A0E2A);
const _ink800 = PdfColor.fromInt(0xff14193D);
const _ink600 = PdfColor.fromInt(0xff4D5380);
const _ink500 = PdfColor.fromInt(0xff767BA3);
const _ink400 = PdfColor.fromInt(0xff9DA2C4);
const _ink300 = PdfColor.fromInt(0xffD0D3E3);
const _ink200 = PdfColor.fromInt(0xffE7E9F1);
const _ink100 = PdfColor.fromInt(0xffF3F4F9);
const _ink50 = PdfColor.fromInt(0xffFAFBFD);
const _success = PdfColor.fromInt(0xff00C389);
const _successBg = PdfColor.fromInt(0xffE0F7EE);
const _warning = PdfColor.fromInt(0xffF59E0B);
const _error = PdfColor.fromInt(0xffEF4444);
