import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localized_output.dart';
import '../models/analysis_mode.dart';
import '../perc/models/perc_faucet_credit_result.dart';
import '../models/grok_session.dart';
import '../models/locale_config.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import '../services/grok_auth_client.dart';
import '../services/grok_construal_service.dart';

import '../services/grok_oauth_flow.dart';
import '../services/grok_proxy_launcher.dart';
import '../widgets/x_oauth_connecting_dialog.dart';
import '../services/grok_heuristic_construal.dart';
import '../services/narrative_construct_construal.dart';
import '../services/grok_service_config.dart';
import '../services/narrative_link_reader.dart';
import '../services/evolve_engine.dart';
import '../services/evolve_engine_runner.dart';
import '../services/input_edit_guard.dart';
import '../services/pathway_construal_service.dart';

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

  /// Records completed analysis runs for FCG parish voting narratives.
  Future<void> Function({
    required ScenarioInput input,
    required LocaleConfig locale,
    required AnalysisMode mode,
    required EvolveResult result,
  })? scenarioRunRecorder;

  /// Credits Perccent faucet after percent-chance or social-cohesion calculate.
  Future<PercFaucetCreditResult?> Function({
    required AnalysisMode mode,
    required double outcomeScore,
    String? memo,
    double? continuumScs,
    double? vortexScs,
    double? shearScs,
    double? resistanceScs,
    double? flowScs,
  })? analysisRewardHandler;

  AnalysisMode mode = AnalysisMode.cohesionScore;
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

  /// Saved analysis for a mode (current tab or a prior tab run).
  EvolveResult? resultForMode(AnalysisMode mode) {
    if (mode == this.mode) return result;
    return _savedResults[mode];
  }

  bool get hasDualSavedResults =>
      resultForMode(AnalysisMode.percentChance) != null &&
      resultForMode(AnalysisMode.cohesionScore) != null;

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

  /// Resolves web proxy URL (compile-time, asset config, or local proxy probe).
  Future<void> initialize() async {
    await _ensureGrokProxyResolved();
    _grokConfigReady = true;
    notifyListeners();
    Future<void>.microtask(_restoreGrokSessionWhenReady);
  }

  Future<void> _restoreGrokSessionWhenReady() async {
    try {
      await _ensureGrokProxyResolved();
      if (_grokProxyBaseUrl.isEmpty || _usesHeuristicConstrual) return;
      final ready = await _ensureGrokProxyReady();
      if (!ready) return;
      await _syncGrokSessionFromProxy().timeout(const Duration(seconds: 12));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _syncGrokSessionFromProxy() async {
    try {
      if (GrokProxyLauncher.instance.isEmbedded) {
        final embedded = GrokProxyLauncher.instance.embeddedSession;
        if (embedded.canConstrue) {
          grokSession = embedded;
          return;
        }
      }
      final status = await _activeGrokAuth.fetchStatus();
      if (status.canConstrue) {
        grokSession = status;
      }
    } catch (_) {}
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
        if (await _activeGrokAuth.isProxyReachable()) {
          return true;
        }
        if (defaultTargetPlatform == TargetPlatform.android) {
          return _activateAndroidHeuristicFallback();
        }
        return false;
      }
      if (await _activeGrokAuth.isProxyReachable()) {
        return true;
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
    notifyListeners();
    return true;
  }

  @visibleForTesting
  bool activateAndroidHeuristicFallbackForTest() =>
      _activateAndroidHeuristicFallback();

  String _heuristicReadyMessage() {
    if (_androidHeuristicFallback) {
      return strings.t('grok_android_heuristic_ready');
    }
    if (_usesInBrowserGrok) {
      return strings.t('grok_web_heuristic_ready');
    }
    return strings.t('grok_online_ready');
  }

  void _finishHeuristicActivation(
    BuildContext context, {
    bool showSnackBar = true,
  }) {
    grokConstrualEnabled = true;
    isConnectingGrok = false;
    statusMessage = _heuristicReadyMessage();
    notifyListeners();
    if (showSnackBar && context.mounted) {
      _showGrokSnackBar(context, statusMessage!);
    }
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

  String get regionFocusBanner => output.regionFocusBanner(locale.regionId);
  List<String> get missingConstructLabels => _missingConstructLabels();

  void registerFlush(VoidCallback? flush) => _flushFields = flush;
  void flushFields() => _flushFields?.call();

  /// Clear scenario inputs, results, and saved mode state for a new calculation.
  void startFresh() {
    _construeDebounce?.cancel();
    _construeGeneration++;

    mode = AnalysisMode.cohesionScore;
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
    if (enabled) {
      await _ensureGrokProxyResolved();
      if (kIsWeb && !grokProxyConfigured) {
        statusMessage = strings.t('web_grok_inactive_notice');
        notifyListeners();
        return;
      }
    }

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
      _finishHeuristicActivation(context);
      return;
    }

    if (context.mounted) {
      _showGrokSnackBar(context, strings.t('grok_proxy_detected'));
    }

    if (!grokConstrualEnabled) return;

    if (!grokSession.canConstrue) {
      if (!context.mounted) return;
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          GrokProxyLauncher.instance.isEmbedded &&
          GrokProxyLauncher.instance.usesMockConfig) {
        _activateAndroidHeuristicFallback();
        _finishHeuristicActivation(context);
        return;
      }
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
      statusMessage = _heuristicReadyMessage();
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
    if (input.scenarioQuery.trim().isEmpty) {
      statusMessage = strings.t('status_need_posed_question');
      notifyListeners();
      return;
    }
    if (!grokSession.canConstrue && !_usesHeuristicConstrual) {
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
      if (login.mock &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        _activateAndroidHeuristicFallback();
        _finishHeuristicActivation(context);
        return true;
      }

      final authorize = login.authorizeUrl;
      final mockCallback =
          login.mock || GrokAuthClient.isEmbeddedMockCallback(authorize);

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
        statusMessage = strings.t('grok_connecting');
        notifyListeners();
        grokSession = await _awaitXOAuthConnection(
          context,
          authorize: authorize,
          auth: auth,
          redirectUri: login.redirectUri,
          clientId: login.clientId,
        );
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
      if (session.mock) {
        statusMessage = strings.t('grok_mock_mode_blocked');
        await _activeGrokAuth.logout();
        grokSession = const GrokSession();
        if (context.mounted) {
          _showGrokSnackBar(context, statusMessage!, isError: true);
          await _showGrokDialog(
            context,
            title: strings.t('grok_connect_title'),
            body: strings.t('grok_mock_mode_blocked'),
          );
        }
        return false;
      }

      statusMessage = strings
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

  /// Opens X OAuth in the browser, polls the proxy, and auto-dismisses when connected.
  Future<GrokSession> _awaitXOAuthConnection(
    BuildContext context, {
    required Uri authorize,
    required GrokAuthClient auth,
    String redirectUri = '',
    String clientId = '',
  }) async {
    final useMobileAuth = GrokOAuthFlow.usesMobileDeepLink;
    final sessionFuture = useMobileAuth
        ? GrokOAuthFlow.completeAuthorization(
            authorizeUrl: authorize,
            auth: auth,
          )
        : auth.waitForSession();
    var result = const GrokSession();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => XOAuthConnectingDialog(
        authorize: authorize,
        redirectUri: redirectUri,
        clientId: clientId,
        sessionFuture: sessionFuture,
        useMobileAuth: useMobileAuth,
        title: strings.t('grok_connect_title'),
        body: useMobileAuth
            ? strings.t('grok_connecting_mobile')
            : strings.t('grok_connecting'),
        redirectHint: useMobileAuth ? strings.t('grok_oauth_redirect_hint') : '',
        cancelLabel: strings.t('grok_dialog_cancel'),
        onFinished: (session, tab) {
          result = session;
          tab?.close();
        },
      ),
    );

    return result;
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
    final saved = _savedInputs[next];
    if (saved != null && _isPosed(saved)) {
      input = saved;
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

    locale = config;

    if (result != null && (regionChanged || languageChanged)) {
      _reanalyzeAndPersist(statusMessage: strings.t('locale_updated'));
    } else if (regionChanged || languageChanged) {
      _persistCurrentMode();
    }
    notifyListeners();
  }

  void updateInput(ScenarioInput i) {
    final posedReset =
        InputEditGuard.isPosedScenarioReset(input.posedQuestion, i.posedQuestion);
    final pathwaysChanged = InputEditGuard.isPathwayStructureChanged(input, i);
    final clearedGrok = <String>{...grokFilledFields};
    for (final key in grokFilledFields) {
      if (i.constructText(key).trim() != input.constructText(key).trim()) {
        clearedGrok.remove(key);
      }
    }
    grokFilledFields = clearedGrok;

    if (posedReset) {
      // New scenario — drop narrative link and prior outcome tied to the old question.
      input = i.copyWith(sourceUrl: '', pathwayConstruals: {});
      result = null;
      grokFilledFields = {};
      statusMessage = null;
    } else if (pathwaysChanged) {
      input = i.copyWith(pathwayConstruals: {});
      result = null;
      grokFilledFields = {};
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

    late final ScenarioInput loadedInput;
    try {
      await _ensureGrokProxyResolved();
      final content = await _fetchNarrativeContent(trimmed);
      loadedInput = input.copyWith(
        sourceUrl: content.url,
        topic: content.title,
        posedQuestion: ScenarioInput.clamp(content.narrative),
        continuumText: '',
        vortexText: '',
        shearText: '',
        resistanceText: '',
        flowText: '',
      );
      input = loadedInput;
      result = null;
      grokFilledFields = {};
      _persistCurrentMode();
      statusMessage = strings.t('link_fetched');
    } on NarrativeLinkException catch (e) {
      statusMessage = switch (e.code) {
        'empty' => strings.t('link_error_empty'),
        'blocked' => strings.t('link_error_blocked'),
        'x_auth_required' => strings.t('link_error_x_auth'),
        _ => strings.t('link_error_fetch'),
      };
      return;
    } catch (_) {
      statusMessage = strings.t('link_error_fetch');
      return;
    } finally {
      isFetchingLink = false;
      notifyListeners();
    }

    try {
      await _populateConstructsFromNarrative(loadedInput);
    } catch (_) {
      if (_usesHeuristicConstrual) {
        try {
          await _applyHeuristicConstrualToForm(loadedInput);
          statusMessage = strings.t('grok_fields_populated');
        } catch (_) {
          statusMessage = strings.t('link_fetched');
        }
      }
      notifyListeners();
    }
  }

  /// Prefer the embedded/hosted Grok proxy (server-side fetch); fall back to direct HTTP.
  Future<NarrativeLinkContent> _fetchNarrativeContent(String trimmed) async {
    final uri = NarrativeLinkReader.normalizeUrl(trimmed)!;
    final needsProxy = NarrativeLinkReader.requiresProxyFetch(uri);

    if (!kIsWeb) {
      try {
        await _ensureGrokProxyReady();
      } catch (_) {
        // Another listener may still be healthy on 8787.
      }
    }

    final proxy = _grokProxyBaseUrl;
    if (proxy.isNotEmpty && await _activeGrokAuth.isProxyReachable()) {
      try {
        return await _linkReader.fetchViaProxy(proxy, trimmed);
      } on NarrativeLinkException catch (e) {
        if (needsProxy || e.code == 'x_auth_required') rethrow;
      }
    }

    if (needsProxy) {
      throw NarrativeLinkException('blocked', cause: uri.host);
    }

    return await _linkReader.fetch(trimmed);
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

    if (grokConstrualEnabled &&
        !grokSession.canConstrue &&
        !_usesHeuristicConstrual) {
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

      await _reanalyze(working);
      _persistCurrentMode();
      statusMessage = grokConstrualEnabled
          ? strings.t('grok_construal_applied')
          : strings.t('status_done');
      isRunning = false;
      notifyListeners();

      await _runPostCalculateWork(working);
    } on GrokAuthException {
      statusMessage = strings.t('grok_construal_failed');
      grokConstrualEnabled = false;
      grokSession = const GrokSession();
      grokFilledFields = {};
    } finally {
      if (isRunning) {
        isRunning = false;
        notifyListeners();
      }
    }
  }

  /// After cohesion narrative link load — fill blank ω/σ/Iτ/Jμ like percent-chance Grok construal.
  Future<void> _populateConstructsFromNarrative(ScenarioInput narrativeInput) async {
    if (narrativeInput.posedQuestion.trim().isEmpty) return;
    if (!grokConstrualEnabled && !_usesHeuristicConstrual) return;

    final generation = ++_construeGeneration;
    isConstruing = true;
    statusMessage = strings.t('grok_construing');
    notifyListeners();

    try {
      try {
        await _ensureGrokProxyReady();
      } catch (_) {
        // Heuristic construal does not require the proxy.
      }

      final canPopulate =
          grokSession.canConstrue || _usesHeuristicConstrual;
      if (!canPopulate) {
        if (generation != _construeGeneration) return;
        statusMessage = strings.t('grok_sign_in_x_required');
        return;
      }
      if (!grokConstrualEnabled) {
        grokConstrualEnabled = true;
      }
      await _fetchAndApplyConstrual(narrativeInput, persistToForm: true);
      if (generation != _construeGeneration) return;
      statusMessage = strings.t('grok_fields_populated');
    } on GrokAuthException {
      if (generation != _construeGeneration) return;
      statusMessage = strings.t('grok_construal_failed');
    } catch (_) {
      if (generation != _construeGeneration) return;
      statusMessage = strings.t('grok_construal_failed');
    } finally {
      if (generation == _construeGeneration) {
        isConstruing = false;
        notifyListeners();
      }
    }
  }

  Future<void> _applyHeuristicConstrualToForm(ScenarioInput source) async {
    final suggestions = NarrativeConstructConstrual.isNarrativeLinked(source)
        ? NarrativeConstructConstrual.suggest(
            input: source,
            locale: locale,
            output: output,
          )
        : GrokHeuristicConstrual.suggest(
            input: source,
            locale: locale,
            output: output,
          );
    final merged = _grokConstrual.applySuggestions(source, suggestions);
    grokFilledFields = _detectGrokFilled(source, merged);
    input = merged;
    _persistCurrentMode();
    notifyListeners();
  }

  Future<void> _runConstrual() async {
    if (!grokConstrualEnabled || input.scenarioQuery.trim().isEmpty) return;
    if (!grokSession.canConstrue && !_usesHeuristicConstrual) return;

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
    if (PathwayConstrualService.shouldFetchPerPathway(source)) {
      final multi = PathwayConstrualService.resolvePathways(source);
      if (multi != null && multi.parts.isNotEmpty) {
        final labels = multi.parts.map((p) => p.label).toList();
        final parentQuestion = source.posedQuestion.trim().isNotEmpty
            ? source.posedQuestion
            : source.scenarioQuery;
        final results = await Future.wait(
          multi.parts.map((item) {
            final sub = source.copyWith(
              posedQuestion: item.subQuestion,
              parentPosedQuestion: parentQuestion,
              activePathwayLabel: item.label,
              siblingPathwayLabels:
                  labels.where((label) => label != item.label).toList(),
              pathwayConstruals: const {},
              continuumText: '',
              vortexText: '',
              shearText: '',
              resistanceText: '',
              flowText: '',
            );
            return _fetchConstrualSuggestions(sub);
          }),
        );
        final withPathways = PathwayConstrualService.applyPerPathwayResults(
          source: source,
          pathwayConstruals:
              PathwayConstrualService.mapFromResults(labels, results),
          labelsInOrder: labels,
        );
        if (persistToForm) {
          grokFilledFields = _detectGrokFilled(source, withPathways);
          input = withPathways;
          _persistCurrentMode();
        }
        return withPathways;
      }
    }

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
      if (NarrativeConstructConstrual.isNarrativeLinked(source)) {
        return NarrativeConstructConstrual.suggest(
          input: source,
          locale: locale,
          output: output,
        );
      }
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
      xSession: grokSession,
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

  Future<void> _reanalyze([ScenarioInput? source]) async {
    final src = source ?? input;
    if (kIsWeb) {
      result = _engine.analyze(src, mode: mode, locale: locale);
      return;
    }
    result = await runEvolveAnalyze(
      input: src,
      mode: mode,
      locale: locale,
    );
  }

  Future<void> _reanalyzeAndPersist({String? statusMessage}) async {
    await _reanalyze();
    _persistCurrentMode();
    if (statusMessage != null) {
      this.statusMessage = statusMessage;
    }
    notifyListeners();
  }

  Future<void> _runPostCalculateWork(ScenarioInput working) async {
    final analysis = result;
    if (analysis == null) return;

    final recorder = scenarioRunRecorder;
    if (recorder != null) {
      await recorder(
        input: working,
        locale: locale,
        mode: mode,
        result: analysis,
      );
    }

    final reward = analysisRewardHandler;
    if (reward != null) {
      final core = analysis.core;
      final outcomeScore = mode == AnalysisMode.percentChance
          ? analysis.percentChance
          : core.refinedScs;
      await reward(
        mode: mode,
        outcomeScore: outcomeScore,
        memo: _analysisRewardMemo(working, mode),
        continuumScs: outcomeScore,
        vortexScs: core.vortexScs,
        shearScs: core.shearScs,
        resistanceScs: core.resistanceScs,
        flowScs: core.flowScs,
      );
    }
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

  String? _analysisRewardMemo(ScenarioInput working, AnalysisMode analysisMode) {
    final prefix = analysisMode == AnalysisMode.percentChance
        ? 'Percent chance'
        : 'Social cohesion score';
    final detail = working.posedQuestion.trim().isNotEmpty
        ? working.posedQuestion.trim()
        : (working.topic.trim().isNotEmpty
            ? working.topic.trim()
            : working.vortexText.trim());
    if (detail.isEmpty) return prefix;
    return '$prefix: $detail';
  }
}