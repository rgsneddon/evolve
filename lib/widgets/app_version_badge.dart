import 'package:flutter/material.dart';

import '../perc/perc_app_version.dart';

/// Discrete release label shown in the top-right across all builds.
class AppVersionBadge extends StatelessWidget {
  const AppVersionBadge({super.key});

  static String get label =>
      'v${PercAppVersion.releaseOf(PercAppVersion.current)}';

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: Color(0xFF5E6678),
      ),
    );
  }
}