import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import 'home_screen.dart';
import '../perc/screens/wallet_screen.dart';

/// Root shell — Analysis + PERCENTAGE wallet (Beam-style dual-pane navigation).
class EvolveShellScreen extends StatefulWidget {
  const EvolveShellScreen({super.key});

  @override
  State<EvolveShellScreen> createState() => _EvolveShellScreenState();
}

class _EvolveShellScreenState extends State<EvolveShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          WalletScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics),
            label: strings.t('nav_analysis'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: strings.t('nav_wallet'),
          ),
        ],
      ),
    );
  }
}