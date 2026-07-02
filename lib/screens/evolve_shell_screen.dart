import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/models/perc_faucet_credit_result.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../perc/services/perc_faucet_cooldown.dart';
import '../providers/locale_provider.dart';
import 'home_screen.dart';
import '../perc/screens/credit_screen.dart';
import '../perc/screens/wallet_screen.dart';

/// Root shell — Analysis + wallet after PERC address registration.
class EvolveShellScreen extends StatefulWidget {
  const EvolveShellScreen({super.key});

  @override
  State<EvolveShellScreen> createState() => _EvolveShellScreenState();
}

class _EvolveShellScreenState extends State<EvolveShellScreen> {
  int _index = 0;
  PercWalletProvider? _wallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = context.read<PercWalletProvider>();
    if (!identical(_wallet, wallet)) {
      _wallet?.removeListener(_onWalletUpdate);
      _wallet = wallet;
      _wallet!.addListener(_onWalletUpdate);
    }
  }

  @override
  void dispose() {
    _wallet?.removeListener(_onWalletUpdate);
    super.dispose();
  }

  void _onWalletUpdate() {
    final popup = _wallet?.takeCooldownPopup();
    if (popup != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCooldownDialog(popup);
      });
    }
  }

  Future<void> _showCooldownDialog(PercFaucetCreditResult result) async {
    final strings = AppLocalizations.of(context.read<LocaleProvider>().config);
    final wait = result.cooldownRemaining ?? Duration.zero;
    final blockWait = result.nextBlockEstimate ?? wait;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('wallet_cooldown_popup_title')),
        content: Text(
          strings
              .t('wallet_cooldown_popup_body')
              .replaceAll('{wait}', PercFaucetCooldown.formatWait(wait))
              .replaceAll('{blockWait}', PercFaucetCooldown.formatWait(blockWait)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.t('wallet_cooldown_popup_ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);

    if (!wallet.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final destinations = wallet.hasAppAccess
        ? [
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
            NavigationDestination(
              icon: const Icon(Icons.info_outline),
              selectedIcon: const Icon(Icons.info),
              label: strings.t('nav_credit'),
            ),
          ]
        : [
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: strings.t('nav_wallet'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.info_outline),
              selectedIcon: const Icon(Icons.info),
              label: strings.t('nav_credit'),
            ),
          ];

    final screens = wallet.hasAppAccess
        ? const [HomeScreen(), WalletScreen(), CreditScreen()]
        : const [WalletScreen(), CreditScreen()];

    final navIndex = wallet.hasAppAccess
        ? _index
        : _index.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: navIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}