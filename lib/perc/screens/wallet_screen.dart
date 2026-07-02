import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/perc_faucet.dart';
import '../services/perc_faucet_cooldown.dart';
import 'blockchain_explorer_screen.dart';

/// Evolve Wallet — PERC accounts, scenario-driven chain, send/receive.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _registerMode = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);

    if (!wallet.isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (wallet.needsTreasuryPassword) {
      return _treasurySetup(wallet, strings);
    }

    if (!wallet.isLoggedIn) {
      return _loginRegister(wallet, strings);
    }

    return _walletHome(context, wallet, strings);
  }

  List<Widget> _treasuryRemainingLines(
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    return [
      Text(
        strings
            .t('wallet_treasury_remaining')
            .replaceAll('{amount}', wallet.treasuryRemaining.display),
        style: const TextStyle(fontSize: 11, color: Color(0xFF00D9C0)),
      ),
      Text(
        strings
            .t('wallet_treasury_pool')
            .replaceAll('{amount}', wallet.treasuryPool.displayFixed8),
        style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
      ),
    ];
  }

  Widget _publicTreasuryBanner(
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_treasury_title'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ..._treasuryRemainingLines(wallet, strings),
          ],
        ),
      ),
    );
  }

  Widget _treasurySetup(PercWalletProvider wallet, AppLocalizations strings) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                _publicTreasuryBanner(wallet, strings),
                Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          strings.t('wallet_treasury_setup_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('wallet_treasury_setup_note'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9BA3B8),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: strings.t('wallet_treasury_username'),
                          ),
                          controller: TextEditingController(
                            text: PercChainConstants.treasuryUsername,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: strings.t('wallet_password'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: strings.t('wallet_password_confirm'),
                          ),
                        ),
                        if (wallet.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            wallet.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            if (_passwordCtrl.text != _confirmCtrl.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Passwords do not match'),
                                ),
                              );
                              return;
                            }
                            wallet.setupTreasuryPassword(_passwordCtrl.text);
                          },
                          child: Text(strings.t('wallet_create_password')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginRegister(PercWalletProvider wallet, AppLocalizations strings) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                _publicTreasuryBanner(wallet, strings),
                Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          strings.t('wallet_login_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('wallet_login_note'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9BA3B8),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _usernameCtrl,
                          decoration: InputDecoration(
                            labelText: strings.t('wallet_username'),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: strings.t('wallet_password'),
                          ),
                        ),
                        if (wallet.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            wallet.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            if (_registerMode) {
                              wallet.register(
                                _usernameCtrl.text,
                                _passwordCtrl.text,
                              );
                            } else {
                              wallet.login(
                                _usernameCtrl.text,
                                _passwordCtrl.text,
                              );
                            }
                          },
                          child: Text(
                            _registerMode
                                ? strings.t('wallet_register')
                                : strings.t('wallet_sign_in'),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _registerMode = !_registerMode),
                          child: Text(
                            _registerMode
                                ? strings.t('wallet_sign_in')
                                : strings.t('wallet_register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _walletHome(
    BuildContext context,
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    final compact = MediaQuery.sizeOf(context).width < 520;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 12, compact ? 12 : 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(wallet, strings),
                const SizedBox(height: 16),
                _balanceCard(wallet, strings),
                const SizedBox(height: 12),
                _stakingCard(wallet, strings),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showSendDialog(context, wallet, strings),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(strings.t('wallet_send')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showReceiveDialog(context, wallet, strings),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: Text(strings.t('wallet_receive')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _treasuryCard(wallet, strings),
                const SizedBox(height: 12),
                _explorerLink(context, wallet, strings),
                const SizedBox(height: 12),
                _faucetCard(wallet, strings),
                const SizedBox(height: 12),
                _addressCard(context, wallet, strings),
                const SizedBox(height: 20),
                _transactionsHeader(strings),
                const SizedBox(height: 8),
                if (wallet.transactions.isEmpty)
                  _emptyTx(strings)
                else
                  ...wallet.transactions.take(20).map(
                        (tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _txTile(tx, wallet.loggedInUsername, strings),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(PercWalletProvider wallet, AppLocalizations strings) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF00D9C0)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('wallet_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                strings
                    .t('wallet_signed_in_as')
                    .replaceAll('{user}', wallet.loggedInUsername ?? ''),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: wallet.logout,
          child: Text(strings.t('wallet_logout')),
        ),
      ],
    );
  }

  Widget _balanceCard(PercWalletProvider wallet, AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_balance_label'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 8),
            Text(
              wallet.balance.displayFixed8,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00D9C0),
                height: 1,
              ),
            ),
            Text(
              PercChainConstants.currencySymbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
            ),
            if (wallet.statusMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                wallet.statusMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7AE582)),
              ),
            ],
            if (wallet.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                wallet.errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stakingCard(PercWalletProvider wallet, AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.t('wallet_staking_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('wallet_staking_note'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8), height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              strings
                  .t('wallet_staking_earned')
                  .replaceAll('{amount}', wallet.cumulativeStaking.displayFixed8),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF00D9C0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _treasuryCard(PercWalletProvider wallet, AppLocalizations strings) {
    final pct = (wallet.treasuryProgress * 100).clamp(0, 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_treasury_title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              strings.t('wallet_treasury_note'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.4),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: wallet.treasuryCapped ? 1 : wallet.treasuryProgress,
                minHeight: 8,
                backgroundColor: const Color(0xFF1A1F2E),
                color: const Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings
                  .t('wallet_treasury_minted')
                  .replaceAll('{minted}', wallet.treasuryMinted.display)
                  .replaceAll('{cap}', PercChainConstants.maxSupply.display)
                  .replaceAll('{pct}', pct.toStringAsFixed(2)),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            ..._treasuryRemainingLines(wallet, strings),
          ],
        ),
      ),
    );
  }

  Widget _explorerLink(
    BuildContext context,
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const BlockchainExplorerScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_outlined, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('wallet_explorer_link'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6C63FF),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings
                          .t('wallet_explorer_block_current')
                          .replaceAll('{height}', '${wallet.blockHeight}'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: Color(0xFF9BA3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faucetCard(PercWalletProvider wallet, AppLocalizations strings) {
    final reward = wallet.lastReward;
    final cooldown = wallet.faucetCooldownRemaining;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop_outlined, color: Color(0xFF00D9C0), size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.t('wallet_faucet_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('wallet_faucet_note'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8), height: 1.45),
            ),
            if (cooldown != null) ...[
              const SizedBox(height: 10),
              Text(
                strings
                    .t('wallet_faucet_cooldown')
                    .replaceAll('{wait}', PercFaucetCooldown.formatWait(cooldown)),
                style: const TextStyle(fontSize: 12, color: Color(0xFFFF8A65)),
              ),
            ],
            if (reward != null) ...[
              const SizedBox(height: 12),
              _rewardRow(strings.t('wallet_faucet_base'), reward.base.displayFixed8),
              if (reward.bonus.microUnits > 0)
                _rewardRow(
                  strings.t('wallet_faucet_bonus'),
                  '+${reward.bonus.displayFixed8} (${reward.percentChance.round()}%)',
                ),
              _rewardRow(strings.t('wallet_faucet_total'), reward.total.displayFixed8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rewardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFB8B5C8))),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00D9C0)),
          ),
        ],
      ),
    );
  }

  Widget _addressCard(
    BuildContext context,
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_address_label'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 8),
            SelectableText(
              wallet.address,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: wallet.address));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.t('wallet_address_copied'))),
                );
              },
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: Text(strings.t('wallet_copy_address')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsHeader(AppLocalizations strings) {
    return Text(
      strings.t('wallet_transactions_title'),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Color(0xFF9BA3B8),
      ),
    );
  }

  Widget _emptyTx(AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          strings.t('wallet_transactions_empty'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.45)),
        ),
      ),
    );
  }

  Widget _txTile(
    PercTransaction tx,
    String? viewer,
    AppLocalizations strings,
  ) {
    final isOut =
        tx.kind == PercTxKind.transfer && tx.fromUsername == viewer;
    final isIn = tx.kind == PercTxKind.scenarioReward ||
        tx.kind == PercTxKind.stakingReward ||
        (tx.kind == PercTxKind.transfer && tx.toUsername == viewer) ||
        (tx.kind == PercTxKind.treasuryEmission &&
            viewer == PercChainConstants.treasuryUsername);

    final accent = isOut
        ? const Color(0xFFFF8A65)
        : isIn
            ? const Color(0xFF00D9C0)
            : const Color(0xFF6C63FF);

    String title;
    switch (tx.kind) {
      case PercTxKind.treasuryEmission:
        title = strings.t('wallet_tx_treasury');
      case PercTxKind.scenarioReward:
        title = tx.scenarioLabel ?? strings.t('wallet_tx_reward');
      case PercTxKind.stakingReward:
        title = strings.t('wallet_tx_staking');
      case PercTxKind.transfer:
        title = isOut
            ? strings.t('wallet_tx_sent').replaceAll('{user}', tx.toUsername ?? '')
            : strings.t('wallet_tx_received')
                .replaceAll('{user}', tx.fromUsername ?? '');
    }

    final prefix = isOut ? '-' : '+';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    tx.timestamp.toLocal().toString().substring(0, 19),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
                  ),
                ],
              ),
            ),
            Text(
              '$prefix${tx.amount.displayFixed8}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSendDialog(
    BuildContext context,
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) async {
    final toCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('wallet_send_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toCtrl,
              decoration: InputDecoration(labelText: strings.t('wallet_send_to')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: strings.t('wallet_send_amount')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: memoCtrl,
              decoration: InputDecoration(labelText: strings.t('wallet_send_memo')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await wallet.send(
                toUsername: toCtrl.text,
                amountText: amountCtrl.text,
                memo: memoCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(strings.t('wallet_send_confirm')),
          ),
        ],
      ),
    );

    toCtrl.dispose();
    amountCtrl.dispose();
    memoCtrl.dispose();
  }

  Future<void> _showReceiveDialog(
    BuildContext context,
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('wallet_receive_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_receive_note'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 12),
            Text('Username', style: const TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(wallet.loggedInUsername ?? ''),
            const SizedBox(height: 10),
            Text(strings.t('wallet_address_label'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(wallet.address, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: wallet.loggedInUsername ?? ''));
              Navigator.pop(ctx);
            },
            child: Text(strings.t('wallet_copy_address')),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}