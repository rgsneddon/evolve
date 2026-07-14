import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

void main() {
  test('publish pipeline signs by default without SkipCodeSign', () {
    final publish = evolveRepoFile('scripts/publish_github_release.ps1');
    final text = publish.readAsStringSync();
    expect(
      text.contains('build_installers.ps1" -SkipWindowsBuild -SkipApkBuild -SkipDeploy -SkipCodeSign'),
      isFalse,
      reason: 'publish must not hard-code -SkipCodeSign on build_installers',
    );
    expect(text, contains('Assert-ReleaseSigningCredentials'));
    expect(text, contains('[switch]\$SkipCodeSign'));
  });

  test('android release gradle uses release keystore when key.properties exists', () {
    final gradle = evolveRepoFile('android/app/build.gradle.kts');
    final text = gradle.readAsStringSync();
    expect(text, contains('keystorePropertiesFile'));
    expect(text, contains('create("release")'));
    expect(text, contains('signingConfigs.getByName("release")'));
    expect(
      RegExp(r'release\s*\{[^}]*signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)\s*\}')
          .hasMatch(text),
      isFalse,
      reason: 'release must not unconditionally bind to debug signing',
    );
  });

  test('android installer script verifies APK signatures when not skipping', () {
    final script = evolveRepoFile('scripts/build_android_installer.ps1');
    final text = script.readAsStringSync();
    expect(text, contains('Test-ApkReleaseSignatureBatch'));
    expect(text, contains('Assert-AndroidReleaseSigningReady'));
  });

  test('signing setup examples exist for Windows and Android', () {
    expect(evolveRepoFile('code_sign.local.env.example').existsSync(), isTrue);
    expect(evolveRepoFile('android/key.properties.example').existsSync(), isTrue);
    expect(evolveRepoFile('scripts/setup_android_signing.ps1').existsSync(), isTrue);
  });
}