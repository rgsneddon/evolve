import 'package:http/http.dart' as http;

import '../perc_chain_constants.dart';
import 'perc_network_config.dart';

/// Resolves an internet-reachable HTTP endpoint for this wallet node.
class PercPublicEndpoint {
  const PercPublicEndpoint({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  static bool isLoopbackOrPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '127.0.0.1' || h == '::1') return true;
    if (h.startsWith('10.')) return true;
    if (h.startsWith('192.168.')) return true;
    if (h.startsWith('169.254.')) return true;
    final parts = h.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]);
      if (second != null && second >= 16 && second <= 31) return true;
    }
    return false;
  }

  static bool isInternetEndpoint(String? endpoint) {
    if (endpoint == null || endpoint.trim().isEmpty) return false;
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || uri.host.isEmpty) return false;
    return !isLoopbackOrPrivateHost(uri.host);
  }

  Future<String?> resolveInternetEndpoint({required int port}) async {
    final config = await PercNetworkConfig.load();
    final override = config.publicEndpointOverride.trim();
    if (override.isNotEmpty) {
      return _normalize(override, port);
    }

    const envOverride = String.fromEnvironment('PERC_PUBLIC_ENDPOINT');
    if (envOverride.trim().isNotEmpty) {
      return _normalize(envOverride.trim(), port);
    }

    final publicIp = await _lookupPublicIp(config.publicIpLookupUrls);
    if (publicIp == null) return null;
    return 'http://$publicIp:$port';
  }

  Future<String?> _lookupPublicIp(List<String> urls) async {
    for (final url in urls) {
      try {
        final response = await _http
            .get(Uri.parse(url))
            .timeout(PercChainConstants.networkRequestTimeout);
        if (response.statusCode != 200) continue;
        final ip = response.body.trim().split('\n').first.trim();
        if (_looksLikePublicIp(ip)) return ip;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  bool _looksLikePublicIp(String ip) {
    if (ip.isEmpty || ip.contains(':')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return !isLoopbackOrPrivateHost(ip);
  }

  String _normalize(String endpoint, int port) {
    final trimmed = endpoint.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      if (uri.hasPort) return trimmed;
      return '${uri.scheme}://${uri.host}:$port';
    }
    return 'http://$trimmed:$port';
  }
}