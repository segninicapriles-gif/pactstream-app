import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'pact_detail.dart';

/// Genera el "Libro de la Obra" — expediente completo en PDF de un pacto
/// terminado (o en cualquier estado).
///
/// Requiere [l10n] para generar el PDF en el idioma del usuario.
/// El caller lo obtiene con `context.l10n` y lo pasa al constructor.
class ObraReportBuilder {
  ObraReportBuilder({required this.detail, required this.l10n});

  final PactDetail detail;
  final AppLocalizations l10n;

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

    final originalBudget = p.totalAmountCents;
    final addendumDelta =
        activeAddendums.fold<int>(0, (acc, a) => acc + a.extraAmountCents);
    final effectiveBudget = originalBudget + addendumDelta;
    final amountPaid = detail.amountReleasedCents;
    final pctExecuted = effectiveBudget > 0
        ? (amountPaid / effectiveBudget * 100).clamp(0, 100).toDouble()
        : 0.0;

    final pdf = pw.Document(
      title: l10n.pdfReportDocTitle(p.displayId),
      author: 'PactStream',
      creator: 'PactStream',
      subject: l10n.pdfReportDocSubject,
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
                  l10n.pdfReportTitle,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 20,
                    color: _cyan,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  l10n.pdfReportSubtitle,
                  style: pw.TextStyle(
                    font: fontItalic,
                    fontSize: 11,
                    color: _white70,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Container(height: 0.5, color: _cyan.shade(50)),
                pw.SizedBox(height: 14),
                _coverRow(l10n.pdfReportLabelReference, p.displayId, fontBold, fontMono),
                _coverRow(l10n.pdfReportLabelProject, p.title, fontBold, fontMono),
                _coverRow(
                  l10n.pdfReportLabelLocation,
                  '${p.obraAddressLine}'
                  '${p.obraCity != null ? ", ${p.obraCity}" : ""}'
                  '${p.obraProvince != null && p.obraProvince != p.obraCity ? " (${p.obraProvince})" : ""}',
                  fontBold,
                  fontMono,
                ),
                _coverRow(
                  l10n.pdfReportLabelType,
                  isMenor ? l10n.pdfReportMinorWork : l10n.pdfReportMajorWork,
                  fontBold,
                  fontMono,
                ),
                _coverRow(
                  l10n.pdfReportLabelStatus,
                  _pactStateLabel(p.state),
                  fontBold,
                  fontMono,
                ),
                _coverRow(
                  l10n.pdfReportLabelGenerated,
                  _dateStr(DateTime.now()),
                  fontBold,
                  fontMono,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Partes
          _sectionTitle(l10n.pdfReportPartiesTitle, fontBold),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _ink200, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              _tableHeader([l10n.pdfReportHeaderRole, l10n.pdfReportHeaderName, l10n.pdfReportHeaderEmail], fontBold),
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
          _sectionTitle(l10n.pdfReportFinancialTitle, fontBold),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _finCard(
                  l10n.pdfReportOriginalEstimate,
                  AppFormatters.moneyLong(originalBudget),
                  _ink500,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  l10n.pdfReportChangeOrders,
                  '${addendumDelta >= 0 ? "+" : ""}${AppFormatters.moneyLong(addendumDelta)}',
                  addendumDelta >= 0 ? _success : _error,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  l10n.pdfReportEffectiveEstimate,
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
                  l10n.pdfReportAmountPaid,
                  AppFormatters.moneyLong(amountPaid),
                  _success,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  l10n.pdfReportPendingPayment,
                  AppFormatters.moneyLong(effectiveBudget - amountPaid),
                  _ink500,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _finCard(
                  l10n.pdfReportPercentComplete,
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
              l10n.pdfReportIvaNote(
                p.ivaIncluded == true ? l10n.pdfReportIvaIncluded : l10n.pdfReportIvaExcluded,
                '${p.ivaRatePct}',
              ),
              style: pw.TextStyle(fontSize: 8, color: _ink500),
            ),
          ],

          pw.SizedBox(height: 24),

          // ══════════════════════════════════════════
          // 3. TIMELINE
          // ══════════════════════════════════════════
          _sectionTitle(l10n.pdfReportTimelineTitle, fontBold),
          pw.SizedBox(height: 10),
          ..._buildTimeline(fontBold, fontMono),

          pw.SizedBox(height: 24),

          // ══════════════════════════════════════════
          // 4. HITOS / CERTIFICACIONES
          // ══════════════════════════════════════════
          _sectionTitle(
            l10n.pdfReportMilestonesTitle(detail.milestones.length),
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
                ['#', l10n.pdfReportHeaderDescription, l10n.pdfReportHeaderAmount, l10n.pdfReportHeaderPaid, l10n.pdfReportLabelStatus],
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
              l10n.pdfReportAddendumTitle(allAddendums.length),
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
                  ['#', l10n.pdfReportHeaderTitleJustification, l10n.pdfReportHeaderExtraAmount, l10n.pdfReportHeaderExtraDays, l10n.pdfReportLabelStatus],
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
          _sectionTitle(l10n.pdfReportSignaturesTitle, fontBold),
          pw.SizedBox(height: 6),
          pw.Text(
            l10n.pdfSignatureDisclaimer,
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
                  l10n.pdfReportFooterReference(p.displayId),
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
                l10n.pdfReportHeaderBrand,
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
            l10n.pdfReportFooterDate(_dateStr(DateTime.now())),
            style: pw.TextStyle(fontSize: 7, color: _ink500),
          ),
          pw.Text(
            l10n.pdfPageNumber(ctx.pageNumber, ctx.pagesCount),
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

    events.add(_TimelineEvent(p.createdAt, l10n.pdfReportPactCreated, _navy));

    if (p.estimatedStartDate != null) {
      events.add(_TimelineEvent(
          p.estimatedStartDate!, l10n.pdfReportEstimatedStart, _ink500, estimated: true));
    }

    for (final m in detail.milestones) {
      if (m.paidAt != null) {
        events.add(_TimelineEvent(
          m.paidAt!,
          l10n.pdfReportMilestonePaid(m.ordinal, AppFormatters.moneyShort(m.amountCents)),
          _success,
        ));
      }
    }

    for (final a in detail.activeAddendums) {
      events.add(_TimelineEvent(
        a.createdAt,
        l10n.pdfReportAddendumActiveEvent(a.ordinal, '${a.extraAmountCents >= 0 ? "+" : ""}${AppFormatters.moneyShort(a.extraAmountCents)}'),
        _warning,
      ));
    }

    if (p.estimatedEndDate != null) {
      events.add(_TimelineEvent(
          p.estimatedEndDate!, l10n.pdfReportEstimatedEnd, _ink500, estimated: true));
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
                e.label + (e.estimated ? ' ${l10n.pdfReportEstimatedSuffix}' : ''),
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
            _addendumStateLabel(a.state),
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
                signed ? l10n.pdfSigned : l10n.pdfUnsigned,
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
        return l10n.pdfRoleOwner;
      case 'constructor':
        return l10n.pdfRoleContractor;
      case 'tecnico':
        return l10n.pdfRoleArchitect;
      default:
        return role;
    }
  }

  String _pactStateLabel(String state) {
    switch (state) {
      case 'draft':
        return l10n.pdfPactStateDraft;
      case 'signing':
        return l10n.pdfPactStateSigning;
      case 'active':
        return l10n.pdfPactStateActive;
      case 'completed':
        return l10n.pdfPactStateCompleted;
      case 'cancelled':
        return l10n.pdfPactStateCancelled;
      case 'disputed':
        return l10n.pdfPactStateDisputed;
      default:
        return state;
    }
  }

  String _milestoneStateLabel(String state) {
    switch (state) {
      case 'pending':
        return l10n.pdfMilestoneStatePending;
      case 'in_execution':
        return l10n.pdfMilestoneStateInExecution;
      case 'ready_for_review':
        return l10n.pdfMilestoneStateInReview;
      case 'validated':
        return l10n.pdfMilestoneStateValidated;
      case 'approved':
        return l10n.pdfMilestoneStateApproved;
      case 'paid':
        return l10n.pdfMilestoneStatePaid;
      case 'disputed':
        return l10n.pdfMilestoneStateDisputed;
      default:
        return state;
    }
  }

  String _addendumStateLabel(String state) {
    switch (state) {
      case 'active':
        return l10n.pdfAddendumStateActive;
      case 'cancelled':
        return l10n.pdfAddendumStateCancelled;
      default:
        return l10n.pdfAddendumStatePending;
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
