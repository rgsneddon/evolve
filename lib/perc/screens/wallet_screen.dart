import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../models/perc_transaction.dart';
import '../perc_chain_constants.dart';
import '../services/perc_currency.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/perc_faucet.dart';
import '../services/perc_faucet_cooldown.dart';
import '../services/perc_inflation.dart';
import '../services/perc_beam_privacy.dart';
import '../services/perc_block_timing.dart';
import '../services/perc_chronoflux_time_confirmations.dart';
import '../services/perc_send_receive_actions.dart';
import '../widgets/blockchain_launch_balloon.dart';
import '../widgets/perc_dapp_suite_panel.dart';
import '../widgets/wallet_creator_credit.dart';
import 'blockchain_explorer_screen.dart';

/// Evolve Wallet — Perccent accounts, scenario-driven chain, send/receive.
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
  bool _showTreasurySetup = false;
  bool _registerDefaultSet = false;
  PercWalletProvider? _wallet;
  Timer? _inflationTicker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = context.read<PercWalletProvider>();
    if (!identical(_wallet, wallet)) {
      _wallet?.removeListener(_onWalletUpdate);
      _wallet = wallet;
      _wallet!.addListener(_onWalletUpdate);
    }
    if (!_registerDefaultSet && wallet.isReady && !wallet.isLoggedIn) {
      _registerDefaultSet = true;
      _registerMode = !wallet.hasNonTreasuryAccounts;
    }
    _syncInflationTicker(wallet);
  }

  void _syncInflationTicker(PercWalletProvider wallet) {
    final needsTicker =
        wallet.isBlockchainLaunched && wallet.timeToNextInflation != null;
    if (needsTicker && _inflationTicker == null) {
      _inflationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _inflationTicker != null) {
      _inflationTicker!.cancel();
      _inflationTicker = null;
    }
  }

  void _onWalletUpdate() {
    if (!mounted || _wallet == null) return;
    if (_wallet!.takeBlockchainLaunchBalloon()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final strings = AppLocalizations.of(context.read<LocaleProvider>().config);
        showBlockchainLaunchBalloon(context, strings);
      });
    }
  }

  @override
  void dispose() {
    _inflationTicker?.cancel();
    _wallet?.removeListener(_onWalletUpdate);
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);
    _syncInflationTicker(wallet);

    if (!wallet.isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!wallet.isLoggedIn) {
      if (_showTreasurySetup && wallet.needsTreasuryPassword) {
        return _treasurySetup(wallet, strings, showBack: true);
      }
      return _loginRegister(wallet, strings);
    }

    return _walletHome(context, wallet, strings);
  }

  List<Widget> _treasuryRemainingLines(
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    final lines = <Widget>[
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

    if (wallet.isBlockchainLaunched) {
      final epoch = wallet.lastInflationEpoch;
      if (epoch != null) {
        lines.add(
          Text(
            strings
                .t('wallet_treasury_inflation_epoch')
                .replaceAll('{time}', PercInflation.formatEpoch(epoch)),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
          ),
        );
      }

      final inflationLine = wallet.treasuryPoolCritical
          ? strings.t('wallet_treasury_inflation_critical')
          : wallet.inflationReady
              ? strings.t('wallet_treasury_inflation_ready')
              : strings
                  .t('wallet_treasury_inflation_next')
                  .replaceAll(
                    '{wait}',
                    PercInflation.formatCountdown(wallet.timeToNextInflation!),
                  );
      lines.add(
        Text(
          inflationLine,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: wallet.treasuryPoolCritical
                ? const Color(0xFFFF8A65)
                : wallet.inflationReady
                    ? const Color(0xFF00D9C0)
                    : const Color(0xFF6C63FF),
          ),
        ),
      );
    }

    return lines;
  }

  Widget _appGateBanner(AppLocalizations strings) {
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      color: const Color(0xFF1E2433),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_app_gate_title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              strings.t('wallet_app_gate_note'),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9BA3B8),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
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
            if (!wallet.isBlockchainLaunched)
              Text(
                strings.t('wallet_blockchain_awaiting_launch'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFF8A65),
                  height: 1.4,
                ),
              )
            else
              ..._treasuryRemainingLines(wallet, strings),
          ],
        ),
      ),
    );
  }

  Widget _treasurySetup(
    PercWalletProvider wallet,
    AppLocalizations strings, {
    bool showBack = false,
  }) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                if (!wallet.hasAppAccess) _appGateBanner(strings),
                _publicTreasuryBanner(wallet, strings),
                Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _showTreasurySetup = false),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: Text(strings.t('wallet_back_to_sign_in')),
                            ),
                          ),
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
                WalletCreatorCredit(strings: strings),
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
                if (!wallet.hasAppAccess) _appGateBanner(strings),
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
                          _registerMode
                              ? strings.t('wallet_register_title')
                              : strings.t('wallet_login_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _registerMode
                              ? strings.t('wallet_register_note')
                              : strings.t('wallet_login_note'),
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
                            labelText: _registerMode
                                ? strings.t('wallet_choose_username')
                                : strings.t('wallet_username'),
                            hintText: _registerMode
                                ? strings.t('wallet_username_hint')
                                : null,
                            helperText: _registerMode
                                ? strings.t('wallet_username_rules')
                                : null,
                          ),
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
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
                        if (wallet.needsTreasuryPassword) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showTreasurySetup = true),
                            child: Text(strings.t('wallet_treasury_setup_link')),
                          ),
                        ],
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
                        onPressed: wallet.canSendFromSession
                            ? () => PercSendReceiveActions.showSend(
                                  context,
                                  wallet: wallet,
                                  strings: strings,
                                )
                            : wallet.isTreasuryAccount && wallet.isTreasurySendLocked
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          strings.t('wallet_treasury_send_locked'),
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(strings.t('wallet_send')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: wallet.canReceiveFromSession
                            ? () => PercSendReceiveActions.showReceive(
                                  context,
                                  wallet: wallet,
                                  strings: strings,
                                )
                            : null,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: Text(strings.t('wallet_receive')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _privacyCard(strings),
                const SizedBox(height: 12),
                _timeConfirmationsCard(strings),
                const SizedBox(height: 12),
                _evolutionaryChainCard(wallet, strings),
                const SizedBox(height: 12),
                PercDappSuitePanel(
                  wallet: wallet,
                  strings: strings,
                  onSend: () => PercSendReceiveActions.showSend(
                    context,
                    wallet: wallet,
                    strings: strings,
                  ),
                  onReceive: () => PercSendReceiveActions.showReceive(
                    context,
                    wallet: wallet,
                    strings: strings,
                  ),
                ),
                const SizedBox(height: 12),
                _treasuryCard(wallet, strings),
                const SizedBox(height: 12),
                _explorerLink(context, wallet, strings),
                const SizedBox(height: 12),
                _walletMeshCard(wallet, strings),
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
                WalletCreatorCredit(strings: strings),
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
              const SizedBox(height: 2),
              Text(
                strings.t('wallet_creator_credit'),
                style: const TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF7A8299),
                ),
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
              PercCurrency.brandLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
            ),
            Text(
              PercCurrency.denominationNote(),
              style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 8),
            Text(
              strings
                  .t('wallet_avg_block_time')
                  .replaceAll(
                    '{time}',
                    PercBlockTiming.formatAverage(wallet.averageTimePerBlock),
                  ),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            if (PercChainConstants.infiniteContinuumSupply) ...[
              const SizedBox(height: 4),
              Text(
                strings.t('wallet_supply_infinite'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6C63FF)),
              ),
            ],
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
            const SizedBox(height: 6),
            Text(
              strings
                  .t('wallet_treasury_cycle')
                  .replaceAll('{cycle}', '${wallet.treasuryCycle}'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF),
              ),
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
                  .replaceAll('{pct}', pct.toStringAsFixed(2)),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            if (wallet.isTreasurySendLocked) ...[
              const SizedBox(height: 6),
              Text(
                strings.t('wallet_treasury_offline_note'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.4),
              ),
            ],
            ..._treasuryRemainingLines(wallet, strings),
          ],
        ),
      ),
    );
  }

  Widget _privacyCard(AppLocalizations strings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text(
                  strings.t('wallet_privacy_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.t('wallet_privacy_note'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeConfirmationsCard(AppLocalizations strings) {
    final perms = PercChronofluxTimeConfirmations.allPermutations();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('wallet_time_confirmations_title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...perms.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${p.name}: ${PercChronofluxTimeConfirmations.formatInterval(p.interval)} → ${p.confirmationsToSettle} confirmation(s)',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _evolutionaryChainCard(
    PercWalletProvider wallet,
    AppLocalizations strings,
  ) {
    final chainId = wallet.evolutionaryChainId.isEmpty
        ? PercChainConstants.evolutionaryChainId
        : wallet.evolutionaryChainId;
    final principiaId = wallet.chronofluxPrincipiaId.isEmpty
        ? PercChainConstants.chronofluxPrincipiaId
        : wallet.chronofluxPrincipiaId;
    final versions = wallet.evolvedAppVersions.isEmpty
        ? wallet.currentAppVersion
        : wallet.evolvedAppVersions.join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFFFB347)),
                const SizedBox(width: 8),
                Text(
                  strings.t('wallet_evolution_title'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.t('wallet_evolution_note'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            const SizedBox(height: 8),
            Text(
              strings.t('wallet_evolution_chain').replaceAll('{id}', chainId),
              style: const TextStyle(fontSize: 11, color: Color(0xFF00D9C0)),
            ),
            Text(
              strings.t('wallet_evolution_principia').replaceAll('{id}', principiaId),
              style: const TextStyle(fontSize: 11, color: Color(0xFF7A8299)),
            ),
            Text(
              strings
                  .t('wallet_evolution_app')
                  .replaceAll('{version}', wallet.currentAppVersion),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            Text(
              strings
                  .t('wallet_evolution_epochs')
                  .replaceAll('{count}', '${wallet.evolutionEpoch}'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
            ),
            Text(
              strings
                  .t('wallet_evolution_versions')
                  .replaceAll('{versions}', versions),
              style: const TextStyle(fontSize: 10, color: Color(0xFF7A8299)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletMeshCard(PercWalletProvider wallet, AppLocalizations strings) {
    final peers = wallet.connectedPeerWallets;
    final peerLine = peers.isEmpty
        ? '—'
        : peers.join(', ');
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
            if (peers.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                strings.t('wallet_mesh_peers').replaceAll('{peers}', peerLine),
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A8299)),
              ),
            ],
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
        onTap: wallet.isBlockchainLaunched
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BlockchainExplorerScreen(),
                  ),
                );
              }
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.t('wallet_blockchain_awaiting_launch')),
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
              _rewardRow(
                strings.t('wallet_faucet_outcome'),
                reward.outcomeFractionLabel,
              ),
              _rewardRow(
                strings.t('wallet_faucet_total'),
                '${reward.total.displayFixed8} PERC',
              ),
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
              PercBeamPrivacy.shieldAddress(wallet.address),
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
      case PercTxKind.genesisRenewal:
        title = tx.memo ?? strings.t('wallet_tx_genesis');
      case PercTxKind.chronofluxMicroblock:
        title = tx.memo ?? 'Chronoflux microblock seal';
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

}