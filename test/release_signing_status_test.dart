import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

Map<String, dynamic>? _signingStatusForRelease(String release) {
  final path = evolveRepoFile('build/downloads/v$release/signing-status.json');
  if (!path.existsSync()) return null;
  return jsonDecode(path.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test('downloads pages match signing-status.json probe', () {
    final pubspec = evolveRepoFile('pubspec.yaml').readAsStringSync();
    final release =
        RegExp(r'version:\s*(\d+\.\d+\.\d+)\+').firstMatch(pubspec)!.group(1)!;

    final status = _signingStatusForRelease(release);
    expect(status, isNotNull,
        reason: 'Run scripts/sync_downloads_signing_copy.ps1 to generate signing-status.json');

    final windows = status!['windows'] as Map<String, dynamic>;
    final android = status['android'] as Map<String, dynamic>;
    final windowsSigned = windows['authenticodeSigned'] as bool;
    final androidRelease = android['releaseSigned'] as bool;

    final index = evolveRepoFile('downloads/index.html').readAsStringSync();
    final download = evolveRepoFile('download.html').readAsStringSync();

    for (final html in [index, download]) {
      if (windowsSigned) {
        expect(html, contains('Authenticode-signed'));
        expect(html, isNot(contains('SmartScreen may ask you to confirm until')));
      } else {
        expect(html, contains('SmartScreen may ask you to confirm'));
        expect(html, isNot(contains('Authenticode-signed for a trusted install path')));
      }

      if (androidRelease) {
        expect(html, anyOf(
          contains('release-key signed'),
          contains('Evolve release key (not debug)'),
        ));
      }
    }
  });

  test('signing-status.json exists for probed release artifacts', () {
    final pubspec = evolveRepoFile('pubspec.yaml').readAsStringSync();
    final release =
        RegExp(r'version:\s*(\d+\.\d+\.\d+)\+').firstMatch(pubspec)!.group(1)!;

    final statusPath = evolveRepoFile('build/downloads/v$release/signing-status.json');
    expect(statusPath.existsSync(), isTrue);

    final winSetup = Directory('${evolveRepoRoot()}${Platform.pathSeparator}build${Platform.pathSeparator}downloads${Platform.pathSeparator}v$release')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('windows-x64-setup.exe'))
        .toList();
    expect(winSetup, isNotEmpty);
  });
}