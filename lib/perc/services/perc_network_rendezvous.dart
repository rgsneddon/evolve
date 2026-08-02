import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../perc_chain_constants.dart';
import 'perc_ledger.dart';
import 'perc_network_config.dart';
import 'perc_network_protocol.dart';

/// Sender relay PUT wake hint for a recipient wallet.
class InboundRelayHint {
  const InboundRelayHint({
    required this.senderUsername,
    required this.updatedAt,
  });

  final String senderUsername;
  final DateTime updatedAt;
}

/// Internet rendezvous — wallets register public endpoints and relay ledgers.
class PercNetworkRendezvous {
  const PercNetworkRendezvous({http.Client? client}) : _client = client;

  final http.Client? _client;

  @visibleForTesting
  static final Map<String, PercLedger> testRelayByUsername = {};

  @visibleForTesting
  static final Map<String, List<InboundRelayHint>> testHintsByRecipient = {};

  /// Process-local stage for seed-recovery (cleared on app restart / [clearProcessStageForTest]).
  /// Value is the raw transport string (may be composite suite ledger+meta).
  @visibleForTesting
  static final Map<String, String> testSeedRecoveries = {};

  /// Durable remote inject simulating rendezvous server storage after PUT.
  /// Survives [clearProcessStageForTest] so post-restart hub re-publish can
  /// fetch existing suite_seed_transport meta without a live HTTP server.
  @visibleForTesting
  static final Map<String, String> testDurableRemoteSeedRecoveries = {};

  @visibleForTesting
  static void resetForTest() {
    testRelayByUsername.clear();
    testHintsByRecipient.clear();
    testSeedRecoveries.clear();
    testDurableRemoteSeedRecoveries.clear();
  }

  /// Drop process-local stage only (simulates app restart; network durable remains).
  @visibleForTesting
  static void clearProcessStageForTest() {
    testSeedRecoveries.clear();
  }

  http.Client get _http => _client ?? http.Client();

  Future<String?> baseUrl() async {
    final config = await PercNetworkConfig.load();
    final fromConfig = config.rendezvousUrl.trim();
    if (fromConfig.isNotEmpty) return _trimSlash(fromConfig);

    const fromEnv = String.fromEnvironment('PERC_RENDEZVOUS_URL');
    if (fromEnv.trim().isNotEmpty) return _trimSlash(fromEnv.trim());

    return null;
  }

  Future<void> register(PercNetworkStatus status) async {
    final base = await baseUrl();
    if (base == null || status.endpoint == null) return;
    final uri = Uri.parse('$base/perc/rendezvous/register');
    await _postWithRetry(uri, jsonEncode(status.toJson()));
  }

  /// Lightweight address index — discoverable even before a full ledger relay lands.
  Future<void> publishAddress({
    required String address,
    String? username,
  }) async {
    final base = await baseUrl();
    if (base == null) return;
    final uri = Uri.parse('$base/perc/rendezvous/address');
    await _postWithRetry(
      uri,
      jsonEncode({
        'address': address,
        if (username != null && username.isNotEmpty) 'username': username,
      }),
    );
  }

  Future<void> unregister(String username) async {
    final base = await baseUrl();
    if (base == null) return;
    final uri = Uri.parse('$base/perc/rendezvous/unregister');
    try {
      await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username}),
          )
          .timeout(PercChainConstants.networkRequestTimeout);
    } catch (_) {}
  }

  Future<List<PercNetworkStatus>> fetchPeers() async {
    final base = await baseUrl();
    if (base == null) return const [];
    final uri = Uri.parse(
      '$base/perc/rendezvous/peers?chainId=${Uri.encodeComponent(PercChainConstants.evolutionaryChainId)}',
    );
    try {
      final response = await _getWithRetry(uri);
      if (response?.statusCode != 200) return const [];
      final json = jsonDecode(response!.body);
      if (json is! List) return const [];
      return json
          .whereType<Map>()
          .map((e) => PercNetworkStatus.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> relayLedger({
    required String username,
    required PercLedger ledger,
    String? notifyRecipientUsername,
  }) async {
    final recipient = notifyRecipientUsername?.trim();
    testRelayByUsername[username] = PercLedger.fromJson(ledger.toJson());
    if (recipient != null && recipient.isNotEmpty) {
      final hints = testHintsByRecipient.putIfAbsent(recipient, () => []);
      hints.removeWhere((h) => h.senderUsername == username);
      hints.add(
        InboundRelayHint(
          senderUsername: username,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    final base = await baseUrl();
    if (base == null) return;
    final uri = Uri.parse('$base/perc/rendezvous/ledger');
    try {
      await _http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'ledger': ledger.toJson(),
              if (recipient != null && recipient.isNotEmpty)
                'notifyRecipient': recipient,
            }),
          )
          .timeout(PercChainConstants.networkRequestTimeout);
    } catch (_) {}
  }

  /// Recent sender relay PUT hints for a recipient (burst-poll wake).
  Future<List<InboundRelayHint>> fetchInboundRelayHints({
    required String recipientUsername,
  }) async {
    final recipient = recipientUsername.trim();
    if (recipient.isEmpty) return const [];

    final testHints = testHintsByRecipient[recipient];
    if (testHints != null && testHints.isNotEmpty) {
      return List<InboundRelayHint>.from(testHints);
    }

    final base = await baseUrl();
    if (base == null) return const [];
    final uri = Uri.parse(
      '$base/perc/rendezvous/inbound-hints?username=${Uri.encodeComponent(recipient)}',
    );
    try {
      final response = await _getWithRetry(uri);
      if (response?.statusCode != 200) return const [];
      final json = jsonDecode(response!.body);
      if (json is! Map) return const [];
      final hints = json['hints'];
      if (hints is! List) return const [];
      return hints
          .whereType<Map>()
          .map((entry) {
            final sender = (entry['sender'] as String?)?.trim() ?? '';
            if (sender.isEmpty) return null;
            final updatedMs = entry['updatedAt'];
            final updatedAt = updatedMs is num
                ? DateTime.fromMillisecondsSinceEpoch(updatedMs.toInt(),
                    isUtc: true)
                : DateTime.now().toUtc();
            return InboundRelayHint(
              senderUsername: sender,
              updatedAt: updatedAt,
            );
          })
          .whereType<InboundRelayHint>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Whether the seed node currently sees the recipient wallet online (recent heartbeat).
  Future<bool> fetchRecipientOnlineOnSeed({
    String? username,
    String? address,
  }) async {
    final base = await baseUrl();
    if (base == null) return false;
    final params = <String, String>{};
    if (username != null && username.trim().isNotEmpty) {
      params['username'] = username.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      params['address'] = address.trim();
    }
    if (params.isEmpty) return false;
    final uri = Uri.parse('$base/perc/rendezvous/online').replace(
      queryParameters: params,
    );
    try {
      final response = await _getWithRetry(uri);
      if (response?.statusCode != 200) return false;
      final json = jsonDecode(response!.body);
      if (json is! Map) return false;
      return json['online'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<({String address})?> lookupAddress(
    String address,
  ) async {
    final base = await baseUrl();
    if (base == null) return null;
    final uri = Uri.parse(
      '$base/perc/rendezvous/address?address=${Uri.encodeComponent(address)}',
    );
    try {
      final response = await _getWithRetry(uri);
      if (response?.statusCode != 200) return null;
      final json = jsonDecode(response!.body);
      if (json is! Map) return null;
      final resolved = json['address'] as String? ?? address;
      if (resolved.isEmpty) return null;
      return (address: resolved);
    } catch (_) {
      return null;
    }
  }

  Future<void> publishSeedRecoveryEnvelope({
    required String fingerprint,
    required String envelopeB64,
    String? metaBlobB64,
  }) async {
    // Process stage + durable remote (simulates successful server PUT offline).
    testSeedRecoveries[fingerprint] = envelopeB64;
    testDurableRemoteSeedRecoveries[fingerprint] = envelopeB64;
    final base = await baseUrl();
    if (base == null) return;
    final uri = Uri.parse('$base/perc/rendezvous/seed-recovery');
    final body = <String, dynamic>{
      'fingerprint': fingerprint,
      'envelope': envelopeB64,
    };
    // Optional field for servers that store suite meta separately; composite
    // meta may already be embedded in envelopeB64 (suite_seed_transport).
    if (metaBlobB64 != null && metaBlobB64.isNotEmpty) {
      body['meta'] = metaBlobB64;
    }
    // Best-effort network; never hang seed export / hub re-publish offline.
    try {
      await _putWithRetry(uri, jsonEncode(body))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<String?> fetchSeedRecoveryEnvelope({
    required String fingerprint,
  }) async {
    // 1) Process-local stage (same app session).
    final staged = testSeedRecoveries[fingerprint];
    if (staged != null && staged.isNotEmpty) return staged;
    // 2) Durable remote inject (survives process-stage clear / app restart sim).
    final durable = testDurableRemoteSeedRecoveries[fingerprint];
    if (durable != null && durable.isNotEmpty) return durable;
    // 3) Live rendezvous HTTP.
    final base = await baseUrl();
    if (base == null) return null;
    final uri = Uri.parse(
      '$base/perc/rendezvous/seed-recovery?fingerprint=${Uri.encodeComponent(fingerprint)}',
    );
    try {
      final response = await _getWithRetry(uri);
      if (response?.statusCode != 200) return null;
      final json = jsonDecode(response!.body);
      if (json is! Map) return null;
      final envelope = json['envelope'] as String?;
      if (envelope == null || envelope.isEmpty) return null;
      // If server returned separate meta, re-wrap so Suite decode recovers KEYGEN.
      final meta = json['meta'] as String?;
      if (meta != null && meta.isNotEmpty) {
        try {
          // Avoid double-wrapping if envelope is already composite transport.
          final probe = utf8.decode(base64Decode(envelope));
          final map = jsonDecode(probe);
          if (map is Map && map['kind'] == 'suite_seed_transport') {
            return envelope;
          }
        } catch (_) {}
        final wrapped = base64Encode(
          utf8.encode(
            jsonEncode({
              'v': 1,
              'kind': 'suite_seed_transport',
              'ledger': envelope,
              'meta': meta,
            }),
          ),
        );
        return wrapped;
      }
      return envelope;
    } catch (_) {
      return null;
    }
  }

  Future<PercLedger?> fetchRelayedLedger({
    String? username,
    String? address,
  }) async {
    final user = username?.trim();
    if (user != null && user.isNotEmpty) {
      final testRelay = testRelayByUsername[user];
      if (testRelay != null) {
        return PercLedger.fromJson(testRelay.toJson());
      }
    }

    final base = await baseUrl();
    if (base == null) return null;
    final params = <String, String>{};
    if (username != null && username.trim().isNotEmpty) {
      params['username'] = username.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      params['address'] = address.trim();
    }
    if (params.isEmpty) return null;
    final uri = Uri.parse('$base/perc/rendezvous/ledger').replace(
      queryParameters: params,
    );
    try {
      final response = await _http
          .get(uri)
          .timeout(PercChainConstants.networkRequestTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ledgerJson = json['ledger'];
      if (ledgerJson is! Map) return null;
      return PercLedger.fromJson(Map<String, dynamic>.from(ledgerJson));
    } catch (_) {
      return null;
    }
  }

  String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Future<void> _postWithRetry(Uri uri, String body, {int attempts = 3}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final response = await _http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(PercChainConstants.networkRequestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (_) {}
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
      }
    }
  }

  Future<void> _putWithRetry(Uri uri, String body, {int attempts = 3}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final response = await _http
            .put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(PercChainConstants.networkRequestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (_) {}
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
      }
    }
  }

  Future<http.Response?> _getWithRetry(Uri uri, {int attempts = 3}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final response = await _http
            .get(uri)
            .timeout(PercChainConstants.networkRequestTimeout);
        if (response.statusCode == 200) return response;
      } catch (_) {}
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
      }
    }
    return null;
  }
}