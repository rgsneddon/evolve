import 'dart:io';

import 'package:evolve/fcg/data/fcg_uk_ward_moderator_registry.dart';
import 'package:evolve/fcg/mishi/fcg_mishi_bridge_store.dart';
import 'package:evolve/fcg/mishi/fcg_mishi_crypto.dart';
import 'package:evolve/fcg/mishi/fcg_mishi_permission.dart';
import 'package:evolve/perc/services/perc_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late FcgMishiBridgeStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fcg-mishi-test-');
    store = FcgMishiBridgeStore(
      fileResolver: () => FcgMishiBridgeStore.fileForTest(tempDir.path),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('encrypt decrypt round-trips bridge payload', () {
    final payload = {
      'version': 1,
      'verifiers': <String, dynamic>{},
      'permissions': <dynamic>[],
    };
    final encrypted = FcgMishiCrypto.encryptJson(payload);
    final decoded = FcgMishiCrypto.decryptJson(encrypted);
    expect(decoded['version'], 1);
  });

  test('resolveLoginAlias accepts mod slug ONS and MOD_Ward label', () {
    expect(FcgUkWardModeratorRegistry.resolveLoginAlias('mod_ainsdale'), 'mod_ainsdale');
    expect(FcgUkWardModeratorRegistry.resolveLoginAlias('e05000932'), 'e05000932');
    expect(FcgUkWardModeratorRegistry.resolveLoginAlias('MOD_Ainsdale'), 'mod_ainsdale');
    expect(FcgUkWardModeratorRegistry.resolveLoginAlias('mod_fake_ward'), isNull);
  });

  test('moderator verifier export and password check', () async {
    const password = 'moderator-pass-phrase';
    final salt = PercAuth.generateSalt();
    final hash = PercAuth.hashPassword(password, salt);
    await store.upsertModeratorVerifier(
      username: 'mod_ainsdale',
      salt: salt,
      passwordHash: hash,
    );
    expect(
      await store.verifyModeratorPassword(
        loginAlias: 'MOD_Ainsdale',
        password: password,
      ),
      isTrue,
    );
    expect(
      await store.verifyModeratorPassword(
        loginAlias: 'mod_ainsdale',
        password: 'wrong-password',
      ),
      isFalse,
    );
  });

  test('request approve gate grants voting access for forum month', () async {
    const month = '2026-07';
    final addr = 'percpriv1${'a' * 40}';
    await store.requestVotingAccess(
      percAddress: addr,
      walletUsername: 'voter1',
      moderatorUsername: 'mod_ainsdale',
      wardLabel: 'Ainsdale',
      forumMonth: month,
    );
    expect(
      await store.hasApprovedVotingAccess(
        percAddress: addr,
        forumMonth: month,
      ),
      isFalse,
    );
    await store.decidePermission(
      percAddress: addr,
      forumMonth: month,
      status: FcgMishiPermissionStatus.approved,
      moderatorUsername: 'mod_ainsdale',
    );
    expect(
      await store.hasApprovedVotingAccess(
        percAddress: addr,
        forumMonth: month,
      ),
      isTrue,
    );
  });

  test('reject leaves voting access denied', () async {
    const month = '2026-08';
    final addr = 'percpriv1${'b' * 40}';
    await store.requestVotingAccess(
      percAddress: addr,
      walletUsername: 'voter2',
      moderatorUsername: 'mod_birkdale',
      wardLabel: 'Birkdale',
      forumMonth: month,
    );
    await store.decidePermission(
      percAddress: addr,
      forumMonth: month,
      status: FcgMishiPermissionStatus.rejected,
      moderatorUsername: 'mod_birkdale',
    );
    final perm = await store.permissionForAddress(
      percAddress: addr,
      forumMonth: month,
    );
    expect(perm?.status, FcgMishiPermissionStatus.rejected);
    expect(
      await store.hasApprovedVotingAccess(percAddress: addr, forumMonth: month),
      isFalse,
    );
  });
}