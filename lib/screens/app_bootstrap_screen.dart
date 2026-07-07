import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../providers/locale_provider.dart';
import '../perc/widgets/registration_seed_setup_dialog.dart';
import 'evolve_loading_screen.dart';
import 'evolve_shell_screen.dart';

/// Looping banner splash, wallet boot, then user sign-in before the shell.
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key, required this.walletProvider});

  final PercWalletProvider walletProvider;

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _walletReady = false;
  bool _enteredApp = false;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    if (widget.walletProvider.isReady) {
      _walletReady = true;
    } else {
      unawaited(_bootWallet(widget.walletProvider));
    }
  }

  Future<void> _bootWallet(PercWalletProvider wallet) async {
    try {
      await wallet.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Wallet boot timed out after 20s',
        ),
      );
      if (!mounted) return;
      setState(() => _walletReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _bootError = e);
    }
  }

  void _enterApp() {
    setState(() => _enteredApp = true);
  }

  bool get _ready => _walletReady && _enteredApp && _bootError == null;

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const RegistrationSeedSetupDialogHost(
        child: EvolveShellScreen(openRegistrationOnLaunch: false),
      );
    }

    if (_bootError != null) {
      final strings =
          AppLocalizations.of(context.watch<LocaleProvider>().config);
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
                      _walletReady = widget.walletProvider.isReady;
                    });
                    if (!_walletReady) {
                      unawaited(_bootWallet(widget.walletProvider));
                    }
                  },
                  child: Text(strings.t('wallet_opening_retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RegistrationSeedSetupDialogHost(
      child: EvolveLoadingScreen(
        walletReady: _walletReady,
        onAuthenticated: _enterApp,
        onEnterApp: _enterApp,
      ),
    );
  }
}