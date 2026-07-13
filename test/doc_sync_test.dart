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
  expect(readme.toLowerCase(), contains('vpn'),
      reason: '$path must document Evolve VPN');
}

void _expectPrivacyVpnDisclosure(String path) {
  final policy = File(path).readAsStringSync().toLowerCase();
  expect(policy, contains('evolve vpn'),
      reason: '$path must disclose Evolve VPN');
  expect(policy, anyOf(contains('wireguard'), contains('wire guard')),
      reason: '$path must disclose WireGuard bundling');
  expect(policy, anyOf(contains('manual'), contains('connect or disconnect')),
      reason: '$path must disclose manual VPN connect');
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
    final deploy = _siblingFile('evolve_deploy', 'README.md');
    final ghpages = _siblingFile('evolve_ghpages', 'README.md');
    expect(deploy.existsSync(), isTrue);
    expect(ghpages.existsSync(), isTrue);
    _expectReadmeSynced(deploy.path, semver);
    _expectReadmeSynced(ghpages.path, semver);
  });

  test('privacy policy discloses biometric vault, send re-auth, and VPN', () {
    _expectPrivacyBiometricDisclosure('privacy_policy.txt');
    _expectPrivacySendReAuth('privacy_policy.txt');
    _expectPrivacyVpnDisclosure('privacy_policy.txt');
    final deploy = _siblingFile('evolve_deploy', 'privacy_policy.txt');
    final ghpages = _siblingFile('evolve_ghpages', 'privacy_policy.txt');
    _expectPrivacyBiometricDisclosure(deploy.path);
    _expectPrivacyBiometricDisclosure(ghpages.path);
    _expectPrivacySendReAuth(deploy.path);
    _expectPrivacySendReAuth(ghpages.path);
    _expectPrivacyVpnDisclosure(deploy.path);
    _expectPrivacyVpnDisclosure(ghpages.path);
  });

  test('LICENSE copies match canonical repo root', () {
    final root = evolveRepoFile('LICENSE').readAsStringSync();
    expect(evolveRepoFile('assets/LICENSE').readAsStringSync(), root);
    expect(_siblingFile('evolve_deploy', 'LICENSE').readAsStringSync(), root);
    expect(_siblingFile('evolve_deploy', 'assets/LICENSE').readAsStringSync(),
        root);
    expect(_siblingFile('evolve_ghpages', 'LICENSE').readAsStringSync(), root);
    expect(_siblingFile('evolve_ghpages', 'assets/LICENSE').readAsStringSync(),
        root);
  });
}