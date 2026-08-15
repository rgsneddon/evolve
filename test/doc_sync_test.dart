import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

String _semverFromPubspec() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) fail('pubspec.yaml missing version line');
  return match.group(1)!;
}

void _expectReadmeSynced(String path, String semver) {
  final readme = File(path).readAsStringSync();
  expect(readme, contains('v$semver'),
      reason: '$path must advertise v$semver');
  expect(readme, isNot(contains('v4.0.8')),
      reason: '$path must not advertise stale v4.0.8');
  expect(readme.toLowerCase(), contains('biometric'),
      reason: '$path must document Android biometric sign-in');
  expect(readme.toLowerCase(), contains('pull'),
      reason: '$path must document Android wallet refresh');
  expect(readme.toLowerCase(), contains('hold-to-reveal'),
      reason: '$path must document hold-to-reveal password');
  expect(readme.toLowerCase(), contains('send re-authentication'),
      reason: '$path must document send re-authentication');
  expect(readme.toLowerCase(), isNot(contains('evolve vpn')),
      reason: '$path must not document removed Evolve VPN');
}

void _expectPrivacySendReAuth(String path) {
  final policy = File(path).readAsStringSync().toLowerCase();
  expect(policy, anyOf(contains('send re-authentication'), contains('send re-auth')),
      reason: '$path must disclose send re-authentication');
  expect(policy, anyOf(contains('outbound'), contains('before an outbound')),
      reason: '$path must scope send re-auth to outbound transfers');
  expect(policy, anyOf(contains('percent chance'), contains('social cohesion'), contains('analysis')),
      reason: '$path must note analysis paths excluded from send re-auth');
}

void _expectPrivacyBiometricDisclosure(String path) {
  final policy = File(path).readAsStringSync().toLowerCase();
  expect(policy, contains('biometric'),
      reason: '$path must disclose biometric sign-in');
  expect(
    policy,
    anyOf(contains('secure storage'), contains('os-backed secure storage')),
    reason: '$path must disclose on-device secure storage',
  );
  expect(policy, anyOf(contains('opt-in'), contains('opt in')),
      reason: '$path must disclose user opt-in');
  expect(policy, isNot(contains('v4.0.0 build 136')),
      reason: '$path must not carry stale v4.0.0 build 136 header only');
  expect(policy, isNot(contains('evolve vpn')),
      reason: '$path must not disclose removed Evolve VPN');
}

File _siblingFile(String repo, String name) {
  return File(
    '${Directory(evolveRepoRoot()).parent.path}${Platform.pathSeparator}$repo${Platform.pathSeparator}$name',
  );
}

void main() {
  test('README version and wallet features match pubspec', () {
    final semver = _semverFromPubspec();
    _expectReadmeSynced('README.md', semver);
  });

  test('privacy policy discloses biometric vault and send re-auth without VPN',
      () {
    _expectPrivacyBiometricDisclosure('privacy_policy.txt');
    _expectPrivacySendReAuth('privacy_policy.txt');
    for (final repo in ['evolve_deploy', 'evolve_ghpages']) {
      final policy = _siblingFile(repo, 'privacy_policy.txt');
      if (!policy.existsSync()) continue;
      _expectPrivacyBiometricDisclosure(policy.path);
      _expectPrivacySendReAuth(policy.path);
    }
  });

  test('LICENSE copies match canonical repo root', () {
    final root = evolveRepoFile('LICENSE').readAsStringSync();
    expect(evolveRepoFile('assets/LICENSE').readAsStringSync(), root);
    String _norm(String text) => text.replaceAll('\r\n', '\n');
    final rootNorm = _norm(root);
    for (final repo in ['evolve_deploy', 'evolve_ghpages']) {
      final license = _siblingFile(repo, 'LICENSE');
      if (license.existsSync()) {
        expect(_norm(license.readAsStringSync()), rootNorm);
      }
      final assetsLicense = _siblingFile(repo, 'assets/LICENSE');
      if (assetsLicense.existsSync()) {
        expect(_norm(assetsLicense.readAsStringSync()), rootNorm);
      }
    }
  });
}