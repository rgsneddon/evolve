import 'perc_wallet_store.dart';
import 'perc_wallet_store_stub.dart'
    if (dart.library.io) 'perc_wallet_store_io.dart'
    if (dart.library.html) 'perc_wallet_store_web.dart' as platform;

PercWalletStore createPercWalletStore() => platform.createPercWalletStore();