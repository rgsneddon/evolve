import '../models/perc_block.dart';
import '../models/perc_transaction.dart';

/// Short generic labels for the in-app block explorer (mirrors `block_display_label.js`).
class PercBlockDisplayLabel {
  const PercBlockDisplayLabel._();

  static String forBlock(PercBlock block) {
    final txs = block.transactions;
    final kinds = txs.map((t) => t.kind).toSet();
    final text = _collectScenarioText(block);

    if (kinds.contains(PercTxKind.transfer)) return 'Manual tx';

    if (kinds.contains(PercTxKind.scenarioReward)) {
      if (_isScsInput(text)) return 'SCS input';
      if (_isPercentChanceInput(text)) return '% chance input';
      return 'Scenario reward';
    }
    if (kinds.contains(PercTxKind.transferRevert)) return 'Transfer revert';

    if (block.microblockSeal || kinds.contains(PercTxKind.chronofluxMicroblock)) {
      return 'Microblock seal';
    }

    if (kinds.contains(PercTxKind.genesisRenewal)) return 'Genesis renewal';
    if (kinds.contains(PercTxKind.stakingReward)) return 'Staked reward';

    if (kinds.contains(PercTxKind.feeBurn) && !kinds.contains(PercTxKind.transfer)) {
      return 'Burned PERC';
    }

    if (kinds.contains(PercTxKind.treasuryEmission)) {
      if (text.contains('regeneration')) return 'Treasury regeneration';
      if (text.contains('launch')) return 'Blockchain launch';
      return 'Treasury emission';
    }

    if (text.contains('chronoflux microblock')) return 'Microblock seal';
    if (text.contains('treasury regeneration')) return 'Treasury regeneration';
    if (text.contains('blockchain launch')) return 'Blockchain launch';
    if (_isScsInput(text)) return 'SCS input';
    if (_isPercentChanceInput(text)) return '% chance input';

    if (block.triggerUsername != null) return 'Network activity';
    return '—';
  }

  static List<PercTransaction> transferTransactions(PercBlock block) =>
      block.transactions
          .where((t) => t.kind == PercTxKind.transfer)
          .toList(growable: false);

  static bool hasTransfer(PercBlock block) =>
      block.transactions.any((t) => t.kind == PercTxKind.transfer);

  static String _collectScenarioText(PercBlock block) {
    final parts = <String?>[block.scenarioLabel];
    for (final tx in block.transactions) {
      parts.add(tx.scenarioLabel);
      parts.add(tx.memo);
    }
    return parts
        .whereType<String>()
        .map((s) => s.trim().toLowerCase())
        .join(' ');
  }

  static bool _isScsInput(String text) =>
      text.contains('social cohesion') ||
      RegExp(r'\bscs\b').hasMatch(text) ||
      text.contains('cohesion score');

  static bool _isPercentChanceInput(String text) =>
      text.contains('percent chance') || RegExp(r'\bpercent\b').hasMatch(text);
}