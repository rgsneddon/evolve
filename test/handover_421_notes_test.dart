import 'dart:io';

import 'package:evolve/perc/perc_app_version.dart';
import 'package:flutter_test/flutter_test.dart';

String _pubspecVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*([0-9.]+\+\d+)', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    fail('pubspec.yaml missing version: line');
  }
  return match.group(1)!;
}

String _versionJsonRelease() {
  final raw = File('version.json').readAsStringSync();
  final match = RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(raw);
  if (match == null) {
    fail('version.json missing version field');
  }
  return match.group(1)!;
}

void main() {
  test('shipped pin is 4.2.1 and lockstep across PercAppVersion/pubspec/version.json',
      () {
    final current = PercAppVersion.current;
    expect(PercAppVersion.releaseOf(current), '4.2.1');
    expect(current, _pubspecVersion());
    expect(PercAppVersion.releaseOf(current), _versionJsonRelease());
    expect(PercAppVersion.buildOf(current), greaterThan(180));
  });

  test('Apple handover names 4.2.1, iPad, universal IPA, and sole tag v4.2.1', () {
    final notes = File('docs/HANDOVER_4.2.1_APPLE.md').readAsStringSync();
    expect(notes.contains('4.2.1'), isTrue);
    expect(notes.contains('iPad'), isTrue);
    expect(notes.contains('evolve-v4.2.1-ios-setup.ipa'), isTrue);
    expect(notes.contains('evolve-v4.2.1-macos-x64.zip'), isTrue);
    expect(notes.contains('v4.2.1'), isTrue);
    expect(notes.contains('v4.2.1 only') || notes.contains('`v4.2.1` only'), isTrue);
    expect(notes.contains('TARGETED_DEVICE_FAMILY'), isTrue);
  });

  test('Linux/Arch handover names 4.2.1 tarball, Arch pkg, and sole tag v4.2.1',
      () {
    final notes = File('docs/HANDOVER_4.2.1_LINUX_ARCH.md').readAsStringSync();
    expect(notes.contains('4.2.1'), isTrue);
    expect(notes.contains('evolve-v4.2.1-linux-x64.tar.gz'), isTrue);
    expect(notes.contains('evolve-v4.2.1-archlinux-x86_64.pkg.tar.zst'), isTrue);
    expect(notes.contains('v4.2.1'), isTrue);
    expect(notes.contains('v4.2.1 only') || notes.contains('`v4.2.1` only'), isTrue);
  });

  test('iOS project is iPhone+iPad with iPad orientations', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbx.contains('TARGETED_DEVICE_FAMILY = "1,2"'), isTrue);
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist.contains('UISupportedInterfaceOrientations~ipad'), isTrue);
  });
}
