import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('downloads index matches v3.4.6 build 113 release wording', () {
    final index = File('downloads/index.html');
    expect(index.existsSync(), isTrue, reason: 'downloads/index.html must exist');

    final html = index.readAsStringSync();
    expect(html, contains('v3.4.6'));
    expect(html, contains('build 113'));
    expect(html, contains('Windows setup installer'));
    expect(html, contains('not Authenticode-signed'));
    expect(html, isNot(contains('signed setup package')));
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v3.4.6/evolve-v3.4.6-windows-x64-setup.exe',
      ),
    );
    expect(
      html,
      contains(
        'github.com/rgsneddon/evolve/releases/download/v3.4.6/evolve-v3.4.6-android-setup.apk',
      ),
    );
  });
}