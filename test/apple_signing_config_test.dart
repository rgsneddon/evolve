import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural checks that Apple hosts are wired to the real Team ID and
/// bundle id — not secrets, just the non-secret DEVELOPMENT_TEAM / identity
/// configuration used for codesigning with the installed Developer ID /
/// Apple Development certificates.
void main() {
  const teamId = 'SFCBP95595';
  const bundleId = 'com.evolve.chronoflux';

  test('macOS AppInfo.xcconfig pins DEVELOPMENT_TEAM and bundle id', () {
    final f = File('macos/Runner/Configs/AppInfo.xcconfig');
    expect(f.existsSync(), isTrue);
    final text = f.readAsStringSync();
    expect(text, contains('DEVELOPMENT_TEAM = $teamId'));
    expect(text, contains('PRODUCT_BUNDLE_IDENTIFIER = $bundleId'));
  });

  test('iOS ExportOptions.plist pins teamID for automatic development export', () {
    final f = File('ios/ExportOptions.plist');
    expect(f.existsSync(), isTrue);
    final text = f.readAsStringSync();
    expect(text, contains('<key>teamID</key>'));
    expect(text, contains('<string>$teamId</string>'));
    expect(text, contains('<string>development</string>'));
    expect(text, contains('<string>automatic</string>'));
  });

  test('iOS Runner pbxproj sets DEVELOPMENT_TEAM on Runner configs', () {
    final f = File('ios/Runner.xcodeproj/project.pbxproj');
    expect(f.existsSync(), isTrue);
    final text = f.readAsStringSync();
    expect(text, contains('DEVELOPMENT_TEAM = $teamId'));
    expect(text, contains('PRODUCT_BUNDLE_IDENTIFIER = $bundleId'));
  });

  test('macOS Runner pbxproj uses Developer ID Application for Release', () {
    final f = File('macos/Runner.xcodeproj/project.pbxproj');
    expect(f.existsSync(), isTrue);
    final text = f.readAsStringSync();
    expect(text, contains('DEVELOPMENT_TEAM = $teamId'));
    expect(text, contains('Developer ID Application'));
  });
}
