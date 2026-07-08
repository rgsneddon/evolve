import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/models/perc_block.dart';
import 'package:evolve/perc/models/perc_transaction.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_chain_tip.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _blockInput(PercBlock block) => {
      'index': block.index,
      'timestamp': block.timestamp.toIso8601String(),
      'treasuryEmitted': block.treasuryEmitted.toJson(),
      if (block.treasuryCycle != 1) 'treasuryCycle': block.treasuryCycle,
      if (block.isGenesisRenewal) 'isGenesisRenewal': block.isGenesisRenewal,
      if (block.confirmations != PercChainConstants.confirmationsRequired)
        'confirmations': block.confirmations,
      if (block.microblockSeal) 'microblockSeal': block.microblockSeal,
      if (block.chronofluxFingerprint != null)
        'chronofluxFingerprint': block.chronofluxFingerprint,
      if (block.microblocksSealed != null)
        'microblocksSealed': block.microblocksSealed,
      'transactions': block.transactions
          .map(
            (tx) => {
              'id': tx.id,
              'kind': tx.kind.wireName,
              'amount': tx.amount.toJson(),
              'timestamp': tx.timestamp.toIso8601String(),
              if (tx.percentChance != null) 'percentChance': tx.percentChance,
              if (tx.blockIndex != null) 'blockIndex': tx.blockIndex,
              if (tx.confirmations != 0) 'confirmations': tx.confirmations,
              if (tx.continuumScs != null) 'continuumScs': tx.continuumScs,
              if (tx.vortexScs != null) 'vortexScs': tx.vortexScs,
              if (tx.shearScs != null) 'shearScs': tx.shearScs,
              if (tx.resistanceScs != null) 'resistanceScs': tx.resistanceScs,
              if (tx.flowScs != null) 'flowScs': tx.flowScs,
              if (tx.microblockIndex != null)
                'microblockIndex': tx.microblockIndex,
              if (tx.chronofluxFingerprint != null)
                'chronofluxFingerprint': tx.chronofluxFingerprint,
            },
          )
          .toList(growable: false),
    };

Map<String, dynamic> _emitCase(String name, PercBlock block) {
  final ledger = PercLedger(
    accounts: {},
    blocks: [block],
    lastScenarioAt: DateTime.utc(2026, 7, 6, 10),
    treasuryGenesisDone: true,
    cumulativeTreasuryMinted: PercAmount.zero,
  );
  final payloadBytes = utf8.encode(
    jsonEncode(_canonicalBlockJson(ledger.blocks.last)),
  );
  final tipHash = sha256.convert(payloadBytes).toString();
  expect(tipHash, PercChainTip.hash(ledger));
  return {
    'block': _blockInput(block),
    'canonicalJson': utf8.decode(payloadBytes),
    'tipHash': tipHash,
  };
}

Map<String, dynamic> _canonicalBlockJson(PercBlock block) => {
      'index': block.index,
      'timestamp': block.timestamp.toIso8601String(),
      'treasuryEmitted': block.treasuryEmitted.toJson(),
      if (block.treasuryCycle != 1) 'treasuryCycle': block.treasuryCycle,
      if (block.isGenesisRenewal) 'isGenesisRenewal': block.isGenesisRenewal,
      if (block.confirmations != PercChainConstants.confirmationsRequired)
        'confirmations': block.confirmations,
      if (block.microblockSeal) 'microblockSeal': block.microblockSeal,
      if (block.chronofluxFingerprint != null)
        'chronofluxFingerprint': block.chronofluxFingerprint,
      if (block.microblocksSealed != null)
        'microblocksSealed': block.microblocksSealed,
      'transactions': block.transactions
          .map(
            (tx) => {
              'id': tx.id,
              'kind': tx.kind.wireName,
              'amount': tx.amount.toJson(),
              'timestamp': tx.timestamp.toIso8601String(),
              if (tx.percentChance != null) 'percentChance': tx.percentChance,
              if (tx.blockIndex != null) 'blockIndex': tx.blockIndex,
              if (tx.confirmations != 0) 'confirmations': tx.confirmations,
              if (tx.continuumScs != null) 'continuumScs': tx.continuumScs,
              if (tx.vortexScs != null) 'vortexScs': tx.vortexScs,
              if (tx.shearScs != null) 'shearScs': tx.shearScs,
              if (tx.resistanceScs != null) 'resistanceScs': tx.resistanceScs,
              if (tx.flowScs != null) 'flowScs': tx.flowScs,
              if (tx.microblockIndex != null)
                'microblockIndex': tx.microblockIndex,
              if (tx.chronofluxFingerprint != null)
                'chronofluxFingerprint': tx.chronofluxFingerprint,
            },
          )
          .toList(growable: false),
    };

void main() {
  test('emit tip_payload_canonical.json for node parity tests', () {
    final cases = <String, dynamic>{
      'defaults_only': _emitCase(
        'defaults_only',
        PercBlock(
          index: 0,
          timestamp: DateTime.utc(2026, 7, 6, 10),
          treasuryEmitted: PercAmount.zero,
          transactions: [
            PercTransaction(
              id: 'tx-1',
              kind: PercTxKind.transfer,
              amount: const PercAmount(5),
              timestamp: DateTime.utc(2026, 7, 6, 10),
            ),
          ],
        ),
      ),
      'treasury_cycle_two': _emitCase(
        'treasury_cycle_two',
        PercBlock(
          index: 1,
          timestamp: DateTime.utc(2026, 7, 6, 10),
          treasuryEmitted: PercAmount.zero,
          treasuryCycle: 2,
          transactions: [],
        ),
      ),
      'all_optionals': _emitCase(
        'all_optionals',
        PercBlock(
          index: 2,
          timestamp: DateTime.utc(2026, 7, 6, 10),
          treasuryEmitted: const PercAmount(100),
          treasuryCycle: 2,
          isGenesisRenewal: true,
          confirmations: 2,
          microblockSeal: true,
          chronofluxFingerprint: 'cfp-block',
          microblocksSealed: 5,
          transactions: [
            PercTransaction(
              id: 'tx-9',
              kind: PercTxKind.stakingReward,
              amount: const PercAmount(3),
              timestamp: DateTime.utc(2026, 7, 6, 10),
              percentChance: 42.5,
              blockIndex: 2,
              confirmations: 1,
              continuumScs: 1.1,
              vortexScs: 2.2,
              shearScs: 3.3,
              resistanceScs: 4.4,
              flowScs: 5.5,
              microblockIndex: 7,
              chronofluxFingerprint: 'cfp-tx',
            ),
          ],
        ),
      ),
    };

    final path = Platform.isWindows
        ? r'C:\Users\rgsne\evolve_app\perc_chain\fixtures\tip_payload_canonical.json'
        : 'perc_chain/fixtures/tip_payload_canonical.json';
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(cases),
    );
    expect(File(path).existsSync(), isTrue);
  });
}