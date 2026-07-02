import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'perc_ledger.dart';
import 'perc_wallet_store.dart';

class PercWalletStoreIo implements PercWalletStore {
  static const fileName = 'perc_wallet_ledger.json';

  @override
  Future<PercLedger?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return PercLedger.fromJson(json);
  }

  @override
  Future<void> save(PercLedger ledger) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(ledger.toJson()),
    );
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }
}