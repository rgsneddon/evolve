import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../models/perc_dapp_spec.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/perc_dapp_navigator.dart';

/// Beam Wallet `localapps` grid — identical structure in wallet and explorer.
class PercDappSuitePanel extends StatelessWidget {
  const PercDappSuitePanel({
    super.key,
    required this.wallet,
    required this.strings,
    required this.onSend,
    required this.onReceive,
  });

  final PercWalletProvider wallet;
  final AppLocalizations strings;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.apps_rounded, size: 18, color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                Text(
                  strings.t('wallet_dapp_suite_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.t('wallet_dapp_suite_subtitle'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth >= 520 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: PercDappSpec.beamSuite.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final spec = PercDappSpec.beamSuite[index];
                    return _DappTile(
                      spec: spec,
                      onTap: () {
                        if (spec.kind == PercDappKind.sendReceive) {
                          PercDappNavigator.openSendReceiveHub(
                            context,
                            wallet: wallet,
                            strings: strings,
                            onSend: onSend,
                            onReceive: onReceive,
                          );
                        } else {
                          PercDappNavigator.open(
                            context,
                            spec: spec,
                            wallet: wallet,
                            strings: strings,
                            onSend: onSend,
                            onReceive: onReceive,
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DappTile extends StatelessWidget {
  const _DappTile({required this.spec, required this.onTap});

  final PercDappSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: spec.color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(spec.icon, color: spec.color, size: 22),
              const Spacer(),
              Text(
                spec.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                spec.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Color(0xFF9BA3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}