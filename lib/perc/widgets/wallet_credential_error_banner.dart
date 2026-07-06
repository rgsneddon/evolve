import 'package:flutter/material.dart';

/// Wrong username/password errors on wallet login forms.
class WalletCredentialErrorBanner extends StatefulWidget {
  const WalletCredentialErrorBanner({
    super.key,
    required this.errorKey,
    required this.message,
    this.onFadeComplete,
  });

  final String? errorKey;
  final String? message;
  final VoidCallback? onFadeComplete;

  static bool isCredentialError(String? key) =>
      key == 'wallet_err_unknown_account' ||
      key == 'wallet_err_invalid_password';

  @override
  WalletCredentialErrorBannerState createState() =>
      WalletCredentialErrorBannerState();
}

class WalletCredentialErrorBannerState
    extends State<WalletCredentialErrorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  String? _pinnedMessage;
  String? _pinnedKey;
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {
          _pinnedMessage = null;
          _pinnedKey = null;
          _fadingOut = false;
        });
        widget.onFadeComplete?.call();
      }
    });
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant WalletCredentialErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromWidget();
  }

  void _syncFromWidget() {
    if (WalletCredentialErrorBanner.isCredentialError(widget.errorKey) &&
        widget.message != null &&
        widget.message!.isNotEmpty) {
      if (widget.errorKey != _pinnedKey || widget.message != _pinnedMessage) {
        _pinnedKey = widget.errorKey;
        _pinnedMessage = widget.message;
        _fadingOut = false;
        _fade.value = 1.0;
      }
      return;
    }
    if (!WalletCredentialErrorBanner.isCredentialError(widget.errorKey)) {
      _pinnedKey = null;
      _pinnedMessage = null;
      _fadingOut = false;
      _fade.value = 0.0;
    }
  }

  /// Fade out the pinned credential warning (after click or cursor move).
  void dismiss() {
    if (_pinnedMessage == null || _fadingOut) return;
    _fadingOut = true;
    _fade.reverse();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _pinnedMessage;
    if (message == null) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _fade,
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Dismisses a [WalletCredentialErrorBanner] when the user clicks or moves
/// the pointer anywhere inside [child].
class WalletCredentialErrorScope extends StatelessWidget {
  const WalletCredentialErrorScope({
    super.key,
    required this.active,
    required this.onDismiss,
    required this.child,
  });

  final bool active;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onDismiss(),
      onPointerMove: (_) => onDismiss(),
      child: child,
    );
  }
}