import 'package:flutter/material.dart';

import 'mishi_desktop/mishi_app.dart';

/// Desktop-only Mishi entry. Do not wire this to iOS/Android targets.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MishiApp());
}
