import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void _seed(PercLedger ledger) {
  ledger.ensureTreasuryAccount();
  ledger.setupTreasuryPassword('password12345');
  ledger.launchBlockchain();
  ledger.consumeBlockchainLaunchEvent();
}

void main() {
  test('restored clones share address and balance after backup import', () {
    final primary = PercLedger.empty();
    _seed(primary);
    primary.register('traveler', 'password12345');
    primary.login('traveler', 'password12345');
    primary.creditScenario(username: 'traveler', percentChance: 60);
    final address = primary.account('traveler')!.address;

    final exported = PercWalletBackup.exportEncrypted(
      ledger: primary.snapshotForBackup(),
      passphrase: 'backup-passphrase-9',
    );
    final restoredLedger = PercWalletBackup.importEncrypted(
      bytes: exported,
      passphrase: 'backup-passphrase-9',
    );
    restoredLedger.login('traveler', 'password12345');

    expect(restoredLedger.account('traveler')!.address, address);
    expect(
      restoredLedger.account('traveler')!.balance,
      primary.account('traveler')!.balance,
    );
  });

  test('transaction on primary device updates restored clone after peer merge',
      () {
    final primary = PercLedger.empty();
    final clone = PercLedger.empty();
    _seed(primary);
    _seed(clone);

    primary.register('alice', 'password12345');
    primary.register('bob', 'password12345');
    primary.login('alice', 'password12345');
    primary.creditScenario(username: 'alice', percentChance: 80);
    final startingBalance = primary.account('alice')!.balance;

    final backup = primary.snapshotForBackup();
    clone.importPeerLedger(backup, force: true);
    clone.login('alice', 'password12345');

    expect(clone.account('alice')!.address, primary.account('alice')!.address);
    expect(clone.account('alice')!.balance, startingBalance);

    final bobAddr = primary.account('bob')!.address;
    primary.send(
      fromUsername: 'alice',
      toAddress: bobAddr,
      amount: PercAmount.fromPerc(0.00000005),
      deliverInstantly: true,
    );

    clone.mergeNetworkStateFromPeer(primary);
    clone.login('alice', 'password12345');

    expect(
      clone.account('alice')!.balance,
      primary.account('alice')!.balance,
    );
    expect(
      clone.account('alice')!.balance.microUnits,
      lessThan(startingBalance.microUnits),
    );
  });
}