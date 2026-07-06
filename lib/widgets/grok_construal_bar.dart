import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/evolve_provider.dart';
import '../providers/locale_provider.dart';
import '../services/grok_oauth_launcher.dart';

/// Amber bar below locale selector: GROK CONSTRUE (Don't use / Use).
class GrokConstrualBar extends StatelessWidget {
  const GrokConstrualBar({super.key});

  static const _accent = Color(0xFFF59E0B);
  static const _webBlockedRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvolveProvider>();
    final s = AppLocalizations.of(context.watch<LocaleProvider>().config);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final enabled = provider.grokConstrualEnabled;
    final busy = provider.isConnectingGrok || provider.isConstruing;
    final signedIn = provider.grokSession.canConstrue;
    final heuristicMode = provider.grokUsesHeuristicMode;
    final proxyReady = provider.grokProxyConfigured;
    final needsSignIn =
        !heuristicMode && !signedIn && !busy && (enabled || proxyReady);
    final proxyMissing = provider.grokConfigReady && !proxyReady && !heuristicMode;
    final canBegin = enabled &&
        (signedIn || heuristicMode) &&
        provider.input.posedQuestion.trim().isNotEmpty;

    final switchRow = _buildGrokSwitchRow(context, provider, s, enabled);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.4)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleRow(s.t('grok_construe_label'), busy, switchRow),
                const SizedBox(height: 6),
                Text(
                  s.t('grok_bar_hint'),
                  style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF9BA3B8)),
                ),
                if (provider.grokSession.canConstrue) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.t('grok_connected_as').replaceAll('{user}', provider.grokSession.screenName),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
                  ),
                ],
                if (proxyMissing) ...[
                  const SizedBox(height: 8),
                  _proxyMissingRow(context, provider, s),
                ],
                if (needsSignIn) ...[
                  const SizedBox(height: 10),
                  _signInButton(context, provider, s),
                ],
                if (provider.grokPendingAuthorizeUrl != null) ...[
                  const SizedBox(height: 8),
                  _pendingSignInLink(context, provider, s),
                ],
                if (enabled && (signedIn || heuristicMode)) ...[
                  const SizedBox(height: 10),
                  _beginButton(context, provider, s, canBegin, busy),
                ],
                if (provider.statusMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    provider.statusMessage!,
                    style: TextStyle(
                      fontSize: 10,
                      color: busy ? _accent : const Color(0xFF9BA3B8),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: _accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t('grok_construe_label'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: _accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.t('grok_bar_hint'),
                        style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF9BA3B8)),
                      ),
                      if (provider.grokSession.canConstrue)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            s.t('grok_connected_as')
                                .replaceAll('{user}', provider.grokSession.screenName),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
                          ),
                        ),
                      if (provider.statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            provider.statusMessage!,
                            style: TextStyle(
                              fontSize: 10,
                              color: busy ? _accent : const Color(0xFF9BA3B8),
                            ),
                          ),
                        ),
                      if (proxyMissing)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _proxyMissingRow(context, provider, s),
                        ),
                      if (provider.grokPendingAuthorizeUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _pendingSignInLink(context, provider, s),
                        ),
                    ],
                  ),
                ),
                if (needsSignIn) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: _signInButton(context, provider, s),
                  ),
                ],
                if (enabled && (signedIn || heuristicMode)) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 200,
                    child: _beginButton(context, provider, s, canBegin, busy),
                  ),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                    ),
                  ),
                switchRow,
              ],
            ),
    );
  }

  Widget _buildGrokSwitchRow(
    BuildContext context,
    EvolveProvider provider,
    dynamic s,
    bool enabled,
  ) {
    const inactiveLabel = Color(0xFF9BA3B8);
    final webBlocked = kIsWeb && !provider.grokProxyConfigured;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.t('grok_no'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled && !webBlocked ? inactiveLabel : _accent,
          ),
        ),
        const SizedBox(width: 6),
        Switch(
          value: enabled && !webBlocked,
          onChanged: webBlocked
              ? null
              : (v) => provider.setGrokConstrual(v, context),
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? _accent : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _accent.withOpacity(0.35)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          s.t('grok_yes'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled && !webBlocked ? _accent : inactiveLabel,
          ),
        ),
      ],
    );

    if (!webBlocked) return row;

    return TooltipTheme(
      data: const TooltipThemeData(
        decoration: BoxDecoration(
          color: _webBlockedRed,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        waitDuration: Duration(milliseconds: 120),
        showDuration: Duration(seconds: 10),
      ),
      child: Tooltip(
        message: s.t('web_grok_inactive_notice'),
        preferBelow: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.forbidden,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _webBlockedRed,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 6),
                  content: Text(
                    s.t('web_grok_inactive_notice'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
            child: row,
          ),
        ),
      ),
    );
  }

  Widget _signInButton(BuildContext context, EvolveProvider provider, dynamic s) {
    return FilledButton.icon(
      onPressed: provider.isConnectingGrok
          ? null
          : () => provider.connectXAccount(context),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1DA1F2),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF1DA1F2).withOpacity(0.45),
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.login_rounded, size: 20),
      label: Text(
        s.t('grok_sign_in_x'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }

  Widget _beginButton(
    BuildContext context,
    EvolveProvider provider,
    dynamic s,
    bool canBegin,
    bool busy,
  ) {
    return FilledButton.icon(
      onPressed: canBegin && !busy ? () => provider.beginGrokConstrue() : null,
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _accent.withOpacity(0.35),
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.auto_fix_high, size: 20),
      label: Text(
        s.t('grok_begin_construe'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }

  Widget _proxyMissingRow(BuildContext context, EvolveProvider provider, dynamic s) {
    return Row(
      children: [
        Expanded(
          child: Text(
            s.t('grok_proxy_not_detected'),
            style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
          ),
        ),
        TextButton(
          onPressed: provider.isConnectingGrok
              ? null
              : () async {
                  final ok = await provider.refreshGrokProxy();
                  if (!context.mounted) return;
                  final msg = ok ? s.t('grok_proxy_detected') : s.t('grok_proxy_not_detected');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
          child: Text(s.t('grok_retry_proxy')),
        ),
      ],
    );
  }

  Widget _pendingSignInLink(BuildContext context, EvolveProvider provider, dynamic s) {
    final url = provider.grokPendingAuthorizeUrl!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: () => GrokOAuthLauncher.openAuthorizeUrl(Uri.parse(url)),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(s.t('grok_open_x_link')),
        ),
        if (kIsWeb)
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.t('grok_open_x_tab'))),
              );
            },
            child: const Icon(Icons.copy_rounded, size: 16),
          ),
      ],
    );
  }

  Widget _titleRow(String title, bool busy, Widget switchRow) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, color: _accent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _accent,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
          ),
        switchRow,
      ],
    );
  }
}