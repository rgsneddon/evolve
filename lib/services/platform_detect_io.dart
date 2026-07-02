import 'dart:io' show Platform;

bool get platformIsWeb => false;

bool get platformIsMobile => Platform.isAndroid || Platform.isIOS;