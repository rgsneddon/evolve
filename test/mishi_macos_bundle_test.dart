import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shipped Mishi.app has its own bundle id and executable', () {
    final plist = File('mishi/Mishi.app/Contents/Info.plist');
    expect(plist.existsSync(), isTrue, reason: 'Mishi.app must be packaged');
    final raw = plist.readAsStringSync();
    expect(raw, contains('<string>com.evolve.mishi</string>'));
    expect(raw, contains('<string>Mishi</string>'));
    expect(raw, isNot(contains('com.evolve.chronoflux')));
    expect(raw, isNot(contains('<string>Evolve</string>')));
    expect(File('mishi/Mishi.app/Contents/MacOS/Mishi').existsSync(), isTrue);
    expect(File('mishi/Mishi.app/Contents/MacOS/Evolve').existsSync(), isFalse);
  });
}
