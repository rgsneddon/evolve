import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Runtime Perccent network settings (internet rendezvous + public endpoint).
class PercNetworkConfig {
  const PercNetworkConfig({
    this.rendezvousUrl = '',
    this.seedUsername = '',
    this.networkGenesisRevision = 1,
    this.publicEndpointOverride = '',
    this.publicIpLookupUrls = const [
      'https://api.ipify.org',
      'https://ifconfig.me/ip',
    ],
  });

  final String rendezvousUrl;
  final String seedUsername;
  final int networkGenesisRevision;
  final String publicEndpointOverride;
  final List<String> publicIpLookupUrls;

  static PercNetworkConfig? _cached;

  static Future<PercNetworkConfig> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw =
          await rootBundle.loadString('assets/config/perc_network.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _cached = PercNetworkConfig(
        rendezvousUrl: (json['rendezvousUrl'] as String? ?? '').trim(),
        seedUsername: (json['seedUsername'] as String? ?? '').trim(),
        networkGenesisRevision:
            json['networkGenesisRevision'] as int? ?? 1,
        publicEndpointOverride:
            (json['publicEndpointOverride'] as String? ?? '').trim(),
        publicIpLookupUrls: (json['publicIpLookupUrls'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .where((u) => u.trim().isNotEmpty)
            .toList(),
      );
    } catch (_) {
      _cached = const PercNetworkConfig();
    }
    return _cached!;
  }

  static void resetForTest() => _cached = null;
}