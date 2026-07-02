import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists X OAuth tokens locally so sign-in survives app restarts.
class GrokSessionPersistence {
  const GrokSessionPersistence();

  static File? _cachedFile;

  Future<File> _resolveFile() async {
    if (_cachedFile != null) return _cachedFile!;

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationSupportDirectory();
      _cachedFile = File('${dir.path}${Platform.pathSeparator}grok_session.json');
      return _cachedFile!;
    }

    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      _cachedFile = File(
        '$appData${Platform.pathSeparator}EvolveChronoflux${Platform.pathSeparator}grok_session.json',
      );
      return _cachedFile!;
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    _cachedFile = File(
      '$home${Platform.pathSeparator}.evolve${Platform.pathSeparator}grok_session.json',
    );
    return _cachedFile!;
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final file = await _resolveFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}