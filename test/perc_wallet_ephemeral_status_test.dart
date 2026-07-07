import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/models/perc_faucet_credit_result.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_ledger_hub.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';

void main() {
  setUp(() {
    PercLedgerHub.resetForTest();
    PercWalletProvider.sessionTimeoutEnabled = false;
  });

  tearDown(() {
    PercWalletProvider.sessionTimeoutEnabled = true;
    PercLedgerHub.resetForTest();
  });

  test('send status clears from balance card after 15 seconds', () {
    fakeAsync((async) {
      final store = PercWalletStoreMemory();
      final wallet = PercWalletProvider(store: store);
      async.run((_) async {
        await wallet.initialize();
        await wallet.setupTreasuryPassword('password12345');
        await wallet.register('alice', 'password12345');
        PercLedgerHub.instance.ledger.launchBlockchain();
        final credit = await wallet.creditScenario(outcomeScore: 80, memo: 'fund');
        expect(credit?.status, PercFaucetCreditStatus.credited);

        PercLedgerHub.instance.ledger.register('bob', 'password12345');
        final bobAddr = PercLedgerHub.instance.ledger.account('bob')!.address;

        await wallet.send(toAddress: bobAddr, amountText: '0.00000001');
        expect(wallet.statusMessage, 'wallet_status_sent_instant');

        async.elapse(const Duration(seconds: 14));
        expect(wallet.statusMessage, 'wallet_status_sent_instant');

        async.elapse(const Duration(seconds: 1));
        expect(wallet.statusMessage, isNull);
      });
    });
  });
}