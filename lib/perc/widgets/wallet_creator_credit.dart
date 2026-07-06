import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Creator credit shown on all wallet surfaces.
class WalletCreatorCredit extends StatelessWidget {
  const WalletCreatorCredit({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          strings.t('wallet_creator_credit'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Color(0xFF7A8299),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}