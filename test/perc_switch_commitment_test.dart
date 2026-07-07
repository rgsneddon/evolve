import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_switch_commitment.dart';

void main() {
  test('derive is deterministic for same binding', () {
    final a = PercSwitchCommitment.derive('transfer:tx-1');
    final b = PercSwitchCommitment.derive('transfer:tx-1');
    expect(a, b);
    expect(a.startsWith('swc1'), isTrue);
  });

  test('validates matching commitment', () {
    final binding = 'password:salt:hash';
    final tag = PercSwitchCommitment.forPasswordHash('hash', 'salt');
    expect(PercSwitchCommitment.validates(tag, binding), isTrue);
  });

  test('rejects tampered commitment', () {
    final tag = PercSwitchCommitment.forTransferId('tx-9');
    expect(PercSwitchCommitment.validates('${tag}x', 'transfer:tx-9'), isFalse);
  });
}