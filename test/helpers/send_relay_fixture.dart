import 'package:evolve/perc/models/perc_amount.dart';


import 'package:evolve/perc/services/perc_block_display_label.dart';
import 'package:evolve/perc/services/perc_ledger.dart';

/// Builds a relay ledger exactly as [PercLedger.send] finalizes it (golden-path fixture).
class SendRelayFixture {
  static void _seed(PercLedger ledger) {
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.networkGenesisRevision = 2;
    ledger.launchBlockchain();
    ledger.consumeBlockchainLaunchEvent();
  }

  static ({PercLedger ledger, String transferTxId, int transferBlockIndex}) build() {
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('android_user', 'password12345');
    ledger.register('windows_user', 'password12345');
    ledger.creditScenario(username: 'android_user', percentChance: 80);
    ledger.login('android_user', 'password12345');

    final tx = ledger.send(
      fromUsername: 'android_user',
      toAddress: ledger.account('windows_user')!.address,
      amount: PercAmount.fromPerc(0.00000005),
      deliverInstantly: true,
    );

    final transferBlock = ledger.blocks.lastWhere(PercBlockDisplayLabel.hasTransfer);
    return (
      ledger: ledger,
      transferTxId: tx.id,
      transferBlockIndex: transferBlock.index,
    );
  }

  static Map<String, dynamic> ledgerJson() => build().ledger.toJson();

  static String transferTxIdFromLedger(Map<String, dynamic> json) {
    final blocks = json['blocks'] as List<dynamic>? ?? [];
    for (final raw in blocks) {
      final block = raw as Map<String, dynamic>;
      final txs = block['transactions'] as List<dynamic>? ?? [];
      for (final txRaw in txs) {
        final tx = txRaw as Map<String, dynamic>;
        if (tx['kind'] == 'transfer') {
          return tx['id'] as String;
        }
      }
    }
    throw StateError('transfer tx missing from relay fixture');
  }
}