import 'package:evolve/perc/providers/perc_wallet_provider.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Concurrent wallet mesh status — connection count and sync only (no peer IDs).
class WalletMeshCard extends StatelessWidget {
  const WalletMeshCard({
    super.key,
    required this.wallet,
    required this.strings,
  });

  final PercWalletProvider wallet;
  final AppLocalizations strings;

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
                const Icon(Icons.device_hub, size: 18, color: Color(0xFF00D9C0)),
                const SizedBox(width: 8),
                Text(
                  strings.t('wallet_mesh_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              wallet.isWalletMeshComplete
                  ? strings
                      .t('wallet_mesh_connected')
                      .replaceAll('{count}', '${wallet.connectedWalletCount}')
                  : strings.t('wallet_mesh_incomplete'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 4),
            Text(
              wallet.isNetworkSynced
                  ? strings
                      .t('wallet_mesh_network_synced')
                      .replaceAll('{height}', '${wallet.networkBlockHeight}')
                      .replaceAll(
                        '{node}',
                        wallet.isWalletNodeOnline ? 'online' : 'offline',
                      )
                  : strings
                      .t('wallet_mesh_network_syncing')
                      .replaceAll('{height}', '${wallet.networkBlockHeight}'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF7A8299)),
            ),
            if (wallet.walletNodeEndpoint != null &&
                wallet.walletNodeEndpoint!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                strings
                    .t('wallet_endpoint_label')
                    .replaceAll('{endpoint}', wallet.walletNodeEndpoint ?? ''),
                style: const TextStyle(fontSize: 10, color: Color(0xFF5E6678)),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: wallet.isSyncingWallet ? null : wallet.syncWalletToSeed,
                icon: wallet.isSyncingWallet
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(
                  wallet.isSyncingWallet
                      ? strings.t('wallet_sync_syncing')
                      : strings.t('wallet_sync_button'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}