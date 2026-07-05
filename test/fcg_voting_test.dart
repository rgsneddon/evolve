import 'package:evolve/data/outcome_registry.dart';
import 'package:evolve/fcg/models/fcg_models.dart';
import 'package:evolve/fcg/providers/fcg_voting_provider.dart';
import 'package:evolve/fcg/services/fcg_moderator.dart';
import 'package:evolve/fcg/services/fcg_policy_analyzer.dart';
import 'package:evolve/fcg/services/fcg_store_memory.dart';
import 'package:evolve/models/analysis_mode.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/evolve_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await OutcomeRegistry.ensureLoaded();
  });

  test('seeds thirty empty voter slots', () {
    final slots = FcgWardDatabase.seedSlots();
    expect(slots.length, FcgWardDatabase.slotCount);
    expect(slots.first.slot, 1);
    expect(slots.last.slot, 30);
    expect(slots.every((s) => !s.isEnrolled), isTrue);
  });

  test('only whitelisted UK ward MOD usernames are moderators', () {
    expect(FcgModerator.isModeratorUsername('mod_ainsdale'), isTrue);
    expect(FcgModerator.isModeratorUsername('MOD_Ainsdale'), isTrue);
    expect(FcgModerator.isModeratorUsername('e05000932'), isTrue);
    expect(FcgModerator.isModeratorUsername('mod_not_a_real_ward'), isFalse);
    expect(FcgModerator.isModeratorUsername('e05000000'), isFalse);
    expect(FcgModerator.isModeratorUsername('alice'), isFalse);
  });

  test('moderator enrolls PERC addresses and wallets cast one vote each', () async {
    final addr1 = 'percpriv1${'a' * 40}';
    final addr2 = 'percpriv1${'b' * 40}';

    final store = FcgStoreMemory();
    final fcg = FcgVotingProvider(
      store: store,
      analyzer: const FcgPolicyAnalyzer(),
    );
    await fcg.initialize();

    final session = await fcg.initiateSession(
      moderatorUsername: 'mod_ainsdale',
      regionId: 'uk_ireland',
      policyQuestion: 'Should the parish adopt the flood levy?',
      runCohesion: true,
      runPercent: true,
      locale: const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );

    expect(session, isNotNull);
    expect(session!.slots.length, 30);

    final committed1 = await fcg.commitSlotAddress(
      slotNumber: 1,
      percAddress: addr1,
      moderatorUsername: 'mod_ainsdale',
    );
    final committed2 = await fcg.commitSlotAddress(
      slotNumber: 2,
      percAddress: addr2,
      moderatorUsername: 'mod_ainsdale',
    );
    expect(committed1, isTrue);
    expect(committed2, isTrue);
    expect(fcg.activeSession!.enrolledCount, 2);
    expect(fcg.canWalletVote(addr1), isTrue);
    expect(fcg.canWalletVote('percpriv1unknown'), isFalse);

    await fcg.castUserVote(
      walletAddress: addr1,
      vote: FcgVoteChoice.support,
    );
    await fcg.castUserVote(
      walletAddress: addr2,
      vote: FcgVoteChoice.oppose,
    );

    final active = fcg.activeSession!;
    expect(active.votesCast, 2);
    expect(active.tally[FcgVoteChoice.support], 1);
    expect(active.tally[FcgVoteChoice.oppose], 1);

    final reloaded = FcgVotingProvider(
      store: store,
      analyzer: const FcgPolicyAnalyzer(),
    );
    await reloaded.initialize();
    expect(reloaded.activeSession?.policyQuestion, session.policyQuestion);
    expect(reloaded.activeSession?.votesCast, 2);
    expect(reloaded.slotForWalletAddress(addr1)?.vote, FcgVoteChoice.support);
  });

  test('rejects duplicate PERC address in another slot', () async {
    final addr = 'percpriv1${'a' * 40}';

    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await fcg.initialize();
    await fcg.initiateSession(
      moderatorUsername: 'mod_ainsdale',
      regionId: 'uk_ireland',
      policyQuestion: 'Levy vote',
      runCohesion: true,
      runPercent: false,
      locale: LocaleConfig.defaults,
    );

    await fcg.commitSlotAddress(
      slotNumber: 3,
      percAddress: addr,
      moderatorUsername: 'mod_ainsdale',
    );
    final duplicate = await fcg.commitSlotAddress(
      slotNumber: 4,
      percAddress: addr,
      moderatorUsername: 'mod_ainsdale',
    );

    expect(duplicate, isFalse);
    expect(fcg.errorMessage, 'fcg_address_already_enrolled');
  });

  test('records scenario runs for narrative library', () async {
    final fcg = FcgVotingProvider(store: FcgStoreMemory());
    await fcg.initialize();

    const input = ScenarioInput(
      posedQuestion: 'Will parish cohesion improve under the levy?',
    );
    const locale = LocaleConfig(regionId: 'uk_ireland', languageCode: 'en');
    final result = const EvolveEngine().analyze(
      input,
      locale: locale,
      mode: AnalysisMode.cohesionScore,
    );

    await fcg.recordScenarioRun(
      input: input,
      locale: locale,
      mode: AnalysisMode.cohesionScore,
      result: result,
    );

    final narratives = fcg.cohesionNarrativesForRegion('uk_ireland');
    expect(narratives.length, 1);
    expect(narratives.first.narrativeExcerpt, isNotEmpty);
  });
}