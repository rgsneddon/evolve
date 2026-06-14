import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_output.dart';
import '../models/analysis_mode.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import '../services/grok_auth_client.dart';
import '../services/grok_construal_service.dart';

import '../services/grok_oauth_launcher.dart';
import '../services/grok_proxy_launcher.dart';
import '../services/grok_heuristic_construal.dart';
import '../services/grok_service_config.dart';
import '../services/narrative_link_reader.dart';
import '../services/evolve_engine.dart';

class EvolveProvider extends ChangeNotifier {
  EvolveProvider({
    EvolveEngine? engine,
    NarrativeLinkReader? linkReader,
    GrokAuthClient? grokAuth,
    GrokConstrualService? grokConstrual,
  })  : _engine = engine ?? const EvolveEngine(),
        _linkReader = linkReader ?? const NarrativeLinkReader(),
        _grokAuth = grokAuth ?? const GrokAuthClient(),
        _grokConstrual = grokConstrual ?? const GrokConstrualService();

  final EvolveEngine _engine;
  final NarrativeLinkReader _linkReader;
  final GrokAuthClient _grokAuth;
  final GrokConstrualService _grokConstrual;

  AnalysisMode mode = AnalysisMode.percentChance;
  LocaleConfig locale = LocaleConfig.defaults;
  ScenarioInput input = const ScenarioInput();
  EvolveResult? result;
  bool isRunning = false;
  bool isFetchingLink = false;
  bool isConnectingGrok = false;
  bool grokConstrualEnabled = false;
  bool isConstruing = false;
  GrokSession grokSession = const GrokSession();
  Set<String> grokFilledFields = {};
  String? statusMessage;
  VoidCallback? _flushFields;
  Timer? _construeDebounce;
  int _construeGeneration = 0;
  int freshSession = 0;
  String _grokProxyBaseUrl = '';
  bool _grokConfigReady = false;
  bool _androidHeuristicFallback = false;
  String? grokPendingAuthorizeUrl;

  final Map<AnalysisMode, ScenarioInput> _savedInputs = {};
  final Map<AnalysisMode, EvolveResult?> _savedResults = {};

  AppLocalizations get strings => AppLocalizations.of(locale);
  LocalizedOutput get output => LocalizedOutput.of(locale);

  bool get grokConfigReady => _grokConfigReady;

  bool get _usesInBrowserGrok =>
      GrokServiceConfig.usesInBrowserConstrual(_grokProxyBaseUrl);

  bool get _usesHeuristicConstrual => _usesInBrowserGrok || _androidHeuristicFallback;

  /// True when a Grok proxy URL is configured (local or remote) for X OAuth + live construal.
  bool get grokProxyConfigured => _grokProxyBaseUrl.isNotEmpty;

  /// GitHub Pages / HTTPS web with no hosted proxy — uses in-browser heuristic construal.
  bool get grokUsesHeuristicWeb => _usesInBrowserGrok;

  /// Web or Android fallback — no live proxy / X OAuth required for construal.
  bool get grokUsesHeuristicMode => _usesHeuristicConstrual;

  /// Grok construal can run (live proxy or heuristic mode).
  bool get grokConstrualAvailable => grokProxyConfigured || grokUsesHeuristicMode;

  static const _heuristicWebSession = GrokSession(
    connected: true,
    premium: true,
    screenName: '@evolve_web',
    displayName: 'Evolve Web Heuristic',
    mock: true,
  );

  static const _heuristicAndroidSession = GrokSession(
    connected: true,
    premium: true,
    screenName: '@evolve_android',
    displayName: 'Evolve Android Heuristic',
    mock: true,
  );

  /// Resolves web proxy URL (compile-time, asset config, or local proxy probe).
  Future<void> initialize() async {
    await _ensureGrokProxyResolved();
    _grokConfigReady = true;
    notifyListeners();
  }

  /// Re-probes / starts the Grok proxy. Safe to call before sign-in.
  Future<bool> refreshGrokProxy() => _ensureGrokProxyReady();

  Future<bool> _ensureGrokProxyResolved() async {
    final resolved = await GrokServiceConfig.resolveProxyBaseUrlAsync(
      fallbackBaseUrl: _grokAuth.baseUrl,
    );
    final changed = resolved != _grokProxyBaseUrl;
    _grokProxyBaseUrl = resolved;
    if (changed) notifyListeners();
    return _grokProxyBaseUrl.isNotEmpty;
  }

  /// Resolves proxy URL (web) and starts embedded proxy (Windows/Android/desktop).
  Future<bool> _ensureGrokProxyReady() async {
    await _ensureGrokProxyResolved();
    if (_usesInBrowserGrok) {
      _androidHeuristicFallback = false;
      if (grokSession.canConstrue) return true;
      grokSession = _heuristicWebSession;
      notifyListeners();
      return true;
    }

    if (!kIsWeb) {
      try {
        await GrokProxyLauncher.instance.ensureRunning();
        if (GrokProxyLauncher.instance.isEmbedded) {
          _androidHeuristicFallback = false;
          final port = GrokProxyLauncher.instance.port;
          final local = 'http://127.0.0.1:$port';
          if (_grokProxyBaseUrl != local) {
            _grokProxyBaseUrl = local;
            notifyListeners();
          }
          return true;
        }
      } catch (_) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          return _activateAndroidHeuristicFallback();
        }
        return false;
      }
    }

    final reachable = await _activeGrokAuth.isProxyReachable();
    if (!reachable &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      return _activateAndroidHeuristicFallback();
    }
    return reachable;
  }

  bool _activateAndroidHeuristicFallback() {
    _androidHeuristicFallback = true;
    if (!grokSession.canConstrue) {
      grokSession = _heuristicAndroidSession;
    }
    notifyListeners();
    return true;
  }

  void _showGrokSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF1F2937),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  GrokAuthClient get _activeGrokAuth => GrokAuthClient(baseUrl: _grokProxyBaseUrl);

  GrokConstrualService get _activeGrokConstrual {
    final base = _grokProxyBaseUrl;
    if (base.isEmpty || base == _grokConstrual.baseUrl) return _grokConstrual;
    return GrokConstrualService(baseUrl: base);
  }

  String get vortexFocusHint => output.vortexFocusHint(locale.regionId);
  String get posedQuestionHint => output.vortexRegionExample(locale.regionId);
  String get regionFocusBanner => output.regionFocusBanner(locale.regionId);
  List<String> get missingConstructLabels => _missingConstructLabels();

  void registerFlush(VoidCallback? flush) => _flushFields = flush;
  void flushFields() => _flushFields?.call();

  /// Clear scenario inputs, results, and saved mode state for a new calculation.
  void startFresh() {
    _construeDebounce?.cancel();
    _construeGeneration++;

    mode = AnalysisMode.percentChance;
    input = const ScenarioInput();
    result = null;
    _savedInputs.clear();
    _savedResults.clear();
    grokFilledFields = {};
    isRunning = false;
    isFetchingLink = false;
    isConnectingGrok = false;
    isConstruing = false;
    statusMessage = null;
    freshSession++;
    notifyListeners();
  }

  Future<void> setGrokConstrual(bool enabled, BuildContext context) async {
    if (!enabled) {
      grokConstrualEnabled = false;
      isConnectingGrok = false;
      isConstruing = false;
      grokFilledFields = {};
      _construeDebounce?.cancel();
      statusMessage = strings.t('grok_offline_mode');
      notifyListeners();
      return;
    }

    grokConstrualEnabled = true;
    isConnectingGrok = true;
    statusMessage = strings.t('grok_starting_proxy');
    notifyListeners();

    final proxyReady = await _ensureGrokProxyReady();

    if (!proxyReady) {
      grokConstrualEnabled = false;
      isConnectingGrok = false;
      statusMessage = strings.t('grok_proxy_unreachable');
      notifyListeners();
      if (context.mounted) {
        _showGrokSnackBar(context, statusMessage!, isError: true);
        await _showGrokDialog(
          context,
          title: strings.t('grok_connect_title'),
          body: strings.t('grok_proxy_unreachable'),
        );
      }
      return;
    }

    if (_usesHeuristicConstrual) {
      grokConstrualEnabled = true;
      isConnectingGrok = false;
      statusMessage = _androidHeuristicFallback
          ? strings.t('grok_android_heuristic_ready')
          : strings.t('grok_web_heuristic_ready');
      notifyListeners();
      if (context.mounted) {
        _showGrokSnackBar(context, statusMessage!);
      }
      return;
    }

    if (context.mounted) {
      _showGrokSnackBar(context, strings.t('grok_proxy_detected'));
    }

    if (!grokConstrualEnabled) return;

    if (!grokSession.canConstrue) {
      if (!context.mounted) return;
      final ok = await _connectGrok(context);
      if (!grokConstrualEnabled) return;
      if (!ok) {
        grokConstrualEnabled = false;
        isConnectingGrok = false;
        notifyListeners();
        if (context.mounted && statusMessage != null) {
          _showGrokSnackBar(context, statusMessage!, isError: true);
        }
        return;
      }
    } else {
      isConnectingGrok = false;
    }

    grokConstrualEnabled = true;
    statusMessage = strings.t('grok_online_ready');
    notifyListeners();
  }

  /// Opens X OAuth via the Grok proxy and verifies Premium subscription.
  Future<void> connectXAccount(BuildContext context) async {
    isConnectingGrok = true;
    statusMessage = strings.t('grok_preparing_sign_in');
    notifyListeners();

    final proxyReady = await _ensureGrokProxyReady();

    if (!proxyReady) {
      isConnectingGrok = false;
      statusMessage = strings.t('grok_proxy_unreachable');
      notifyListeners();
      if (context.mounted) {
        _showGrokSnackBar(context, statusMessage!, isError: true);
        await _showGrokDialog(
          context,
          title: strings.t('grok_connect_title'),
          body: strings.t('grok_web_proxy_required'),
        );
      }
      return;
    }

    if (_usesHeuristicConstrual) {
      isConnectingGrok = false;
      statusMessage = _androidHeuristicFallback
          ? strings.t('grok_android_heuristic_ready')
          : strings.t('grok_web_heuristic_ready');
      grokConstrualEnabled = true;
      notifyListeners();
      if (context.mounted) {
        _showGrokSnackBar(context, statusMessage!);
      }
      return;
    }

    if (!grokConstrualEnabled) {
      grokConstrualEnabled = true;
      notifyListeners();
    }

    if (!context.mounted) {
      isConnectingGrok = false;
      notifyListeners();
      return;
    }
    final ok = await _connectGrok(context);
    if (!ok) {
      grokSession = const GrokSession();
      if (context.mounted && statusMessage != null) {
        _showGrokSnackBar(context, statusMessage!, isError: true);
      }
    } else if (context.mounted) {
      _showGrokSnackBar(
        context,
        strings.t('grok_connected_as').replaceAll('{user}', grokSession.screenName),
      );
    }
    notifyListeners();
  }

  /// User-triggered construal — flushes the form, then fills blank ω/σ/Iτ/Jμ from the full question.
  Future<void> beginGrokConstrue() async {
    flushFields();
    _construeDebounce?.cancel();

    if (!grokConstrualEnabled) {
      statusMessage = strings.t('grok_begin_requires_enable');
      notifyListeners();
      return;
    }
    if (input.posedQuestion.trim().isEmpty) {
      statusMessage = strings.t('status_need_posed_question');
      notifyListeners();
      return;
    }
    if (!grokSession.canConstrue) {
      statusMessage = strings.t('grok_premium_required');
      notifyListeners();
      return;
    }

    await _runConstrual();
  }

  Future<bool> _connectGrok(BuildContext context) async {
    isConnectingGrok = true;
    grokPendingAuthorizeUrl = null;
    statusMessage = strings.t('grok_preparing_sign_in');
    notifyListeners();

    try {
      final auth = _activeGrokAuth;
      final login = await auth.beginLogin();
      final authorize = login.authorizeUrl;
      final mockCallback = GrokAuthClient.isEmbeddedMockCallback(authorize);

      if (mockCallback) {
        statusMessage = strings.t('grok_mock_signing_in');
        notifyListeners();
        if (GrokProxyLauncher.instance.isEmbedded) {
          grokSession = await GrokProxyLauncher.instance.completeOAuthInProcess(
            'mock',
            'mock',
          );
        } else {
          grokSession = await auth.completeMockLogin();
        }
      } else {
        grokPendingAuthorizeUrl = authorize.toString();
        notifyListeners();
        if (!context.mounted) return false;
        final opened = await _promptOpenXSignIn(
          context,
          authorize,
          redirectUri: login.redirectUri,
        );
        if (!opened) {
          grokPendingAuthorizeUrl = null;
          statusMessage = strings.t('grok_connect_cancelled');
          return false;
        }
        statusMessage = strings.t('grok_connecting');
        notifyListeners();
        grokSession = await auth.waitForSession();
      }

      final session = grokSession;
      grokPendingAuthorizeUrl = null;

      if (!session.connected) {
        if (session.oauthError.isNotEmpty) {
          statusMessage = strings.t('grok_oauth_denied');
          if (context.mounted) {
            _showGrokSnackBar(context, session.oauthError, isError: true);
            await _showGrokDialog(
              context,
              title: strings.t('grok_connect_title'),
              body: '${strings.t('grok_oauth_portal_checklist')}\n\n${session.oauthError}',
            );
          }
        } else {
          statusMessage = strings.t('grok_connect_cancelled');
        }
        return false;
      }
      if (!session.premium) {
        statusMessage = strings.t('grok_premium_required');
        await _activeGrokAuth.logout();
        grokSession = const GrokSession();
        if (context.mounted) {
          _showGrokSnackBar(context, strings.t('grok_premium_required'), isError: true);
          await _showGrokDialog(
            context,
            title: strings.t('grok_connect_title'),
            body: strings.t('grok_premium_required'),
          );
        }
        return false;
      }

      statusMessage = session.mock
          ? strings
              .t('grok_mock_signed_in')
              .replaceAll('{user}', session.screenName)
          : strings
              .t('grok_connected_as')
              .replaceAll('{user}', session.screenName);
      return true;
    } on GrokAuthException {
      grokPendingAuthorizeUrl = null;
      statusMessage = strings.t('grok_connect_failed');
      if (context.mounted) {
        _showGrokSnackBar(context, strings.t('grok_connect_failed'), isError: true);
      }
      return false;
    } finally {
      isConnectingGrok = false;
      notifyListeners();
    }
  }

  /// DuckDuckGo and other browsers block popups — user must tap to open the link.
  Future<bool> _promptOpenXSignIn(
    BuildContext context,
    Uri authorize, {
    required String redirectUri,
  }) async {
    var opened = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(strings.t('grok_connect_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.t('grok_open_x_body')),
              if (redirectUri.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strings.t('grok_oauth_redirect_hint'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9BA3B8)),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  redirectUri,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE8ECF4),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SelectableText(
                authorize.toString(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.t('grok_dialog_cancel')),
          ),
          FilledButton.icon(
            onPressed: () {
              GrokOAuthLauncher.openAuthorizeUrl(authorize);
              opened = true;
              Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(strings.t('grok_open_x_tab')),
          ),
        ],
      ),
    );
    return opened;
  }

  Future<void> _showGrokDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.t('grok_dialog_ok')),
          ),
        ],
      ),
    );
  }

  /// Switch mode: persist current tab, restore prior tab input if previously posed.
  void setMode(AnalysisMode next) {
    if (next == mode) return;
    flushFields();
    _persistCurrentMode();

    mode = next;
    if (_savedInputs.containsKey(next) && _isPosed(_savedInputs[next]!)) {
      input = _savedInputs[next]!;
      result = _savedResults[next];
    } else {
      input = const ScenarioInput();
      result = null;
    }
    statusMessage = null;
    notifyListeners();
  }

  void setLocale(LocaleConfig config) {
    final regionChanged = config.regionId != locale.regionId;
    final languageChanged = config.languageCode != locale.languageCode;

    if (regionChanged) {
      final posed = input.posedQuestion.trim();
      final oldExample = output.vortexRegionExample(locale.regionId).trim();
      final newOut = LocalizedOutput.of(config);
      if (posed.isEmpty || posed == oldExample) {
        input = input.copyWith(
          posedQuestion: newOut.vortexRegionExample(config.regionId),
        );
      }
    }

    locale = config;

    if (result != null && (regionChanged || languageChanged)) {
      _reanalyze();
      _persistCurrentMode();
      statusMessage = strings.t('locale_updated');
    } else if (regionChanged || languageChanged) {
      _persistCurrentMode();
    }
    notifyListeners();
  }

  void updateInput(ScenarioInput i) {
    final posedChanged = i.posedQuestion.trim() != input.posedQuestion.trim();
    final clearedGrok = <String>{...grokFilledFields};
    for (final key in grokFilledFields) {
      if (i.constructText(key).trim() != input.constructText(key).trim()) {
        clearedGrok.remove(key);
      }
    }
    grokFilledFields = clearedGrok;

    if (posedChanged) {
      // New scenario — drop narrative link and prior outcome tied to the old question.
      input = i.copyWith(sourceUrl: '');
      result = null;
      grokFilledFields = {};
      statusMessage = null;
    } else {
      input = i;
    }
    notifyListeners();
  }

  Future<void> fetchNarrativeFromLink(String url) async {
    final trimmed = url.trim();
    if (NarrativeLinkReader.normalizeUrl(trimmed) == null) {
      statusMessage = strings.t('link_error_invalid');
      notifyListeners();
      return;
    }

    isFetchingLink = true;
    statusMessage = strings.t('link_fetching');
    notifyListeners();

    try {
      final content = await _linkReader.fetch(trimmed);
      input = input.copyWith(
        sourceUrl: content.url,
        topic: content.title,
        posedQuestion: ScenarioInput.clamp(content.narrative),
        vortexText: '',
      );
      result = null;
      grokFilledFields = {};
      _persistCurrentMode();
      statusMessage = strings.t('link_fetched');
      if (grokConstrualEnabled) {
        await _runConstrual();
      }
    } on NarrativeLinkException catch (e) {
      statusMessage = switch (e.code) {
        'empty' => strings.t('link_error_empty'),
        'blocked' => strings.t('link_error_blocked'),
        _ => strings.t('link_error_fetch'),
      };
    } catch (_) {
      statusMessage = strings.t('link_error_fetch');
    }

    isFetchingLink = false;
    notifyListeners();
  }

  Future<void> calculate() async {
    flushFields();
    if (mode == AnalysisMode.percentChance) {
      if (!input.hasQuestion) {
        statusMessage = strings.t('status_need_posed_question');
        notifyListeners();
        return;
      }
    } else if (!input.hasCohesionScenario) {
      statusMessage = strings.t('status_need_scenario');
      notifyListeners();
      return;
    }

    if (grokConstrualEnabled && !grokSession.canConstrue) {
      statusMessage = strings.t('grok_premium_required');
      grokConstrualEnabled = false;
      notifyListeners();
      return;
    }

    if (!grokConstrualEnabled && !input.hasAllConstructTexts) {
      statusMessage = strings
          .t('status_need_constructs')
          .replaceAll('{missing}', _missingConstructLabels().join(', '));
      notifyListeners();
      return;
    }

    isRunning = true;
    statusMessage = grokConstrualEnabled
        ? strings.t('status_calc_grok_pipeline')
        : strings.t('status_calc_pipeline');
    notifyListeners();

    try {
      var working = input;
      if (grokConstrualEnabled) {
        working = await _fetchAndApplyConstrual(working, persistToForm: true);
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
      _reanalyze(working);
      _persistCurrentMode();
      statusMessage = grokConstrualEnabled
          ? strings.t('grok_construal_applied')
          : strings.t('status_done');
    } on GrokAuthException {
      statusMessage = strings.t('grok_construal_failed');
      grokConstrualEnabled = false;
      grokSession = const GrokSession();
      grokFilledFields = {};
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  Future<void> _runConstrual() async {
    if (!grokConstrualEnabled || input.posedQuestion.trim().isEmpty) return;
    if (!grokSession.canConstrue) return;

    final generation = ++_construeGeneration;
    isConstruing = true;
    statusMessage = strings.t('grok_construing');
    notifyListeners();

    try {
      await _fetchAndApplyConstrual(input, persistToForm: true);
      if (generation != _construeGeneration) return;
      statusMessage = strings.t('grok_fields_populated');
    } on GrokAuthException {
      if (generation != _construeGeneration) return;
      statusMessage = strings.t('grok_construal_failed');
      grokConstrualEnabled = false;
      grokSession = const GrokSession();
      grokFilledFields = {};
    } finally {
      if (generation == _construeGeneration) {
        isConstruing = false;
        notifyListeners();
      }
    }
  }

  Future<ScenarioInput> _fetchAndApplyConstrual(
    ScenarioInput source, {
    required bool persistToForm,
  }) async {
    final suggestions = await _fetchConstrualSuggestions(source);

    final merged = _grokConstrual.applySuggestions(source, suggestions);
    if (persistToForm) {
      grokFilledFields = _detectGrokFilled(source, merged);
      input = merged;
      _persistCurrentMode();
    }
    return merged;
  }

  Future<GrokConstrualResult> _fetchConstrualSuggestions(ScenarioInput source) async {
    if (_usesHeuristicConstrual) {
      return GrokHeuristicConstrual.suggest(
        input: source,
        locale: locale,
        output: output,
      );
    }

    if (!grokSession.canConstrue) {
      throw GrokAuthException('premium_required');
    }

    if (!await _ensureGrokProxyReady()) {
      throw GrokAuthException('proxy_unreachable');
    }
    return _activeGrokConstrual.fetchSuggestions(
      input: source,
      locale: locale,
      output: output,
    );
  }

  Set<String> _detectGrokFilled(ScenarioInput before, ScenarioInput after) {
    final filled = <String>{...grokFilledFields};
    for (final key in ScenarioInput.constructKeys) {
      final wasBlank = before.constructText(key).trim().isEmpty;
      final nowFilled = after.constructText(key).trim().isNotEmpty;
      if (wasBlank && nowFilled) {
        filled.add(key);
      }
    }
    return filled;
  }

  List<String> _missingConstructLabels() => input.missingConstructKeys
      .map((key) => '${strings.constructName(key)} (${_constructSymbol(key)})')
      .toList();

  String _constructSymbol(String key) => switch (key) {
        'vortex' => 'ω',
        'shear' => 'σ',
        'resistance' => 'Iτ',
        'flow' => 'Jμ',
        _ => '',
      };

  void _reanalyze([ScenarioInput? source]) {
    result = _engine.analyze(source ?? input, mode: mode, locale: locale);
  }

  void _persistCurrentMode() {
    _savedInputs[mode] = input;
    _savedResults[mode] = result;
  }

  bool _isPosed(ScenarioInput i) =>
      i.posedQuestion.trim().isNotEmpty ||
      i.vortexText.trim().isNotEmpty ||
      i.topic.trim().isNotEmpty ||
      i.shearText.trim().isNotEmpty ||
      i.resistanceText.trim().isNotEmpty ||
      i.flowText.trim().isNotEmpty;
}