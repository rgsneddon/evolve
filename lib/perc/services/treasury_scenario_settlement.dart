import '../models/perc_amount.dart';

/// Ordered treasury operations for one scenario draw.
enum TreasuryScenarioOpKind {
  debitReward,
  mintBootstrap,
  mintAccrual,
  markGenesisDone,
}

class TreasuryScenarioOp {
  const TreasuryScenarioOp(this.kind, [this.amount]);

  final TreasuryScenarioOpKind kind;
  final PercAmount? amount;
}

/// Pure planner: genesis bootstrap mints before the first payout; later draws
/// debit pre-draw balance first and accrue emission after payout.
class TreasuryScenarioSettlement {
  const TreasuryScenarioSettlement._();

  static bool canDebitFromBalance({
    required PercAmount balance,
    required PercAmount debit,
    required PercAmount minimumReserve,
  }) {
    final after = balance - debit;
    return after.microUnits >= minimumReserve.microUnits;
  }

  /// Returns ops in apply order. [preDrawBalance] is treasury balance after
  /// pool renewal/regeneration credits and before any draw-local minting.
  static List<TreasuryScenarioOp> plan({
    required PercAmount preDrawBalance,
    required PercAmount minimumReserve,
    required PercAmount reward,
    required bool treasuryGenesisDone,
    required PercAmount bootstrapAmount,
    required PercAmount accrualAmount,
    required bool skipPayout,
  }) {
    final ops = <TreasuryScenarioOp>[];
    final needsBootstrap =
        !treasuryGenesisDone && bootstrapAmount.isPositive;
    final payoutBalance = needsBootstrap
        ? preDrawBalance + bootstrapAmount
        : preDrawBalance;
    final canPayout = !skipPayout &&
        reward.isPositive &&
        canDebitFromBalance(
          balance: payoutBalance,
          debit: reward,
          minimumReserve: minimumReserve,
        );

    if (needsBootstrap && canPayout) {
      ops.add(
        TreasuryScenarioOp(
          TreasuryScenarioOpKind.mintBootstrap,
          bootstrapAmount,
        ),
      );
    }

    if (canPayout) {
      ops.add(TreasuryScenarioOp(TreasuryScenarioOpKind.debitReward, reward));
    }

    if (!treasuryGenesisDone) {
      if (bootstrapAmount.isPositive) {
        if (!ops.any((o) => o.kind == TreasuryScenarioOpKind.mintBootstrap)) {
          ops.add(
            TreasuryScenarioOp(
              TreasuryScenarioOpKind.mintBootstrap,
              bootstrapAmount,
            ),
          );
        }
      } else {
        ops.add(const TreasuryScenarioOp(TreasuryScenarioOpKind.markGenesisDone));
      }
    }

    if (accrualAmount.isPositive) {
      ops.add(
        TreasuryScenarioOp(TreasuryScenarioOpKind.mintAccrual, accrualAmount),
      );
    } else if (!treasuryGenesisDone &&
        !ops.any((o) => o.kind == TreasuryScenarioOpKind.mintBootstrap)) {
      ops.add(const TreasuryScenarioOp(TreasuryScenarioOpKind.markGenesisDone));
    }

    return ops;
  }

  static int indexOfFirstMint(List<TreasuryScenarioOp> ops) {
    for (var i = 0; i < ops.length; i++) {
      final kind = ops[i].kind;
      if (kind == TreasuryScenarioOpKind.mintBootstrap ||
          kind == TreasuryScenarioOpKind.mintAccrual) {
        return i;
      }
    }
    return -1;
  }

  static int indexOfDebitReward(List<TreasuryScenarioOp> ops) {
    return ops.indexWhere((o) => o.kind == TreasuryScenarioOpKind.debitReward);
  }
}