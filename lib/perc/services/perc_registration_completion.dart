import 'perc_chain_alignment.dart';

/// Pure decision for how registration completion should proceed after adoption.
class RegistrationCompletionAction {
  const RegistrationCompletionAction({
    required this.publishNow,
    required this.markAwaiting,
    required this.offlineHonest,
  });

  final bool publishNow;
  final bool markAwaiting;
  final bool offlineHonest;
}

class PercRegistrationCompletion {
  const PercRegistrationCompletion._();

  static RegistrationCompletionAction decide(PercRegistrationSeedAdoption adoption) {
    if (!adoption.seedReachable) {
      return const RegistrationCompletionAction(
        publishNow: false,
        markAwaiting: false,
        offlineHonest: true,
      );
    }
    if (!adoption.isAligned) {
      return const RegistrationCompletionAction(
        publishNow: false,
        markAwaiting: true,
        offlineHonest: false,
      );
    }
    return const RegistrationCompletionAction(
      publishNow: true,
      markAwaiting: false,
      offlineHonest: false,
    );
  }
}