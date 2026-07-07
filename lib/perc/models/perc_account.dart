import 'perc_amount.dart';
import 'perc_transaction.dart';

class PercAccount {
  PercAccount({
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.address,
    this.passwordSet = true,
    this.balance = PercAmount.zero,
    this.lastFaucetDrawAt,
    this.cumulativeStakingEarned = PercAmount.zero,
    this.scenarioBlockHeight = 0,
    this.passwordSwitchCommit,
    this.seedFingerprint,
    this.seedRecoveryEnvelope,
    List<PercTransaction>? transactions,
  }) : transactions = transactions ?? [];

  final String username;
  String passwordHash;
  String salt;
  final String address;
  bool passwordSet;
  PercAmount balance;
  DateTime? lastFaucetDrawAt;
  PercAmount cumulativeStakingEarned;
  int scenarioBlockHeight;
  String? passwordSwitchCommit;
  String? seedFingerprint;
  String? seedRecoveryEnvelope;
  final List<PercTransaction> transactions;

  Map<String, dynamic> toJson() => {
        'username': username,
        'passwordHash': passwordHash,
        'salt': salt,
        'address': address,
        'passwordSet': passwordSet,
        'balance': balance.toJson(),
        if (lastFaucetDrawAt != null)
          'lastFaucetDrawAt': lastFaucetDrawAt!.toIso8601String(),
        'cumulativeStakingEarned': cumulativeStakingEarned.toJson(),
        if (scenarioBlockHeight > 0) 'scenarioBlockHeight': scenarioBlockHeight,
        if (passwordSwitchCommit != null)
          'passwordSwitchCommit': passwordSwitchCommit,
        if (seedFingerprint != null) 'seedFingerprint': seedFingerprint,
        if (seedRecoveryEnvelope != null)
          'seedRecoveryEnvelope': seedRecoveryEnvelope,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  factory PercAccount.fromJson(Map<String, dynamic> json) => PercAccount(
        username: json['username'] as String,
        passwordHash: json['passwordHash'] as String,
        salt: json['salt'] as String,
        address: json['address'] as String,
        passwordSet: json['passwordSet'] as bool? ?? true,
        balance: json['balance'] is Map
            ? PercAmount.fromJson(json['balance'] as Map<String, dynamic>)
            : PercAmount(json['balance'] as int? ?? 0),
        lastFaucetDrawAt: json['lastFaucetDrawAt'] != null
            ? DateTime.parse(json['lastFaucetDrawAt'] as String)
            : null,
        cumulativeStakingEarned: json['cumulativeStakingEarned'] != null
            ? PercAmount.fromJson(
                json['cumulativeStakingEarned'] as Map<String, dynamic>)
            : PercAmount.zero,
        scenarioBlockHeight: json['scenarioBlockHeight'] as int? ?? 0,
        passwordSwitchCommit: json['passwordSwitchCommit'] as String?,
        seedFingerprint: json['seedFingerprint'] as String?,
        seedRecoveryEnvelope: json['seedRecoveryEnvelope'] as String?,
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((t) =>
                PercTransaction.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );
}