import 'package:evolve/providers/locale_provider.dart';
import 'package:evolve/services/locale_store_memory.dart';

Future<LocaleProvider> createTestLocaleProvider() async {
  final locale = LocaleProvider(store: LocaleStoreMemory());
  await locale.initialize();
  return locale;
}