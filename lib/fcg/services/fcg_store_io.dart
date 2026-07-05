import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/fcg_models.dart';
import 'fcg_store.dart';

FcgStore createFcgStore() => FcgStoreIo();

class FcgStoreIo implements FcgStore {
  static const fileName = 'fcg_ward_database.json';

  @override
  Future<FcgWardDatabase?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    return FcgWardDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(FcgWardDatabase database) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(database.toJson()),
    );
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }
}