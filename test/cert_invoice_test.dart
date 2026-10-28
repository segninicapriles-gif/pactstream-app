import 'package:flutter_test/flutter_test.dart';
import 'package:pactstream/features/pact/data/milestone_detail.dart';

// Factura de la certificación (28-oct): la emite CostPact o el sistema externo
// del constructor; PactStream solo la guarda. Se adjunta también aprobada o
// pagada, que es cuando se emite la factura de una certificación.

MilestoneFull _m(String state, String role, {String? path, String? number}) =>
    MilestoneFull.fromJson({
      'id': 'm1',
      'pact_id': 'p1',
      'pact_display_id': 'PS-1',
      'pact_title': 'Obra',
      'pact_type': 'obra_mayor',
      'display_id': 'H-1',
      'ordinal': 1,
      'name': 'Estructura',
      'amount_cents': 100000,
      'state': state,
      'state_updated_at': '2026-10-28T10:00:00Z',
      'my_role': role,
      'invoice_number': number,
      'invoice_storage_path': path,
    });

void main() {
  test('lee la factura del detalle', () {
    final m = _m('paid', 'constructor', path: 'p1/m1/f.pdf', number: 'F2026/0012');
    expect(m.hasInvoice, isTrue);
    expect(m.invoiceNumber, 'F2026/0012');
    expect(_m('paid', 'constructor').hasInvoice, isFalse);
  });

  test('solo el constructor adjunta, de la ejecución al pago', () {
    for (final s in ['in_execution', 'awaiting_promotor', 'approved_by_tech', 'paid']) {
      expect(_m(s, 'constructor').canAttachInvoice, isTrue, reason: s);
    }
    expect(_m('pending', 'constructor').canAttachInvoice, isFalse);
    expect(_m('disputed', 'constructor').canAttachInvoice, isFalse);
    expect(_m('paid', 'promotor').canAttachInvoice, isFalse);
  });
}
