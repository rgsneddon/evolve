import 'dart:io';

import 'package:evolve/fcg/mishi/fcg_mishi_bridge_store.dart';
import 'package:evolve/fcg/mishi/fcg_mishi_permission.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evolve ↔ Mishi shared bridge (same contract as private mishi CLI).
void main() {
  late Directory tempDir;
  late FcgMishiBridgeStore evolveStore;
  late FcgMishiBridgeStore mishiStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mishi-bridge-int-');
    final resolver = () => FcgMishiBridgeStore.fileForTest(tempDir.path);
    evolveStore = FcgMishiBridgeStore(fileResolver: resolver);
    mishiStore = FcgMishiBridgeStore(fileResolver: resolver);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Mishi CLI path approves Evolve voter via encrypted bridge', () async {
    const password = 'mishi-integration-passphrase';
    final salt = PercAuth.generateSalt();
    final hash = PercAuth.hashPassword(password, salt);
    await evolveStore.upsertModeratorVerifier(
      username: 'mod_ainsdale',
      salt: salt,
      passwordHash: hash,
    );

    expect(
      await mishiStore.verifyModeratorPassword(
        loginAlias: 'MOD_Ainsdale',
        password: password,
      ),
      isTrue,
    );

    final addr = 'percpriv1${'d' * 40}';
    await evolveStore.requestVotingAccess(
      percAddress: addr,
      walletUsername: 'parishvoter',
      moderatorUsername: 'mod_ainsdale',
      wardLabel: 'Ainsdale',
      forumMonth: '2026-07',
    );

    await mishiStore.decidePermission(
      percAddress: addr,
      forumMonth: '2026-07',
      status: FcgMishiPermissionStatus.approved,
      moderatorUsername: 'mod_ainsdale',
    );

    expect(
      await evolveStore.hasApprovedVotingAccess(
        percAddress: addr,
        forumMonth: '2026-07',
      ),
      isTrue,
    );
  });
}