import 'package:flutter/material.dart';

import '../models/locale_config.dart';

/// Region flag — image assets for UK/USA (Windows-safe), emoji for others.
class RegionFlag extends StatelessWidget {
  const RegionFlag({
    super.key,
    required this.regionId,
    this.size = 18,
  });

  final String regionId;
  final double size;

  static const _imageFlags = {
    'uk_ireland': 'assets/flags/gb.png',
    'usa': 'assets/flags/us.png',
    'europe': 'assets/flags/eu.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _imageFlags[regionId];
    if (asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          asset,
          width: size,
          height: size * 0.72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emojiFlag(),
        ),
      );
    }
    return _emojiFlag();
  }

  Widget _emojiFlag() {
    var emoji = '🌐';
    for (final r in LocaleConfig.regions) {
      if (r.id == regionId) {
        emoji = r.flag;
        break;
      }
    }
    return Text(emoji, style: TextStyle(fontSize: size));
  }
}