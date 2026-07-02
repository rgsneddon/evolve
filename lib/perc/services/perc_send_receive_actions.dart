import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../providers/perc_wallet_provider.dart';
import 'perc_beam_privacy.dart';

/// Send/receive dialogs — available to every registered wallet user.
class PercSendReceiveActions {
  const PercSendReceiveActions._();

  static Future<void> showSend(
    BuildContext context, {
    required PercWalletProvider wallet,
    required AppLocalizations strings,
  }) async {
    if (!wallet.canSendFromSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('wallet_treasury_send_locked'))),
      );
      return;
    }

    final peers = wallet.sendablePeers;
    final toCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String? selectedPeer = peers.isNotEmpty ? peers.first : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(strings.t('wallet_send_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (peers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedPeer,
                  decoration: InputDecoration(labelText: strings.t('wallet_send_to')),
                  items: peers
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    selectedPeer = v;
                    toCtrl.text = v ?? '';
                  }),
                )
              else
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
                final to = selectedPeer ?? toCtrl.text;
                await wallet.send(
                  toUsername: to,
                  amountText: amountCtrl.text,
                  memo: memoCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(strings.t('wallet_send_confirm')),
            ),
          ],
        ),
      ),
    );

    toCtrl.dispose();
    amountCtrl.dispose();
    memoCtrl.dispose();
  }

  static Future<void> showReceive(
    BuildContext context, {
    required PercWalletProvider wallet,
    required AppLocalizations strings,
  }) async {
    if (!wallet.canReceiveFromSession) return;

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
            Text(strings.t('wallet_username'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(wallet.loggedInUsername ?? ''),
            const SizedBox(height: 10),
            Text(strings.t('wallet_address_label'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            SelectableText(
              PercBeamPrivacy.shieldAddress(wallet.address),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: wallet.address));
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