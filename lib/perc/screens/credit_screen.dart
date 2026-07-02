import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../widgets/wallet_creator_credit.dart';

/// Credit and governance context for parish-ward consensus use.
class CreditScreen extends StatelessWidget {
  const CreditScreen({super.key});

  static const governanceUrl =
      'https://x.com/EvolveChronoflux/status/1';

  @override
  Widget build(BuildContext context) {
    final strings =
        AppLocalizations.of(context.watch<LocaleProvider>().config);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.t('credit_title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.t('credit_governance_intro'),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFFD8DCE8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Color(0xFFD8DCE8),
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '${strings.t('credit_governance_intro')} ${strings.t('credit_governance_link_label')} at ',
                              ),
                              TextSpan(
                                text: governanceUrl,
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => launchUrl(
                                        Uri.parse(governanceUrl),
                                        mode: LaunchMode.externalApplication,
                                      ),
                              ),
                              TextSpan(text: strings.t('credit_governance_link_suffix')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.t('credit_parish_note'),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF9BA3B8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.t('credit_cohesion_goal'),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00D9C0),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.t('credit_peace_goal'),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFFFFB347),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.t('credit_attribution_title'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('credit_attribution_body'),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF9BA3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                WalletCreatorCredit(strings: strings),
              ],
            ),
          ),
        ),
      ),
    );
  }
}