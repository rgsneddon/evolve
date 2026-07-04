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
    try {
      await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(status.toJson()),
          )
          .timeout(PercChainConstants.networkRequestTimeout);
    } catch (_) {}
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
      final response = await _http
          .get(uri)
          .timeout(PercChainConstants.networkRequestTimeout);
      if (response.statusCode != 200) return const [];
      final json = jsonDecode(response.body);
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

  Future<({String username, String address})?> lookupAddress(
    String address,
  ) async {
    final base = await baseUrl();
    if (base == null) return null;
    final uri = Uri.parse(
      '$base/perc/rendezvous/address?address=${Uri.encodeComponent(address)}',
    );
    try {
      final response = await _http
          .get(uri)
          .timeout(PercChainConstants.networkRequestTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map) return null;
      final username = json['username'] as String?;
      final resolved = json['address'] as String? ?? address;
      if (username == null || username.isEmpty) return null;
      return (username: username, address: resolved);
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
}