import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/grok_proxy/grok_proxy_store.dart';

void main() {
  test('tokenExchangeHeaders uses Basic Auth for confidential clients', () {
    final headers = tokenExchangeHeaders('client-id', 'client-secret');
    expect(headers['Content-Type'], 'application/x-www-form-urlencoded');
    final auth = headers['Authorization']!;
    expect(auth.startsWith('Basic '), isTrue);
    final decoded = utf8.decode(base64Decode(auth.substring(6)));
    expect(decoded, 'client-id:client-secret');
  });

  test('tokenExchangeHeaders omits Authorization for public clients', () {
    final headers = tokenExchangeHeaders('client-id', '');
    expect(headers.containsKey('Authorization'), isFalse);
  });

  test('tokenExchangeBody includes client_id only for public clients', () {
    final publicBody = tokenExchangeBody(
      code: 'abc',
      clientId: 'client-id',
      clientSecret: '',
      redirectUri: 'http://127.0.0.1:8787/auth/callback',
      codeVerifier: 'verifier',
    );
    expect(publicBody['client_id'], 'client-id');
    expect(publicBody.containsKey('client_secret'), isFalse);

    final confidentialBody = tokenExchangeBody(
      code: 'abc',
      clientId: 'client-id',
      clientSecret: 'secret',
      redirectUri: 'http://127.0.0.1:8787/auth/callback',
      codeVerifier: 'verifier',
    );
    expect(confidentialBody.containsKey('client_id'), isFalse);
    expect(confidentialBody.containsKey('client_secret'), isFalse);
    expect(confidentialBody['code_verifier'], 'verifier');
  });
}