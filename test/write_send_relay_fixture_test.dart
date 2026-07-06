import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/send_relay_fixture.dart';

/// Writes `perc_chain/fixtures/relay_after_send.json` for Node golden-path tests.
void main() {
  test('write send relay fixture from PercLedger.send', () {
    final built = SendRelayFixture.build();
    final fixture = {
      'transferTxId': built.transferTxId,
      'transferBlockIndex': built.transferBlockIndex,
      'ledger': built.ledger.toJson(),
    };

    final out = File('perc_chain/fixtures/relay_after_send.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(fixture));

    expect(built.transferTxId, isNotEmpty);
    expect(built.transferBlockIndex, greaterThanOrEqualTo(0));
    expect(
      SendRelayFixture.transferTxIdFromLedger(fixture['ledger'] as Map<String, dynamic>),
      built.transferTxId,
    );
  });
}