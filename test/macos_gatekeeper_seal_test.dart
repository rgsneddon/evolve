import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

void main() {
  test('Release entitlements forbid get-task-allow via shipped seal script', () {
    final result = Process.runSync(
      'python3',
      ['scripts/seal_macos_evolve.py', '--check-entitlements'],
      workingDirectory: evolveRepoRoot(),
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout.toString(), contains('entitlements_ok'));
  });

  test('seal_macos_evolve.py is the Developer ID + notary + staple path', () {
    final script =
        evolveRepoFile('scripts/seal_macos_evolve.py').readAsStringSync();
    expect(script, contains('Developer ID Application'));
    expect(script, contains('--options'));
    expect(script, contains('runtime'));
    expect(script, contains('--timestamp'));
    expect(script, contains('notarytool'));
    expect(script, contains('--wait'));
    expect(script, contains('stapler'));
    expect(script, contains('staple'));
    expect(script, contains('ditto'));
    expect(script, contains('--keepParent'));
    expect(script, contains('get-task-allow'));
    expect(script, isNot(contains('xattr -d com.apple.quarantine')));
  });

  test('Release.entitlements does not enable a debugger', () {
    final text =
        evolveRepoFile('macos/Runner/Release.entitlements').readAsStringSync();
    expect(text, isNot(contains('get-task-allow')));
    expect(text, contains('network.client'));
  });
}
