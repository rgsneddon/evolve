import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/app_update_check.dart';

/// Latest-version advisory shown on the splash / loading screen.
class SplashVersionStatus extends StatelessWidget {
  const SplashVersionStatus({
    super.key,
    required this.info,
    required this.checking,
    required this.strings,
  });

  final AppUpdateInfo? info;
  final bool checking;
  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text(
              strings.t('splash_version_checking'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
          ],
        ),
      );
    }

    final status = info;
    if (status == null || !status.checkSucceeded) {
      return const SizedBox.shrink();
    }

    if (status.updateAvailable) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2A14).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Text(
                strings
                    .t('splash_version_update')
                    .replaceAll('{latest}', status.latestLabel)
                    .replaceAll('{current}', status.currentLabel),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFCD34D),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: strings.t('splash_version_update_action'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00D9C0),
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _openUpdate(status.updateUrl),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: Color(0xFF00D9C0)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              strings
                  .t('splash_version_latest')
                  .replaceAll('{version}', status.currentLabel),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}