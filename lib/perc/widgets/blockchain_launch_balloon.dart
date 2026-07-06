import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Celebration when the treasurer launches the chain on first sign-in.
Future<void> showBlockchainLaunchBalloon(
  BuildContext context,
  AppLocalizations strings,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(strings.t('wallet_blockchain_launch_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎈', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            strings.t('wallet_blockchain_launch_body'),
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.45),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(strings.t('wallet_blockchain_launch_ok')),
        ),
      ],
    ),
  );
}