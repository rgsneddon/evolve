import 'package:flutter/foundation.dart';

import 'perc_wallet_store.dart';
import 'perc_wallet_store_io.dart';
import 'perc_wallet_store_stub.dart';

PercWalletStore createPercWalletStore() {
  if (kIsWeb) return PercWalletStoreStub();
  return PercWalletStoreIo();
}