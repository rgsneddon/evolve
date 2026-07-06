import '../models/locale_config.dart';
import 'locale_store.dart';

class LocaleStoreMemory implements LocaleStore {
  LocaleConfig? _config;

  @override
  Future<LocaleConfig?> load() async => _config;

  @override
  Future<void> save(LocaleConfig config) async {
    _config = config;
  }
}