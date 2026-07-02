import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/grok_session.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/grok_auth_client.dart';
import 'package:evolve/services/grok_construal_service.dart';
import 'package:evolve/services/grok_proxy_launcher.dart';

void main() {
  HttpServer? server;
  late int port;
  late String baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server!.port;
    baseUrl = 'http://127.0.0.1:$port';

    server!.listen((request) async {
      final path = request.uri.path;
      if (path == '/health') {
        request.response
          ..statusCode = 200
          ..write('{"ok":true}');
      } else if (path == '/auth/status') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({
            'connected': true,
            'premium': true,
            'screenName': 'test_user',
            'displayName': 'Test User',
            'mock': false,
          }));
      } else if (path == '/auth/login') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({
            'authorizeUrl': '$baseUrl/auth/callback?code=mock&state=mock',
          }));
      } else if (path == '/auth/mock-complete' && request.method == 'POST') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({
            'connected': true,
            'premium': true,
            'screenName': 'test_user',
            'displayName': 'Test User',
            'mock': true,
          }));
      } else if (path == '/construe' && request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(body) as Map<String, dynamic>;
        final question = '${payload['posedQuestion'] ?? ''}';
        request.response
          ..statusCode = 200
          ..write(jsonEncode({
            'vortexText': '',
            'shearText':
                'σ (shear): Grievance levers on "$question" in ${payload['regionLabel']}.',
            'resistanceText': 'Iτ (resistance): Drag levers in ${payload['regionLabel']}.',
            'flowText': '',
            'provenance': 'test',
          }));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server?.close(force: true);
  });

  test('GrokAuthClient reads premium session from proxy', () async {
    final auth = GrokAuthClient(baseUrl: baseUrl);
    expect(await auth.isProxyReachable(), isTrue);
    final session = await auth.fetchStatus();
    expect(session.canConstrue, isTrue);
    expect(session.screenName, 'test_user');
  });

  test('GrokAuthClient completeMockLogin returns mock session not construable', () async {
    final auth = GrokAuthClient(baseUrl: baseUrl);
    final session = await auth.completeMockLogin();
    expect(session.connected, isTrue);
    expect(session.premium, isTrue);
    expect(session.canConstrue, isFalse);
    expect(session.mock, isTrue);
  });

  test('GrokConstrualService fills only blank fields', () async {
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of unrest near-term?',
      shearText: 'User supplied shear bias.',
    );
    final service = GrokConstrualService(baseUrl: baseUrl);
    final suggestions = await service.fetchSuggestions(
      input: input,
      locale: const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );
    final merged = service.applySuggestions(input, suggestions);

    expect(merged.shearText, 'User supplied shear bias.');
    expect(merged.resistanceText, contains('Iτ (resistance)'));
    expect(merged.resistanceText, isNot(contains('UK & Ireland')));
    expect(merged.resistanceText, isNot(contains('"')));
    expect(merged.shearText, isNot(contains('What is the chance')));
  });

  test('embedded GrokProxyLauncher completes mock OAuth in-process', () async {
    final launcher = GrokProxyLauncher.instance;
    final port = 18000 + (DateTime.now().millisecond % 1000);
    await launcher.ensureRunning(port: port);
    expect(launcher.isEmbedded, isTrue);

    final session = await launcher.completeOAuthInProcess('mock', 'mock');
    expect(session.connected, isTrue);
    expect(session.premium, isTrue);
    expect(session.canConstrue, isFalse);
    expect(session.mock, isTrue);
    expect(session.screenName, 'evolve_mock');

    await launcher.stop();
  });

  test('GrokConstrualResult detects suggestions', () {
    const empty = GrokConstrualResult();
    const filled = GrokConstrualResult(shearText: 'x');
    expect(empty.hasSuggestions, isFalse);
    expect(filled.hasSuggestions, isTrue);
  });
}