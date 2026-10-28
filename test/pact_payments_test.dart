import 'package:flutter_test/flutter_test.dart';
import 'package:pactstream/features/pact/data/pact_detail.dart';

// «Cobrado» sale de `payments` (libro único mock/Mangopay, 28-oct), no de
// sumar hitos en estado 'paid'.

Map<String, dynamic> _pact() => {
      'id': 'p1',
      'display_id': 'PS-1',
      'title': 'Pacto',
      'pact_type': 'obra_mayor',
      'state': 'in_execution',
      'state_updated_at': '2026-10-28T10:00:00Z',
      'obra_address_line': 'Calle 1',
      'created_by_user_id': 'u1',
      'created_at': '2026-10-01T10:00:00Z',
      'my_user_id': 'u1',
    };

Map<String, dynamic> _pay(String id, String type, String state, int cents,
        {String? transfer}) =>
    {
      'id': id,
      'milestone_id': 'm-$id',
      'payment_type': type,
      'amount_cents': cents,
      'state': state,
      'destination_user_id': 'u2',
      'mangopay_transaction_id': transfer,
      'succeeded_at': state == 'succeeded' ? '2026-10-28T12:00:00Z' : null,
      'created_at': '2026-10-28T11:00:00Z',
    };

void main() {
  test('cobrado = solo liberaciones de hito en succeeded (mock y Mangopay)', () {
    final d = PactDetail.fromJson({
      'pact': _pact(),
      'payments': [
        _pay('a', 'milestone_release', 'succeeded', 100000),
        _pay('b', 'milestone_release', 'succeeded', 50000, transfer: 'tr_1'),
        _pay('c', 'milestone_release', 'created', 70000),
        _pay('d', 'pay_in', 'succeeded', 900000),
        _pay('e', 'milestone_release', 'failed', 30000),
      ],
    });
    expect(d.collectedCents, 150000);
    expect(d.payments.first.mangopayTransactionId, isNull);
    expect(d.payments[1].mangopayTransactionId, 'tr_1');
  });

  test('sin clave payments (RPC antiguo o sin economics) cobrado = 0', () {
    final d = PactDetail.fromJson({'pact': _pact()});
    expect(d.payments, isEmpty);
    expect(d.collectedCents, 0);
  });
}
