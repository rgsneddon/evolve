import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet screen wires Android RefreshIndicator to refreshInboundNow', () {
    final source = File('lib/perc/screens/wallet_screen.dart').readAsStringSync();
    expect(source, contains('RefreshIndicator'));
    expect(source, contains('defaultTargetPlatform == TargetPlatform.android'));
    expect(source, contains('onRefresh: wallet.refreshInboundNow'));
    expect(source, contains('AlwaysScrollableScrollPhysics'));
  });
}