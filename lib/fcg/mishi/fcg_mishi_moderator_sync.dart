import '../../perc/services/perc_ledger.dart';
import '../services/fcg_moderator.dart';
import 'fcg_mishi_bridge_store.dart';

/// Pushes moderator salt+hash to the encrypted Mishi bridge after Evolve login.
Future<void> syncModeratorVerifierToMishiBridge({
  required PercLedger ledger,
  required String username,
  FcgMishiBridgeStore? bridge,
}) async {
  if (!FcgModerator.isModeratorUsername(username)) return;
  final account = ledger.account(username);
  if (account == null) return;
  final store = bridge ?? FcgMishiBridgeStore();
  await store.upsertModeratorVerifier(
    username: username,
    salt: account.salt,
    passwordHash: account.passwordHash,
  );
}