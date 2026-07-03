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

    final addresses = wallet.sendableAddresses;
    final toCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String? selectedAddress = addresses.isNotEmpty ? addresses.first : null;
    if (selectedAddress != null) {
      toCtrl.text = selectedAddress!;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(strings.t('wallet_send_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: toCtrl,
                decoration: InputDecoration(
                  labelText: strings.t('wallet_send_to'),
                  hintText: strings.t('wallet_send_to_hint'),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                onChanged: (_) => setState(() => selectedAddress = null),
              ),
              if (addresses.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedAddress,
                  decoration: InputDecoration(
                    labelText: strings.t('wallet_send_address_pick'),
                  ),
                  items: addresses
                      .map(
                        (addr) => DropdownMenuItem(
                          value: addr,
                          child: Text(
                            PercBeamPrivacy.shieldAddress(addr),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    selectedAddress = v;
                    toCtrl.text = v ?? '';
                  }),
                ),
              ],
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
                final to = toCtrl.text.trim().isNotEmpty
                    ? toCtrl.text
                    : (selectedAddress ?? '');
                await wallet.send(
                  toAddress: to,
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