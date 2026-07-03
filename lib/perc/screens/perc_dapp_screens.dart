import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../models/perc_side_chain.dart';
import '../perc_chain_constants.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/perc_currency.dart';
import '../services/perc_faucet_cooldown.dart';
import '../widgets/chronoflux_five_point_graph_panel.dart';
import '../widgets/wallet_creator_credit.dart';

Widget _chronofluxGraphStrip(PercWalletProvider wallet, AppLocalizations strings) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ChronofluxFivePointGraphPanel(
        wallet: wallet,
        strings: strings,
        compact: true,
      ),
    );

class PercSendReceiveHubScreen extends StatelessWidget {
  const PercSendReceiveHubScreen({
    super.key,
    required this.strings,
    required this.onSend,
    required this.onReceive,
  });

  final AppLocalizations strings;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_send_receive'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.t('wallet_dapp_send_receive_note'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: wallet.canSendFromSession ? onSend : null,
                icon: const Icon(Icons.send_rounded),
                label: Text(strings.t('wallet_send')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: wallet.canReceiveFromSession ? onReceive : null,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Text(strings.t('wallet_receive')),
              ),
              if (wallet.isTreasuryAccount && wallet.isTreasurySendLocked) ...[
                const SizedBox(height: 12),
                Text(
                  strings.t('wallet_treasury_send_locked'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFFB347)),
                ),
              ],
              const Spacer(),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

class PercSideChainScreen extends StatelessWidget {
  const PercSideChainScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final side = wallet.sideChain;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_side_chain'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow(strings.t('wallet_sidechain_id'), side.sideChainId),
              _infoRow(strings.t('wallet_sidechain_parent'), side.parentChainId),
              _infoRow(
                strings.t('wallet_sidechain_height'),
                '${side.microblockHeight}',
              ),
              _infoRow(
                strings.t('wallet_sidechain_pending'),
                '${side.pendingMicroblocks} / ${side.microblocksPerBlock}',
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: side.sealProgress.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: const Color(0xFF1A1F2E),
                  color: const Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 12),
              _infoRow(
                strings.t('wallet_sidechain_main_height'),
                '#${side.parentMainBlockHeight}',
              ),
              if (side.lastSealMainBlockIndex != null)
                _infoRow(
                  strings.t('wallet_sidechain_last_seal'),
                  '#${side.lastSealMainBlockIndex}',
                ),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

class PercGovernanceScreen extends StatelessWidget {
  const PercGovernanceScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_governance'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.t('wallet_staking_note'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              const SizedBox(height: 4),
              _infoRow(
                strings.t('wallet_staking_earned').replaceAll('{amount}', ''),
                wallet.cumulativeStaking.displayFixed8,
              ),
              _infoRow(strings.t('wallet_block_height'), '${wallet.blockHeight}'),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

class PercAnalysisGalleryScreen extends StatelessWidget {
  const PercAnalysisGalleryScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final reward = wallet.lastReward;
    final cooldown = wallet.faucetCooldownRemaining;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_analysis'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.t('wallet_faucet_note'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              if (reward != null) ...[
                const SizedBox(height: 16),
                _infoRow(
                  strings.t('wallet_faucet_title'),
                  '+${reward.total.displayFixed8} ${PercChainConstants.currencySymbol}',
                ),
              ],
              if (cooldown != null) ...[
                const SizedBox(height: 8),
                Text(
                  strings
                      .t('wallet_faucet_cooldown')
                      .replaceAll('{wait}', PercFaucetCooldown.formatWait(cooldown)),
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFFB347)),
                ),
              ],
              const Spacer(),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

class PercSideChainBridgeScreen extends StatelessWidget {
  const PercSideChainBridgeScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final side = wallet.sideChain;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_bridge'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.t('wallet_dapp_bridge_note'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              const SizedBox(height: 4),
              _bridgeRow(
                strings.t('wallet_dapp_side_chain'),
                side.sideChainId,
                side.pendingMicroblocks,
              ),
              const Icon(Icons.arrow_downward, color: Color(0xFF6C63FF)),
              _bridgeRow(
                strings.t('wallet_dapp_main_chain'),
                side.parentChainId,
                side.parentMainBlockHeight,
              ),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

class PercMeshBridgeScreen extends StatelessWidget {
  const PercMeshBridgeScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final peers = wallet.connectedPeerWallets;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_mesh'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                wallet.isWalletMeshComplete
                    ? strings
                        .t('wallet_mesh_connected')
                        .replaceAll('{count}', '${wallet.connectedWalletCount}')
                    : strings.t('wallet_mesh_incomplete'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              const SizedBox(height: 4),
              ...peers.map(
                (peer) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.link, color: Color(0xFF818CF8)),
                    title: Text(peer),
                    subtitle: Text(strings.t('wallet_dapp_mesh_peer')),
                  ),
                ),
              ),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

class PercNameServiceScreen extends StatelessWidget {
  const PercNameServiceScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final users = wallet.allRegisteredWallets;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_names'))),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length + 2,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _chronofluxGraphStrip(wallet, strings);
            }
            if (index == users.length + 1) {
              return WalletCreatorCredit(strings: strings);
            }
            final user = users[index - 1];
            final address = wallet.addressForUsername(user);
            return Card(
              child: ListTile(
                title: Text(user),
                subtitle: SelectableText(
                  address,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: address)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PercAssetMinterScreen extends StatelessWidget {
  const PercAssetMinterScreen({super.key, required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('wallet_dapp_minter'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.t('wallet_treasury_note'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9BA3B8)),
              ),
              const SizedBox(height: 12),
              _chronofluxGraphStrip(wallet, strings),
              const SizedBox(height: 4),
              _infoRow(
                strings
                    .t('wallet_treasury_minted')
                    .replaceAll('{minted}', wallet.treasuryMinted.display)
                    .replaceAll(
                      '{pct}',
                      '${(wallet.treasuryProgress * 100).toStringAsFixed(1)}',
                    ),
                '',
              ),
              _infoRow(
                strings.t('wallet_treasury_cycle').replaceAll('{cycle}', '${wallet.treasuryCycle}'),
                '',
              ),
              WalletCreatorCredit(strings: strings),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8))),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

Widget _bridgeRow(String label, String chainId, int value) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(chainId, style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8))),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}