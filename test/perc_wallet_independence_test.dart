import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

void main() {
  test('importPeerLedger preserves local wallet credentials', () {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('alice', 'password12345');

    final remote = PercLedger.fromJson(local.toJson());
    remote.creditScenario(
      username: 'alice',
      percentChance: 50,
      scenarioLabel: 'peer growth',
    );

    expect(remote.blockHeight, greaterThan(local.blockHeight));

    local.importPeerLedger(
      remote,
      expectedTipHash: PercChainTip.hash(remote),
    );

    expect(local.blockHeight, remote.blockHeight);
    expect(
      PercAuth.verifyPassword(
        password: 'password12345',
        salt: local.account('alice')!.salt,
        expectedHash: local.account('alice')!.passwordHash,
      ),
      isTrue,
    );
  });

  test('importPeerLedger keeps local-only wallet independent of network', () {
    final local = PercLedger.empty();
    local.ensureTreasuryAccount();
    local.setupTreasuryPassword('password12345');
    local.launchBlockchain();
    local.register('device_only', 'password12345');

    final remote = PercLedger.fromJson(local.toJson());
    remote.accounts.remove('device_only');
    remote.creditScenario(
      username: PercChainConstants.treasuryUsername,
      percentChance: 40,
      scenarioLabel: 'network advance',
    );

    expect(remote.blockHeight, greaterThan(local.blockHeight));
    expect(remote.accounts.containsKey('device_only'), isFalse);

    local.importPeerLedger(
      remote,
      expectedTipHash: PercChainTip.hash(remote),
    );

    expect(local.blockHeight, remote.blockHeight);
    expect(local.accounts.containsKey('device_only'), isTrue);
    expect(
      PercAuth.verifyPassword(
        password: 'password12345',
        salt: local.account('device_only')!.salt,
        expectedHash: local.account('device_only')!.passwordHash,
      ),
      isTrue,
    );
  });
}