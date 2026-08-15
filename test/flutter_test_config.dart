import 'dart:async';

import 'package:evolve/perc/services/perc_pool_miner_book.dart';
import 'package:evolve/providers/evolve_provider.dart';

/// Unit tests do not hit live mineperc. Inject a book through
/// [PercLedger.creditScenario] or [PercPoolMinerBook.fetchOverride].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PercPoolMinerBook.fetchOverride = () async => const [];
  EvolveProvider.skipEmbeddedGrokProxyForTests = true;
  await testMain();
}
