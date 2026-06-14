/// X / Grok connection state for optional live construal.
class GrokSession {
  const GrokSession({
    this.connected = false,
    this.premium = false,
    this.screenName = '',
    this.displayName = '',
    this.mock = false,
    this.oauthError = '',
  });

  final bool connected;
  final bool premium;
  final String screenName;
  final String displayName;
  final bool mock;
  final String oauthError;

  bool get canConstrue => connected && premium;

  factory GrokSession.fromJson(Map<String, dynamic> json) => GrokSession(
        connected: json['connected'] == true,
        premium: json['premium'] == true,
        screenName: '${json['screenName'] ?? ''}',
        displayName: '${json['displayName'] ?? ''}',
        mock: json['mock'] == true,
        oauthError: '${json['oauthError'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'connected': connected,
        'premium': premium,
        'screenName': screenName,
        'displayName': displayName,
        'mock': mock,
        if (oauthError.isNotEmpty) 'oauthError': oauthError,
      };

  GrokSession copyWith({
    bool? connected,
    bool? premium,
    String? screenName,
    String? displayName,
    bool? mock,
    String? oauthError,
  }) =>
      GrokSession(
        connected: connected ?? this.connected,
        premium: premium ?? this.premium,
        screenName: screenName ?? this.screenName,
        displayName: displayName ?? this.displayName,
        mock: mock ?? this.mock,
        oauthError: oauthError ?? this.oauthError,
      );
}

/// Optional field suggestions returned by Grok construal.
class GrokConstrualResult {
  const GrokConstrualResult({
    this.vortexText = '',
    this.shearText = '',
    this.resistanceText = '',
    this.flowText = '',
    this.provenance = 'offline',
  });

  final String vortexText;
  final String shearText;
  final String resistanceText;
  final String flowText;
  final String provenance;

  factory GrokConstrualResult.fromJson(Map<String, dynamic> json) =>
      GrokConstrualResult(
        vortexText: '${json['vortexText'] ?? ''}',
        shearText: '${json['shearText'] ?? ''}',
        resistanceText: '${json['resistanceText'] ?? ''}',
        flowText: '${json['flowText'] ?? ''}',
        provenance: '${json['provenance'] ?? 'grok'}',
      );

  bool get hasSuggestions =>
      vortexText.isNotEmpty ||
      shearText.isNotEmpty ||
      resistanceText.isNotEmpty ||
      flowText.isNotEmpty;
}