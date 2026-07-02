import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/models/perc_faucet_credit_result.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../perc/services/perc_faucet_cooldown.dart';
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
              .replaceAll('{blockWait}', PercFaucetCooldown.formatWait(blockWait))
              .replaceAll('{base}', '0.00000050'),
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