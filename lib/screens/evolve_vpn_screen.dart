import 'package:evolve_tunnel/evolve_tunnel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../perc/providers/perc_wallet_provider.dart';
import '../providers/locale_provider.dart';

/// Evolve-only VPN tab — manual connect/disconnect, log-deletion status.
class EvolveVpnScreen extends StatefulWidget {
  const EvolveVpnScreen({super.key});

  @override
  State<EvolveVpnScreen> createState() => _EvolveVpnScreenState();
}

class _EvolveVpnScreenState extends State<EvolveVpnScreen> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);
    final wallet = context.watch<PercWalletProvider>();
    final tunnel = context.watch<EvolveTunnelController>();

    final connected = tunnel.state == VpnConnectState.connected;
    final busy = tunnel.state == VpnConnectState.connecting ||
        tunnel.state == VpnConnectState.disconnecting;
    final canTapConnect = tunnel.canConnect && !busy && !connected;
    final canTapDisconnect = connected && !busy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.t('vpn_title'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              EvolveTunnelController.freeUseDisclaimer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!wallet.hasAppAccess) ...[
              const SizedBox(height: 12),
              Text(
                strings.t('vpn_wallet_gate'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.amber.shade200),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canTapConnect ? tunnel.connectTunnel : null,
                    icon: const Icon(Icons.vpn_key),
                    label: Text(strings.t('vpn_connect')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        canTapDisconnect ? tunnel.disconnectTunnel : null,
                    icon: const Icon(Icons.vpn_key_off),
                    label: Text(strings.t('vpn_disconnect')),
                  ),
                ),
              ],
            ),
            if (tunnel.lastBanner != null) ...[
              const SizedBox(height: 12),
              MaterialBanner(
                content: Text(tunnel.lastBanner!),
                leading: const Icon(Icons.privacy_tip_outlined),
                actions: [
                  TextButton(
                    onPressed: tunnel.dismissBanner,
                    child: Text(strings.t('vpn_dismiss')),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              strings.t('vpn_status_heading'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    tunnel.processLog,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}