import 'dart:convert';

import 'package:http/http.dart' as http;

import '../perc_chain_constants.dart';
import 'perc_ledger.dart';
import 'perc_network_config.dart';
import 'perc_network_protocol.dart';

/// Internet rendezvous — wallets register public endpoints and relay ledgers.
class PercNetworkRendezvous {
  const PercNetworkRendezvous({http.Client? client}) : _client = client;

  final http.Client? _client;

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
  }) async {
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
            }),
          )
          .timeout(PercChainConstants.networkRequestTimeout);
    } catch (_) {}
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

  Future<({String username, String address})?> lookupAddress(
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
      final username = json['username'] as String?;
      final resolved = json['address'] as String? ?? address;
      if (resolved.isEmpty) return null;
      return (username: username ?? '', address: resolved);
    } catch (_) {
      return null;
    }
  }

  Future<PercLedger?> fetchRelayedLedger(String username) async {
    final base = await baseUrl();
    if (base == null) return null;
    final uri = Uri.parse(
      '$base/perc/rendezvous/ledger?username=${Uri.encodeComponent(username)}',
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