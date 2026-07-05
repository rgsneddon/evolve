import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/perc_app_version.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../perc/widgets/wallet_auth_panel.dart';
import '../providers/locale_provider.dart';
import '../services/app_update_check.dart';
import '../widgets/evolve_banner_loop.dart';
import '../widgets/splash_version_status.dart';

/// Launch screen — looping article banner until the user signs in or enters.
class EvolveLoadingScreen extends StatefulWidget {
  const EvolveLoadingScreen({
    super.key,
    required this.walletReady,
    this.onAuthenticated,
    this.onEnterApp,
  });

  final bool walletReady;
  final VoidCallback? onAuthenticated;
  final VoidCallback? onEnterApp;

  @visibleForTesting
  static Duration? introDurationOverride;

  static Duration get introDuration =>
      introDurationOverride ?? const Duration(seconds: 3);

  static String get versionLabel =>
      'v${PercAppVersion.releaseOf(PercAppVersion.current)}';

  @override
  State<EvolveLoadingScreen> createState() => _EvolveLoadingScreenState();
}

class _EvolveLoadingScreenState extends State<EvolveLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _showAuth = false;
  bool _hadAccessAtBoot = false;
  bool _capturedBootAccess = false;
  PercWalletProvider? _wallet;
  bool _checkingUpdate = true;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    unawaited(_checkForUpdates());
    _intro = AnimationController(
      vsync: this,
      duration: EvolveLoadingScreen.introDuration,
    );
    if (EvolveLoadingScreen.introDuration == Duration.zero) {
      _showAuth = true;
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) setState(() => _showAuth = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = context.read<PercWalletProvider>();
    if (!_capturedBootAccess) {
      _hadAccessAtBoot = wallet.hasAppAccess;
      _capturedBootAccess = true;
    }
    if (!identical(_wallet, wallet)) {
      _wallet?.removeListener(_onWalletChanged);
      _wallet = wallet;
      _wallet!.addListener(_onWalletChanged);
    }
  }

  @override
  void didUpdateWidget(EvolveLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.walletReady &&
        (_intro.status == AnimationStatus.completed ||
            EvolveLoadingScreen.introDuration == Duration.zero)) {
      _showAuth = true;
    }
  }

  Future<void> _checkForUpdates() async {
    final info = await const AppUpdateChecker().check();
    if (!mounted) return;
    setState(() {
      _updateInfo = info;
      _checkingUpdate = false;
    });
  }

  void _onWalletChanged() {
    if (!mounted || !_showAuth || !widget.walletReady) return;
    final wallet = _wallet;
    if (wallet == null) return;
    if (wallet.hasAppAccess && !_hadAccessAtBoot) {
      widget.onAuthenticated?.call();
    }
  }

  @override
  void dispose() {
    _wallet?.removeListener(_onWalletChanged);
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppLocalizations.of(context.watch<LocaleProvider>().config);
    final wallet = context.watch<PercWalletProvider>();
    final authVisible = _showAuth && widget.walletReady;
    final authSlide = authVisible ? 0.0 : 28.0;
    final authOpacity = authVisible ? 1.0 : 0.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const EvolveBannerLoop(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66080B12),
                  Color(0xAA0A0E18),
                  Color(0xEE0A0E18),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF8B83FF),
                                    Color(0xFF6C63FF),
                                    Color(0xFF00D9C0),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'EVOLVE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Full Community Governance Suite',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                EvolveLoadingScreen.versionLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  color:
                                      Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                              SplashVersionStatus(
                                info: _updateInfo,
                                checking: _checkingUpdate,
                                strings: strings,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: authOpacity,
                          duration: const Duration(milliseconds: 450),
                          child: AnimatedSlide(
                            offset: Offset(0, authSlide / 120),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: _authSection(wallet, strings),
                            ),
                          ),
                        ),
                        if (!widget.walletReady)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  strings.t('splash_preparing_wallet'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9BA3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _authSection(PercWalletProvider wallet, AppLocalizations strings) {
    if (wallet.hasAppAccess) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.t('splash_signed_in_as')
                .replaceAll('{user}', wallet.loggedInUsername ?? ''),
            style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.onEnterApp ?? widget.onAuthenticated,
            child: Text(strings.t('splash_enter_app')),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141824).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: const WalletAuthPanel(
          compact: true,
          showCreatorCredit: false,
        ),
      ),
    );
  }
}