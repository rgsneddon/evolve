import '../models/locale_config.dart';

abstract class LocaleStore {
  Future<LocaleConfig?> load();
  Future<void> save(LocaleConfig config);
}