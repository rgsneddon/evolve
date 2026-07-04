import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_amount.dart';
import 'package:evolve/perc/perc_chain_constants.dart';
import 'package:evolve/perc/services/perc_currency.dart';

void main() {
  test('currency name is Perccent with PERC symbol', () {
    expect(PercChainConstants.currencyName, 'Perccent');
    expect(PercChainConstants.currencySymbol, 'PERC');
    expect(PercChainConstants.centValueInPerc, '0.00000001');
    expect(PercChainConstants.centsPerPerc, 100000000);
    expect(PercChainConstants.minimumTransferAmount, PercAmount.smallestUnit);
    expect(PercChainConstants.sendTransactionFee, PercAmount.smallestUnit);
    expect(PercChainConstants.infiniteContinuumSupply, isTrue);
    expect(PercChainConstants.poolRenewalAllocation.asPerc, 283000000);
    expect(PercChainConstants.confirmationsRequired, 1);
  });

  test('1 cent equals 0.00000001 PERC', () {
    const oneCent = PercAmount(1);
    expect(oneCent.displayFixed8, '0.00000001');
    expect(oneCent.asCents, 1);
    expect(oneCent.centDisplay, '1 cent');
  });

  test('PercCurrency brand and denomination labels', () {
    expect(PercCurrency.brandLabel, 'PERC · Perccent');
    expect(PercCurrency.denominationNote(), '1 cent = 0.00000001 PERC');
    expect(
      PercCurrency.sendFeeNote(),
      'Network fee: 0.00000001 PERC per send (burned)',
    );
    expect(
      PercCurrency.cumulativeBurnedNote(PercAmount.smallestUnit),
      'Cumulative burned: 0.00000001 PERC',
    );
    expect(
      PercCurrency.formatWithCents(PercAmount(5)),
      '0.00000005 PERC (5 cents)',
    );
  });
}