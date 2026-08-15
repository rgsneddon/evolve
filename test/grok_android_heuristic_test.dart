import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_auth_client.dart';

void main() {
  test('login.mock is treated as embedded mock callback', () {
    final localhostMock = Uri.parse(
      'http://127.0.0.1:8787/auth/callback?code=mock&state=mock',
    );
    final mobileMock = Uri.parse('evolve://auth/callback?code=mock&state=mock');

    expect(GrokAuthClient.isEmbeddedMockCallback(localhostMock), isTrue);
    expect(GrokAuthClient.isEmbeddedMockCallback(mobileMock), isFalse);
  });
}