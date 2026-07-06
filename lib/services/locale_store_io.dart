import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/locale_config.dart';
import 'locale_store.dart';

LocaleStore createLocaleStore() => LocaleStoreIo();

class LocaleStoreIo implements LocaleStore {
  static const fileName = 'evolve_locale.json';

  @override
  Future<LocaleConfig?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final region = json['regionId'] as String?;
    final language = json['languageCode'] as String?;
    if (region == null || language == null) return null;
    return LocaleConfig(regionId: region, languageCode: language);
  }

  @override
  Future<void> save(LocaleConfig config) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'regionId': config.regionId,
        'languageCode': config.languageCode,
      }),
    );
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }
}