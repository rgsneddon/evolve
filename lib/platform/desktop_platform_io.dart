import 'dart:io' show Platform;

/// Flutter sets FLUTTER_TEST=true while `flutter test` is running.
bool get isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';