import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:evolve/perc/services/perc_block_display_label.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_transfer_relay_ack.dart';

/// Builds a relay ledger exactly as [PercLedger.send] finalizes it (golden-path fixture).
class SendRelayFixture {
  static void _seed(PercLedger ledger) {
    ledger.ensureTreasuryAccount();
    ledger.setupTreasuryPassword('password12345');
    ledger.networkGenesisRevision = 2;
    ledger.launchBlockchain();
    ledger.consumeBlockchainLaunchEvent();
  }

  static const _defaultWindowsSalt = 'relay-fixture-windows-salt-v1';

  static String defaultWindowsAddress() => PercAuth.deriveAddress(
        'windows_user',
        _defaultWindowsSalt,
      );

  static ({PercLedger ledger, String transferTxId, int transferBlockIndex}) build({
    String? windowsAddress,
  }) {
    final resolvedAddress = windowsAddress ?? defaultWindowsAddress();
    final ledger = PercLedger.empty();
    _seed(ledger);
    ledger.register('android_user', 'password12345');
    ledger.ensureRemoteAccount(
      username: 'windows_user',
      address: resolvedAddress,
    );
    ledger.creditScenario(username: 'android_user', percentChance: 80);
    ledger.login('android_user', 'password12345');

    final tx = ledger.send(
      fromUsername: 'android_user',
      toAddress: resolvedAddress,
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

  static Map<String, dynamic> ledgerJson({String? windowsAddress}) =>
      build(windowsAddress: windowsAddress).ledger.toJson();

  /// Taller seed ledger after [PercTransferRelayAck] promotes a shorter sender relay.
  static ({
    PercLedger ledger,
    String transferTxId,
    int transferBlockIndex,
    int canonicalIndex,
  }) buildTallerSeedWithRelayAck({String? windowsAddress}) {
    final built = build(windowsAddress: windowsAddress);
    final seed = PercLedger.empty();
    _seed(seed);
    for (var i = 0; i < 3; i++) {
      seed.blocks.add(
        PercBlock(
          index: seed.blocks.length,
          timestamp: DateTime.now().toUtc(),
          transactions: const [],
          treasuryEmitted: PercAmount.zero,
          scenarioLabel: 'Seed ahead $i',
        ),
      );
    }
    expectRelayShorterThanSeed(built.ledger, seed);
    PercTransferRelayAck.acknowledgeRelayTransfers(seed, built.ledger);
    seed.mergeDiscoverableAccounts(built.ledger);
    final canonicalIndex = seed.blocks.length - 1;
    return (
      ledger: seed,
      transferTxId: built.transferTxId,
      transferBlockIndex: built.transferBlockIndex,
      canonicalIndex: canonicalIndex,
    );
  }

  static void expectRelayShorterThanSeed(PercLedger relay, PercLedger seed) {
    if (relay.blockHeight >= seed.blockHeight) {
      throw StateError(
        'relay height ${relay.blockHeight} must be shorter than seed ${seed.blockHeight}',
      );
    }
  }

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