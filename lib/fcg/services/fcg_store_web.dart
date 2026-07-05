import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/fcg_models.dart';
import 'fcg_store.dart';

FcgStore createFcgStore() => FcgStoreWeb();

class FcgStoreWeb implements FcgStore {
  static const storageKey = 'evolve_fcg_ward_database_v1';

  @override
  Future<FcgWardDatabase?> load() async {
    final raw = html.window.localStorage[storageKey];
    if (raw == null || raw.trim().isEmpty) return null;
    return FcgWardDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(FcgWardDatabase database) async {
    html.window.localStorage[storageKey] =
        const JsonEncoder.withIndent('  ').convert(database.toJson());
  }
}