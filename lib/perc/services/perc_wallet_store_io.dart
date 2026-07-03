import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'perc_ledger.dart';
import 'perc_wallet_store.dart';

PercWalletStore createPercWalletStore() => PercWalletStoreIo();

class PercWalletStoreIo implements PercWalletStore {
  static const fileName =
      'perc_evolve-chronoflux-principia-chain-1_ledger.json';
  static const legacyFileName = 'perc_wallet_ledger.json';

  @override
  Future<PercLedger?> load() async {
    final file = await _file();
    if (await file.exists()) {
      return _read(file);
    }
    final legacy = await _legacyFile();
    if (await legacy.exists()) {
      return _read(legacy);
    }
    return null;
  }

  @override
  Future<void> save(PercLedger ledger) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(ledger.toJson()),
    );
    final legacy = await _legacyFile();
    if (await legacy.exists()) {
      await legacy.delete();
    }
  }

  Future<PercLedger?> _read(File file) async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    return PercLedger.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<File> _legacyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$legacyFileName');
  }
}