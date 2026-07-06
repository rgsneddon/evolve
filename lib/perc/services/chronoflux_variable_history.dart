import '../models/chronoflux_construct_snapshot.dart';
import '../models/perc_block.dart';
import '../models/perc_transaction.dart';

/// Collects up to five Chronoflux construct snapshots from scenario blocks.
class ChronofluxVariableHistory {
  const ChronofluxVariableHistory._();

  static const int pointCount = 5;

  static List<ChronofluxConstructSnapshot> fromBlocks(List<PercBlock> blocks) {
    final snapshots = <ChronofluxConstructSnapshot>[];
    for (final block in blocks) {
      for (final tx in block.transactions) {
        final snap = snapshotFromTransaction(tx);
        if (snap != null) snapshots.add(snap);
      }
    }
    if (snapshots.length <= pointCount) return snapshots;
    return snapshots.sublist(snapshots.length - pointCount);
  }

  static ChronofluxConstructSnapshot? snapshotFromTransaction(PercTransaction tx) {
    if (tx.kind != PercTxKind.scenarioReward) return null;
    if (tx.vortexScs != null &&
        tx.shearScs != null &&
        tx.resistanceScs != null &&
        tx.flowScs != null) {
      return ChronofluxConstructSnapshot.fromCore(
        continuumScs: tx.continuumScs ?? tx.percentChance ?? tx.vortexScs!,
        vortexScs: tx.vortexScs!,
        shearScs: tx.shearScs!,
        resistanceScs: tx.resistanceScs!,
        flowScs: tx.flowScs!,
        timestamp: tx.timestamp,
        outcomeScore: tx.percentChance,
      );
    }
    if (tx.percentChance != null) {
      return ChronofluxConstructSnapshot.inferFromOutcome(
        outcomeScore: tx.percentChance!,
        timestamp: tx.timestamp,
      );
    }
    return null;
  }

  /// Time labels aligned to Chronoflux input order (ρt → ω → σ → Iτ → Jμ).
  static List<DateTime> inputAlignedTimes(ChronofluxConstructSnapshot latest) {
    const step = Duration(seconds: 1);
    final anchor = latest.timestamp.toUtc();
    return List.generate(
      pointCount,
      (i) => anchor.subtract(step * (pointCount - 1 - i)),
    );
  }

  static List<double> seriesForKey(
    List<ChronofluxConstructSnapshot> history,
    String key,
  ) =>
      history.map((s) => s.valueForKey(key).clamp(0.0, 100.0)).toList();

  static List<String> timeLabels(List<ChronofluxConstructSnapshot> history) {
    if (history.isEmpty) return [];
    if (history.length == 1) {
      final t = history.first.timestamp.toLocal();
      return [
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      ];
    }
    return history
        .map((s) {
          final t = s.timestamp.toLocal();
          return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        })
        .toList();
  }
}