import 'package:flutter_test/flutter_test.dart';

import 'test_paths.dart';

void main() {
  test('downloads index matches current release wording', () {
    final pubspec = evolveRepoFile('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue);
    final pubspecText = pubspec.readAsStringSync();
    final versionMatch =
        RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)').firstMatch(pubspecText);
    expect(versionMatch, isNotNull, reason: 'pubspec version line required');
    final release = versionMatch!.group(1)!;
    final build = versionMatch.group(2)!;

    final index = evolveRepoFile('downloads/index.html');
    expect(index.existsSync(), isTrue, reason: 'downloads/index.html must exist');

    final html = index.readAsStringSync();
    expect(html, contains('v$release'));
    expect(html, contains('build $build'));
    expect(html, contains('Windows setup installer'));
    expect(html, contains('not Authenticode-signed'));
    expect(html, isNot(contains('signed setup package')));
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v$release/evolve-v$release-windows-x64-setup.exe',
      ),
    );
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v$release/evolve-v$release-android-setup.apk',
      ),
    );
  });
}