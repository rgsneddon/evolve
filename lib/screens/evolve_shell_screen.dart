import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/models/perc_faucet_credit_result.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../perc/services/perc_network_coordinator.dart';
import '../perc/services/perc_faucet_cooldown.dart';
import '../providers/evolve_provider.dart';
import '../providers/locale_provider.dart';
import '../fcg/screens/fcg_voting_screen.dart';
import 'home_screen.dart';
import '../perc/screens/credit_screen.dart';
import '../perc/screens/wallet_screen.dart';

/// Root shell — Analysis + wallet after PERC address registration.
class EvolveShellScreen extends StatefulWidget {
  const EvolveShellScreen({super.key, this.openRegistrationOnLaunch = false});

  /// When true, wallet registration/login is shown on first frame (unsigned users).
  final bool openRegistrationOnLaunch;

  @override
  State<EvolveShellScreen> createState() => _EvolveShellScreenState();
}

class _EvolveShellScreenState extends State<EvolveShellScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  late bool _walletTabVisited = widget.openRegistrationOnLaunch;
  PercWalletProvider? _wallet;
  EvolveProvider? _evolve;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive;
    PercNetworkCoordinator.instance.setAppInBackground(inBackground);
    if (state == AppLifecycleState.resumed) {
      _wallet?.checkSessionTimeout();
      final wallet = _wallet;
      final evolve = _evolve;
      if (wallet != null) unawaited(wallet.refreshInboundNow());
      if (evolve != null) unawaited(evolve.resumeGrokOAuthCheck());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = context.read<PercWalletProvider>();
    if (_wallet != wallet) {
      _wallet?.removeListener(_onWalletUpdate);
      _wallet = wallet;
      _wallet!.addListener(_onWalletUpdate);
    }
    _evolve = context.read<EvolveProvider>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
              icon: const Icon(Icons.how_to_vote_outlined),
              selectedIcon: const Icon(Icons.how_to_vote),
              label: strings.t('nav_voting'),
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

    final walletTabIndex = wallet.hasAppAccess ? 1 : 0;
    final navIndex = wallet.hasAppAccess
        ? _index
        : _index.clamp(0, destinations.length - 1);

    final showWallet =
        _walletTabVisited || navIndex == walletTabIndex;
    if (navIndex == walletTabIndex && !_walletTabVisited) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _walletTabVisited = true);
      });
    }

    return Scaffold(
      body: wallet.hasAppAccess
          ? IndexedStack(
              index: navIndex,
              children: [
                const HomeScreen(),
                showWallet ? const WalletScreen() : const SizedBox.shrink(),
                const FcgVotingScreen(),
                const CreditScreen(),
              ],
            )
          : IndexedStack(
              index: navIndex,
              children: [
                showWallet ? const WalletScreen() : const SizedBox.shrink(),
                const CreditScreen(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}