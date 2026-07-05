import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../providers/locale_provider.dart';
import 'evolve_loading_screen.dart';
import 'evolve_shell_screen.dart';

/// Splash animation, background wallet boot, then analysis or registration.
class AppBootstrapScreen extends StatefulWidget {
  const AppBootstrapScreen({super.key, required this.walletProvider});

  final PercWalletProvider walletProvider;

  @visibleForTesting
  static Duration? minSplashDurationOverride;

  static Duration get _minSplashDuration =>
      minSplashDurationOverride ?? EvolveLoadingScreen.splashDuration;

  @override
  State<AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<AppBootstrapScreen> {
  bool _splashDone = false;
  bool _walletReady = false;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    if (widget.walletProvider.isReady) {
      _walletReady = true;
    } else {
      unawaited(_bootWallet(widget.walletProvider));
    }
    unawaited(_runSplash());
  }

  Future<void> _runSplash() async {
    await Future.delayed(AppBootstrapScreen._minSplashDuration);
    if (!mounted) return;
    setState(() => _splashDone = true);
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

  bool get _ready => _splashDone && _walletReady && _bootError == null;

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      final wallet = widget.walletProvider;
      return EvolveShellScreen(
        openRegistrationOnLaunch: !wallet.hasAppAccess,
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

    return EvolveLoadingScreen(duration: AppBootstrapScreen._minSplashDuration);
  }
}