import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../perc/widgets/wallet_opening_screen.dart';
import '../providers/locale_provider.dart';
import 'evolve_shell_screen.dart';

/// Boots the wallet in the background and shows a loading screen if it takes >1s.
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key, required this.walletProvider});

  final PercWalletProvider walletProvider;

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  static const _slowOpenDelay = Duration(seconds: 1);

  bool _ready = false;
  bool _showOpening = false;
  Timer? _slowTimer;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    if (widget.walletProvider.isReady) {
      _ready = true;
      return;
    }
    _slowTimer = Timer(_slowOpenDelay, () {
      if (!_ready && mounted) setState(() => _showOpening = true);
    });
    unawaited(_bootWallet(widget.walletProvider));
  }

  Future<void> _bootWallet(PercWalletProvider wallet) async {
    try {
      await wallet.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bootError = e);
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const EvolveShellScreen();

    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);

    if (_bootError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.t('wallet_opening_error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _bootError = null;
                      _showOpening = false;
                    });
                    _slowTimer?.cancel();
                    _slowTimer = Timer(_slowOpenDelay, () {
                      if (!_ready && mounted) setState(() => _showOpening = true);
                    });
                    unawaited(_bootWallet(widget.walletProvider));
                  },
                  child: Text(strings.t('wallet_opening_retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showOpening) {
      return WalletOpeningScreen(strings: strings);
    }

    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}