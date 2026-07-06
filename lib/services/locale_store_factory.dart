import 'locale_store.dart';
import 'locale_store_stub.dart'
    if (dart.library.io) 'locale_store_io.dart'
    if (dart.library.html) 'locale_store_web.dart' as platform;

LocaleStore createLocaleStore() => platform.createLocaleStore();