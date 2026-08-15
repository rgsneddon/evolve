import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _scratch = Platform.environment['SCRATCH'] ??
    '/var/folders/qb/tz4y4zts04z4846pbq95l6kw0000gp/T/grok-goal-5fa0907a8752/implementer';

void main() {
  test('sibling apps share HTTPS rendezvous and skip dead :9477 chain hops', () {
    const rendezvous = 'https://135.181.152.10.sslip.io/perc';
    final roots = [
      Directory('/Users/russellsneddon/evolve'),
      Directory('/Users/russellsneddon/git'),
      Directory('/Users/russellsneddon/evolve-apple'),
    ];
    final lines = <String>[];
    for (final root in roots) {
      final name = root.path.split('/').last;
      final network = File('${root.path}/assets/config/perc_network.json');
      final endpoint = File(
        '${root.path}/lib/perc/services/perc_public_endpoint.dart',
      );
      final wallet = File(
        '${root.path}/lib/perc/providers/perc_wallet_provider.dart',
      );
      final android = File(
        '${root.path}/android/app/src/main/res/xml/network_security_config.xml',
      );
      expect(network.existsSync(), isTrue, reason: '$name perc_network.json');
      final networkBody = network.readAsStringSync();
      expect(networkBody.contains(rendezvous), isTrue, reason: name);
      expect(networkBody.contains('217.142.21.226'), isFalse, reason: name);
      expect(
        endpoint.readAsStringSync().contains('isChainFetchEndpoint'),
        isTrue,
        reason: name,
      );
      final walletBody = wallet.readAsStringSync();
      expect(
        walletBody.contains('!_registrationAwaitingSeedAlignment'),
        isFalse,
        reason: '$name splash must not wait on seed alignment',
      );
      expect(android.existsSync(), isTrue, reason: '$name cleartext policy');
      final androidBody = android.readAsStringSync();
      expect(androidBody.contains('127.0.0.1'), isTrue, reason: name);
      expect(
        androidBody.contains('cleartextTrafficPermitted="true"'),
        isTrue,
        reason: name,
      );
      lines.add(
        'app=$name rendezvous=$rendezvous chainFetch=yes '
        'splashBlocksOnAlignment=no androidLoopbackCleartext=yes',
      );
    }
    Directory(_scratch).createSync(recursive: true);
    File('$_scratch${Platform.pathSeparator}sibling-sync.log').writeAsStringSync(
      '${lines.join('\n')}\n',
    );
  });
}
