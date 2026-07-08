import 'dart:io';

import 'package:evolve/fcg/mishi/fcg_mishi_bridge_store.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_moderator.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors [FcgVotingScreen] gating at lines 74–110: non-moderators without
/// Mishi approval see the blocked title/body (moderator consult copy).
void main() {
  test(
    'non-approved voter sees blocking page describing portal and moderator consult',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('fcg-blocked-ui-');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final bridge = FcgMishiBridgeStore(
        fileResolver: () => FcgMishiBridgeStore.fileForTest(tempDir.path),
      );
      final fcg = FcgVotingProvider(
        store: FcgStoreMemory(),
        mishiBridge: bridge,
      );
      await fcg.initialize();

      const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');
      const addr = 'percpriv1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final approved = await fcg.refreshVotingAccess(
        walletAddress: addr,
        walletUsername: 'parishvoter',
        regionId: locale.regionId,
        locale: locale,
      );
      expect(approved, isFalse);
      expect(fcg.votingAccessApproved, isFalse);

      final strings = AppLocalizations.of(locale);
      final modUsername = fcg.moderatorUsernameForRegion(locale.regionId);
      final regionLabel = FcgModerator.regionLabel(locale.regionId);
      final blockedTitle = strings.t('fcg_voting_access_blocked_title');
      final blockedBody = strings
          .t('fcg_voting_access_blocked_body')
          .replaceAll('{mod}', modUsername)
          .replaceAll('{region}', regionLabel);

      expect(blockedTitle, contains('moderator approval'));
      expect(blockedBody, contains('Parish voting is gated'));
      expect(blockedBody, contains('Consult your ward moderator'));
      expect(blockedBody, contains('monthly forum'));
      expect(blockedBody, contains(modUsername));
    },
  );
}