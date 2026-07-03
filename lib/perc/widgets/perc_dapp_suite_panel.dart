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
            _FeaturedDappTile(
              spec: PercDappSpec.featuredDapp,
              strings: strings,
              onTap: () => PercDappNavigator.open(
                context,
                spec: PercDappSpec.featuredDapp,
                wallet: wallet,
                strings: strings,
                onSend: onSend,
                onReceive: onReceive,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth >= 520 ? 3 : 2;
                final gridApps = PercDappSpec.beamSuite
                    .where((d) => !d.featured)
                    .toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gridApps.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final spec = gridApps[index];
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

class _FeaturedDappTile extends StatelessWidget {
  const _FeaturedDappTile({
    required this.spec,
    required this.strings,
    required this.onTap,
  });

  final PercDappSpec spec;
  final AppLocalizations strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: spec.color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: spec.color.withOpacity(0.55), width: 1.5),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: spec.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(spec.icon, color: spec.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('wallet_dapp_featured_label'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: spec.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.t('wallet_dapp_ward_voting'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.description,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: spec.color, size: 28),
            ],
          ),
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