import 'dart:convert';
import 'dart:io';

/// Persists X OAuth tokens locally so sign-in survives app restarts.
class GrokSessionPersistence {
  const GrokSessionPersistence();

  File get _file {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return File('$appData${Platform.pathSeparator}EvolveChronoflux${Platform.pathSeparator}grok_session.json');
    }
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return File('$home${Platform.pathSeparator}.evolve${Platform.pathSeparator}grok_session.json');
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final file = _file;
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final file = _file;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final file = _file;
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}