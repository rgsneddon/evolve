import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/perc/services/perc_ledger.dart';
import 'package:evolve/perc/services/perc_wallet_backup.dart';
import 'package:evolve/perc/services/perc_wallet_backup_clipboard.dart';

void main() {
  test('clipboard encode/decode round-trips encrypted backup bytes', () {
    final ledger = PercLedger.empty();
    ledger.ensureTreasuryAccount();
    ledger.register('clip', 'password123');

    final bytes = PercWalletBackup.exportEncrypted(
      ledger: ledger,
      passphrase: 'clipboard-pass',
    );
    final encoded = PercWalletBackupClipboard.encodeForClipboard(bytes);
    expect(encoded.startsWith(PercWalletBackupClipboard.webPrefix), isTrue);

    final decoded = PercWalletBackupClipboard.decode(encoded);
    expect(decoded, bytes);

    final restored = PercWalletBackup.importEncrypted(
      bytes: decoded!,
      passphrase: 'clipboard-pass',
    );
    expect(restored.account('clip'), isNotNull);
  });
}