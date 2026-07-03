import 'dart:io' show Platform;

bool get platformIsWeb => false;

bool get platformIsMobile => Platform.isAndroid || Platform.isIOS;

bool get platformIsMacOS => Platform.isMacOS;