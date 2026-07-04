import 'dart:convert';

import 'package:http/http.dart' as http;

import '../perc_chain_constants.dart';
import 'perc_ledger.dart';
import 'perc_network_protocol.dart';

/// HTTP client for Perccent wallet-node sync.
class PercNetworkClient {
  const PercNetworkClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  static const _statusPath = '/perc/status';
  static const _ledgerPath = '/perc/ledger';

  Future<PercNetworkStatus?> fetchStatus(String endpoint) async {
    final uri = _resolve(endpoint, _statusPath);
    if (uri == null) return null;
    try {
      final response = await _http
          .get(uri)
          .timeout(PercChainConstants.networkRequestTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PercNetworkStatus.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<PercLedger?> fetchLedger(String endpoint) async {
    final uri = _resolve(endpoint, _ledgerPath);
    if (uri == null) return null;
    try {
      final response = await _http
          .get(uri)
          .timeout(PercChainConstants.networkRequestTimeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PercLedger.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<bool> pushLedger({
    required String endpoint,
    required PercLedger ledger,
  }) async {
    final uri = _resolve(endpoint, _ledgerPath);
    if (uri == null) return false;
    try {
      final response = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(ledger.toJson()),
          )
          .timeout(PercChainConstants.networkRequestTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Uri? _resolve(String endpoint, String path) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return null;
    final base = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return Uri.tryParse('$base$path');
  }
}