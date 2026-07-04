import '../models/perc_amount.dart';
import '../perc_chain_constants.dart';

/// Perccent display helpers — PERC main unit, cent sub-denomination.
class PercCurrency {
  const PercCurrency._();

  static String get brandLabel =>
      '${PercChainConstants.currencySymbol} · ${PercChainConstants.currencyName}';

  static String denominationNote() =>
      '1 ${PercChainConstants.centName} = ${PercChainConstants.centValueInPerc} ${PercChainConstants.currencySymbol}';

  static String minimumTransferNote() =>
      'Minimum transfer: ${PercChainConstants.minimumTransferAmount.displayFixed8} ${PercChainConstants.currencySymbol}';

  static String formatPerc(PercAmount amount) =>
      '${amount.displayFixed8} ${PercChainConstants.currencySymbol}';

  static String formatWithCents(PercAmount amount) {
    if (!amount.isPositive) return formatPerc(amount);
    return '${formatPerc(amount)} (${amount.centDisplay})';
  }
}