import 'dart:convert';

import 'package:http/http.dart' as http;

import 'perc_network_config.dart';
import 'scenario_mirror_payout.dart';

/// Live mineperc `/api/stats` book. Empty on fetch failure (no mirror).
class PercPoolMinerBook {
  const PercPoolMinerBook._();

  static Future<List<Map<String, Object?>>> Function()? fetchOverride;

  static Future<List<Map<String, Object?>>> fetch({
    http.Client? client,
    String? url,
  }) async {
    if (fetchOverride != null) return fetchOverride!();
    final net = await PercNetworkConfig.load();
    final raw = (url ?? net.poolStatsUrl).trim();
    if (raw.isEmpty) return const [];
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return const [];
    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return const [];
      return minerBookFromPoolStats(jsonDecode(res.body));
    } catch (_) {
      return const [];
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
