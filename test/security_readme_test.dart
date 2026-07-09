import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

File _siblingRepoReadme(String repoFolder) {
  return File(
    '${Directory(evolveRepoRoot()).parent.path}${Platform.pathSeparator}$repoFolder${Platform.pathSeparator}README.md',
  );
}

void _expectSecuritySection(String label, String markdown) {
  final lower = markdown.toLowerCase();
  expect(
    lower,
    anyOf(
      contains('security / safe use'),
      contains('## security'),
    ),
    reason: '$label README must have a Security / Safe use section',
  );
  expect(
    lower,
    anyOf(contains('checked regularly'), contains('regular checks')),
    reason: '$label README must state regular security checks',
  );
  expect(lower, contains('sha-256'), reason: '$label README must mention SHA-256 verification');
  expect(
    lower,
    anyOf(
      contains('cannot guarantee'),
      contains('do not guarantee'),
      contains('not guarantee'),
    ),
    reason: '$label README must state scan limitations honestly',
  );
}

void _expectScanScript(String repoRoot, String repoLabel) {
  final scan = File(
    '$repoRoot${Platform.pathSeparator}scripts${Platform.pathSeparator}scan_release_artifacts.ps1',
  );
  expect(scan.existsSync(), isTrue, reason: '$repoLabel scan_release_artifacts.ps1 must exist');
}

void _expectSignOrPublishWiring(String repoRoot, String repoLabel) {
  final scriptsDir = Directory('$repoRoot${Platform.pathSeparator}scripts');
  expect(scriptsDir.existsSync(), isTrue);
  final wired = scriptsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ps1'))
      .any((f) {
    final text = f.readAsStringSync().toLowerCase();
    return text.contains('scan_release_artifacts') ||
        text.contains('invoke-releaseartifactsecurityscan');
  });
  expect(wired, isTrue, reason: '$repoLabel release scripts must invoke security scan');
}

void main() {
  test('evolve README contains security / safe use disclaimer', () {
    final readme = evolveRepoFile('README.md');
    _expectSecuritySection('evolve_app', readme.readAsStringSync());
  });

  test('perccent_wallet README contains security / safe use disclaimer', () {
    final readme = _siblingRepoReadme('perccent_wallet');
    expect(readme.existsSync(), isTrue);
    _expectSecuritySection('perccent_wallet', readme.readAsStringSync());
  });

  test('SECURITY.md documents per-finding exception ids', () {
    final evolveSec = evolveRepoFile('SECURITY.md');
    final walletRoot =
        '${Directory(evolveRepoRoot()).parent.path}${Platform.pathSeparator}perccent_wallet';
    final walletSecurity = File(
      '$walletRoot${Platform.pathSeparator}SECURITY.md',
    );
    expect(evolveSec.existsSync(), isTrue);
    expect(walletSecurity.existsSync(), isTrue);
    final evolveText = evolveSec.readAsStringSync();
    final walletText = walletSecurity.readAsStringSync();
    expect(evolveText, contains('EX-dart_pub_audit_unavailable'));
    expect(walletText, contains('EX-dart_pub_audit_unavailable'));
  });

  test('security scan scripts exist and are wired into release flow', () {
    final evolveRoot = evolveRepoRoot();
    _expectScanScript(evolveRoot, 'evolve_app');
    _expectSignOrPublishWiring(evolveRoot, 'evolve_app');

    final walletRoot =
        '${Directory(evolveRoot).parent.path}${Platform.pathSeparator}perccent_wallet';
    _expectScanScript(walletRoot, 'perccent_wallet');
    _expectSignOrPublishWiring(walletRoot, 'perccent_wallet');

    final verify = File(
      '$walletRoot${Platform.pathSeparator}scripts${Platform.pathSeparator}verify_download_packages.ps1',
    );
    expect(verify.existsSync(), isTrue, reason: 'perccent verify_download_packages.ps1 must exist');
  });
}