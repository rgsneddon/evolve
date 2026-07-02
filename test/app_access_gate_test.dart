import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/main.dart';
import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/perc/services/perc_wallet_store_memory.dart';
import 'package:evolve/providers/evolve_provider.dart';
import 'package:evolve/widgets/evolve_banner.dart';

Future<void> _unlockApp(PercWalletProvider wallet) async {
  await wallet.initialize();
  await wallet.setupTreasuryPassword('password12345');
  await wallet.register('appuser', 'password12345');
}

void main() {
  testWidgets('app shows wallet gate until PERC address is registered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await provider.initialize();
    await wallet.initialize();

    await tester.pumpWidget(
      EvolveApp(evolveProvider: provider, walletProvider: wallet),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(wallet.hasAppAccess, isFalse);
    expect(find.text('Create your wallet first'), findsOneWidget);
    expect(find.byType(EvolveBanner), findsNothing);
    expect(find.text('RUN ANALYSIS'), findsNothing);
  });

  testWidgets('app unlocks analysis after registration generates address', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = EvolveProvider();
    final wallet = PercWalletProvider(store: PercWalletStoreMemory());
    await provider.initialize();
    await _unlockApp(wallet);

    expect(wallet.hasAppAccess, isTrue);
    expect(wallet.address.startsWith('perc1'), isTrue);

    await tester.pumpWidget(
      EvolveApp(evolveProvider: provider, walletProvider: wallet),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EvolveBanner), findsOneWidget);
    expect(find.text('RUN ANALYSIS'), findsOneWidget);
    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
  });
}