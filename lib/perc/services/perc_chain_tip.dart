import 'dart:convert';

import 'package:crypto/crypto.dart';

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
    final last = ledger.blocks.last;
    final payload = utf8.encode(jsonEncode(last.toJson()));
    return sha256.convert(payload).toString();
  }
}