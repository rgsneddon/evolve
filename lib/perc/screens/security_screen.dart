import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../providers/perc_wallet_provider.dart';
import '../services/security_backup_files.dart';
import '../services/security_recovery_service.dart';

/// Backup export, file restore, and optional seed-phrase recovery.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    super.key,
    this.recoveryService,
  });

  /// Optional injected ports (widget tests supply a [BackupBytesResolver]).
  final SecurityRecoveryService? recoveryService;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _exportPassCtrl = TextEditingController();
  final _restorePassCtrl = TextEditingController();
  bool _obscureExport = true;
  bool _obscureRestore = true;

  SecurityRecoveryService get _recovery =>
      widget.recoveryService ?? SecurityRecoveryService.production();

  @override
  void dispose() {
    _exportPassCtrl.dispose();
    _restorePassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<PercWalletProvider>();
    final strings = AppLocalizations.of(context.watch<LocaleProvider>().config);

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('nav_security'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            strings.t('security_intro'),
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 20),
          _sectionTitle(strings.t('security_export_title')),
          Text(strings.t('security_export_note'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8))),
          const SizedBox(height: 8),
          TextField(
            key: const Key('security_export_pass_field'),
            controller: _exportPassCtrl,
            obscureText: _obscureExport,
            decoration: InputDecoration(
              labelText: strings.t('security_backup_passphrase'),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureExport ? Icons.visibility : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscureExport = !_obscureExport),
              ),
            ),
            enabled: wallet.isLoggedIn,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('security_export_button'),
            onPressed: wallet.isLoggedIn ? () => _exportBackup(wallet) : null,
            icon: const Icon(Icons.download_outlined),
            label: Text(strings.t('security_export_action')),
          ),
          const SizedBox(height: 24),
          _sectionTitle(strings.t('security_restore_title')),
          Text(strings.t('security_restore_note'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8))),
          const SizedBox(height: 8),
          TextField(
            key: const Key('security_restore_pass_field'),
            controller: _restorePassCtrl,
            obscureText: _obscureRestore,
            decoration: InputDecoration(
              labelText: strings.t('security_backup_passphrase'),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureRestore ? Icons.visibility : Icons.visibility_off),
                onPressed: () =>
                    setState(() => _obscureRestore = !_obscureRestore),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('security_restore_button'),
            onPressed: () => _restoreBackup(wallet),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(strings.t('security_restore_action')),
          ),
          if (wallet.localizedStatusMessage(
                  AppLocalizations.of(context.read<LocaleProvider>().config)) !=
              null) ...[
            const SizedBox(height: 16),
            Text(
              wallet.localizedStatusMessage(
                AppLocalizations.of(context.read<LocaleProvider>().config),
              )!,
              style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 12),
            ),
          ],
          if (wallet.localizedErrorMessage(
                  AppLocalizations.of(context.read<LocaleProvider>().config)) !=
              null) ...[
            const SizedBox(height: 8),
            Text(
              wallet.localizedErrorMessage(
                AppLocalizations.of(context.read<LocaleProvider>().config),
              )!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      );

  Future<void> _exportBackup(PercWalletProvider wallet) async {
    try {
      final bytes = wallet.exportEncryptedBackup(_exportPassCtrl.text);
      final name =
          'perccent-wallet-backup-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').split('.').first}.percbackup';
      if (kIsWeb) {
        await Clipboard.setData(
          ClipboardData(
            text: SecurityRecoveryService.encodeBackupForClipboard(bytes),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Backup copied — paste when restoring or save as .percbackup',
              ),
            ),
          );
        }
        return;
      }
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PERC Backup', extensions: ['percbackup', 'json']),
        ],
      );
      if (location == null) return;
      await writeBackupFile(location.path, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _restoreBackup(PercWalletProvider wallet) async {
    try {
      final bytes = await _recovery.resolveBackupBytes();
      if (bytes == null) return;
      await wallet.restoreFromEncryptedBackup(bytes, _restorePassCtrl.text);
    } catch (_) {}
  }

}