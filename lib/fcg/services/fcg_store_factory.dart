import 'fcg_store.dart';
import 'fcg_store_stub.dart'
    if (dart.library.io) 'fcg_store_io.dart'
    if (dart.library.html) 'fcg_store_web.dart' as platform;

FcgStore createFcgStore() => platform.createFcgStore();