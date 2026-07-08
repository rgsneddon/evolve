import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/perc_block.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import 'perc_ledger.dart';

/// Canonical chain tip used to align wallets at the same block height.
class PercChainTip {
  const PercChainTip._();

  static int height(PercLedger ledger) => ledger.blockHeight;

  static String hash(PercLedger ledger) {
    final chainId = ledger.evolutionaryChainId.isEmpty
        ? PercChainConstants.evolutionaryChainId
        : ledger.evolutionaryChainId;
    if (ledger.blocks.isEmpty) {
      return sha256.convert(utf8.encode('genesis:$chainId')).toString();
    }
    final payload = utf8.encode(jsonEncode(_blockTipJson(ledger.blocks.last)));
    return sha256.convert(payload).toString();
  }

  static Map<String, dynamic> _blockTipJson(PercBlock block) => {
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
        'transactions':
            block.transactions.map(_txTipJson).toList(growable: false),
      };

  static Map<String, dynamic> _txTipJson(PercTransaction tx) => {
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
        if (tx.microblockIndex != null) 'microblockIndex': tx.microblockIndex,
        if (tx.chronofluxFingerprint != null)
          'chronofluxFingerprint': tx.chronofluxFingerprint,
      };
}