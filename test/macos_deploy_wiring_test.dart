import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/app_update_check.dart';

import 'test_paths.dart';

void main() {
  test('macOS project tree and packaging scripts exist', () {
    for (final path in [
      'macos/Runner.xcodeproj/project.pbxproj',
      'macos/Runner.xcworkspace/contents.xcworkspacedata',
      'macos/Runner/Configs/AppInfo.xcconfig',
      'macos/Runner/Release.entitlements',
      'macos/Runner/Info.plist',
      'macos/SIGNING.md',
      'scripts/build_macos_installer.ps1',
      'scripts/seal_macos_evolve.py',
      'scripts/macos_project_audit.ps1',
      'scripts/lib/macos_build.ps1',
      'docs/MAC_BUILDS.md',
      'installer/macos/README.txt',
    ]) {
      expect(evolveRepoFile(path).existsSync(), isTrue, reason: path);
    }
  });

  test('macOS AppInfo uses Evolve bundle ID and product name', () {
    final appInfo =
        evolveRepoFile('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync();
    expect(appInfo, contains('PRODUCT_BUNDLE_IDENTIFIER = com.evolve.chronoflux'));
    expect(appInfo, contains('PRODUCT_NAME = Evolve'));
  });

  test('macOS signing doc and entitlements support network + DEVELOPMENT_TEAM', () {
    final signing = evolveRepoFile('macos/SIGNING.md').readAsStringSync();
    expect(signing, contains('com.evolve.chronoflux'));
    expect(signing, contains('DEVELOPMENT_TEAM'));
    expect(signing, contains('flutter build macos'));
    expect(signing, contains('notarytool'));
    expect(signing, contains('stapler'));

    final releaseEnt =
        evolveRepoFile('macos/Runner/Release.entitlements').readAsStringSync();
    expect(releaseEnt, contains('network.client'));

    final info = evolveRepoFile('macos/Runner/Info.plist').readAsStringSync();
    expect(info, contains('NSCameraUsageDescription'));
  });

  test('macOS packaging script stages versioned zip under build/downloads', () {
    final script =
        evolveRepoFile('scripts/build_macos_installer.ps1').readAsStringSync();
    expect(script, contains('macos-x64.zip'));
    expect(script, contains(r'build\downloads\v'));
    expect(script, contains('Test-MacosBuildHost'));
    expect(script, contains('SkipMacosBuild'));
    expect(script, contains('Get-EvolveReleaseDownloadBase'));
  });

  test('Mac runbook covers tools, signing, IPA, macOS build, handoff', () {
    final runbook = evolveRepoFile('docs/MAC_BUILDS.md').readAsStringSync();
    expect(runbook, contains('Xcode'));
    expect(runbook, contains('Flutter'));
    expect(runbook, contains('DEVELOPMENT_TEAM'));
    expect(runbook, contains('flutter build ipa'));
    expect(runbook, contains('flutter build macos'));
    expect(runbook, contains('build/downloads'));
    expect(runbook, contains('perccent_wallet'));
    expect(runbook, contains('GitHub Releases'));
    expect(runbook, contains('GITHUB_RELEASES.md'));
    expect(runbook, contains('upload_release_assets.ps1'));
  });

  test('publish and upload attach every platform to vX.Y.Z only', () {
    final policy = evolveRepoFile('docs/GITHUB_RELEASES.md').readAsStringSync();
    expect(policy, contains('vX.Y.Z'));
    expect(policy, contains('This Windows PC'));
    expect(policy, contains('Mac'));
    expect(policy, contains('Never'));
    expect(policy, contains('v4.1.12-macos-ios-android'));

    final publish =
        evolveRepoFile('scripts/publish_github_release.ps1').readAsStringSync();
    expect(publish, contains('Get-EvolveCanonicalReleaseTag'));
    expect(publish, contains('attaching assets to the same version tag'));
    expect(publish, contains('one GitHub Release per version'));

    final upload =
        evolveRepoFile('scripts/upload_release_assets.ps1').readAsStringSync();
    expect(upload, contains('Get-EvolveCanonicalReleaseTag'));
    expect(upload, isNot(contains('macos-ios-android')));

    final winDoc = evolveRepoFile('docs/WINDOWS_RELEASES.md').readAsStringSync();
    expect(winDoc, contains('vX.Y.Z'));
    expect(winDoc, contains('Linux'));
    expect(winDoc, contains('Arch'));
  });

  test('macOS update URLs prefer GitHub Releases zip', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final urls = AppUpdateChecker.updateUrlsForRelease('4.1.8');
    expect(urls.first, contains('evolve-v4.1.8-macos-x64.zip'));
    expect(
      urls.first,
      contains('github.com/rgsneddon/evolve/releases/download/v4.1.8'),
    );
  });

  test('macos_project_audit.ps1 encodes expected bundle id', () {
    final audit =
        evolveRepoFile('scripts/macos_project_audit.ps1').readAsStringSync();
    expect(audit, contains('com.evolve.chronoflux'));
    expect(audit, contains('AppInfo.xcconfig'));
  });
}
