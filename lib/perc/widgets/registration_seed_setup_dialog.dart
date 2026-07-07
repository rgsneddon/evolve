import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../providers/perc_wallet_provider.dart';

/// One-time 12-word seed offer shown immediately after new registration.
class RegistrationSeedSetupDialog extends StatefulWidget {
  const RegistrationSeedSetupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RegistrationSeedSetupDialog(),
    );
  }

  @override
  State<RegistrationSeedSetupDialog> createState() =>
      _RegistrationSeedSetupDialogState();
}

class _RegistrationSeedSetupDialogState
    extends State<RegistrationSeedSetupDialog> {
  List<String>? _words;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final strings =
        AppLocalizations.of(context.watch<LocaleProvider>().config);
    final generated = _words != null;

    return AlertDialog(
      scrollable: true,
      title: Text(strings.t('registration_seed_title')),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.t('registration_seed_one_chance_notice'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF59E0B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              generated
                  ? strings.t('registration_seed_write_down_note')
                  : strings.t('registration_seed_intro'),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 16),
            _wordGrid(strings),
            const SizedBox(height: 16),
            if (!generated)
              FilledButton(
                key: const Key('registration_seed_generate_button'),
                onPressed: _busy ? null : _generate,
                child: Text(strings.t('registration_seed_generate_action')),
              ),
            if (generated) ...[
              FilledButton(
                key: const Key('registration_seed_confirm_saved_button'),
                onPressed: _busy ? null : () => _finish(enableSeed: true),
                child: Text(strings.t('registration_seed_confirm_saved_action')),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              key: const Key('registration_seed_skip_button'),
              onPressed: _busy ? null : () => _finish(enableSeed: false),
              child: Text(strings.t('registration_seed_skip_action')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wordGrid(AppLocalizations strings) {
    final words = _words ?? List.filled(12, '');
    Widget box(int index) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2030),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A3348)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  words[index].isEmpty
                      ? strings.t('registration_seed_box_placeholder')
                      : words[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: words[index].isEmpty
                        ? FontWeight.w400
                        : FontWeight.w700,
                    color: words[index].isEmpty
                        ? const Color(0xFF4B5563)
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Table(
      children: List.generate(4, (row) {
        final base = row * 3;
        return TableRow(
          children: [box(base), box(base + 1), box(base + 2)],
        );
      }),
    );
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final wallet = context.read<PercWalletProvider>();
      final words = await wallet.generateRegistrationSeed();
      if (!mounted) return;
      setState(() => _words = words);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish({required bool enableSeed}) async {
    setState(() => _busy = true);
    try {
      final wallet = context.read<PercWalletProvider>();
      await wallet.completeRegistrationSeedSetup(enableSeed: enableSeed);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Blocks clipboard on generated seed words (write-down only).
class RegistrationSeedSetupDialogHost extends StatefulWidget {
  const RegistrationSeedSetupDialogHost({super.key, required this.child});

  final Widget child;

  @override
  State<RegistrationSeedSetupDialogHost> createState() =>
      _RegistrationSeedSetupDialogHostState();
}

class _RegistrationSeedSetupDialogHostState
    extends State<RegistrationSeedSetupDialogHost> {
  PercWalletProvider? _wallet;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wallet = context.read<PercWalletProvider>();
    if (!identical(_wallet, wallet)) {
      _wallet?.removeListener(_onWalletChanged);
      _wallet = wallet;
      _wallet!.addListener(_onWalletChanged);
    }
    _maybeShowDialog();
  }

  void _onWalletChanged() => _maybeShowDialog();

  void _maybeShowDialog() {
    if (!mounted || _dialogOpen) return;
    final wallet = _wallet;
    if (wallet == null || !wallet.pendingSeedSetup) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await RegistrationSeedSetupDialog.show(context);
      if (mounted) setState(() => _dialogOpen = false);
    });
  }

  @override
  void dispose() {
    _wallet?.removeListener(_onWalletChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}